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
  bool _diskBootstrapDone = false;
  bool _decoderBootstrapDone = false;

  /// Lets each feed tab (General / Near Me / Following) run its own bootstrap
  /// prefetch after a tab switch instead of reusing the first tab's warm state.
  void resetForTabSwitch() {
    _diskBootstrapDone = false;
    _decoderBootstrapDone = false;
    // Each tab must gate decoder warm on its own first visible paint —
    // leaving this true leaks orphan warm tasks from the previous tab.
    decoderWarmEnabled = false;
  }

  /// Tab switch / cold session — resets decoder warm pipeline.
  void prepareForSessionStart() {
    decoderWarmEnabled = false;
    _decoderBootstrapDone = false;
    // Allow a fresh near-window disk warm after tab/overlay return.
    _diskBootstrapDone = false;
  }

  /// Normal page settle — keeps decoder warm once the visible reel has painted.
  void onVisiblePageSettled() {
    // Intentionally no-op: decoder warm persists across swipes for consistency.
  }

  /// @deprecated Use [prepareForSessionStart] for tab/overlay; [onVisiblePageSettled] for swipes.
  void prepareForVisibleAttach() => prepareForSessionStart();

  /// Disk-prefetch the visible reel (+ N+1) so the open can hit local bytes.
  ///
  /// Waits up to [maxWaitMs] for the preferred tier to land on disk.
  Future<void> prefetchVisibleReel(
    int visibleIndex, {
    int maxWaitMs = 700,
  }) async {
    if (!await _canPreload()) {
      return;
    }
    // Near window: visible + the next *video*. Warming a wide [+1..+3] window
    // here diluted download bandwidth during fast swipe bursts (N+1 kept
    // missing cache), so keep the window at two targets — but skip photo
    // posts (no candidates) when picking "next" so a run of photos doesn't
    // leave the following video un-prefetched.
    final nextVideoIndex = _nextVideoIndexAfter(visibleIndex);
    await _warmIndices(
      [
        visibleIndex,
        if (nextVideoIndex != null) nextVideoIndex,
      ],
      reason: 'visible_now',
      decoderWarmLimit: 0,
      visibleIndex: visibleIndex,
      // The first video after a photo run must keep N+1 priority even when
      // its raw index delta is +2/+3, or scroll-start cancels its download.
      priorityOverrides: nextVideoIndex == null
          ? null
          : {nextVideoIndex: 100},
    );
    if (maxWaitMs <= 0) {
      return;
    }
    await _awaitPartialCacheForIndex(visibleIndex, maxWaitMs: maxWaitMs);
  }

  /// First index after [visibleIndex] with real video candidates, scanning a
  /// few slots ahead so photo posts (no candidates) are skipped.
  int? _nextVideoIndexAfter(int visibleIndex, {int scan = 8}) {
    for (var i = visibleIndex + 1; i <= visibleIndex + scan; i++) {
      final target = _sourceBuilder(i);
      if (target != null &&
          target.candidates.isNotEmpty &&
          target.key.isNotEmpty) {
        return i;
      }
    }
    return null;
  }

  /// Near-window indices that skip photo gaps so N+1/N+2 *videos* get disk
  /// bytes (raw +1/+2 often lands on photos and wastes warm slots).
  List<int> _videoBridgedWarmIndices({
    required int visibleIndex,
    required int depth,
    int? towardIndex,
  }) {
    final indices = <int>{visibleIndex, if (towardIndex != null) towardIndex};
    var foundForward = 0;
    final forwardStart = towardIndex ?? visibleIndex;
    for (var i = forwardStart + 1;
        i <= forwardStart + 14 && foundForward < depth;
        i++) {
      final target = _sourceBuilder(i);
      if (target != null &&
          target.candidates.isNotEmpty &&
          target.key.isNotEmpty) {
        indices.add(i);
        foundForward++;
      }
    }
    for (var i = visibleIndex - 1; i >= visibleIndex - 8; i--) {
      final target = _sourceBuilder(i);
      if (target != null &&
          target.candidates.isNotEmpty &&
          target.key.isNotEmpty) {
        indices.add(i);
        break;
      }
    }
    return indices.toList();
  }

  /// Await until the preferred ladder URL for [index] is on disk.
  ///
  /// flutter_cache_manager only exposes the file after a **full** download, so
  /// we await the in-flight completer (capped) rather than polling for a
  /// partial that never appears mid-flight.
  Future<bool> _awaitPartialCacheForIndex(
    int index, {
    required int maxWaitMs,
  }) async {
    final target = _sourceBuilder(index);
    if (target == null || target.candidates.isEmpty) {
      return false;
    }
    const resolver = VideoSourceResolver();
    final ordered = resolver.prioritizeForPreload(
      target.candidates,
      offsetFromVisible: 0,
      dualTier: RemoteConfigService.instance.reelsDualTierPreload,
    );
    if (ordered.isEmpty) {
      return false;
    }

    for (final chosen in ordered) {
      if (await isPlaybackUrlCached(chosen.url, cacheManager: _cacheManager)) {
        ReelsPerf.log(
          'partial_ready index=$index tier=${resolver.mp4Tier(chosen.url)} '
          'waitMs=0',
        );
        return true;
      }
    }

    final cacheManager = ReelsVideoCacheManager.instance;
    final preferred = ordered.first;
    if (!cacheManager.isQueuedOrInFlight(preferred.url)) {
      prefetchPlaybackUrl(
        preferred.url,
        cacheManager: _cacheManager,
        priority: 120,
      );
    }
    final started = DateTime.now().millisecondsSinceEpoch;
    await cacheManager.waitForUrl(preferred.url, maxWaitMs: maxWaitMs);
    if (await isPlaybackUrlCached(
      preferred.url,
      cacheManager: _cacheManager,
    )) {
      ReelsPerf.log(
        'partial_ready index=$index tier=${resolver.mp4Tier(preferred.url)} '
        'waitMs=${DateTime.now().millisecondsSinceEpoch - started}',
      );
      return true;
    }
    // Brief poll in case another tier finished first.
    for (final chosen in ordered) {
      if (await isPlaybackUrlCached(chosen.url, cacheManager: _cacheManager)) {
        return true;
      }
    }
    return false;
  }

  /// Disk-prefetch ahead immediately; decoder warm waits until [decoderWarmEnabled].
  Future<void> bootstrapFromVisible(int visibleIndex) async {
    if (!await _canPreload()) {
      return;
    }
    final diskDepth = await _resolvePreloadDepth();
    final bootstrapIndices = _videoBridgedWarmIndices(
      visibleIndex: visibleIndex,
      depth: diskDepth,
    );
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
    final nextVideo = _nextVideoIndexAfter(visibleIndex);
    unawaited(
      _warmIndices(
        [nextVideo ?? visibleIndex + 1],
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
    _deviceConstraints.recordSwipe();
    // Starve far downloads so bandwidth feeds the reel you're swiping to
    // (same idea as TikTok/IG near-window reservation).
    ReelsVideoCacheManager.instance.cancelBelowPriority(90);
    var depth = await _resolvePreloadDepth();
    if (_deviceConstraints.needsConstrainedSurfaceRecovery) {
      // Still warm toward +1/+2 on Honor — clamping too hard left fling
      // landings cold HTTPS every time.
      depth = depth.clamp(2, 3);
      extraDepth = extraDepth.clamp(0, 1);
    }
    final effectiveDepth = depth + extraDepth;
    final towardVideo = () {
      final t = _sourceBuilder(towardIndex);
      if (t != null && t.candidates.isNotEmpty && t.key.isNotEmpty) {
        return towardIndex;
      }
      return towardIndex > fromIndex
          ? _nextVideoIndexAfter(towardIndex - 1)
          : null;
    }();
    final indices = _videoBridgedWarmIndices(
      visibleIndex: fromIndex,
      depth: effectiveDepth,
      towardIndex: towardVideo ?? towardIndex,
    );
    final priorityOverrides = <int, int>{};
    if (towardVideo != null) {
      priorityOverrides[towardVideo] = 120;
      final nextAfterToward = _nextVideoIndexAfter(towardVideo);
      if (nextAfterToward != null) {
        priorityOverrides[nextAfterToward] = 100;
      }
    }
    await _warmIndices(
      indices,
      reason: 'scroll_start',
      decoderWarmLimit: 0,
      visibleIndex: towardIndex,
      priorityOverrides:
          priorityOverrides.isEmpty ? null : priorityOverrides,
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
    var demuxIndex = towardIndex;
    final toward = _sourceBuilder(towardIndex);
    if (toward == null ||
        toward.candidates.isEmpty ||
        toward.key.isEmpty) {
      // Swiping across photos — demux the next real video so land isn't cold.
      demuxIndex = _nextVideoIndexAfter(towardIndex - 1) ?? towardIndex;
    }
    await _prefetchFeedSlotForIndex(
      demuxIndex,
      offsetFromVisible: (demuxIndex - fromIndex).abs().clamp(1, 3),
    );
  }

  Future<void> onVisibleIndexChanged(int currentIndex) async {
    if (!await _canPreload()) {
      return;
    }

    // Keep only the near window queued — priorities: visible 110, +1 100, -1 95,
    // +2 90. Drop anything farther so concurrency slots fill N+1 720 first.
    ReelsVideoCacheManager.instance.cancelBelowPriority(90);

    final diskDepth = await _resolvePreloadDepth();
    if (diskDepth <= 0) {
      return;
    }
    final decoderDepth = useMediaKit && _mediaKitPool.maxWarmSlots == 0
        ? 0
        : diskDepth.clamp(0, _mediaKitPool.maxWarmSlots);

    final throttleDecoder = _deviceConstraints.shouldThrottleDecoderWarm();

    final nextVideo = _nextVideoIndexAfter(currentIndex);
    final nextNextVideo =
        nextVideo == null ? null : _nextVideoIndexAfter(nextVideo);
    final indices = _videoBridgedWarmIndices(
      visibleIndex: currentIndex,
      depth: diskDepth,
    );
    final priorityOverrides = <int, int>{
      if (nextVideo != null) nextVideo: 100,
      if (nextNextVideo != null) nextNextVideo: 90,
    };

    await _warmIndices(
      indices,
      reason: 'page_settled',
      decoderWarmLimit: throttleDecoder ? 0 : decoderDepth,
      visibleIndex: currentIndex,
      priorityOverrides:
          priorityOverrides.isEmpty ? null : priorityOverrides,
    );

    if (!throttleDecoder && useMediaKit) {
      final demuxTarget = nextVideo ?? currentIndex + 1;
      unawaited(
        _prefetchFeedSlotForIndex(
          demuxTarget,
          offsetFromVisible: 1,
        ),
      );
    }

    await _deviceConstraints.ensureInitialized();
    final releaseWindow =
        _deviceConstraints.needsConstrainedSurfaceRecovery ? 5 : 3;
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
    if (delta == 0) {
      return 120;
    }
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
      return 95;
    }
    if (delta == -2) {
      return 88;
    }
    return 50;
  }

  Future<void> _warmIndices(
    List<int> indices, {
    required String reason,
    int? decoderWarmLimit,
    required int visibleIndex,
    Map<int, int>? priorityOverrides,
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
      final hasOverride = priorityOverrides?.containsKey(index) ?? false;
      // Overridden "next video" (photo run bridged) behaves like a normal N+1
      // for tier selection too, not like a far +2/+3 slot.
      final offset = hasOverride ? 1 : (index - visibleIndex).abs();
      final preloadOrdered = resolver.prioritizeForPreload(
        target.candidates,
        offsetFromVisible: offset,
        dualTier: dualTier,
      );
      final priority =
          priorityOverrides?[index] ?? _priorityForIndex(index, visibleIndex);
      for (var i = 0; i < preloadOrdered.length; i++) {
        final chosen = preloadOrdered[i];
        final isHls = chosen.url.toLowerCase().contains('.m3u8');
        if (isHls) {
          continue;
        }
        // Secondary tiers (e.g. 1080) must lose to N+1's primary (≥100).
        final tierPriority =
            i == 0 ? priority : (priority - 30).clamp(10, 85);
        prefetchPlaybackUrl(
          chosen.url,
          cacheManager: _cacheManager,
          priority: tierPriority,
          isTablet: isTablet,
        );
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
    if (networkClass == NetworkClass.offline) {
      return 0;
    }
    // Online (Wi-Fi or cellular): same deep prefetch window.
    final depth = RemoteConfigService.instance.preloadLimitWifi.clamp(3, 7);
    if (_deviceConstraints.needsConstrainedSurfaceRecovery) {
      return depth.clamp(3, 4);
    }
    return depth;
  }
}
