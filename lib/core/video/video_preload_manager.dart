import 'dart:async';

import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'cached_playback_url.dart';
import 'device_constraints.dart';
import 'network_policy.dart';
import 'media_kit_player_pool.dart';
import 'reels_perf.dart';
import 'video_player_pool.dart';
import 'video_preload_target.dart';
import 'video_source_resolver.dart';
import 'prefetch_indices.dart';
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
       _deviceConstraints = deviceConstraints ?? DeviceConstraints.instance,
       _cacheManager =
           cacheManager ?? ReelsVideoCacheManager.instance.manager;

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

  /// Tab switch / cold session — resets decoder warm pipeline.
  void prepareForSessionStart() {
    decoderWarmEnabled = false;
    _decoderBootstrapDone = false;
  }

  /// Normal page settle — keeps decoder warm once the visible reel has painted.
  void onVisiblePageSettled() {
    // Intentionally no-op: decoder warm persists across swipes for consistency.
  }

  /// @deprecated Use [prepareForSessionStart] for tab/overlay; [onVisiblePageSettled] for swipes.
  void prepareForVisibleAttach() => prepareForSessionStart();

  /// Disk-prefetch ahead immediately; decoder warm waits until [decoderWarmEnabled].
  Future<void> bootstrapFromVisible(int visibleIndex) async {
    if (!await _canPreload()) {
      return;
    }
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
          visibleIndex: visibleIndex,
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
        visibleIndex: visibleIndex,
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
    final ordered = const VideoSourceResolver().prioritizeForPreload(
      target.candidates,
      offsetFromVisible: 1,
      dualTier: RemoteConfigService.instance.reelsDualTierPreload,
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
    int extraDepth = 0,
  }) async {
    if (!await _canPreload()) {
      return;
    }
    await _deviceConstraints.ensureInitialized();
    final depth = await _resolvePreloadDepth();
    final indices = buildDirectionalPrefetchIndices(
      fromIndex: fromIndex,
      towardIndex: towardIndex,
      depth: depth,
      extraDepth: extraDepth,
    );
    await _warmIndices(
      indices,
      reason: 'scroll_start',
      decoderWarmLimit: 0,
      visibleIndex: fromIndex,
    );
  }

  /// Scroll past ~45% — demux-ahead on hidden slot or buffer-only warm.
  Future<void> onScrollDemuxAhead({
    required int towardIndex,
    required int fromIndex,
  }) async {
    if (!await _canPreload()) {
      return;
    }
    await _deviceConstraints.ensureInitialized();
    if (!_deviceConstraints.scrollDemuxPrefetchEnabled) {
      return;
    }
    await _prefetchFeedSlotForIndex(
      towardIndex,
      offsetFromVisible: (towardIndex - fromIndex).abs().clamp(1, 3),
    );
  }

  Future<void> onVisibleIndexChanged(int currentIndex) async {
    if (!await _canPreload()) {
      return;
    }

    ReelsVideoCacheManager.instance.cancelBelowPriority(40);

    final diskDepth = await _resolvePreloadDepth();
    if (diskDepth <= 0) {
      return;
    }
    final decoderDepth = useMediaKit && _mediaKitPool.maxWarmSlots == 0
        ? 0
        : diskDepth.clamp(0, _mediaKitPool.maxWarmSlots);

    final throttleDecoder = _deviceConstraints.shouldThrottleDecoderWarm();
    _lastPreloadIndex = currentIndex;

    final indices = buildSettledPrefetchIndices(
      visibleIndex: currentIndex,
      depth: diskDepth,
    );

    await _warmIndices(
      indices,
      reason: 'page_settled',
      decoderWarmLimit: throttleDecoder ? 0 : decoderDepth,
      visibleIndex: currentIndex,
    );

    if (!throttleDecoder && useMediaKit) {
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

  Future<void> _prefetchFeedSlotAhead(int currentIndex) async {
    await _prefetchFeedSlotForIndex(currentIndex + 1, offsetFromVisible: 1);
  }

  Future<void> _prefetchFeedSlotForIndex(
    int index, {
    int offsetFromVisible = 1,
  }) async {
    final nextTarget = _sourceBuilder(index);
    if (nextTarget == null ||
        nextTarget.candidates.isEmpty ||
        nextTarget.key.isEmpty) {
      return;
    }
    const resolver = VideoSourceResolver();
    final networkClass = await _networkPolicy.currentNetworkClass();
    final dualTier = RemoteConfigService.instance.reelsDualTierPreload;
    final ordered = resolver.prioritizeForPreload(
      nextTarget.candidates,
      offsetFromVisible: offsetFromVisible,
      dualTier: dualTier,
    );
    if (ordered.isEmpty) {
      return;
    }
    final chosen = ordered.first;
    final playbackUrl = await _playbackUrl(chosen.url, networkClass);
    final tier = resolver.mp4Tier(chosen.url) ?? 'other';
    final cached = await isPlaybackUrlCached(
      chosen.url,
      cacheManager: _cacheManager,
    );
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'prefetch_slot',
        tier: tier,
        cacheHit: cached,
        extra: {'index': index},
      ),
    );
    await _mediaKitPool.scheduleDemuxAhead(
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

  int _priorityForIndex(int index, int visibleIndex) {
    final delta = index - visibleIndex;
    if (delta == 1) {
      return 100;
    }
    if (delta == 2) {
      return 90;
    }
    if (delta == 3) {
      return 80;
    }
    if (delta == -1) {
      return 70;
    }
    return 50;
  }

  Future<void> _warmIndices(
    List<int> indices, {
    required String reason,
    int? decoderWarmLimit,
    required int visibleIndex,
  }) async {
    const resolver = VideoSourceResolver();
    final networkClass = await _networkPolicy.currentNetworkClass();
    final dualTier = RemoteConfigService.instance.reelsDualTierPreload;
    final isTablet = _mediaKitPool.maxWarmSlots > 1;
    final seenKeys = <String>{};
    var decodersWarmed = 0;

    for (var pos = 0; pos < indices.length; pos++) {
      final index = indices[pos];
      final target = _sourceBuilder(index);
      if (target == null || target.candidates.isEmpty || target.key.isEmpty) {
        continue;
      }
      if (!seenKeys.add(target.key)) {
        continue;
      }
      final offset = (index - visibleIndex).abs();
      final preloadOrdered = resolver.prioritizeForPreload(
        target.candidates,
        offsetFromVisible: offset.clamp(1, 99),
        dualTier: dualTier,
      );
      final priority = _priorityForIndex(index, visibleIndex);
      for (final chosen in preloadOrdered) {
        final isHls = chosen.url.toLowerCase().contains('.m3u8');
        if (!isHls) {
          prefetchPlaybackUrl(
            chosen.url,
            cacheManager: _cacheManager,
            priority: priority,
            isTablet: isTablet,
          );
        }
      }
      final chosen = preloadOrdered.first;
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
    ReelsPerf.log('warm reason=$reason count=${seenKeys.length}');
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
    return resolveBestPlaybackUrl(remoteUrl, cacheManager: _cacheManager);
  }

  Future<int> _resolvePreloadDepth() async {
    final isDataSaver = SettingsService.instance.dataSaverEnabled.value;
    if (isDataSaver) {
      return 0;
    }
    await _deviceConstraints.ensureInitialized();
    if (_deviceConstraints.deviceTierSync == ReelsDeviceTier.c) {
      return 2;
    }
    final networkClass = await _networkPolicy.currentNetworkClass();
    switch (networkClass) {
      case NetworkClass.wifi:
        return RemoteConfigService.instance.preloadLimitWifi.clamp(3, 5);
      case NetworkClass.mobile:
        return RemoteConfigService.instance.preloadLimitMobile.clamp(3, 5);
      case NetworkClass.offline:
        return 0;
    }
  }
}
