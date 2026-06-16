import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'cached_playback_url.dart';
import 'device_constraints.dart';
import 'network_policy.dart';
import 'media_kit_player_pool.dart';
import 'video_player_pool.dart';
import 'video_preload_target.dart';
import 'video_source_resolver.dart';
import '../../services/feature_flags/remote_config_service.dart';
import '../../services/settings/settings_service.dart';

typedef VideoPreloadBuilder = VideoPreloadTarget? Function(int index);

class VideoPreloadManager {
  VideoPreloadManager({
    required VideoPreloadBuilder sourceBuilder,
    VideoPlayerPool? pool,
    MediaKitPlayerPool? mediaKitPool,
    this.useMediaKit = true,
    this.decoderWarmEnabled = true,
    NetworkPolicy? networkPolicy,
    DeviceConstraints? deviceConstraints,
    BaseCacheManager? cacheManager,
  }) : _sourceBuilder = sourceBuilder,
       _pool = pool ?? VideoPlayerPool.instance,
       _mediaKitPool = mediaKitPool ?? MediaKitPlayerPool.instance,
       _networkPolicy = networkPolicy ?? NetworkPolicy(),
       _deviceConstraints = deviceConstraints ?? DeviceConstraints(),
       _cacheManager = cacheManager ?? DefaultCacheManager();

  /// When false, only disk-prefetch runs — no off-screen MediaKit decoders.
  /// Home enables this after the visible reel paints its first frame; profile
  /// keeps it off so MTK never holds more than one decoder.
  bool decoderWarmEnabled;

  final VideoPreloadBuilder _sourceBuilder;
  final VideoPlayerPool _pool;
  final MediaKitPlayerPool _mediaKitPool;
  final bool useMediaKit;
  final NetworkPolicy _networkPolicy;
  final DeviceConstraints _deviceConstraints;
  final BaseCacheManager _cacheManager;
  int _lastPreloadIndex = -1;
  bool _diskBootstrapDone = false;
  bool _decoderBootstrapDone = false;

  /// Lets each feed tab (General / Near Me / Following) run its own bootstrap
  /// prefetch after a tab switch instead of reusing the first tab's warm state.
  void resetForTabSwitch() {
    _diskBootstrapDone = false;
    _decoderBootstrapDone = false;
    _lastPreloadIndex = -1;
    decoderWarmEnabled = false;
  }

  /// Called before attaching a new visible reel so MTK keeps a single decoder
  /// until the first frame paints (off-screen warm stays disk-only until then).
  void prepareForVisibleAttach() {
    decoderWarmEnabled = false;
    _decoderBootstrapDone = false;
  }

