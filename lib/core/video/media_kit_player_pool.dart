import 'dart:async';
import 'dart:collection';

import 'package:cookster/core/video/feed_ping_pong_controller.dart';
import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:cookster/services/settings/settings_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PooledMediaKitPlayer {
  PooledMediaKitPlayer({
    required this.key,
    required this.player,
    this.feedActiveSlotIndex,
    this.feedFlipped = false,
    this.feedOpenedMedia = false,
  });

  final String key;
  final Player player;
  final int? feedActiveSlotIndex;
  final bool feedFlipped;
  final bool feedOpenedMedia;
}

class _RecentPaintEntry {
  const _RecentPaintEntry({
    required this.sourceUrl,
    required this.paintedAtMs,
  });

  final String sourceUrl;
  final int paintedAtMs;
}

/// MediaKit player pool for reels with priority for the visible slot.
///
/// - [acquire], [setActive], [unmuteAndPlay], [pause], [pauseAll], [release]
///   run on a **priority** lane and never wait behind [warmUp].
/// - [warmUp] opens media then primes the first frame in the background (never
///   blocks [acquire]); [isFrameReady] reflects primed slots.
/// - Hard cap of [_maxPoolSize] players; LRU eviction for idle (lease 0) entries.
/// - Warm slot cap: 2 on phone, 3 on tablet ([tabletBreakpoint] logical px).
class MediaKitPlayerPool {
  MediaKitPlayerPool._();

  static final MediaKitPlayerPool instance = MediaKitPlayerPool._();

  FeedPingPongController? _feedPingPong;
  bool _feedPingPongConfigured = false;

  FeedPingPongController get _pingPong {
    _feedPingPong ??= FeedPingPongController(singleSlotMode: true);
    return _feedPingPong!;
  }

  bool get feedSingleSlotMode => _pingPong.singleSlotMode;

  // Pool size vs. warm slots are decoupled on purpose:
  //   * [_maxWarmSlots] (1 on phone) caps how many *background* decoders may
  //     actively buffer ahead — concurrent active 720p decode stays at 2
  //     (visible + 1 ahead), which is what the MediaTek codec sustains without
  //     starving (4 *actively* warming slots was what caused discardFps spikes).
  //   * [maxPoolSizePhone] (4) keeps a couple of *recently played* decoders
  //     resident but paused, so swiping back to the last 1-2 reels resumes
  //     instantly instead of cold-reloading. Paused instances don't decode, so
  //     they don't compete for the codec.
  static const int maxPoolSizePhone = 2;
  static const int maxPoolSizeTablet = 5;
  static const double tabletBreakpoint = 600;

  /// LRU order: oldest at [LinkedHashMap.keys.first], MRU at last.
  final LinkedHashMap<String, Player> _players = LinkedHashMap<String, Player>();
  final Map<String, int> _leaseCount = <String, int>{};
  final Map<String, String> _sourceByKey = <String, String>{};
  final Set<String> _warmInFlight = <String>{};
  final Set<String> _frameReadyKeys = <String>{};
  final Set<String> _bufferPrimedKeys = <String>{};
  /// Survives feed slot unmap so swiping back can skip cold-open gates when bytes are on disk.
  final Map<String, _RecentPaintEntry> _recentPaintByKey = <String, _RecentPaintEntry>{};
  static const int _recentPaintTtlMs = 10 * 60 * 1000;
  static const int _maxRecentPaintEntries = 20;

  String? _activeKey;

  String? get activePoolKey => _activeKey;

  /// Dual-slot feed ping-pong: prefetch on hidden, flip on swipe, recycle hidden only.
  final ValueNotifier<int> feedSurfaceGeneration = ValueNotifier<int>(0);
  final List<VoidCallback> _feedSlotRecycleListeners = <VoidCallback>[];
  final List<VoidCallback> _feedSlotAwaitingRecycleListeners = <VoidCallback>[];

  /// Opens on the active single-slot decoder (Honor fatigue tracking).
  int get feedOpenCount => _pingPong.activeOpenCount;

  void addFeedSlotRecycleListener(VoidCallback listener) {
    _feedSlotRecycleListeners.add(listener);
  }

  void removeFeedSlotRecycleListener(VoidCallback listener) {
    _feedSlotRecycleListeners.remove(listener);
  }

  void addFeedSlotAwaitingRecycleListener(VoidCallback listener) {
    _feedSlotAwaitingRecycleListeners.add(listener);
  }

  void removeFeedSlotAwaitingRecycleListener(VoidCallback listener) {
    _feedSlotAwaitingRecycleListeners.remove(listener);
  }

  void _notifyFeedSlotAwaitingRecycle() {
    for (final listener
        in List<VoidCallback>.from(_feedSlotAwaitingRecycleListeners)) {
      listener();
    }
  }

  void _notifyFeedSlotRecycled() {
    for (final listener in List<VoidCallback>.from(_feedSlotRecycleListeners)) {
      listener();
    }
  }
  /// Bumped on every feed present flip so the single [Video] surface rebinds.
  final ValueNotifier<int> feedActiveSlotIndexNotifier = ValueNotifier<int>(0);
  String? _feedVisibleKey;
  int _feedOpenToken = 0;

  Player? get _feedVisiblePlayer => _pingPong.activePlayer;

  int get activeFeedSlotIndex => _pingPong.activeSlotIndex;

  int feedSlotGeneration(int index) => _pingPong.slotGeneration(index);

  VideoController? feedSlotVideoController(int index) =>
      _pingPong.videoControllerForSlot(index);

  Future<void> ensureFeedPingPongInitialized() async {
    if (!_feedPingPongConfigured) {
      await DeviceConstraints.instance.ensureInitialized();
      _feedPingPong = FeedPingPongController(
        singleSlotMode: DeviceConstraints.instance.needsSingleSlotFeedSync,
        onSlotsChanged: () {
          feedActiveSlotIndexNotifier.value = _pingPong.activeSlotIndex;
        },
        onBeforeSlotRecycle: (key) {
          _clearFrameReady(key);
          _notifyFeedSlotAwaitingRecycle();
        },
        onSlotRecycled: () {
          feedActiveSlotIndexNotifier.value = _pingPong.activeSlotIndex;
          _notifyFeedSlotRecycled();
        },
      );
      _feedPingPongConfigured = true;
    }
    await _pingPong.ensureInitialized();
  }

  /// Wait for in-flight priority / warm work (e.g. profile dispose before re-open).
  Future<void> awaitOperationsIdle() async {
    await _priorityChain;
    await _warmChain;
  }

