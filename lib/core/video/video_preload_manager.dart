import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'device_constraints.dart';
import 'network_policy.dart';
import 'media_kit_player_pool.dart';
import 'video_player_pool.dart';
import 'video_preload_target.dart';
import '../../services/feature_flags/remote_config_service.dart';
import '../../services/settings/settings_service.dart';

typedef VideoPreloadBuilder = VideoPreloadTarget? Function(int index);

class VideoPreloadManager {
  VideoPreloadManager({
    required VideoPreloadBuilder sourceBuilder,
    VideoPlayerPool? pool,
    MediaKitPlayerPool? mediaKitPool,
    this.useMediaKit = true,
    NetworkPolicy? networkPolicy,
    DeviceConstraints? deviceConstraints,
    BaseCacheManager? cacheManager,
  }) : _sourceBuilder = sourceBuilder,
       _pool = pool ?? VideoPlayerPool.instance,
       _mediaKitPool = mediaKitPool ?? MediaKitPlayerPool.instance,
       _networkPolicy = networkPolicy ?? NetworkPolicy(),
       _deviceConstraints = deviceConstraints ?? DeviceConstraints(),
       _cacheManager = cacheManager ?? DefaultCacheManager();

  final VideoPreloadBuilder _sourceBuilder;
  final VideoPlayerPool _pool;
  final MediaKitPlayerPool _mediaKitPool;
  final bool useMediaKit;
  final NetworkPolicy _networkPolicy;
  final DeviceConstraints _deviceConstraints;
  final BaseCacheManager _cacheManager;
  int _lastPreloadIndex = -1;
  bool _bootstrapDone = false;

  /// Warm visible + next 3 reels as soon as the feed is available.
  Future<void> bootstrapFromVisible(int visibleIndex) async {
    if (_bootstrapDone) {
      return;
    }
    if (!await _canPreload()) {
      return;
    }
    _bootstrapDone = true;
    // Do not warm the visible index — [ReelVideoPlayer] acquires it on the
    // priority lane; warming it here races for decoders and can block first play.
    unawaited(
      _warmIndices(
        [
          visibleIndex + 1,
          visibleIndex + 2,
          visibleIndex + 3,
          visibleIndex - 1,
        ],
        reason: 'bootstrap',
      ),
    );
  }

  /// Priority warm for session restore / visible reel (up to [maxWaitMs]).
  Future<void> warmIndexNow(int index, {int maxWaitMs = 2200}) async {
    if (!await _canPreload()) {
      return;
    }
    final target = _sourceBuilder(index);
    if (target == null || target.candidates.isEmpty || target.key.isEmpty) {
      return;
    }
    final url = target.candidates.first.url;
    if (useMediaKit) {
      if (_mediaKitPool.isWarmed(target.key)) {
        return;
      }
      unawaited(
        _mediaKitPool.warmUp(key: target.key, sourceUrl: url),
      );
      var waited = 0;
      while (waited < maxWaitMs) {
        if (_mediaKitPool.isWarmed(target.key)) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
        waited += 16;
      }
    }
  }

  /// Called when the user starts dragging toward another page (before settle).
  Future<void> onScrollToward({
    required int fromIndex,
    required int towardIndex,
  }) async {
    if (!await _canPreload()) {
      return;
    }
    final depth = await _resolvePreloadDepth();
    final indices = <int>{
      towardIndex,
      towardIndex + 1,
      towardIndex + 2,
      towardIndex - 1,
      fromIndex + 1,
      fromIndex + 2,
      fromIndex - 1,
    };
    for (var step = 1; step <= depth; step++) {
      indices.add(towardIndex + step);
      indices.add(fromIndex + step);
    }
    await _warmIndices(indices.toList(), reason: 'scroll_start');
  }

  Future<void> onVisibleIndexChanged(int currentIndex) async {
    if (!await _canPreload()) {
      return;
    }

    final preloadDepth = await _resolvePreloadDepth();
    if (preloadDepth <= 0) {
      return;
    }

    if (currentIndex == _lastPreloadIndex &&
        _deviceConstraints.shouldThrottleFastSwipe()) {
      return;
    }
    _lastPreloadIndex = currentIndex;

    final indices = <int>[];
    for (var step = 1; step <= preloadDepth; step++) {
      indices.add(currentIndex + step);
    }
    indices.add(currentIndex - 1);
    indices.add(currentIndex - 2);

    await _warmIndices(indices, reason: 'page_settled');

    const releaseWindow = 5;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (useMediaKit) {
          unawaited(
            _mediaKitPool.releaseFarFrom(
              currentIndex,
              window: releaseWindow,
              keyResolver: _resolveKey,
            ),
          );
        } else {
          unawaited(
            _pool.releaseFarFrom(
              currentIndex,
              window: releaseWindow,
              keyResolver: _resolveKey,
            ),
          );
        }
      }),
    );
  }

  Future<bool> _canPreload() async {
    if (!RemoteConfigService.instance.preloadEnabled) {
      return false;
    }
    if (await _deviceConstraints.isBatteryLow()) {
      return false;
    }
    final depth = await _resolvePreloadDepth();
    return depth > 0;
  }

  Future<void> _warmIndices(
    List<int> indices, {
    required String reason,
  }) async {
    final networkClass = await _networkPolicy.currentNetworkClass();
    final seenKeys = <String>{};

    for (final index in indices) {
      final target = _sourceBuilder(index);
      if (target == null || target.candidates.isEmpty || target.key.isEmpty) {
        continue;
      }
      if (!seenKeys.add(target.key)) {
        continue;
      }
      final chosen = target.candidates.first;
      final isHls = chosen.url.toLowerCase().contains('.m3u8');
      if (networkClass == NetworkClass.wifi && !isHls) {
        unawaited(_cacheManager.downloadFile(chosen.url));
      }
      if (useMediaKit) {
        unawaited(
          _mediaKitPool.warmUp(key: target.key, sourceUrl: chosen.url),
        );
      }
    }
  }

  String? _resolveKey(int index) {
    final target = _sourceBuilder(index);
    if (target == null || target.key.isEmpty) {
      return null;
    }
    return target.key;
  }

  Future<int> _resolvePreloadDepth() async {
    final isDataSaver = SettingsService.instance.dataSaverEnabled.value;
    if (isDataSaver) {
      return 0;
    }
    final networkClass = await _networkPolicy.currentNetworkClass();
    switch (networkClass) {
      case NetworkClass.wifi:
        return RemoteConfigService.instance.preloadLimitWifi.clamp(3, 4);
      case NetworkClass.mobile:
        return RemoteConfigService.instance.preloadLimitMobile.clamp(2, 3);
      case NetworkClass.offline:
        return 0;
    }
  }
}