  /// Disk-prefetch ahead immediately; decoder warm waits until [decoderWarmEnabled].
  Future<void> bootstrapFromVisible(int visibleIndex) async {
    if (!await _canPreload()) {
      return;
    }
    // Do not warm the visible index — [ReelVideoPlayer] acquires it on the
    // priority lane; warming it here races for decoders and can block first play.
    final diskDepth = await _resolvePreloadDepth();
    final bootstrapIndices = <int>[
      for (var step = 1; step <= diskDepth; step++) visibleIndex + step,
      visibleIndex - 1,
    ];
    if (!_diskBootstrapDone) {
      _diskBootstrapDone = true;
      unawaited(
        _warmIndices(
          bootstrapIndices,
          reason: 'bootstrap_disk',
          decoderWarmLimit: 0,
        ),
      );
    }
    if (!decoderWarmEnabled || _decoderBootstrapDone) {
      return;
    }
    _decoderBootstrapDone = true;
    unawaited(
      _warmIndices(
        [visibleIndex + 1],
        reason: 'bootstrap_decoder',
        decoderWarmLimit: _mediaKitPool.maxWarmSlots,
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
    final networkClass = await _networkPolicy.currentNetworkClass();
    final ordered = const VideoSourceResolver().prioritizeForNetwork(
      target.candidates,
      networkClass,
    );
    final chosen = ordered.first;
    final url = await _playbackUrl(chosen.url, networkClass);
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
    // Bytes only while dragging — never spawn a second MTK decoder mid-swipe.
    await _warmIndices(
      indices.toList(),
      reason: 'scroll_start',
      decoderWarmLimit: 0,
    );
  }

  Future<void> onVisibleIndexChanged(int currentIndex) async {
    if (!await _canPreload()) {
      return;
    }

    // Disk prefetch goes deep (just MP4 bytes, no decoder); decoder warm-up
    // stays shallow (hardware codec is scarce). Decoupling these is what makes
    // each swipe instant without starving the visible reel's decoder.
    final diskDepth = await _resolvePreloadDepth();
    if (diskDepth <= 0) {
      return;
    }
    // Feed ping-pong owns both decoders on phone — never spawn a third via warmUp.
    final decoderDepth = useMediaKit && _mediaKitPool.maxWarmSlots == 0
        ? 0
        : diskDepth.clamp(0, _mediaKitPool.maxWarmSlots);

    if (currentIndex == _lastPreloadIndex &&
        _deviceConstraints.shouldThrottleFastSwipe()) {
      return;
    }
    _lastPreloadIndex = currentIndex;

    final indices = <int>[];
    for (var step = 1; step <= diskDepth; step++) {
      indices.add(currentIndex + step);
    }
    indices.add(currentIndex - 1);
    indices.add(currentIndex - 2);

    await _warmIndices(
      indices,
      reason: 'page_settled',
      decoderWarmLimit: decoderDepth,
    );

    if (useMediaKit) {
      unawaited(_prefetchFeedSlotAhead(currentIndex));
    }

    const releaseWindow = 3;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () {
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

  /// Opens the next reel on the feed ping-pong hidden slot (muted demux ahead).
  Future<void> _prefetchFeedSlotAhead(int currentIndex) async {
    final nextTarget = _sourceBuilder(currentIndex + 1);
    if (nextTarget == null ||
        nextTarget.candidates.isEmpty ||
        nextTarget.key.isEmpty) {
      return;
    }
    const resolver = VideoSourceResolver();
    final networkClass = await _networkPolicy.currentNetworkClass();
    final ordered = resolver.prioritizeForNetwork(
      nextTarget.candidates,
      networkClass,
    );
    if (ordered.isEmpty) {
      return;
    }
    final playbackUrl = await _playbackUrl(ordered.first.url, networkClass);
    await _mediaKitPool.prefetchFeedReel(
      key: nextTarget.key,
      sourceUrl: playbackUrl,
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
    int? decoderWarmLimit,
  }) async {
    const resolver = VideoSourceResolver();
    final networkClass = await _networkPolicy.currentNetworkClass();
    final seenKeys = <String>{};
    var decodersWarmed = 0;

    for (final index in indices) {
      final target = _sourceBuilder(index);
      if (target == null || target.candidates.isEmpty || target.key.isEmpty) {
        continue;
      }
      if (!seenKeys.add(target.key)) {
        continue;
      }
      final ordered = resolver.prioritizeForNetwork(
        target.candidates,
        networkClass,
      );
      final chosen = ordered.first;
      final isHls = chosen.url.toLowerCase().contains('.m3u8');
      // Disk prefetch the playback tier (720p) for every index — bytes only,
      // no decoder, so it's safe to go deep. This is what makes a reel paint
      // instantly when it becomes visible: the bytes are already cached.
      if (!isHls) {
        prefetchPlaybackUrl(chosen.url, cacheManager: _cacheManager);
      }
      // Open a decoder only for the shallow window (scarce hardware resource).
      final canWarmDecoder =
          decoderWarmLimit == null || decodersWarmed < decoderWarmLimit;
      if (useMediaKit && decoderWarmEnabled && canWarmDecoder) {
        final playbackUrl = await _playbackUrl(chosen.url, networkClass);
        unawaited(
          _mediaKitPool.warmUp(key: target.key, sourceUrl: playbackUrl),
        );
        decodersWarmed++;
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

  Future<String> _playbackUrl(String remoteUrl, NetworkClass network) async {
    if (network == NetworkClass.offline ||
        remoteUrl.toLowerCase().contains('.m3u8')) {
      return remoteUrl;
    }
    return resolveCachedPlaybackUrl(remoteUrl, cacheManager: _cacheManager);
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