  bool _isFeedPingPongPlayer(Player? player) {
    if (player == null) {
      return false;
    }
    return identical(player, _pingPong.slot0.player) ||
        identical(player, _pingPong.slot1.player);
  }
  double _screenWidth = 400;
  int _priorityDepth = 0;
  /// Latest reel that should receive audio; older [activateVisible] calls bail out.
  String? _audibleTargetKey;
  final Set<String> _userPausedKeys = <String>{};
  /// Bumped on [pauseAllImmediate] — in-flight unmute retries must bail out.
  int _suspendEpoch = 0;

  bool _isStaleFeedOpen(int openToken) => openToken < _feedOpenToken;

  /// Chains only priority (visible / active) operations.
  Future<void> _priorityChain = Future<void>.value();

  /// Chains background warm-ups; never awaited by [acquire].
  Future<void> _warmChain = Future<void>.value();

  /// Bumped on [disposeAll] so in-flight [warmUp] tasks cannot register players.
  int _disposeGeneration = 0;

  /// Call from UI (e.g. reels [MediaQuery.sizeOf].width) to tune warm limits.
  void setScreenWidth(double logicalWidth) {
    if (logicalWidth > 0) {
      _screenWidth = logicalWidth;
      ReelsVideoCacheManager.instance.managerForTablet(isTablet: _isTablet);
    }
  }

  bool get _isTablet => _screenWidth >= tabletBreakpoint;

  int get _maxPoolSize => _isTablet ? maxPoolSizeTablet : maxPoolSizePhone;

  int get _maxWarmSlots {
    if (_isTablet) {
      return 2;
    }
    return DeviceConstraints.instance.phoneWarmSlots;
  }

  /// Off-screen warm cap — keep preload depth aligned.
  int get maxWarmSlots => _maxWarmSlots;

  bool isWarmed(String key) => _players.containsKey(key);

  String? sourceUrlForKey(String key) => _sourceByKey[key];

  Player? playerForKey(String key) => _players[key];

  bool isFrameReady(String key) => _frameReadyKeys.contains(key);

  /// True when this key is the active slot, playing, and not muted.
  bool isPausedByUser(String key) => _userPausedKeys.contains(key);

  void clearUserPaused(String key) => _userPausedKeys.remove(key);

  bool isActiveAudible(String key) {
    if (_feedVisibleKey != null && key == _feedVisibleKey) {
      final player = _feedVisiblePlayer;
      if (player == null) {
        return false;
      }
      return player.state.volume > 50 && player.state.playing;
    }
    if (_activeKey != key) {
      return false;
    }
    final player = _players[key];
    if (player == null) {
      return false;
    }
    return player.state.playing && player.state.volume > 50;
  }

  /// Demux/decode buffered without a [Video] surface (width stays null until attach).
  bool isBufferPrimed(String key) => _bufferPrimedKeys.contains(key);

  String? get feedVisibleKey => _feedVisibleKey;

  bool isFeedVisibleKey(String key) =>
      _feedVisibleKey != null && _feedVisibleKey == key;

  /// True when [key] already has media opened in the pool — skip cold
  /// [Player.open] and the heavy pause/seek/wait rewind path.
  bool canInstantResume(String key) {
    final player = _players[key];
    if (player == null) {
      return false;
    }
    final source = _sourceByKey[key];
    if (source == null || source.isEmpty) {
      return false;
    }
    return !player.state.completed;
  }

  void markFrameReadyFromSurface(String key) {
    _markFrameReady(key);
    final source = _sourceByKey[key];
    if (source != null && source.isNotEmpty) {
      markRecentPaint(key, source);
    }
  }

  /// True when this reel painted recently — used for fast scroll-back even after slot unmap.
  bool hadRecentPaint(String key, {String? sourceUrl}) {
    if (key.isEmpty) {
      return false;
    }
    final entry = _recentPaintByKey[key];
    if (entry == null) {
      return false;
    }
    final ageMs = DateTime.now().millisecondsSinceEpoch - entry.paintedAtMs;
    if (ageMs > _recentPaintTtlMs) {
      _recentPaintByKey.remove(key);
      return false;
    }
    if (sourceUrl != null &&
        sourceUrl.isNotEmpty &&
        entry.sourceUrl.isNotEmpty &&
        entry.sourceUrl != sourceUrl) {
      return false;
    }
    return true;
  }

  void markRecentPaint(String key, String sourceUrl) {
    if (key.isEmpty || sourceUrl.isEmpty) {
      return;
    }
    _recentPaintByKey[key] = _RecentPaintEntry(
      sourceUrl: sourceUrl,
      paintedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _trimRecentPaintCache();
  }

  /// Drop stale warm work when navigation mutes the feed (no full pool dispose).
  void onEnterMutedContext() {
    _warmInFlight.clear();
    _trimRecentPaintCache();
  }

  void _trimRecentPaintCache() {
    if (_recentPaintByKey.length <= _maxRecentPaintEntries) {
      return;
    }
    final entries = _recentPaintByKey.entries.toList()
      ..sort((a, b) => a.value.paintedAtMs.compareTo(b.value.paintedAtMs));
    final removeCount = entries.length - _maxRecentPaintEntries;
    for (var i = 0; i < removeCount; i++) {
      _recentPaintByKey.remove(entries[i].key);
    }
  }

  void clearRecentPaint(String key) {
    _recentPaintByKey.remove(key);
  }

  /// Clears off-screen priming so UI does not skip the poster before attach.
  void invalidatePrimedFrame(String key) {
    _clearFrameReady(key);
  }

  void _markFrameReady(String key) {
    _frameReadyKeys.add(key);
  }

  void _clearFrameReady(String key) {
    _frameReadyKeys.remove(key);
    _bufferPrimedKeys.remove(key);
  }

  static bool isLocalPlaybackUrl(String url) {
    if (url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.startsWith('file://') ||
        (!lower.startsWith('http') && !lower.contains('.m3u8'));
  }

  /// Only rewind background warm slots — never the visible audible reel.
  bool _needsBackgroundReset(Player player) {
    return player.state.completed ||
        player.state.position.inMilliseconds > 250;
  }

  Future<void> _waitForPositionNearStart(Player player, String key) async {
    var waited = 0;
    while (waited < 500) {
      if (_players[key] != player) {
        return;
      }
      if (!_needsBackgroundReset(player)) {
        return;
      }
      try {
        await player.seek(Duration.zero);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  /// Fast visible entry for a pooled slot — media is already demuxed so we only
  /// seek to the start and play. Avoids the pause/flush/wait loop that shows up
  /// in device logs as multi-decoder stalls when swiping back to recent reels.
  Future<void> _quickStartLocked(String key, {bool playMuted = true}) async {
    if (key.isEmpty || !_players.containsKey(key)) {
      return;
    }
    final player = _players[key];
    if (player == null) {
      return;
    }
    _activeKey = key;
    _touchLru(key);
    await _silenceOthersLocked(key);
    if (_players[key] != player) {
      return;
    }
    try {
      if (player.state.completed ||
          player.state.position.inMilliseconds > 32) {
        await player.seek(Duration.zero);
      }
      await player.setVolume(0);
      if (playMuted && !player.state.playing) {
        await player.play();
      }
      _bufferPrimedKeys.add(key);
    } catch (_) {}
  }

  /// Pause, seek to 0, wait for demuxer, then play muted (visible reel entry point).
  Future<void> _rewindToStartLocked(String key, {bool playMuted = true}) async {
    if (key.isEmpty || !_players.containsKey(key)) {
      return;
    }
    final player = _players[key];
    if (player == null) {
      return;
    }
    _activeKey = key;
    _touchLru(key);
    _clearFrameReady(key);
    await _silenceOthersLocked(key);
    if (_players[key] != player) {
      return;
    }
    try {
      await player.pause();
      await player.seek(Duration.zero);
      await _waitForPositionNearStart(player, key);
      if (_players[key] != player) {
        return;
      }
      await player.setVolume(0);
      if (playMuted && !player.state.playing) {
        await player.play();
      }
    } catch (_) {}
  }

  Future<void> _prepareVisibleLocked(String key) async {
    final player = _players[key];
    if (player != null && canInstantResume(key)) {
      await _quickStartLocked(key);
    } else {
      await _rewindToStartLocked(key);
    }
  }

  // ---------------------------------------------------------------------------
  // Priority lane (visible reel — never blocked by warmUp)
  // ---------------------------------------------------------------------------

  Future<T> _runPriority<T>(Future<T> Function() action) {
    _priorityDepth++;
    final completer = Completer<T>();
    final previous = _priorityChain;
    _priorityChain = previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      } finally {
        _priorityDepth--;
      }
    });
    return completer.future;
  }

  void _touchLru(String key) {
    final player = _players.remove(key);
    if (player != null) {
      _players[key] = player;
    }
  }

  int _warmCount() {
    var count = 0;
    for (final key in _players.keys) {
      if ((_leaseCount[key] ?? 0) == 0 && key != _activeKey) {
        count++;
      }
    }
    return count;
  }

  String? _lruEvictableKey({String? except}) {
    for (final key in _players.keys) {
      if (key == except || key == _activeKey) {
        continue;
      }
      if ((_leaseCount[key] ?? 0) == 0) {
        return key;
      }
    }
    return null;
  }

  Future<void> _disposeKey(String key) async {
    _leaseCount.remove(key);
    _sourceByKey.remove(key);
    _warmInFlight.remove(key);
    _clearFrameReady(key);
    final player = _players.remove(key);
    if (_activeKey == key) {
      _activeKey = null;
    }
    if (_feedVisibleKey == key) {
      _feedVisibleKey = null;
    }
    _userPausedKeys.remove(key);
    if (player == null) {
      return;
    }
    if (_isFeedPingPongPlayer(player)) {
      return;
    }
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  void _unmapFeedVisibleKey(String oldKey) {
    final mapped = _players[oldKey];
    if (oldKey.isEmpty || !_isFeedPingPongPlayer(mapped)) {
      return;
    }
    _players.remove(oldKey);
    _leaseCount.remove(oldKey);
    _sourceByKey.remove(oldKey);
    _warmInFlight.remove(oldKey);
    // Keep frame-ready / buffer-primed so scroll-back skips poster and reveals video.
    _userPausedKeys.remove(oldKey);
    if (_activeKey == oldKey) {
      _activeKey = null;
    }
    if (_feedVisibleKey == oldKey) {
      _feedVisibleKey = null;
    }
  }

  /// Feed-only: ping-pong present — flip if prefetched, else open on active slot.
  /// [openToken] must be the widget's [_playbackGeneration]; stale calls are ignored.
  /// [preserveFrameReady] — quality-tier swaps while the poster is already down.
  Future<PooledMediaKitPlayer> openVisibleReel({
    required String key,
    required String sourceUrl,
    required int openToken,
    bool preserveFrameReady = false,
  }) {
    return _runPriority(() async {
      _feedOpenToken = openToken;
      await _disposeIdleWarmExcept(key);

      final previousKey = _feedVisibleKey;
      if (previousKey != null &&
          previousKey != key &&
          previousKey.isNotEmpty) {
        _unmapFeedVisibleKey(previousKey);
      }

      if (_isStaleFeedOpen(openToken)) {
        final player = _pingPong.activePlayer;
        if (player == null) {
          throw StateError('Feed ping-pong player missing for stale open');
        }
        return PooledMediaKitPlayer(
          key: _feedVisibleKey ?? key,
          player: player,
          feedActiveSlotIndex: _pingPong.activeSlotIndex,
        );
      }

      final suspendEpoch = _suspendEpoch;
      FeedPresentResult? result;
      final fastReopen = hadRecentPaint(key, sourceUrl: sourceUrl) ||
          isLocalPlaybackUrl(sourceUrl);
      try {
        result = await _pingPong.presentReel(
          key: key,
          sourceUrl: sourceUrl,
          openToken: openToken,
          suspended: _isSuspendedSince(suspendEpoch),
          userPaused: _userPausedKeys.contains(key),
          fastReopen: fastReopen,
        );
      } catch (_) {
        _unmapFeedVisibleKey(key);
        rethrow;
      }

      if (result == null || _isStaleFeedOpen(openToken)) {
        final player = _pingPong.activePlayer;
        if (player == null) {
          throw StateError('Feed ping-pong player missing after stale present');
        }
        return PooledMediaKitPlayer(
          key: _feedVisibleKey ?? key,
          player: player,
          feedActiveSlotIndex: _pingPong.activeSlotIndex,
        );
      }

      _feedVisibleKey = key;
      _activeKey = key;
      _audibleTargetKey = key;
      feedActiveSlotIndexNotifier.value = result.activeSlotIndex;
      _players[key] = result.player;
      _sourceByKey[key] = sourceUrl;
      _leaseCount[key] = 1;
      _warmInFlight.remove(key);
      _touchLru(key);
      _bufferPrimedKeys.add(key);
      if (result.openedMedia && !preserveFrameReady) {
        _clearFrameReady(key);
      }

      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'present',
          flip: result.flipped,
          coldOpen: result.openedMedia,
          feedMode: _pingPong.singleSlotMode ? 'single_slot' : 'dual_slot',
          extra: {
            'key': key,
            'slot': result.activeSlotIndex,
          },
        ),
      );

      return PooledMediaKitPlayer(
        key: key,
        player: result.player,
        feedActiveSlotIndex: result.activeSlotIndex,
        feedFlipped: result.flipped,
        feedOpenedMedia: result.openedMedia,
      );
    });
  }

  /// Scroll-proportional demux-ahead: dual-slot hidden prefetch or buffer warm.
  Future<void> scheduleDemuxAhead({
    required String key,
    required String sourceUrl,
    int? prefetchToken,
  }) async {
    if (key.isEmpty || sourceUrl.isEmpty) {
      return;
    }
    await DeviceConstraints.instance.ensureInitialized();
    if (DeviceConstraints.instance.suppressScrollDecoderWarm) {
      if (!_feedPingPongConfigured) {
        await ensureFeedPingPongInitialized();
      }
      primeBufferHint(key: key, sourceUrl: sourceUrl);
      return;
    }
    if (!_feedPingPongConfigured) {
      await ensureFeedPingPongInitialized();
    }
    if (!_pingPong.singleSlotMode) {
      await prefetchFeedReel(
        key: key,
        sourceUrl: sourceUrl,
        prefetchToken: prefetchToken,
      );
      return;
    }
    await warmUp(key: key, sourceUrl: sourceUrl);
  }

  int _lastSurfaceRecoveryMs = 0;
  String? _lastSurfaceRecoveryKey;

  /// Seek-to-start + optional surface bump when decode runs but nothing paints.
  Future<void> recoverFeedVisibleSurface(
    String key, {
    bool bumpSurface = true,
  }) {
    return _runPriority(() => _recoverFeedVisibleSurfaceLocked(
          key,
          bumpSurface: bumpSurface,
        ));
  }

  /// Render-stall recovery: surface bump + hard decoder recycle (openToken guarded).
  Future<void> recoverFeedVisibleSurfaceAfterStall(
    String key, {
    required int openToken,
  }) {
    return _runPriority(() async {
      if (key.isEmpty || _feedVisibleKey != key || _isStaleFeedOpen(openToken)) {
        return;
      }
      if (!_feedPingPongConfigured) {
        await ensureFeedPingPongInitialized();
      }
      await _recoverFeedVisibleSurfaceLocked(key, bumpSurface: true);
      if (_isStaleFeedOpen(openToken)) {
        return;
      }
      if (!DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
        await _pingPong.forceRecycleActiveDecoder();
      }
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'surface_recovery',
          feedMode: _pingPong.singleSlotMode ? 'single_slot' : 'dual_slot',
          extra: {'key': key, 'stall': true},
        ),
      );
    });
  }

  Future<void> _recoverFeedVisibleSurfaceLocked(
    String key, {
    required bool bumpSurface,
  }) async {
    if (key.isEmpty || _feedVisibleKey != key) {
      return;
    }
    await DeviceConstraints.instance.ensureInitialized();
    final primedScrollBack = isFrameReady(key) ||
        hadRecentPaint(key) ||
        isBufferPrimed(key);
    // Honor/MTK: never tear down the ImageReader here — logs show
    // Rendered 0/s + VideoOutput deleteGlobalObjectRef when we force-recycle
    // while the Flutter [Video] widget is still mounted (tab return, etc.).
    if (DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
      final player = _pingPong.activePlayer;
      if (player != null) {
        try {
          if (!player.state.playing) {
            await player.play();
          }
        } catch (_) {}
      }
      if (!primedScrollBack) {
        await _pingPong.recycleActiveDecoderIfStale();
      }
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'surface_recovery',
          feedMode: _pingPong.singleSlotMode ? 'single_slot' : 'dual_slot',
          extra: {'key': key, 'mtk_soft': true, 'primed': primedScrollBack},
        ),
      );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (bumpSurface &&
        _lastSurfaceRecoveryKey == key &&
        now - _lastSurfaceRecoveryMs < 900) {
      return;
    }
    final player = _pingPong.activePlayer;
    if (player == null) {
      return;
    }
    try {
      await player.pause();
      await player.seek(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 48));
      await player.play();
      await player.setVolume(0);
    } catch (_) {}
    _lastSurfaceRecoveryKey = key;
    _lastSurfaceRecoveryMs = now;
    if (!bumpSurface) {
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'surface_recovery',
          feedMode: _pingPong.singleSlotMode ? 'single_slot' : 'dual_slot',
          extra: {'key': key, 'bump': false},
        ),
      );
      return;
    }
    feedSurfaceGeneration.value++;
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'surface_recovery',
        feedMode: _pingPong.singleSlotMode ? 'single_slot' : 'dual_slot',
        extra: {'key': key},
      ),
    );
  }

  /// Proactive decoder recycle on Honor after many swipes (single-slot fatigue).
  Future<bool> recycleFeedDecoderIfStale() {
    return _runPriority(() => _pingPong.recycleActiveDecoderIfStale());
  }

  /// Hard reset for post-unmask render death (Rendered 0/s, decoder flush
  /// storm) that native telemetry cannot see — it only watches for a stall
  /// *before* first frame. Soft recovery (play/seek on the same decoder) does
  /// not help once the render pipe is dead, so this forces a brand new
  /// Player/texture even on Honor/MTK, deliberately bypassing the tier guard
  /// that normally avoids recycling those devices.
  Future<void> forceRecycleFeedVisibleSurfaceHard(String key) {
    return _runPriority(() async {
      if (key.isEmpty || _feedVisibleKey != key) {
        return;
      }
      if (!_feedPingPongConfigured) {
        await ensureFeedPingPongInitialized();
      }
      await _pingPong.forceRecycleActiveDecoder();
    });
  }

  /// Opens the next reel on the hidden ping-pong slot (muted, demux ahead).
  Future<void> prefetchFeedReel({
    required String key,
    required String sourceUrl,
    int? prefetchToken,
  }) {
    if (key.isEmpty || sourceUrl.isEmpty) {
      return Future<void>.value();
    }
    final token = prefetchToken ?? _feedOpenToken;
    _enqueueWarm(() async {
      await _waitForPriorityLane(maxMs: 8000);
      if (_priorityDepth > 0) {
        return;
      }
      await _pingPong.prefetchReel(
        key: key,
        sourceUrl: sourceUrl,
        prefetchToken: token,
      );
      _sourceByKey[key] = sourceUrl;
      _bufferPrimedKeys.add(key);
    });
    return Future<void>.value();
  }

  String? _lastAudibleResumeKey;
  int _lastAudibleResumeMs = 0;

  /// Resume feed audio after tab/background mute without re-opening media.
  Future<void> resumeFeedVisible(String key) {
    return feedResumeAudibleWhenReady(key);
  }

  /// Primary audio entry at poster_unmask — bypasses suspend-epoch and pool-map gates.
  Future<void> forceFeedAudibleAtPosterUnmask(String key) {
    return _runPriority(() async {
      if (key.isEmpty ||
          _feedVisibleKey != key ||
          _userPausedKeys.contains(key) ||
          _pingPong.visibleKey != key) {
        ReelsPerf.log(
          'feed_audible skip key=$key feed=$_feedVisibleKey vis=${_pingPong.visibleKey}',
        );
        return;
      }
      _audibleTargetKey = key;
      _activeKey = key;
      _lastAudibleResumeKey = key;
      _lastAudibleResumeMs = DateTime.now().millisecondsSinceEpoch;
      final player = _feedVisiblePlayer;
      if (player == null) {
        ReelsPerf.log('feed_audible skip no player key=$key');
        return;
      }
      if (_players[key] == null) {
        _players[key] = player;
        _leaseCount[key] = (_leaseCount[key] ?? 0).clamp(1, 999);
      }
      await _pingPong.forceRestartActiveAudio();
      ReelsPerf.log(
        'feed_audible key=$key ok=${isActiveAudible(key)} '
        'vol=${player.state.volume} playing=${player.state.playing}',
      );
    });
  }

  /// Single unmute entry — debounced; never seek (Honor flush storms).
  /// Post-paint retries pass [force: true] so the 600ms debounce cannot block them.
  void unmuteFeedVisibleImmediate(String key, {bool force = false}) {
    if (key.isEmpty ||
        _feedVisibleKey != key ||
        _userPausedKeys.contains(key)) {
      return;
    }
    if (_pingPong.visibleKey != key) {
      return;
    }
    if (!force && !isFrameReady(key)) {
      return;
    }
    if (isActiveAudible(key)) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        _lastAudibleResumeKey == key &&
        now - _lastAudibleResumeMs < 600) {
      return;
    }
    _lastAudibleResumeKey = key;
    _lastAudibleResumeMs = now;
    _audibleTargetKey = key;
    _activeKey = key;
    unawaited(
      _runPriority(
        () => _unmuteAndPlayLocked(key, suspendEpoch: _suspendEpoch),
      ),
    );
  }

  /// Hint that disk prefetch finished — visible open resolves local bytes faster.
  void primeBufferHint({required String key, required String sourceUrl}) {
    if (key.isEmpty || sourceUrl.isEmpty) {
      return;
    }
    _sourceByKey[key] = sourceUrl;
    _bufferPrimedKeys.add(key);
  }

  /// Unmute when [key] is on the active slot and a frame has painted.
  Future<void> feedResumeAudibleWhenReady(String key, {bool force = false}) {
    return _runPriority(() async {
      if (key.isEmpty ||
          _feedVisibleKey != key ||
          _userPausedKeys.contains(key)) {
        return;
      }
      if (_pingPong.visibleKey != key) {
        return;
      }
      if (!force && !isFrameReady(key)) {
        return;
      }
      if (isActiveAudible(key)) {
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force &&
          _lastAudibleResumeKey == key &&
          now - _lastAudibleResumeMs < 600) {
        return;
      }
      _lastAudibleResumeKey = key;
      _lastAudibleResumeMs = now;
      _audibleTargetKey = key;
      _activeKey = key;
      await _unmuteAndPlayLocked(key, suspendEpoch: _suspendEpoch);
    });
  }

  Future<void> _evictLruIfNeeded({String? protect}) async {
    while (_players.length >= _maxPoolSize) {
      final evict = _lruEvictableKey(except: protect);
      if (evict == null) {
        break;
      }
      await _disposeKey(evict);
    }
  }

  Future<void> _setActiveLocked(String key, {required bool muted}) async {
    _activeKey = key;
    _touchLru(key);
    final snapshot = Map<String, Player>.from(_players);
    for (final entry in snapshot.entries) {
      final player = _players[entry.key];
      if (player == null) {
        continue;
      }
      if (entry.key == key) {
        try {
          await player.setVolume(muted ? 0 : 100);
        } catch (_) {}
        if (_players[entry.key] != player) {
          continue;
        }
        if (!player.state.playing) {
          try {
            await player.play();
          } catch (_) {}
        }
      } else {
        try {
          if (player.state.playing) {
            await player.pause();
          }
          if (_players[entry.key] == player) {
            await player.setVolume(0);
          }
        } catch (_) {}
      }
    }
  }

  void _suspendPlayback() {
    _suspendEpoch++;
    _audibleTargetKey = null;
    _lastAudibleResumeKey = null;
  }

  bool _isSuspendedSince(int epoch) => epoch != _suspendEpoch;

  /// Synchronous mute/pause for tab switches — stops audio before async cleanup runs.
  void silenceAllSync({String? exceptKey}) {
    if (exceptKey == null || exceptKey.isEmpty) {
      _activeKey = null;
    } else {
      _activeKey = exceptKey;
    }
    for (final entry in _players.entries) {
      if (exceptKey != null &&
          exceptKey.isNotEmpty &&
          entry.key == exceptKey) {
        continue;
      }
      final player = entry.value;
      if (_isFeedPingPongPlayer(player) &&
          exceptKey != null &&
          exceptKey.isNotEmpty &&
          entry.key == exceptKey) {
        continue;
      }
      if (_isFeedPingPongPlayer(player)) {
        continue;
      }
      try {
        unawaited(player.setVolume(0));
        if (player.state.playing) {
          unawaited(player.pause());
        }
      } catch (_) {}
    }
    if (exceptKey == null || exceptKey.isEmpty) {
      unawaited(_pingPong.silenceAllSlots());
    } else if (_feedVisibleKey == exceptKey) {
      unawaited(_pingPong.muteHiddenSlot());
    } else {
      unawaited(_pingPong.silenceAllSlots());
    }
  }

  /// Mutes off-screen slots on swipe. When [exceptKey] is set, that slot is left
  /// alone so it can rewind/play without an extra pause→flush→stop cycle.
  void pauseAllImmediate({String? exceptKey}) {
    _suspendPlayback();
    silenceAllSync(exceptKey: exceptKey);
    if (exceptKey != null && exceptKey.isNotEmpty) {
      unawaited(_runPriority(() => _silenceOthersLocked(exceptKey)));
    } else {
      unawaited(_runPriority(_silenceAllLocked));
    }
  }

  /// Awaitable full pause (tab leave, route overlay, app background).
  Future<void> pauseAllAwait({String? exceptKey}) async {
    pauseAllImmediate(exceptKey: exceptKey);
    if (exceptKey != null && exceptKey.isNotEmpty) {
      await _runPriority(() => _silenceOthersLocked(exceptKey));
    } else {
      await _runPriority(_silenceAllLocked);
    }
  }

  Future<void> _silenceAllLocked() async {
    final snapshot = Map<String, Player>.from(_players);
    for (final entry in snapshot.entries) {
      final player = _players[entry.key];
      if (player == null || _isFeedPingPongPlayer(player)) {
        continue;
      }
      try {
        if (player.state.playing) {
          await player.pause();
        }
        if (_players[entry.key] == player) {
          await player.setVolume(0);
        }
      } catch (_) {}
    }
    await _pingPong.silenceAllSlots();
  }

  /// Mutes/pauses every slot except [exceptKey] (used when unmuting the visible reel).
  Future<void> _silenceOthersLocked(String exceptKey) async {
    final snapshot = Map<String, Player>.from(_players);
    for (final entry in snapshot.entries) {
      if (entry.key == exceptKey) {
        continue;
      }
      final player = _players[entry.key];
      if (player == null || _isFeedPingPongPlayer(player)) {
        continue;
      }
      try {
        if (player.state.playing) {
          await player.pause();
        }
        // Skip seek-to-zero for background players during feed swipe —
        // rewind happens lazily via _quickStartLocked when the player
        // becomes visible again. Removing the eager seek saves ~30ms
        // per silenced player per swipe.
        if (_players[entry.key] == player) {
          await player.setVolume(0);
        }
      } catch (_) {}
    }
  }

  Future<void> pauseByUser(String key) {
    return _runPriority(() async {
      _userPausedKeys.add(key);
      _activeKey = key;
      if (_feedVisibleKey == key) {
        await _pingPong.muteActiveForUser();
        return;
      }
      final player = _players[key];
      if (player == null) {
        return;
      }
      try {
        await player.pause();
        await player.setVolume(0);
      } catch (_) {}
    });
  }

  /// Feed user resume after [pauseByUser] — play + unmute on the active slot.
  Future<void> feedUserResume(String key) {
    return _runPriority(() async {
      if (_feedVisibleKey != key) {
        return;
      }
      _userPausedKeys.remove(key);
      _audibleTargetKey = key;
      _activeKey = key;
      await _pingPong.resumeActiveForUser(expectedKey: key);
    });
  }

  Future<void> _unmuteAndPlayLocked(
    String key, {
    required int suspendEpoch,
    int? openToken,
  }) async {
    if (openToken != null && _isStaleFeedOpen(openToken)) {
      return;
    }
    // Only block feed ping-pong players competing for a different feed slot.
    // Standalone (non-feed) players must be allowed to unmute.
    final player = _players[key] ?? _feedVisiblePlayer;
    if (player != null &&
        _isFeedPingPongPlayer(player) &&
        _feedVisibleKey != null &&
        key != _feedVisibleKey) {
      return;
    }
    if (_userPausedKeys.contains(key)) {
      return;
    }
    final isFeedVisible =
        _feedVisibleKey == key && _isFeedPingPongPlayer(_feedVisiblePlayer);
    final isStandalone = player != null && !_isFeedPingPongPlayer(player);
    if (!isFeedVisible && !isStandalone && _isSuspendedSince(suspendEpoch)) {
      return;
    }
    if (player == null) {
      return;
    }
    _activeKey = key;
    _audibleTargetKey = key;
    _touchLru(key);
    // Feed uses one physical [Player] — silencing pool slots here only flushes audio.
    if (_feedVisiblePlayer == null ||
        !identical(player, _feedVisiblePlayer)) {
      await _silenceOthersLocked(key);
    }
    if ((_players[key] != null && _players[key] != player) ||
        _audibleTargetKey != key ||
        (!isFeedVisible && !isStandalone && _isSuspendedSince(suspendEpoch))) {
      return;
    }
    if (player.state.completed) {
      await player.seek(Duration.zero);
      await _waitForPositionNearStart(player, key);
      if (_players[key] != player || (!isStandalone && _isSuspendedSince(suspendEpoch))) {
        return;
      }
    }
    await _tryAudiblePlayback(
      player,
      key,
      suspendEpoch: suspendEpoch,
      openToken: openToken,
    );
  }

  /// Unmute + play once — pause/play retry loops were causing AudioTrack flush spam.
  Future<bool> _tryAudiblePlayback(
    Player player,
    String key, {
    required int suspendEpoch,
    int? openToken,
  }) async {
    if (openToken != null && _isStaleFeedOpen(openToken)) {
      return false;
    }
    // Only block feed ping-pong players competing for a different feed slot.
    final isStandalonePlayer = _players[key] == player && !_isFeedPingPongPlayer(player);
    if (!isStandalonePlayer &&
        _feedVisiblePlayer != null &&
        _feedVisibleKey != null &&
        key != _feedVisibleKey) {
      return false;
    }
    final isFeedVisible =
        _feedVisibleKey == key && _isFeedPingPongPlayer(_feedVisiblePlayer);
    if ((!isFeedVisible && !isStandalonePlayer && _isSuspendedSince(suspendEpoch)) ||
        (_players[key] != player && player != _feedVisiblePlayer) ||
        _userPausedKeys.contains(key) ||
        _audibleTargetKey != key) {
      return false;
    }
    try {
      if (player.state.volume <= 50) {
        await player.setVolume(100);
      }
      if (!player.state.playing) {
        await player.play();
      }
      if (player.state.volume <= 50) {
        await player.setVolume(100);
      }
    } catch (_) {}
    return (isStandalonePlayer || !_isSuspendedSince(suspendEpoch)) &&
        _players[key] == player &&
        player.state.volume > 50 &&
        player.state.playing;
  }

  String? _lastActivateKey;
  int _lastActivateMs = 0;

  /// Single entry to make [key] the only audible reel (fixes multi-track fights).
  Future<void> activateVisible(String key) {
    return _runPriority(() async {
      final suspendEpoch = _suspendEpoch;
      if (key.isEmpty ||
          !_players.containsKey(key) ||
          _userPausedKeys.contains(key) ||
          _isSuspendedSince(suspendEpoch)) {
        return;
      }
      // Only block feed ping-pong players competing for a different feed slot.
      final playerForKey = _players[key];
      if (playerForKey != null &&
          _isFeedPingPongPlayer(playerForKey) &&
          _feedVisibleKey != null &&
          key != _feedVisibleKey) {
        return;
      }
      final isStandaloneKey = playerForKey != null && !_isFeedPingPongPlayer(playerForKey);
      if (_feedVisibleKey == key && _isFeedPingPongPlayer(_players[key])) {
        if (isActiveAudible(key)) {
          return;
        }
        if (_pingPong.visibleKey != key) {
          return;
        }
        _audibleTargetKey = key;
        _activeKey = key;
        await _unmuteAndPlayLocked(key, suspendEpoch: suspendEpoch);
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final player = _players[key];
      final needsAudible = player == null ||
          player.state.volume <= 50 ||
          !player.state.playing;
      if (!needsAudible &&
          _feedVisibleKey == key &&
          _lastActivateKey == key &&
          now - _lastActivateMs < 400) {
        return;
      }
      _lastActivateKey = key;
      _lastActivateMs = now;

      _audibleTargetKey = key;
      await _silenceOthersLocked(key);
      if (_audibleTargetKey != key || (!isStandaloneKey && _isSuspendedSince(suspendEpoch))) {
        return;
      }

      _activeKey = key;
      await _unmuteAndPlayLocked(key, suspendEpoch: suspendEpoch);
    });
  }

  /// True when [key] is the sole feed-visible mapping and playing unmuted.
  bool isFeedVisibleAudible(String key) {
    return _feedVisibleKey == key && isActiveAudible(key);
  }

  /// Pauses/mutes off-screen slots and restores audible playback for [key].
  Future<void> ensureAudible(String key) => activateVisible(key);

  Future<void> _waitForWarmKey(String key, {int maxMs = 2500}) async {
    var waited = 0;
    while (waited < maxMs) {
      if (_players.containsKey(key)) {
        return;
      }
      if (!_warmInFlight.contains(key)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  /// Drop idle warm decoders before the visible reel unmutes.
  ///
  /// Paused warm slots were still holding OpenSL audio outputs; on MTK/Oppo
  /// that triggers `SL_RESULT_MEMORY_FAILURE` and random silent reels.
  Future<void> _disposeIdleWarmExcept(String key) async {
    final toDispose = <String>[];
    for (final entry in _players.entries) {
      final slotKey = entry.key;
      if (slotKey == key ||
          (_leaseCount[slotKey] ?? 0) > 0 ||
          _warmInFlight.contains(slotKey)) {
        continue;
      }
      if (_isFeedPingPongPlayer(entry.value)) {
        continue;
      }
      toDispose.add(slotKey);
    }
    for (final slotKey in toDispose) {
      await _disposeKey(slotKey);
    }
  }

  Future<PooledMediaKitPlayer> acquire({
    required String key,
    required String sourceUrl,
    bool autoPlay = false,
  }) {
    return _runPriority(() async {
      if (SettingsService.instance.dataSaverEnabled.value) {
        // Still allow one visible player in data saver.
      }

      await _disposeIdleWarmExcept(key);

      if (_warmInFlight.contains(key)) {
        await _waitForWarmKey(key);
      }

      final existing = _players[key];
      if (existing != null) {
        if (_sourceByKey[key] != sourceUrl) {
          return replaceSource(
            key: key,
            sourceUrl: sourceUrl,
            autoPlay: autoPlay,
          );
        }
        _touchLru(key);
        if ((_leaseCount[key] ?? 0) == 0) {
          _leaseCount[key] = 1;
        }
        _warmInFlight.remove(key);
        if (autoPlay || _activeKey == key) {
          await _prepareVisibleLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: existing);
      }

      await _evictLruIfNeeded(protect: key);
      if (_players.length >= _maxPoolSize) {
        final recycled = await _recycleLruPlayer(key, sourceUrl);
        _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
        if (autoPlay || _activeKey == key) {
          await _prepareVisibleLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: recycled);
      }

      _clearFrameReady(key);
      final player = Player();
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      _players[key] = player;
      _sourceByKey[key] = sourceUrl;
      _bufferPrimedKeys.add(key);
      _leaseCount[key] = 1;
      if (autoPlay || _activeKey == key) {
        await _prepareVisibleLocked(key);
      }
      return PooledMediaKitPlayer(key: key, player: player);
    });
  }

  Future<PooledMediaKitPlayer> replaceSource({
    required String key,
    required String sourceUrl,
    bool autoPlay = false,
  }) {
    return _runPriority(() async {
      final existing = _players[key];
      if (existing != null) {
        _touchLru(key);
        _clearFrameReady(key);
        await existing.open(Media(sourceUrl), play: false);
        await existing.setVolume(0);
        _sourceByKey[key] = sourceUrl;
        _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
        if (autoPlay) {
          await _rewindToStartLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: existing);
      }

      return acquire(key: key, sourceUrl: sourceUrl, autoPlay: autoPlay);
    });
  }

  Future<Player> _recycleLruPlayer(String key, String sourceUrl) async {
    var lruKey = _lruEvictableKey(except: key);
    if (lruKey == null) {
      // Leaked display leases (swipe without surrender) pin every slot; force-
      // drop the oldest non-active entry instead of spawning a 5th decoder.
      for (final candidate in _players.keys) {
        if (candidate != key && candidate != _activeKey) {
          await _disposeKey(candidate);
          lruKey = _lruEvictableKey(except: key);
          break;
        }
      }
    }
    if (lruKey == null) {
      final player = Player();
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      _players[key] = player;
      _sourceByKey[key] = sourceUrl;
      _bufferPrimedKeys.add(key);
      return player;
    }
    final player = _players.remove(lruKey)!;
    _leaseCount.remove(lruKey);
    _sourceByKey.remove(lruKey);
    _warmInFlight.remove(lruKey);
    _clearFrameReady(lruKey);
    if (_activeKey == lruKey) {
      _activeKey = null;
    }
    try {
      await player.stop();
    } catch (_) {}
    _clearFrameReady(key);
    try {
      await player.open(Media(sourceUrl), play: false);
    } catch (e) {
      // Native decoder crash during recycle — dispose broken player,
      // fall back to a fresh instance so the pool map stays consistent.
      try {
        await player.dispose();
      } catch (_) {}
      final fresh = Player();
      try {
        await fresh.open(Media(sourceUrl), play: false);
        await fresh.setVolume(0);
      } catch (_) {}
      _players[key] = fresh;
      _sourceByKey[key] = sourceUrl;
      _bufferPrimedKeys.add(key);
      return fresh;
    }
    await player.setVolume(0);
    _players[key] = player;
    _sourceByKey[key] = sourceUrl;
    _bufferPrimedKeys.add(key);
    return player;
  }

  Future<void> setActive(String key) {
    return _runPriority(() => _setActiveLocked(key, muted: true));
  }

  /// Rewinds to the start and plays muted while off-screen slots stay silent.
  Future<void> prepareVisiblePlayback(String key) {
    return _runPriority(() => _prepareVisibleLocked(key));
  }

  Future<void> unmuteAndPlay(String key) {
    return _runPriority(
      () => _unmuteAndPlayLocked(key, suspendEpoch: _suspendEpoch),
    );
  }

  Future<void> pause(String key) {
    return _runPriority(() async {
      final player = _players[key];
      if (player == null) {
        return;
      }
      await player.pause();
    });
  }

  /// Instant mute/pause on swipe; priority lane only reconciles state afterward.
  Future<void> pauseAll() async {
    await pauseAllAwait();
  }

  Future<void> release(String key) {
    return _runPriority(() => _releaseLocked(key));
  }

  /// Drops one display lease without evicting the player (reels page hide).
  Future<void> surrenderLease(String key) {
    return _runPriority(() async {
      final currentLease = _leaseCount[key] ?? 0;
      if (currentLease <= 0) {
        return;
      }
      _leaseCount[key] = currentLease - 1;
    });
  }

  Future<void> _releaseLocked(String key) async {
    final currentLease = _leaseCount[key] ?? 0;
    if (currentLease > 1) {
      _leaseCount[key] = currentLease - 1;
      return;
    }
    await _disposeKey(key);
  }

  Future<void> _disposeFeedVisiblePlayer() async {
    _feedVisibleKey = null;
    _feedOpenToken = 0;
    await _pingPong.disposeAll();
  }

  Future<void> releaseAll() {
    return _runPriority(() async {
      final keys = _players.keys.toList(growable: false);
      for (final key in keys) {
        _leaseCount[key] = 1;
        await _disposeKey(key);
      }
      await _disposeFeedVisiblePlayer();
      _activeKey = null;
    });
  }

  Future<void> disposeAll() {
    return _runPriority(() async {
      _suspendPlayback();
      _disposeGeneration++;
      _warmInFlight.clear();
      final keys = _players.keys.toList(growable: false);
      for (final key in keys) {
        await _disposeKey(key);
      }
      await _disposeFeedVisiblePlayer();
      _activeKey = null;
      _audibleTargetKey = null;
      feedSurfaceGeneration.value++;
    });
  }

  // ---------------------------------------------------------------------------
  // Background lane (preload — open only, yields to priority)
  // ---------------------------------------------------------------------------

  static const int _warmPriorityWaitMs = 2500;
  int _activeWarmTasks = 0;

  Future<void> _waitForPriorityLane({required int maxMs}) async {
    var waited = 0;
    while (_priorityDepth > 0 && waited < maxMs) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  void _enqueueWarm(Future<void> Function() work) {
    final next = _warmChain.then((_) async {
      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_priorityDepth > 0) {
        return;
      }
      await work();
    }, onError: (_) {});
    _warmChain = next;
    unawaited(next);
  }

  /// Opens media and buffers demux off-screen (parallel slots).
  /// Returns immediately; never blocks [acquire].
  Future<void> warmUp({required String key, required String sourceUrl}) {
    if (SettingsService.instance.dataSaverEnabled.value) {
      return Future<void>.value();
    }
    if (key == _feedVisibleKey ||
        _players.containsKey(key) ||
        (_leaseCount[key] ?? 0) > 0 ||
        _warmInFlight.contains(key)) {
      return Future<void>.value();
    }
    if (_warmCount() >= _maxWarmSlots) {
      return Future<void>.value();
    }

    _warmInFlight.add(key);
    unawaited(_runWarmUpTask(key: key, sourceUrl: sourceUrl));
    return Future<void>.value();
  }

  Future<void> _runWarmUpTask({
    required String key,
    required String sourceUrl,
  }) async {
    final generation = _disposeGeneration;
    final warmOpenToken = _feedOpenToken;
    try {
      while (_activeWarmTasks >= _maxWarmSlots) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      _activeWarmTasks++;

      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_players.containsKey(key) || (_leaseCount[key] ?? 0) > 0) {
        return;
      }
      if (_warmCount() >= _maxWarmSlots) {
        return;
      }
      await _evictLruIfNeeded(protect: key);
      if (_players.length >= _maxPoolSize) {
        return;
      }

      if (generation != _disposeGeneration) {
        return;
      }
      // Bail if a newer visible reel was requested while we waited
      if (warmOpenToken < _feedOpenToken) {
        return;
      }
      final player = Player(
        configuration: const PlayerConfiguration(muted: true),
      );
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      if (generation != _disposeGeneration ||
          _players.containsKey(key) ||
          (_leaseCount[key] ?? 0) > 0) {
        await player.dispose();
        return;
      }
      _players[key] = player;
      _sourceByKey[key] = sourceUrl;
      _leaseCount[key] = 0;
      unawaited(_primeFirstFrameOffScreen(key, player));
    } catch (_) {
      await _disposeKey(key);
    } finally {
      _activeWarmTasks--;
      _warmInFlight.remove(key);
    }
  }

  Future<void> releaseFarFrom(
    int visibleIndex, {
    required int window,
    required String? Function(int index) keyResolver,
  }) {
    _enqueueWarm(() async {
      if (_priorityDepth > 0) {
        return;
      }
      final keepKeys = <String>{};
      for (var offset = -window; offset <= window; offset++) {
        final resolved = keyResolver(visibleIndex + offset);
        if (resolved != null && resolved.isNotEmpty) {
          keepKeys.add(resolved);
        }
      }
      final active = _activeKey;
      if (active != null) {
        keepKeys.add(active);
      }
      final toRelease = _players.keys
          .where(
            (k) =>
                !keepKeys.contains(k) &&
                (_leaseCount[k] ?? 0) == 0 &&
                !_warmInFlight.contains(k),
          )
          .toList(growable: false);

      for (final key in toRelease) {
        await _disposeKey(key);
      }

      while (_players.length > _maxPoolSize) {
        final evict = _lruEvictableKey();
        if (evict == null) {
          break;
        }
        await _disposeKey(evict);
      }
    });
    return Future<void>.value();
  }

  /// Marks a warmed slot demux-ready so the visible swap skips the cold
  /// open + rewind. media_kit cannot decode a frame off-screen ([Player.state]
  /// `width` stays null until a [Video] surface attaches, and a paused
  /// `play:false` player never advances position), so "primed" here means the
  /// media is opened and demuxed. The widget's paint-gate still keeps the
  /// poster until the real frame paints on attach, so this never shows black.
  Future<void> _primeFirstFrameOffScreen(String key, Player player) async {
    try {
      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_players[key] != player || (_leaseCount[key] ?? 0) > 0) {
        return;
      }
      try {
        await player.setVolume(0);
        if (player.state.playing) {
          await player.pause();
        }
      } catch (_) {}
      if (_players[key] == player && (_leaseCount[key] ?? 0) == 0) {
        _bufferPrimedKeys.add(key);
      }
    } catch (_) {}
  }
}
