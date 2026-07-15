import 'dart:async';

import 'package:cookster/core/video/reel_render_telemetry.dart';
import 'package:cookster/core/video/reels_device_capability_store.dart';
import 'package:cookster/core/video/reels_tier_analytics.dart';
import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/feed_ping_pong_controller.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/mpv_surface_stability.dart';
import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/services/feature_flags/remote_config_service.dart';
import 'package:cookster/core/widgets/reel_gapless_poster.dart';
import 'package:cookster/core/widgets/reel_playback_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Full-screen MediaKit reel player with poster until a real decoded frame.
///
/// Thumbnail stays visible until **both**:
/// - [Player.state.position] > 32 ms
/// - [Player.state.width] != null
///
/// The [Video] surface uses a stable [ValueKey] (`reel_surface`) across reel
/// swipes so the native output is not torn down on every page change.
class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({
    super.key,
    required this.thumbnailUrl,
    this.posterFallbackUrl,
    this.blurThumbnailUrl,
    required this.videoUrl,
    this.videoId,
    this.hlsUrl,
    this.qualityMp4Urls = const [],
    this.playerPoolKey,
    this.releaseOnDispose = true,
    this.transcodeReady = true,
    this.onPlaybackReady,
    this.onFeedVideoPainted,
    this.onFeedAwaitingPaint,
    this.onVideoCompleted,
    this.onStateChanged,
    this.showProgressBar = false,
  });

  final String thumbnailUrl;
  final String? posterFallbackUrl;
  final String? blurThumbnailUrl;
  /// When false, prefer grid/upload cover over CDN thumb.webp (fresh uploads).
  final bool transcodeReady;
  final String videoUrl;
  final String? videoId;
  final String? hlsUrl;
  final List<String> qualityMp4Urls;
  final String? playerPoolKey;
  /// When false, pool lease is kept across widget lifecycle (reels singleton).
  final bool releaseOnDispose;
  final VoidCallback? onPlaybackReady;
  /// Fired after the feed surface is opaque and has composited real frames —
  /// parent can drop the poster mask on top without a black flash.
  final VoidCallback? onFeedVideoPainted;
  /// Fired before slot recycle / awaiting paint — parent should force poster mask.
  final VoidCallback? onFeedAwaitingPaint;
  final VoidCallback? onVideoCompleted;
  /// Prefer this over [GlobalKey] for parents that mount/unmount the player
  /// (home feed after camera) — avoids StatefulElement.activate null crashes.
  final ValueChanged<ReelVideoPlayerState?>? onStateChanged;
  /// Thin gold progress line at the bottom of feed reels.
  final bool showProgressBar;

  @override
  State<ReelVideoPlayer> createState() => ReelVideoPlayerState();
}

class ReelVideoPlayerState extends State<ReelVideoPlayer> {
  static int _liveInstances = 0;

  static const _frameTimeoutDuration = Duration(seconds: 2);
  static const double _tabletBreakpoint = 600;
  static const int _maxSurfaceRecoveryAttempts = 2;

  final VideoSourceResolver _resolver = const VideoSourceResolver();
  final NetworkPolicy _networkPolicy = NetworkPolicy();
  final MediaKitPlayerPool _pool = MediaKitPlayerPool.instance;
  final VideoAnalyticsTracker _analytics = VideoAnalyticsTracker();

  VideoController? _videoController;
  int _activeFeedSlotIndex = 0;
  String? _pooledKey;
  /// Once true, [Video] with [Key('reel_surface')] stays in the tree across swipes.
  bool _videoSurfaceMounted = false;

  bool _showThumbnail = true;
  bool _frameReady = false;
  /// Decoded frame is trusted; surface may still be settling on Honor/MTK.
  bool _videoSurfaceVisible = false;
  /// Skip heavy reveal delays when pool already has media / flip-back resume.
  bool _fastFeedReveal = false;
  /// After proactive slot recycle, use cold unmask gates until next paint.
  bool _postRecycleUnmask = false;
  int _surfaceRevealedAtMs = 0;
  /// Last successful poster_unmask — ignore spurious native stall events shortly after.
  int _feedPosterUnmaskedAtMs = 0;
  /// Post-unmask position-freeze watchdog: native telemetry only detects a
  /// stall *before* first frame, so a decoder that dies after a clean unmask
  /// (Rendered 0/s flush storm) is otherwise invisible to us until it crashes.
  Timer? _renderDeathWatchdog;
  int _watchdogLastPositionMs = -1;
  int _watchdogStuckTicks = 0;
  int _watchdogNearZeroTicks = 0;
  /// Max position observed after poster_unmask (detects "never left start").
  int _watchdogMaxPositionSinceUnmaskMs = 0;
  /// Intentional rewind-to-0 before unmask needs a long grace — Honor often
  /// sits at pos=0 for 2–4s after that seek while the surface is already live.
  int _watchdogNearZeroGraceUntilMs = 0;
  /// Shared in-flight reason for paint-stall / render-stall / render-death recovery.
  String? _surfaceRecoveryInFlightReason;
  int? _surfaceRecoveryBudgetGen;
  int _surfaceRecoveryAttemptsForGen = 0;
  static const int _maxSurfaceRecoveriesPerGeneration = 1;
  /// Composited frames counted after [_videoSurfaceVisible] — pre-visible ticks
  /// do not render on MTK (Rendered 0/s while opacity 0).
  int _visibleSurfacePaintFrames = 0;
  /// Frames after [Video] is in the tree — avoids trusting demux-only pool state.
  int _surfacePaintFrames = 0;
  bool _showRetry = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  /// Set when a switch/load is requested while [_isInitializing] — drained in finally.
  bool _pendingSwitchAfterInit = false;
  /// Pool key the in-flight [_loadVideo]/[_switchVideo] is targeting.
  String? _initializingForKey;
  /// Last key a switch/load was started for (survives past [_isInitializing]).
  String? _lastSwitchTargetKey;
  /// Epoch ms of the last switch/load start — same-key cooldown for rebuild noise.
  int _lastSwitchAttemptMs = 0;
  static const int _sameKeyRetryCooldownMs = 400;
  /// Temporary storm diagnostics.
  int _switchCallCount = 0;
  int? _lastSwitchDiagAtMs;
  bool _completionNotified = false;
  bool _userPaused = false;
  bool _showPlayPauseIcon = false;
  bool _iconShowsPause = false;
  int _playbackGeneration = 0;
  /// Generation tied to the current [_pooledKey] attach (stale async must bail).
  int _attachGeneration = 0;
  int _frameWatchGeneration = 0;

  Timer? _frameTimeout;
  Timer? _iconHideTimer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;

  final Set<String> _failedSourceUrls = <String>{};
  /// Set when a successful open still fails paint after surface recovery —
  /// stops [_openWithCandidates] from cascading to the next quality tier.
  bool _abortQualityCascade = false;
  bool _upgradeInFlight = false;
  bool _lastOpenCacheHit = false;
  bool _lastOpenPartialCache = false;
  bool _lastOpenWasCold = false;
  DateTime? _openStartedAt;
  int? _stableFrameWidth;
  int? _stableFrameHeight;
  int _dimensionStableTicks = 0;
  int _surfaceRecoveryAttempts = 0;
  int _revealGeneration = 0;
  int _lastDimensionChangeMs = 0;
  /// Bumped when the strict [Video] surface must be torn down and recreated.
  int _surfaceEpoch = 0;

  String get _poolKey =>
      widget.playerPoolKey ?? widget.videoId ?? widget.videoUrl;

  /// Feed keeps pool leases + fast resume; profile opens fresh (strict poster gate).
  bool get _strictSurfaceGate => widget.releaseOnDispose;

  /// Home/profile reels: one [Player] surface, swap media on swipe (no pause).
  int _registeredPlayerHandle = 0;

  bool get _usesFeedVisibleChannel => !widget.releaseOnDispose;

  bool _isTabletLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= _tabletBreakpoint;
  }

  List<VideoSourceCandidate> _resolvedCandidates() {
    return _resolver.resolveCandidates(
      hlsUrl: widget.hlsUrl,
      mp4Url: widget.videoUrl,
      qualityMp4Urls: widget.qualityMp4Urls,
    );
  }

  @override
  void initState() {
    super.initState();
    _liveInstances++;
    widget.onStateChanged?.call(this);
    debugPrint(
      '[ReelVideoPlayer] init hash=$hashCode live=$_liveInstances '
      'key=$_poolKey feedChannel=$_usesFeedVisibleChannel',
    );
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.addListener(_onFeedActiveSlotChanged);
      _pool.addFeedSlotRecycleListener(_onFeedSlotRecycled);
      _pool.addFeedSlotAwaitingRecycleListener(_onFeedSlotAwaitingRecycle);
      _pool.feedSurfaceGeneration.addListener(_onFeedSurfaceBumped);
      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
      unawaited(ReelRenderTelemetry.instance.ensureInitialized());
      ReelRenderTelemetry.instance.onStall = _onRenderTelemetryStall;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }
        // Session-cold (no pool opens yet): do not race a cold HTTPS open
        // ahead of the host's warm-gated ensureVisibleOpen / resume path.
        // Prefetch needs those milliseconds to land file:// bytes first.
        if (_pool.feedOpenCount == 0) {
          return;
        }
        unawaited(_loadVideo());
      });
      return;
    }
    unawaited(_loadVideo());
  }

  /// True when a switch/load is in-flight, pending, or within cooldown for [key].
  bool _isTargetingOrCoolingKey(String key) {
    if (key.isEmpty) {
      return false;
    }
    if (_isInitializing && _initializingForKey == key) {
      return true;
    }
    if (_pendingSwitchAfterInit &&
        (_initializingForKey == key || _lastSwitchTargetKey == key)) {
      return true;
    }
    if (_lastSwitchTargetKey == key) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSwitchAttemptMs < _sameKeyRetryCooldownMs) {
        return true;
      }
    }
    return false;
  }

  void _logSwitchDiag(
    String event, {
    required String reason,
    String? key,
    int? generation,
    int? elapsedMs,
    String? bail,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = _lastSwitchDiagAtMs == null ? 0 : now - _lastSwitchDiagAtMs!;
    _lastSwitchDiagAtMs = now;
    debugPrint(
      '[ReelsPoster] $event reel=${widget.videoId} '
      'reason=$reason call=#$_switchCallCount deltaMs=$delta '
      'init=$_isInitializing initKey=$_initializingForKey '
      'pending=$_pendingSwitchAfterInit lastTarget=$_lastSwitchTargetKey '
      'pooled=$_pooledKey poolKey=${key ?? _poolKey} '
      'gen=${generation ?? _playbackGeneration} '
      '${elapsedMs != null ? 'elapsedMs=$elapsedMs ' : ''}'
      '${bail != null ? 'bail=$bail ' : ''}'
      'visibleKey=${_pool.feedVisibleKey}',
    );
  }

  /// Force-open the current widget reel when the pool visible key drifted (fast scroll).
  Future<void> ensureVisibleOpen() async {
    if (_isDisposed || !_usesFeedVisibleChannel || !mounted) {
      return;
    }
    final key = _poolKey;
    if (key.isEmpty) {
      return;
    }
    // Already opening this reel — do not queue a restart.
    if (_isInitializing && _initializingForKey == key) {
      return;
    }
    if (_pool.isFeedVisibleKey(key) &&
        _pooledKey == key &&
        (_frameReady || _pool.isFrameReady(key))) {
      return;
    }
    if (_isInitializing) {
      _pendingSwitchAfterInit = true;
      return;
    }
    // Explicit settle may retry after a stale bail (bypasses rebuild cooldown).
    if (_pooledKey == null) {
      await _loadVideo(reason: 'ensureVisible');
    } else {
      await _switchVideo(reason: 'ensureVisible');
    }
  }

  /// Re-open feed playback after a route overlay silenced the pool (visit profile, etc.).
  Future<void> resumeAfterRouteOverlay() async {
    if (_isDisposed || !_usesFeedVisibleChannel || !mounted) {
      return;
    }
    final key = _poolKey;
    if (_isInitializing) {
      // Same target already opening — let it finish.
      if (key.isNotEmpty && _initializingForKey == key) {
        return;
      }
      _pendingSwitchAfterInit = true;
      return;
    }
    await _pool.ensureFeedPingPongInitialized();
    if (key.isNotEmpty &&
        _pooledKey == key &&
        _pool.isFeedVisibleKey(key)) {
      await _pool.resumeFeedVisible(key);
      return;
    }
    // Pool was torn down (profile reels) — discard stale attach state and reopen.
    _syncPlaybackGenerationWithPool();
    _playbackGeneration++;
    _revealGeneration++;
    _attachGeneration = _playbackGeneration;
    _frameReady = false;
    _videoSurfaceVisible = false;
    _videoSurfaceMounted = false;
    _pooledKey = null;
    _fastFeedReveal = false;
    _postRecycleUnmask = false;
    _surfacePaintFrames = 0;
    _visibleSurfacePaintFrames = 0;
    _resetDimensionStability();
    _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
    _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);
    _failedSourceUrls.clear();
    widget.onFeedAwaitingPaint?.call();
    _logPoster(
      'route_overlay_resume',
      detail: 'key=$key openCount=${_pool.feedOpenCount}',
    );
    await _loadVideo();
  }

  /// Recover GL surface after app resume without remounting the player widget.
  Future<void> resumeAfterAppBackground() async {
    if (_isDisposed || !_usesFeedVisibleChannel || !mounted) {
      return;
    }
    final widgetKey = _poolKey;
    final poolKey = _pooledKey ?? widgetKey;
    final hadPaint =
        widgetKey.isNotEmpty && _pool.hadRecentPaint(widgetKey);
    final stillPrimed = widgetKey.isNotEmpty &&
        (_pool.isFrameReady(widgetKey) || hadPaint);
    if (stillPrimed) {
      _fastFeedReveal = true;
    } else {
      _videoSurfaceVisible = false;
      _frameReady = false;
      _fastFeedReveal = false;
      _surfacePaintFrames = 0;
      _visibleSurfacePaintFrames = 0;
      _resetDimensionStability();
    }
    if (widgetKey.isNotEmpty) {
      if (!stillPrimed) {
        _pool.invalidatePrimedFrame(widgetKey);
      }
      unawaited(
        _pool.recoverFeedVisibleSurface(
          widgetKey,
          bumpSurface: !stillPrimed && !hadPaint,
        ),
      );
    }
    if (widgetKey.isNotEmpty &&
        widgetKey != poolKey &&
        !_pool.isFeedVisibleKey(widgetKey)) {
      await _loadVideo();
      return;
    }
    final player = _activePlayer;
    if (player == null) {
      await _loadVideo();
      return;
    }
    if (stillPrimed && _canShowVideo(player)) {
      await _onFrameReady(player, generation: _attachGeneration);
      return;
    }
    _afterSurfaceMounted(
      player,
      paintTicks: _needsConstrainedStartGate ? 10 : 4,
    );
    if (_canShowVideo(player)) {
      await _onFrameReady(player, generation: _attachGeneration);
    } else if (widgetKey.isNotEmpty && !_pool.isFeedVisibleKey(widgetKey)) {
      await _loadVideo();
    }
  }

  void _onFeedActiveSlotChanged() {
    if (!mounted || _isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    final slotIndex = _pool.activeFeedSlotIndex;
    if (slotIndex == _activeFeedSlotIndex) {
      return;
    }
    _activeFeedSlotIndex = slotIndex;
    _videoController = _pool.feedSlotVideoController(slotIndex);
    setState(() {});
  }

  void _onFeedSlotAwaitingRecycle() {
    if (!mounted || _isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    _stopRenderDeathWatchdog();
    _revealGeneration++;
    _videoSurfaceVisible = false;
    _frameReady = false;
    _postRecycleUnmask = true;
    _fastFeedReveal = false;
    widget.onFeedAwaitingPaint?.call();
    _logPoster(
      'slot_recycle_await',
      detail: 'openCount=${_pool.feedOpenCount} gen=$_playbackGeneration',
    );
  }

  void _onFeedSlotRecycled() {
    if (!mounted || _isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    final oldHandle = _registeredPlayerHandle;
    if (oldHandle != 0) {
      _registeredPlayerHandle = 0;
      unawaited(() async {
        // Unregister first so notifySurfaceCleanup cannot emit stall into a live watch.
        await ReelRenderTelemetry.instance.unregisterSlot(oldHandle);
        await ReelRenderTelemetry.instance.notifySurfaceCleanup(oldHandle);
      }());
    }
    _surfacePaintFrames = 0;
    _visibleSurfacePaintFrames = 0;
    _frameReady = false;
    _videoSurfaceVisible = false;
    _postRecycleUnmask = true;
    _fastFeedReveal = false;
    _feedPosterUnmaskedAtMs = 0;
    _resetDimensionStability();
    _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
    _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);
    // Remask again after handle swap — awaiting-recycle can race setState and
    // leave Opacity-1 SurfaceView black under a dropped poster.
    widget.onFeedAwaitingPaint?.call();
    _logPoster(
      'slot_recycled',
      detail: 'openCount=${_pool.feedOpenCount} gen=$_playbackGeneration',
    );
    setState(() {});
  }

  /// Keep widget [_playbackGeneration] ahead of the singleton pool watermark.
  /// Remount (photo→video) resets local gen to 0 while [_feedOpenToken] stays
  /// high — without sync every open is instantly stale (bail=no_attach).
  void _syncPlaybackGenerationWithPool() {
    if (!_usesFeedVisibleChannel) {
      return;
    }
    final poolToken = _pool.feedOpenToken;
    if (_playbackGeneration < poolToken) {
      _playbackGeneration = poolToken;
    }
  }

  int _nextPlaybackGeneration() {
    _syncPlaybackGenerationWithPool();
    return ++_playbackGeneration;
  }

  /// Cancel in-flight reveal/unmask when the user swipes to another reel.
  void cancelInFlightPlaybackForPageChange() {
    if (_isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    // onPageChanged already called pauseAllImmediate — a second suspend here
    // bumps the epoch twice and aborts the unmute that should follow unmask.
    _stopRenderDeathWatchdog();
    _feedPosterUnmaskedAtMs = 0;
    _syncPlaybackGenerationWithPool();
    _playbackGeneration++;
    _revealGeneration++;
    // Invalidate in-flight pool presents so they abort before mapping the wrong key.
    _pool.invalidateFeedOpenToken();
    _videoSurfaceVisible = false;
    _frameReady = false;
    _surfacePaintFrames = 0;
    _visibleSurfacePaintFrames = 0;
    widget.onFeedAwaitingPaint?.call();
  }

  void _onFeedSurfaceBumped() {
    if (!mounted || _isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    final key = _pooledKey;
    final keepVisible = key != null &&
        key.isNotEmpty &&
        _poolProvenSurfacePaint(key);
    if (!keepVisible) {
      _videoSurfaceVisible = false;
      _frameReady = false;
      _surfacePaintFrames = 0;
      _resetDimensionStability();
      if (key != null && key.isNotEmpty) {
        _pool.invalidatePrimedFrame(key);
      }
    }
    final player = _activePlayer;
    if (player != null) {
      _afterSurfaceMounted(
        player,
        paintTicks: _needsConstrainedStartGate ? 10 : 4,
      );
    }
    final hadUnmasked = _feedPosterUnmaskedAtMs > 0;
    _logPoster('surface_bumped', detail: 'key=$key keep=$keepVisible');
    if (hadUnmasked &&
        key != null &&
        key.isNotEmpty &&
        !_userPaused &&
        _feedVisibleKeyMatches(key) &&
        !_pool.isActiveAudible(key)) {
      unawaited(_pool.forceFeedAudibleAtPosterUnmask(key));
    }
    setState(() {});
  }

  bool _feedVisibleKeyMatches(String key) =>
      _pool.isFeedVisibleKey(key) && _pool.feedVisibleKey == key;

  /// At most one surface recovery per generation; only one recovery in-flight.
  bool _tryBeginSurfaceRecovery(String reason, int generation) {
    if (_surfaceRecoveryInFlightReason != null) {
      _logPoster(
        'recovery_concurrent_blocked',
        detail: 'gen=$generation already_in_progress=$_surfaceRecoveryInFlightReason',
      );
      return false;
    }
    if (_surfaceRecoveryBudgetGen != generation) {
      _surfaceRecoveryBudgetGen = generation;
      _surfaceRecoveryAttemptsForGen = 0;
    }
    if (_surfaceRecoveryAttemptsForGen >= _maxSurfaceRecoveriesPerGeneration) {
      _logPoster(
        'recovery_budget_exceeded',
        detail: 'gen=$generation attempts=$_surfaceRecoveryAttemptsForGen '
            'fallback=retry_overlay',
      );
      return false;
    }
    _surfaceRecoveryAttemptsForGen++;
    _surfaceRecoveryInFlightReason = reason;
    return true;
  }

  void _endSurfaceRecovery() {
    _surfaceRecoveryInFlightReason = null;
  }

  /// Hide video surface when a reel switch is committed — not during partial scroll.
  void deferSurfaceForSwipe() {
    if (_isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    _pool.pauseAllImmediate();
    _feedPosterUnmaskedAtMs = 0;
    _revealGeneration++;
    if (_videoSurfaceVisible) {
      _videoSurfaceVisible = false;
    }
    if (_frameReady) {
      _frameReady = false;
    }
    _surfacePaintFrames = 0;
    _visibleSurfacePaintFrames = 0;
    widget.onFeedAwaitingPaint?.call();
    _logPoster('swipe_hide_surface');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onStateChanged != widget.onStateChanged) {
      oldWidget.onStateChanged?.call(null);
      widget.onStateChanged?.call(this);
    }
    final id = widget.videoId?.trim() ?? '';
    final targetKey = _poolKey;
    // Same reel: ignore URL/cache/tier settle AND "targeting but not attached"
    // rebuild noise — that loop caused N switch_cold with no open_done.
    if (id.isNotEmpty &&
        id == oldWidget.videoId &&
        _usesFeedVisibleChannel) {
      if (_pooledKey == id ||
          _pool.isFeedVisibleKey(id) ||
          _isTargetingOrCoolingKey(id) ||
          _pool.canInstantResume(id) ||
          _pool.isFrameReady(id) ||
          _pool.isBufferPrimed(id)) {
        return;
      }
    }
    if (_usesFeedVisibleChannel &&
        targetKey.isNotEmpty &&
        _isTargetingOrCoolingKey(targetKey) &&
        (id.isEmpty || id == oldWidget.videoId)) {
      return;
    }
    final videoChanged = widget.videoId != oldWidget.videoId ||
        widget.videoUrl != oldWidget.videoUrl ||
        widget.hlsUrl != oldWidget.hlsUrl ||
        widget.playerPoolKey != oldWidget.playerPoolKey;
    if (videoChanged || _pooledKey != _poolKey) {
      // URL/tier settle while open is in flight must not restart decode.
      if (_isInitializing &&
          widget.videoId != null &&
          widget.videoId!.isNotEmpty &&
          widget.videoId == oldWidget.videoId) {
        return;
      }
      _revealGeneration++;
      _failedSourceUrls.clear();
      // Hide surface flags without setState — a rebuild here re-enters this
      // method for the same unattached key and storms switch_cold.
      _videoSurfaceVisible = false;
      _frameReady = false;
      unawaited(_switchVideo(reason: 'didUpdate'));
    }
  }

  @override
  void dispose() {
    _liveInstances--;
    debugPrint(
      '[ReelVideoPlayer] dispose hash=$hashCode live=$_liveInstances '
      'key=${_pooledKey ?? _poolKey}',
    );
    widget.onStateChanged?.call(null);
    _isDisposed = true;
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.removeListener(_onFeedActiveSlotChanged);
      _pool.removeFeedSlotRecycleListener(_onFeedSlotRecycled);
      _pool.removeFeedSlotAwaitingRecycleListener(_onFeedSlotAwaitingRecycle);
      _pool.feedSurfaceGeneration.removeListener(_onFeedSurfaceBumped);
      if (ReelRenderTelemetry.instance.onStall == _onRenderTelemetryStall) {
        ReelRenderTelemetry.instance.onStall = null;
      }
      if (_registeredPlayerHandle != 0) {
        unawaited(
          ReelRenderTelemetry.instance.unregisterSlot(_registeredPlayerHandle),
        );
        _registeredPlayerHandle = 0;
      }
    }
    _playbackGeneration++;
    _cancelFrameWatch();
    _frameTimeout?.cancel();
    _stopRenderDeathWatchdog();
    _iconHideTimer?.cancel();
    _detachAnalyticsAndListeners();
    final key = _pooledKey;
    _pooledKey = null;
    _videoController = null;
    if (key != null) {
      if (_usesFeedVisibleChannel) {
        unawaited(_pool.pause(key));
      } else if (widget.releaseOnDispose) {
        unawaited(_pool.release(key));
      } else {
        unawaited(_pool.surrenderLease(key));
      }
    }
    super.dispose();
  }

  int _minPositionMsForFrame() {
    if (!_usesFeedVisibleChannel) {
      return 32;
    }
    if (_needsConstrainedStartGate) {
      return _isWarmUnmaskPath() ? 48 : 96;
    }
    return 8;
  }

  bool _hasRealFrame(Player player, [Duration? position]) {
    final pos = position ?? player.state.position;
    if (player.state.width == null) {
      return false;
    }
    final posMs = pos.inMilliseconds;
    if (_needsConstrainedStartGate &&
        _usesFeedVisibleChannel &&
        _openStartedAt != null) {
      final sinceOpenMs =
          DateTime.now().difference(_openStartedAt!).inMilliseconds;
      // Stale demux position from a prior visit (e.g. pos=2400ms on reopen).
      if (sinceOpenMs < 800 && posMs > 600) {
        return false;
      }
    }
    return posMs > _minPositionMsForFrame();
  }

  /// Frames the surface must composite after a decoded frame before we trust
  /// the GL texture has painted. On Android/Impeller the player position
  /// advances a few frames before the texture actually paints — hiding the
  /// poster on position alone shows a black surface (worse at 720p). Requiring
  /// a couple of composited frames closes that black-flash window.
  static const int _minSurfacePaintFrames = 2;
  static const int _minSurfacePaintFramesBuffered = 1;
  static const int _minSurfacePaintFramesConstrained = 8;
  static const int _minDimensionStableTicksConstrained = 4;
  static const int _minDimensionStableTicksCached = 2;

  bool get _needsConstrainedStartGate =>
      DeviceConstraints.instance.needsConstrainedSurfaceRecovery;

  int _frameWaitTimeoutMs() {
    if (_fastFeedReveal || _scrollBackCacheEligible(_pooledKey)) {
      return _needsConstrainedStartGate ? 1600 : 1200;
    }
    if (_lastOpenCacheHit || _lastOpenPartialCache) {
      return _needsConstrainedStartGate ? 2400 : 1600;
    }
    if (_needsConstrainedStartGate) {
      return 5200;
    }
    return 3200;
  }

  /// Parallel retry overlay — must exceed [_frameWaitTimeoutMs] + recovery on Honor.
  Duration _retryUiTimeout() {
    if (_strictSurfaceGate || _needsConstrainedStartGate) {
      final waitMs = _frameWaitTimeoutMs() +
          (_maxSurfaceRecoveryAttempts * 2800) +
          1200;
      return Duration(milliseconds: waitMs);
    }
    return _frameTimeoutDuration;
  }

  void _resetDimensionStability() {
    _stableFrameWidth = null;
    _stableFrameHeight = null;
    _dimensionStableTicks = 0;
    _lastDimensionChangeMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Codec output often pads to YUV stride (406→416 width, 1080→1088 height).
  /// Treating that as a format change reset the surface on Honor (Rendered 0/s).
  bool _isBenignCodecDimensionChange(
    int? prevW,
    int? prevH,
    int? nextW,
    int? nextH,
  ) {
    if (prevW == null ||
        prevH == null ||
        nextW == null ||
        nextH == null) {
      return false;
    }
    if (prevW == nextW && prevH == nextH) {
      return true;
    }
    // Odd container heights (721) → even crop (720) must not restart reveal.
    final evenPrevW = prevW.isOdd ? prevW - 1 : prevW;
    final evenPrevH = prevH.isOdd ? prevH - 1 : prevH;
    final evenNextW = nextW.isOdd ? nextW - 1 : nextW;
    final evenNextH = nextH.isOdd ? nextH - 1 : nextH;
    if (evenPrevW == evenNextW && evenPrevH == evenNextH) {
      return true;
    }
    final dw = (nextW - prevW).abs();
    final dh = (nextH - prevH).abs();
    if (dw == 0 && dh > 0 && dh <= 32) {
      return true;
    }
    if (dh == 0 && dw > 0 && dw <= 32) {
      return true;
    }
    return dw <= 32 && dh <= 32;
  }

  /// Honor/MTK: wait until codec output size stops changing (406→416 stride,
  /// 720→721 crop) before attaching the visible surface — otherwise media_kit
  /// tears down ImageReader mid-reveal (Rendered 0/s, Discarded 30/s).
  Future<bool> _awaitCodecOutputDimensionsSettled(
    Player player, {
    required int generation,
    required int revealGen,
    int stableMs = 64,
  }) async {
    if (!_needsConstrainedStartGate) {
      return true;
    }
    int? lastW = player.state.width;
    int? lastH = player.state.height;
    var settledSince = DateTime.now();
    // Cap hard — odd↔even stride flicker must not add ~2s before unmask.
    final deadline = DateTime.now().add(const Duration(milliseconds: 480));
    while (DateTime.now().isBefore(deadline)) {
      if (!_isCurrentAttach(generation) ||
          revealGen != _revealGeneration ||
          !mounted ||
          _isDisposed) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final w = player.state.width;
      final h = player.state.height;
      if (w == null || h == null || w <= 0 || h <= 0) {
        lastW = w;
        lastH = h;
        settledSince = DateTime.now();
        continue;
      }
      if (w == lastW && h == lastH) {
        if (DateTime.now().difference(settledSince).inMilliseconds >=
            stableMs) {
          return true;
        }
      } else if (_isBenignCodecDimensionChange(lastW, lastH, w, h)) {
        // Stride/odd-height tweaks (721↔720) — keep clock running.
        lastW = w;
        lastH = h;
        if (DateTime.now().difference(settledSince).inMilliseconds >=
            (stableMs ~/ 2).clamp(24, stableMs)) {
          return true;
        }
      } else {
        lastW = w;
        lastH = h;
        settledSince = DateTime.now();
      }
    }
    final w = lastW;
    final h = lastH;
    return w != null && h != null && w > 0 && h > 0;
  }

  int _minPositionAdvanceForPosterUnmask() {
    if (_needsConstrainedStartGate) {
      final key = _pooledKey ?? '';
      final scrollBackReopen = key.isNotEmpty &&
          _pool.hadRecentPaint(key) &&
          !_pool.isFeedVisibleKey(key);
      if (scrollBackReopen) {
        return 150;
      }
      if (_lastOpenCacheHit ||
          _lastOpenPartialCache ||
          _pool.hadRecentPaint(key)) {
        return 48;
      }
      return 120;
    }
    return 32;
  }

  /// Decoder is advancing but Honor may report Rendered 0/s — avoid Retry overlay.
  bool _isDecodeLikelyActive(Player player) {
    if (!player.state.playing) {
      return false;
    }
    if (player.state.width == null || player.state.height == null) {
      return false;
    }
    return player.state.position.inMilliseconds >=
        _minPositionMsForFrame();
  }

  bool _dimensionsSettledFor(int ms) {
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _lastDimensionChangeMs;
    return elapsed >= ms;
  }

  void _trackDimensionStability(Player player) {
    // After poster_unmask, codec stride tweaks must not hide the surface —
    // that recreates ImageReader and kills playback on Honor.
    if (_feedPosterUnmaskedAtMs > 0) {
      return;
    }
    final width = player.state.width;
    final height = player.state.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    if (width == _stableFrameWidth && height == _stableFrameHeight) {
      _dimensionStableTicks++;
    } else {
      _lastDimensionChangeMs = DateTime.now().millisecondsSinceEpoch;
      final hadStableDims =
          _stableFrameWidth != null && _stableFrameHeight != null;
      final benign = hadStableDims &&
          _isBenignCodecDimensionChange(
            _stableFrameWidth,
            _stableFrameHeight,
            width,
            height,
          );
      _stableFrameWidth = width;
      _stableFrameHeight = height;
      if (benign) {
        return;
      }
      _dimensionStableTicks = 0;
      if (hadStableDims &&
          _needsConstrainedStartGate &&
          _frameReady &&
          !_videoSurfaceVisible) {
        _revealGeneration++;
        _frameReady = false;
        _surfacePaintFrames = 0;
        final key = _pooledKey;
        if (key != null && key.isNotEmpty) {
          _pool.invalidatePrimedFrame(key);
        }
        _logPoster('dims_changed', detail: '${width}x$height');
        if (mounted && !_isDisposed) {
          setState(() {});
        }
      }
    }
  }

  int _requiredDimensionStableTicks() {
    if (!_needsConstrainedStartGate) {
      return 0;
    }
    if (_lastOpenCacheHit ||
        _lastOpenPartialCache ||
        _scrollBackCacheEligible(_pooledKey)) {
      return _minDimensionStableTicksCached;
    }
    return _minDimensionStableTicksConstrained;
  }

  int _requiredSurfacePaintFrames() {
    final key = _pooledKey;
    if (_needsConstrainedStartGate) {
      if (_fastFeedReveal && _poolProvenSurfacePaint(key)) {
        return _minSurfacePaintFramesBuffered;
      }
      if (_lastOpenWasCold) {
        if (_lastOpenCacheHit ||
            _lastOpenPartialCache ||
            _scrollBackCacheEligible(key)) {
          return _minSurfacePaintFrames + 1;
        }
        return _minSurfacePaintFramesConstrained;
      }
      if (_lastOpenCacheHit ||
          _lastOpenPartialCache ||
          _scrollBackCacheEligible(key)) {
        return _minSurfacePaintFrames;
      }
      return _minSurfacePaintFramesConstrained;
    }
    if (RemoteConfigService.instance.reelsFastFrameGate && _lastOpenCacheHit) {
      return 0;
    }
    if (!_strictSurfaceGate &&
        key != null &&
        key.isNotEmpty &&
        (_pool.isBufferPrimed(key) || _lastOpenPartialCache) &&
        !_pool.isFrameReady(key)) {
      return _minSurfacePaintFramesBuffered;
    }
    return _minSurfacePaintFrames;
  }

  bool _dimensionsAreStable() {
    final required = _requiredDimensionStableTicks();
    if (required <= 0) {
      return true;
    }
    return _dimensionStableTicks >= required;
  }

  /// Adaptive BoxFit: use [BoxFit.cover] for standard 9:16 content (seamless
  /// full-bleed) but fall back to [BoxFit.contain] when the video's native AR
  /// deviates by more than 15% from the container's AR. This prevents the
  /// aggressive zoom-crop seen on square, 4:3, or 2:3 encodes.
  BoxFit _adaptiveFit(BoxConstraints constraints) {
    final vw = _stableFrameWidth;
    final vh = _stableFrameHeight;
    if (vw == null || vh == null || vw <= 0 || vh <= 0) {
      return BoxFit.cover; // Safe default until dimensions are known.
    }
    
    final videoAR = vw / vh;
    
    // Standard 9:16 video is ~0.5625. Modern phones are 9:19.5 (~0.46) to 9:21 (~0.42).
    // The deviation can exceed 30%, which previously triggered BoxFit.contain (letterboxing).
    // We want all "vertical" videos (up to ~3:4 = 0.75) to cover the screen.
    // Only use contain for videos that are square (1.0) or landscape (>1.0).
    if (videoAR <= 0.8) {
      return BoxFit.cover;
    }
    
    return BoxFit.contain;
  }

  bool _canShowVideo(Player player, [Duration? position]) {
    if (!_videoSurfaceMounted ||
        _surfacePaintFrames < _requiredSurfacePaintFrames()) {
      return false;
    }
    if (!_dimensionsAreStable()) {
      return false;
    }
    return _hasRealFrame(player, position);
  }

  bool _shouldShowVideoLayer(Player? player) {
    if (!_videoSurfaceMounted || player == null) {
      return false;
    }
    if (_frameReady) {
      return true;
    }
    if (_surfacePaintFrames >= _requiredSurfacePaintFrames() &&
        _hasRealFrame(player)) {
      return true;
    }
    return false;
  }

  void _resetFrameStateForKey(String key) {
    final attachGen = _attachGeneration;
    _frameWatchGeneration++;
    _userPaused = false;
    _surfacePaintFrames = 0;
    _resetDimensionStability();
    _surfaceRecoveryAttempts = 0;
    _stopRenderDeathWatchdog();
    if (key.isNotEmpty) {
      _pool.clearUserPaused(key);
      if (_strictSurfaceGate) {
        _pool.invalidatePrimedFrame(key);
      }
    }
    _showThumbnail = true;
    _frameReady = false;
    _videoSurfaceVisible = false;
    _showRetry = false;
    _completionNotified = false;
    _frameTimeout?.cancel();
    _frameTimeout = Timer(_retryUiTimeout(), () {
      if (!mounted || _isDisposed || _frameReady) {
        return;
      }
      if (!_isCurrentAttach(attachGen)) {
        return;
      }
      final player = _videoController?.player;
      if (player != null &&
          player.state.playing &&
          player.state.position.inMilliseconds > 200) {
        unawaited(_onFrameReady(player, generation: _attachGeneration));
        return;
      }
      if (player != null && _isDecodeLikelyActive(player)) {
        return;
      }
      setState(() => _showRetry = true);
    });
  }

  void _cancelFrameWatch() {
    _frameWatchGeneration++;
    _positionSub?.cancel();
    _positionSub = null;
    _widthSub?.cancel();
    _widthSub = null;
    _heightSub?.cancel();
    _heightSub = null;
    _frameTimeout?.cancel();
    _frameTimeout = null;
  }

  void _notifyFrameReady(Player player, {required int generation}) {
    if (_usesFeedVisibleChannel && _needsConstrainedStartGate) {
      _scheduleFeedFrameReadyAfterSurfaceMount(
        player,
        generation: generation,
      );
      return;
    }
    unawaited(_onFrameReady(player, generation: generation));
  }

  void _onPlayerStateTick(Player player) {
    if (!mounted || _isDisposed) {
      return;
    }
    // Auto-seek to start on completion — some devices stall on the completion
    // notifier and never trigger the loop restart callback.
    if (_frameReady &&
        player.state.completed &&
        _usesFeedVisibleChannel &&
        !_userPaused &&
        !_completionNotified) {
      _completionNotified = true;
      widget.onVideoCompleted?.call();
      return;
    }
    if (_frameReady) {
      return;
    }
    _trackDimensionStability(player);
    if (_canShowVideo(player)) {
      _notifyFrameReady(player, generation: _attachGeneration);
    }
  }

  void _afterSurfaceMounted(Player player, {int paintTicks = 6}) {
    // Count composited frames for several frames after mount (or until the
    // frame is shown) so [_surfacePaintFrames] reflects real compositing, not
    // just a single post-frame tick.
    void scheduleTick(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }
        _surfacePaintFrames++;
        _onPlayerStateTick(player);
        if (!_frameReady && remaining > 0) {
          scheduleTick(remaining - 1);
        }
      });
    }

    scheduleTick(paintTicks);
  }

  bool _isCurrentAttach(int generation) =>
      generation == _playbackGeneration && generation == _attachGeneration;

  Future<void> _ensureAudibleForKey(String key, {required int generation}) async {
    if (!_isCurrentAttach(generation) ||
        key.isEmpty ||
        _userPaused ||
        !mounted ||
        _isDisposed) {
      return;
    }
    if (_pooledKey != key) {
      return;
    }
    if (_usesFeedVisibleChannel && _pool.isFeedVisibleAudible(key)) {
      return;
    }
    if (!_usesFeedVisibleChannel && _pool.isActiveAudible(key)) {
      return;
    }
    await _pool.activateVisible(key);
  }

  bool _poolProvenSurfacePaint(String? key) =>
      key != null &&
      key.isNotEmpty &&
      (_pool.isFrameReady(key) || _pool.hadRecentPaint(key));

  bool _scrollBackCacheEligible(String? key) =>
      key != null && key.isNotEmpty && _pool.hadRecentPaint(key);

  /// Honor/MTK instant path: pool already painted this key — skip slow reveal.
  bool _honorInstantRevealEligible(Player player) {
    if (!_needsConstrainedStartGate) {
      return false;
    }
    final key = _pooledKey;
    if (key == null || key.isEmpty || !_pool.isFrameReady(key)) {
      return false;
    }
    if (!_hasRealFrame(player)) {
      return false;
    }
    return _fastFeedReveal || !_lastOpenWasCold;
  }

  /// Honor/MTK: fast-reveal when surface was proven; warm gates for cache hits.
  bool _eligibleForFastReveal(Player player) {
    if (_honorInstantRevealEligible(player)) {
      return true;
    }
    if (_needsConstrainedStartGate) {
      return false;
    }
    final key = _pooledKey;
    if (_fastFeedReveal && _poolProvenSurfacePaint(key)) {
      return true;
    }
    if ((_lastOpenCacheHit || _lastOpenPartialCache) &&
        _scrollBackCacheEligible(key)) {
      return true;
    }
    return !_lastOpenWasCold &&
        _poolProvenSurfacePaint(key) &&
        _pool.canInstantResume(key!) &&
        _hasRealFrame(player);
  }

  bool _isWarmUnmaskPath() {
    if (!_needsConstrainedStartGate) {
      return true;
    }
    if (_postRecycleUnmask) {
      return false;
    }
    final key = _pooledKey ?? '';
    return _lastOpenCacheHit ||
        _lastOpenPartialCache ||
        (_fastFeedReveal &&
            key.isNotEmpty &&
            (_pool.hadRecentPaint(key) || _pool.isBufferPrimed(key)));
  }

  int _requiredOpaquePaintFrames() {
    if (!_needsConstrainedStartGate) {
      return 2;
    }
    // Cold network opens used to wait 4 frames (~200ms+) after long flings.
    return _isWarmUnmaskPath() ? 2 : 3;
  }

  /// Mount [Video] and wait for native ImageReader before [Player.open] on Honor.
  /// Logs: decode headless → onSurfaceAvailable → codec release → Rendered 0/s.
  Future<void> _ensureFeedSurfaceMountedBeforeOpen({
    required int generation,
  }) async {
    if (!_usesFeedVisibleChannel || !_needsConstrainedStartGate) {
      return;
    }
    await _pool.ensureFeedPingPongInitialized();
    final slotIndex = _pool.activeFeedSlotIndex;
    _activeFeedSlotIndex = slotIndex;
    _videoController = _pool.feedSlotVideoController(slotIndex);
    final needsBuild = !_videoSurfaceMounted;
    _videoSurfaceMounted = true;
    if (needsBuild && mounted && !_isDisposed) {
      setState(() {});
    }
    final warm = _isWarmUnmaskPath() || _videoSurfaceMounted;
    final mountFrames = warm ? 2 : 6;
    for (var i = 0; i < mountFrames; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (generation != _playbackGeneration || !mounted || _isDisposed) {
        return;
      }
    }
    final delayMs = warm ? (_lastOpenCacheHit ? 0 : 32) : 150;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (generation != _playbackGeneration || !mounted || _isDisposed) {
        return;
      }
    }
    _logPoster('surface_mounted', detail: 'slot=$slotIndex gen=$generation warm=$warm');
  }

  void _scheduleFeedFrameReadyAfterSurfaceMount(
    Player player, {
    required int generation,
  }) {
    unawaited(() async {
      if (!_needsConstrainedStartGate) {
        if (_canShowVideo(player) &&
            _isCurrentAttach(generation) &&
            mounted &&
            !_isDisposed) {
          await _onFrameReady(player, generation: generation);
        }
        return;
      }
      final warm = _isWarmUnmaskPath();
      final frameWaits = warm ? 1 : 4;
      for (var i = 0; i < frameWaits; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
          return;
        }
      }
      if (!warm) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      } else if (!_lastOpenCacheHit) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
      if (_canShowVideo(player)) {
        await _onFrameReady(player, generation: generation);
      }
    }());
  }

  Future<void> _setVideoSurfaceVisible({
    required int generation,
    required Player player,
    required String detail,
  }) async {
    _videoSurfaceVisible = true;
    _visibleSurfacePaintFrames = 0;
    _surfaceRevealedAtMs = DateTime.now().millisecondsSinceEpoch;
    _logPoster(
      'surface_revealed',
      detail: '$detail ${player.state.width}x${player.state.height} '
          'pos=${player.state.position.inMilliseconds}ms',
    );
    if (mounted && !_isDisposed) {
      setState(() {});
    }
    if (_usesFeedVisibleChannel) {
      final key = _pooledKey;
      await _awaitFeedOpaquePaint(generation: generation, player: player);
      if (key != null &&
          key.isNotEmpty &&
          _isCurrentAttach(generation) &&
          mounted &&
          !_isDisposed &&
          _videoSurfaceVisible &&
          !_pool.isFrameReady(key)) {
        _pool.markFrameReadyFromSurface(key);
      }
    }
  }

  Future<void> _ensureFeedAudibleAfterPaint(String key, int generation) async {
    if (key.isEmpty ||
        _userPaused ||
        !_isCurrentAttach(generation) ||
        !mounted ||
        _isDisposed ||
        !_videoSurfaceVisible) {
      return;
    }
    await _pool.ensureFeedAudibleWithRetry(key);
  }

  Future<void> _resumeAudibleAfterReveal({
    required String? key,
    required int generation,
  }) async {
    if (key == null ||
        key.isEmpty ||
        _userPaused ||
        !_isCurrentAttach(generation)) {
      return;
    }
    if (_usesFeedVisibleChannel) {
      if (!_pool.isActiveAudible(key)) {
        await _pool.feedResumeAudibleWhenReady(key);
      }
      return;
    }
    if (!_pool.isActiveAudible(key)) {
      await _ensureAudibleForKey(key, generation: generation);
    }
  }

  Future<void> _revealVideoSurface({
    required int generation,
    required Player player,
  }) async {
    final revealGen = ++_revealGeneration;
    final startW = player.state.width;
    final startH = player.state.height;
    final startPosMs = player.state.position.inMilliseconds;
    final useFastReveal = _eligibleForFastReveal(player);

    if (useFastReveal) {
      for (var i = 0; i < 2; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrentAttach(generation) ||
            revealGen != _revealGeneration ||
            !mounted ||
            _isDisposed) {
          _logPoster('surface_reveal_aborted', detail: 'stale_fast');
          return;
        }
      }
      if (_canShowVideo(player)) {
        if (!_isCurrentAttach(generation) ||
            revealGen != _revealGeneration ||
            !mounted ||
            _isDisposed) {
          return;
        }
        if (_needsConstrainedStartGate) {
          final settled = await _awaitCodecOutputDimensionsSettled(
            player,
            generation: generation,
            revealGen: revealGen,
          );
          if (!settled) {
            _logPoster('surface_reveal_aborted', detail: 'dims_unsettled_fast');
            return;
          }
        }
        await _setVideoSurfaceVisible(
          generation: generation,
          player: player,
          detail: 'fast',
        );
        return;
      }
    }

    if (_needsConstrainedStartGate) {
      final warm = _isWarmUnmaskPath();
      final gateMs = (warm ||
              _lastOpenCacheHit ||
              _lastOpenPartialCache ||
              _scrollBackCacheEligible(_pooledKey) ||
              _fastFeedReveal)
          ? 0
          : 48;
      if (gateMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: gateMs));
      }
      if (!_isCurrentAttach(generation) ||
          revealGen != _revealGeneration ||
          !mounted ||
          _isDisposed) {
        _logPoster('surface_reveal_aborted', detail: 'stale_after_delay');
        return;
      }
      final frameWaits = warm ? 1 : 2;
      for (var i = 0; i < frameWaits; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrentAttach(generation) ||
            revealGen != _revealGeneration ||
            !mounted ||
            _isDisposed) {
          _logPoster('surface_reveal_aborted', detail: 'stale_after_frame');
          return;
        }
      }
      var polled = 0;
      final pollLimitMs = (_fastFeedReveal || _scrollBackCacheEligible(_pooledKey))
          ? 1200
          : (warm ? 1200 : 2000);
      while (polled < pollLimitMs) {
        if (!_isCurrentAttach(generation) ||
            revealGen != _revealGeneration ||
            !mounted ||
            _isDisposed) {
          _logPoster('surface_reveal_aborted', detail: 'stale_while_poll');
          return;
        }
        final w = player.state.width;
        final h = player.state.height;
        if (w != startW || h != startH) {
          if (_isBenignCodecDimensionChange(startW, startH, w, h)) {
            // Keep polling — stride padding is not a failed reveal.
          } else {
            _logPoster(
              'surface_reveal_aborted',
              detail: 'dims ${startW}x$startH -> ${w}x$h',
            );
            _videoSurfaceVisible = false;
            _frameReady = false;
            _surfacePaintFrames = 0;
            _resetDimensionStability();
            final key = _pooledKey;
            if (key != null && key.isNotEmpty) {
              _pool.invalidatePrimedFrame(key);
            }
            if (mounted && !_isDisposed) {
              setState(() {});
            }
            return;
          }
        }
        final posMs = player.state.position.inMilliseconds;
        final minAdvanceMs = warm
            ? 32
            : ((_lastOpenCacheHit || _lastOpenPartialCache) ? 48 : 120);
        if (posMs >= startPosMs + minAdvanceMs &&
            _canShowVideo(player) &&
            _dimensionsSettledFor(
              warm
                  ? 48
                  : ((_lastOpenCacheHit || _lastOpenPartialCache) ? 60 : 280),
            )) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
        polled += 50;
      }
      if (!_canShowVideo(player)) {
        _logPoster('surface_reveal_timeout', detail: 'poster_hold');
        _frameReady = false;
        _videoSurfaceVisible = false;
        final key = _pooledKey;
        if (key != null && key.isNotEmpty) {
          _pool.invalidatePrimedFrame(key);
        }
        if (mounted && !_isDisposed) {
          setState(() {});
        }
        return;
      }
    } else {
      // 32ms is sufficient for Qualcomm/Pixel to finish the surface handshake.
      await Future<void>.delayed(const Duration(milliseconds: 32));
      if (!_isCurrentAttach(generation) || revealGen != _revealGeneration) {
        return;
      }
    }

    if (!_isCurrentAttach(generation) ||
        revealGen != _revealGeneration ||
        !mounted ||
        _isDisposed ||
        !_canShowVideo(player)) {
      _logPoster('surface_reveal_aborted', detail: 'final_check');
      return;
    }
    if (_needsConstrainedStartGate) {
      final settled = await _awaitCodecOutputDimensionsSettled(
        player,
        generation: generation,
        revealGen: revealGen,
      );
      if (!settled) {
        _logPoster('surface_reveal_aborted', detail: 'dims_unsettled');
        return;
      }
    }
    await _setVideoSurfaceVisible(
      generation: generation,
      player: player,
      detail: '',
    );
  }

  /// Poster mask stays up until frames composited *after* the surface is visible.
  /// Pre-visible decoder ticks show Rendered 0/s on Honor while opacity was 0.
  Future<void> _awaitFeedOpaquePaint({
    required int generation,
    required Player player,
  }) async {
    final requiredFrames = _requiredOpaquePaintFrames();
    final wallStartMs = DateTime.now().millisecondsSinceEpoch;
    final minWallMs = _needsConstrainedStartGate
        ? (_isWarmUnmaskPath() ? 24 : 64)
        : 0;
    final startPosMs = player.state.position.inMilliseconds;

    for (var i = 0; i < requiredFrames; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!_isCurrentAttach(generation) ||
          !mounted ||
          _isDisposed ||
          !_videoSurfaceVisible) {
        return;
      }
      _visibleSurfacePaintFrames++;
      _onPlayerStateTick(player);
    }

    if (_needsConstrainedStartGate) {
      var polled = 0;
      while (polled < 400) {
        if (!_isCurrentAttach(generation) ||
            !mounted ||
            _isDisposed ||
            !_videoSurfaceVisible) {
          return;
        }
        final posMs = player.state.position.inMilliseconds;
        final minAdvance = _minPositionAdvanceForPosterUnmask();
        if (posMs >= startPosMs + minAdvance && _canShowVideo(player)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
        polled += 16;
        _onPlayerStateTick(player);
      }
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - wallStartMs;
    if (minWallMs > 0 && elapsed < minWallMs) {
      await Future<void>.delayed(Duration(milliseconds: minWallMs - elapsed));
      if (!_isCurrentAttach(generation) ||
          !mounted ||
          _isDisposed ||
          !_videoSurfaceVisible) {
        return;
      }
    }

    if (!_canShowVideo(player)) {
      if (_isDecodeLikelyActive(player)) {
        _logPoster('poster_hold', detail: 'decode_active_wait_paint');
        var polled = 0;
        while (polled < 1200) {
          if (!_isCurrentAttach(generation) ||
              !mounted ||
              _isDisposed ||
              !_videoSurfaceVisible) {
            return;
          }
          if (_canShowVideo(player)) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 16));
          polled += 16;
          _onPlayerStateTick(player);
        }
      }
      if (!_canShowVideo(player)) {
        _logPoster('poster_hold', detail: 'opaque_wait');
        return;
      }
    }
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }

    final handle = _registeredPlayerHandle;
    final paintReady = _canShowVideo(player);
    if (_usesFeedVisibleChannel && handle != 0) {
      await ReelRenderTelemetry.instance.surfaceRevealed(handle);
    }

    final confirmed = await ReelRenderTelemetry.instance.waitForRenderConfirm(
      playerHandle: handle,
      paintReady: paintReady,
      paintReadyProbe: () => _canShowVideo(player),
      trustPaintReady: !_needsConstrainedStartGate,
    );

    if (!_isCurrentAttach(generation) ||
        !mounted ||
        _isDisposed ||
        !_videoSurfaceVisible) {
      return;
    }

    if (!confirmed) {
      if (_usesFeedVisibleChannel) {
        _logPoster('poster_hold', detail: 'render_confirm_failed');
        unawaited(
          _handleRenderStall(
            signature: 'timeout',
            generation: generation,
          ),
        );
      }
      return;
    }

    final key = _pooledKey;
    if (key != null && key.isNotEmpty) {
      // Must precede poster_unmask — unmute gates on [isFrameReady].
      _pool.markFrameReadyFromSurface(key);
    }

    var rewoundForUnmask = false;
    if (_usesFeedVisibleChannel && player.state.position.inMilliseconds > 200) {
      // The video has been playing muted to pump frames and verify surface health.
      // If it advanced significantly, rewind to the beginning BEFORE dropping the poster
      // so the user doesn't see a visual jump ("shake") when the frame resets.
      rewoundForUnmask = true;
      await player.seek(Duration.zero);
      var polled = 0;
      while (polled < 200) {
        if (!_isCurrentAttach(generation) || !mounted || _isDisposed) return;
        if (player.state.position.inMilliseconds < 100) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
        polled += 16;
        _onPlayerStateTick(player);
      }
      // Seek alone can leave Honor sitting at 0 with playing=true until play()
      // restarts the clock — without this the render-death watchdog fires.
      await player.play();
    }

    _logPoster(
      'poster_unmask',
      detail: 'opaque=$_visibleSurfacePaintFrames/$requiredFrames '
          'warm=${_isWarmUnmaskPath()} revealAge=${DateTime.now().millisecondsSinceEpoch - _surfaceRevealedAtMs}ms',
    );
    _postRecycleUnmask = false;
    _feedPosterUnmaskedAtMs = DateTime.now().millisecondsSinceEpoch;
    
    if (key != null && key.isNotEmpty) {
      _startRenderDeathWatchdog(
        player: player,
        generation: generation,
        key: key,
        rewoundForUnmask: rewoundForUnmask,
      );
    }
    
    if (_usesFeedVisibleChannel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }
        widget.onFeedVideoPainted?.call();
      });
      unawaited(_recordCleanOpen());
      if (key != null && key.isNotEmpty) {
        unawaited(_pool.forceFeedAudibleAtPosterUnmask(key));
      }
    }
  }

  void _onRenderTelemetryStall(ReelRenderStallEvent event) {
    if (event.playerHandle != _registeredPlayerHandle) {
      return;
    }
    if (!mounted || _isDisposed) {
      return;
    }
    unawaited(
      _handleRenderStall(
        signature: event.signature,
        generation: _attachGeneration,
      ),
    );
  }

  Future<void> _registerRenderSlot(Player player) async {
    if (!_usesFeedVisibleChannel) {
      return;
    }
    final handle = await ReelRenderTelemetry.instance.playerHandleFor(player);
    if (handle == 0) {
      return;
    }
    if (_registeredPlayerHandle != 0 &&
        _registeredPlayerHandle != handle) {
      await ReelRenderTelemetry.instance.unregisterSlot(_registeredPlayerHandle);
    }
    _registeredPlayerHandle = handle;
    await ReelRenderTelemetry.instance.registerSlot(
      slotIndex: _activeFeedSlotIndex,
      playerHandle: handle,
    );
  }

  Future<void> _recordCleanOpen() async {
    if (_needsConstrainedStartGate) {
      return;
    }
    final fromTier = DeviceConstraints.instance.deviceTierSync;
    final promoted =
        await ReelsDeviceCapabilityStore.instance.recordCleanOpen();
    if (promoted != null) {
      DeviceConstraints.instance.refreshFromMeasuredProfile();
      if (promoted != fromTier) {
        unawaited(
          reelsTierAnalytics.logTierPromoted(
            fromTier: fromTier,
            toTier: promoted,
          ),
        );
      }
    }
  }

  void _startRenderDeathWatchdog({
    required Player player,
    required int generation,
    required String key,
    bool rewoundForUnmask = false,
  }) {
    if (!_needsConstrainedStartGate || key.isEmpty) {
      return;
    }
    _renderDeathWatchdog?.cancel();
    _watchdogLastPositionMs = player.state.position.inMilliseconds;
    _watchdogStuckTicks = 0;
    _watchdogNearZeroTicks = 0;
    _watchdogMaxPositionSinceUnmaskMs =
        player.state.position.inMilliseconds.clamp(0, 1 << 30);
    // After an intentional rewind-to-0 for a clean unmask, Honor often needs
    // several seconds before position advances again — do not treat that as
    // render death (that path hard-recycles a already-confirmed surface).
    _watchdogNearZeroGraceUntilMs = rewoundForUnmask
        ? DateTime.now().millisecondsSinceEpoch + 5000
        : DateTime.now().millisecondsSinceEpoch + 1500;
    _renderDeathWatchdog = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!_isCurrentAttach(generation) ||
          !mounted ||
          _isDisposed ||
          _surfaceRecoveryInFlightReason != null) {
        timer.cancel();
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final posMs = player.state.position.inMilliseconds;
      if (posMs > _watchdogMaxPositionSinceUnmaskMs) {
        _watchdogMaxPositionSinceUnmaskMs = posMs;
      }
      final sinceUnmaskMs = nowMs - _feedPosterUnmaskedAtMs;
      final pastGrace = nowMs >= _watchdogNearZeroGraceUntilMs;
      if (player.state.playing && !player.state.completed) {
        if (posMs - _watchdogLastPositionMs < 120) {
          _watchdogStuckTicks++;
        } else {
          _watchdogStuckTicks = 0;
        }
        // Only count near-zero after grace, and only while we've *never*
        // left the start zone. A successful paint + rewind-to-0 must not
        // trip hard recycle just because the clock is slow to restart.
        if (pastGrace &&
            posMs < 280 &&
            _watchdogMaxPositionSinceUnmaskMs < 400) {
          _watchdogNearZeroTicks++;
        } else {
          _watchdogNearZeroTicks = 0;
        }
      } else {
        _watchdogStuckTicks = 0;
        _watchdogNearZeroTicks = 0;
      }
      _watchdogLastPositionMs = posMs;
      // Only recover when decode never advances after unmask (Rendered 0/s /
      // seek-on-resize loop). Mid-playback micro-stalls must not trigger a full
      // slot recycle — that disposes VideoOutput and adds multi-second delay.
      if (_watchdogNearZeroTicks >= 5 &&
          pastGrace &&
          posMs < 280 &&
          _watchdogMaxPositionSinceUnmaskMs < 400) {
        timer.cancel();
        _logPoster(
          'render_death_detected',
          detail: 'pos=${posMs}ms stuck=$_watchdogStuckTicks '
              'nearZero=$_watchdogNearZeroTicks '
              'maxPos=${_watchdogMaxPositionSinceUnmaskMs}ms '
              'sinceUnmask=${sinceUnmaskMs}ms key=$key',
        );
        unawaited(_recoverFromRenderDeath(key));
      }
    });
  }

  void _stopRenderDeathWatchdog() {
    _renderDeathWatchdog?.cancel();
    _renderDeathWatchdog = null;
    _watchdogStuckTicks = 0;
    _watchdogNearZeroTicks = 0;
    _watchdogLastPositionMs = -1;
    _watchdogMaxPositionSinceUnmaskMs = 0;
    _watchdogNearZeroGraceUntilMs = 0;
  }

  /// Resolve the 360 MP4 playback URL for this reel, if the ladder has one.
  /// Used as a render-death fallback tier on constrained devices.
  Future<String?> _lowestTierSourceUrl() async {
    for (final candidate in _resolvedCandidates()) {
      if (_resolver.mp4Tier(candidate.url) == '360') {
        final network = await _networkPolicy.currentNetworkClass();
        return _resolvePlaybackUrlForSource(candidate, network);
      }
    }
    return null;
  }

  /// Hard recovery for a decoder that has gone render-dead after a clean
  /// unmask. Native telemetry cannot see this (it only watches for a stall
  /// before the first frame), and soft play/seek recovery does not restore a
  /// broken render pipe — only a brand new Player/texture does.
  Future<void> _recoverFromRenderDeath(String key) async {
    if (_isDisposed || !mounted) {
      return;
    }
    final generation = _nextPlaybackGeneration();
    if (!_tryBeginSurfaceRecovery('render_death', generation)) {
      return;
    }
    _stopRenderDeathWatchdog();
    _logPoster('render_death_recovery', detail: 'key=$key gen=$generation');
    try {
      // Render death on Honor is a surface/dimension failure, not a decode-
      // capacity one, so retry on the lowest (360) tier: it often carries
      // friendlier (even) dimensions than the odd-height 720 that trips the
      // MediaCodec surface reconfigure loop.
      final sourceUrl =
          await _lowestTierSourceUrl() ?? _pool.sourceUrlForKey(key);
      await _pool.forceRecycleFeedVisibleSurfaceHard(key);
      if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
      _feedPosterUnmaskedAtMs = 0;
      _frameReady = false;
      _videoSurfaceVisible = false;
      _surfacePaintFrames = 0;
      _visibleSurfacePaintFrames = 0;
      _resetDimensionStability();
      _showThumbnail = true;
      _postRecycleUnmask = true;
      if (mounted && !_isDisposed) {
        setState(() {});
      }
      widget.onFeedAwaitingPaint?.call();
      if (sourceUrl == null || sourceUrl.isEmpty) {
        _isInitializing = false;
        unawaited(_loadVideo());
        return;
      }
      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
      _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);
      _pooledKey = key;
      final pooled = await _pool.openVisibleReel(
        key: key,
        sourceUrl: sourceUrl,
        openToken: generation,
      );
      if (pooled == null || !_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
      _activeFeedSlotIndex =
          pooled.feedActiveSlotIndex ?? _pool.activeFeedSlotIndex;
      _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);
      await _registerRenderSlot(pooled.player);
      await _attachPlayer(pooled.player, generation: generation);
    } catch (e) {
      _logPoster('render_death_recovery_failed', detail: 'err=$e');
      _isInitializing = false;
      unawaited(_loadVideo());
    } finally {
      _endSurfaceRecovery();
    }
  }

  Future<void> _handleRenderStall({
    required String signature,
    required int generation,
  }) async {
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    // Once the poster has dropped and the surface is live, re-masking it would
    // produce a visible flash. Playback (incl. audio) is already progressing at
    // that point, so a late stall signal here is treated as a no-op to keep the
    // surface stable rather than thrashing the decoder in a re-open loop.
    if (_feedPosterUnmaskedAtMs > 0) {
      return;
    }
    final key = _pooledKey;
    if (key == null || key.isEmpty) {
      return;
    }
    if (!_tryBeginSurfaceRecovery('render_stall', generation)) {
      return;
    }
    debugPrint(
      '[ReelRender] reel_render_failure sig=$signature reel=$key '
      'gen=$generation tier=${DeviceConstraints.instance.deviceTierSync.name}',
    );
    try {
      final fromTier = DeviceConstraints.instance.deviceTierSync;
      final toTier =
          await ReelsDeviceCapabilityStore.instance.recordFailure(signature);
      DeviceConstraints.instance.refreshFromMeasuredProfile();
      unawaited(
        reelsTierAnalytics.logTierDemoted(
          fromTier: fromTier,
          toTier: toTier,
          signature: signature,
        ),
      );
      unawaited(
        reelsTierAnalytics.logRenderFailure(
          ReelRenderStallEvent(
            slotIndex: _activeFeedSlotIndex,
            playerHandle: _registeredPlayerHandle,
            signature: signature,
            tsMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      if (!_isCurrentAttach(generation)) {
        return;
      }
      _frameReady = false;
      _videoSurfaceVisible = false;
      _showThumbnail = true;
      if (mounted && !_isDisposed) {
        setState(() {});
      }
      await _pool.recoverFeedVisibleSurfaceAfterStall(
        key,
        openToken: generation,
      );
      if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
      _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);
      final player = _activePlayer;
      if (player != null) {
        await _registerRenderSlot(player);
        _postRecycleUnmask = true;
        await _openWithCandidates(
          generation: generation,
          poolKey: key,
          onFailure: () {
            if (mounted && !_isDisposed && _isCurrentAttach(generation)) {
              setState(() => _showRetry = true);
            }
          },
        );
      }
    } finally {
      _endSurfaceRecovery();
    }
  }

  Future<void> _onFrameReady(Player player, {required int generation}) async {
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    if (_frameReady) {
      return;
    }
    if (!_canShowVideo(player)) {
      return;
    }
    final key = _pooledKey;
    _frameReady = true;
    _showThumbnail = false;
    _showRetry = false;
    _frameTimeout?.cancel();

    widget.onPlaybackReady?.call();
    FeedSurfaceParityLock.recordPainted(player.state.width, player.state.height);
    _logPoster(
      'frame_ready',
      detail: 'key=$key ${player.state.width}x${player.state.height} '
          'pos=${player.state.position.inMilliseconds}ms',
    );

    if (_needsConstrainedStartGate && _usesFeedVisibleChannel) {
      if (!_honorInstantRevealEligible(player)) {
        if (_isWarmUnmaskPath()) {
          await WidgetsBinding.instance.endOfFrame;
          if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
            return;
          }
          if (!_lastOpenCacheHit) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
              return;
            }
          }
        } else {
          for (var i = 0; i < 3; i++) {
            await WidgetsBinding.instance.endOfFrame;
            if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
              return;
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
            return;
          }
        }
      }
    }

    await _revealVideoSurface(generation: generation, player: player);
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    if (!_videoSurfaceVisible) {
      return;
    }

    if (!_usesFeedVisibleChannel) {
      await _resumeAudibleAfterReveal(key: key, generation: generation);
      if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
    }
    unawaited(_scheduleCachedHdUpgrade(generation: generation));
  }

  /// Step up to cached HD after paint + audible have settled — must not bump
  /// [_playbackGeneration] or the in-flight unmute is aborted.
  Future<void> _scheduleCachedHdUpgrade({required int generation}) async {
    // 500ms ensures poster unmask is fully complete before any quality switch,
    // preventing the visible 360→720 flash that occurred at 220ms.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    // Only upgrade if poster is already down — never during poster reveal.
    if (_feedPosterUnmaskedAtMs <= 0) {
      return;
    }
    await _maybeUpgradeToCachedHd(generation: generation);
  }

  /// After the poster drops, step up to the best **cached** HD tier.
  /// Wi-Fi: 720→1080 on capable devices. Cellular: 360→720 only.
  /// Honor/MTK stays on the open rung after 720 (720→1080 reconfig kills playback).
  Future<void> _maybeUpgradeToCachedHd({required int generation}) async {
    if (_upgradeInFlight ||
        !_usesFeedVisibleChannel ||
        !_isCurrentAttach(generation) ||
        !mounted ||
        _isDisposed) {
      return;
    }
    final network = await _networkPolicy.currentNetworkClass();
    if (network == NetworkClass.offline) {
      return;
    }
    final poolKey = _pooledKey;
    if (poolKey == null || poolKey.isEmpty) {
      return;
    }
    final currentUrl = _pool.sourceUrlForKey(poolKey);
    final currentTier = _resolver.mp4Tier(currentUrl ?? '') ?? '360';
    // Honor/MTK: ladder already opens 720; mid-play 720→1080 reconfigures
    // MediaCodec and kills audio/playback after ~1s.
    if (_needsConstrainedStartGate && currentTier != '360') {
      return;
    }
    final String? targetTier;
    if (_needsConstrainedStartGate) {
      targetTier = currentTier == '360' ? '720' : null;
    } else if (network == NetworkClass.wifi ||
        network == NetworkClass.mobile) {
      // Mobile upgrades to 1080 like Wi-Fi — same quality on cellular.
      targetTier = currentTier == '1080' ? null : '1080';
    } else {
      targetTier = currentTier == '360' ? '720' : null;
    }
    if (targetTier == null) {
      return;
    }
    final hdCandidate = await _resolver.cachedTierCandidate(
      _resolvedCandidates(),
      tier: targetTier,
    );
    if (hdCandidate == null || !_isCurrentAttach(generation)) {
      return;
    }
    _upgradeInFlight = true;
    try {
      final playbackUrl = await _resolvePlaybackUrlForSource(hdCandidate, network);
      final posterAlreadyDown = _feedPosterUnmaskedAtMs > 0;
      final pooled = await _pool.openVisibleReel(
        key: poolKey,
        sourceUrl: playbackUrl,
        openToken: generation,
        preserveFrameReady: posterAlreadyDown,
      );
      if (pooled == null || !_isCurrentAttach(generation) || !mounted || _isDisposed) {
        return;
      }
      _activeFeedSlotIndex = pooled.feedActiveSlotIndex ?? _pool.activeFeedSlotIndex;
      await _registerRenderSlot(pooled.player);
      if (posterAlreadyDown && _videoSurfaceVisible) {
        _pool.markFrameReadyFromSurface(poolKey);
        await _ensureFeedAudibleAfterPaint(poolKey, generation);
      }
      ReelsPerf.log(
        'upgrade reel=${widget.videoId} tier=$targetTier cache=hit '
        'flip=${!pooled.feedOpenedMedia}',
      );
    } catch (e) {
      ReelsPerf.log('upgrade failed reel=${widget.videoId} err=$e');
    } finally {
      _upgradeInFlight = false;
    }
  }

  bool _syncAudibleInFlight = false;

  /// Single backup after page settle — primary audio is [openVisibleReel].
  Future<void> syncAudibleIfNeeded() async {
    // Feed audio is owned solely by [openVisibleReel] + one-shot tab resume in
    // [ReelsVideoScreen]; backup resume loops caused PlayerBase::stop storms.
    if (_usesFeedVisibleChannel) {
      return;
    }
    if (_syncAudibleInFlight) {
      return;
    }
    final targetKey = _poolKey;
    final generation = _playbackGeneration;
    if (targetKey.isEmpty || _userPaused) {
      return;
    }
    _syncAudibleInFlight = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!_isCurrentAttach(generation) ||
          !mounted ||
          _isDisposed ||
          _pooledKey != targetKey) {
        return;
      }
      await _ensureAudibleForKey(targetKey, generation: generation);
    } finally {
      _syncAudibleInFlight = false;
    }
  }

  Future<void> togglePlayPause() async {
    final key = _pooledKey;
    final player = _activePlayer;
    if (key == null || player == null || _isDisposed) {
      return;
    }
    _iconHideTimer?.cancel();
    if (_userPaused) {
      _userPaused = false;
      _iconShowsPause = false;
      if (_usesFeedVisibleChannel) {
        await _pool.feedUserResume(key);
      } else {
        _pool.clearUserPaused(key);
        if (!player.state.playing) {
          try {
            await player.play();
          } catch (_) {}
        }
        await _pool.activateVisible(key);
      }
    } else {
      _userPaused = true;
      _iconShowsPause = true;
      await _pool.pauseByUser(key);
    }
    if (!mounted || _isDisposed) {
      return;
    }
    setState(() => _showPlayPauseIcon = true);
    _iconHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && !_isDisposed) {
        setState(() => _showPlayPauseIcon = false);
      }
    });
  }

  void _attachFrameWatchers(Player player) {
    _cancelFrameWatch();
    final gen = _frameWatchGeneration;
    _onPlayerStateTick(player);
    _positionSub = player.stream.position.listen((pos) {
      if (gen != _frameWatchGeneration) {
        return;
      }
      _trackDimensionStability(player);
      if (_frameReady && _videoSurfaceVisible) {
        return;
      }
      if (_canShowVideo(player, pos)) {
        _notifyFrameReady(player, generation: _attachGeneration);
        return;
      }
      _onPlayerStateTick(player);
    });
    _widthSub = player.stream.width.listen((_) {
      if (gen != _frameWatchGeneration) {
        return;
      }
      _trackDimensionStability(player);
      final pos = player.state.position;
      if (_canShowVideo(player, pos)) {
        _notifyFrameReady(player, generation: _attachGeneration);
        return;
      }
      _onPlayerStateTick(player);
    });
    _heightSub = player.stream.height.listen((_) {
      if (gen != _frameWatchGeneration) {
        return;
      }
      _trackDimensionStability(player);
      _onPlayerStateTick(player);
    });
  }

  void _attachPlaybackListeners(Player player) {
    _playingSub?.cancel();
    _completedSub?.cancel();
    // Reels repeat in place; the user swipes manually to the next post.
    try {
      player.setPlaylistMode(PlaylistMode.single);
    } catch (_) {}
    _playingSub = player.stream.playing.listen((playing) {
      if (!mounted || _isDisposed) {
        return;
      }
      if (playing) {
        _onPlayerStateTick(player);
      }
    });
    _completedSub = player.stream.completed.listen((completed) {
      if (completed &&
          mounted &&
          !_isDisposed &&
          !_completionNotified) {
        _completionNotified = true;
        widget.onVideoCompleted?.call();
      }
    });
  }

  void _detachAnalyticsAndListeners() {
    _analytics.detach();
    _playingSub?.cancel();
    _playingSub = null;
    _completedSub?.cancel();
    _completedSub = null;
    _cancelFrameWatch();
  }

  bool _isPoolPrimedForKey(String? key) {
    if (_strictSurfaceGate || key == null || key.isEmpty) {
      return false;
    }
    if (!_pool.canInstantResume(key)) {
      return false;
    }
    return _pool.isFrameReady(key) || _pool.isBufferPrimed(key);
  }

  bool _isPoolPrimedForSwipe(String? key, Player player) {
    if (!_isPoolPrimedForKey(key)) {
      return false;
    }
    if (_pool.isFrameReady(key!) && _hasRealFrame(player)) {
      return true;
    }
    return _pool.isBufferPrimed(key);
  }

  Player? get _activePlayer {
    if (_usesFeedVisibleChannel) {
      return _pool.feedSlotVideoController(_activeFeedSlotIndex)?.player;
    }
    return _videoController?.player;
  }

  void _bindPlayer(Player player, {bool afterFlip = false}) {
    if (_usesFeedVisibleChannel) {
      _bindFeedPlayer(
        player,
        activeSlotIndex: _activeFeedSlotIndex,
        afterFlip: afterFlip,
      );
      return;
    }
    final sameSurface = _videoController?.player == player;
    if (!sameSurface) {
      _surfaceEpoch++;
      _videoController = createReelVideoController(player);
      _videoSurfaceMounted = true;
    }
    final key = _pooledKey;
    if (_isPoolPrimedForSwipe(key, player)) {
      final framePrimed = key != null &&
          _pool.isFrameReady(key) &&
          _hasRealFrame(player);
      _surfacePaintFrames = framePrimed
          ? _minSurfacePaintFrames
          : _minSurfacePaintFramesBuffered;
      _afterSurfaceMounted(player, paintTicks: framePrimed ? 6 : 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed || _frameReady) {
          return;
        }
        if (_canShowVideo(player)) {
          unawaited(_onFrameReady(player, generation: _attachGeneration));
        }
      });
      return;
    }
    _surfacePaintFrames = 0;
    _afterSurfaceMounted(player, paintTicks: _lastOpenCacheHit ? 2 : 6);
  }

  void _bindFeedPlayer(
    Player player, {
    required int activeSlotIndex,
    bool afterFlip = false,
  }) {
    _activeFeedSlotIndex = activeSlotIndex;
    _videoController = _pool.feedSlotVideoController(activeSlotIndex);
    _videoSurfaceMounted = true;
    if (afterFlip && _hasRealFrame(player) && !_lastOpenWasCold) {
      if (_poolProvenSurfacePaint(_pooledKey)) {
        _fastFeedReveal = true;
      }
      _surfacePaintFrames = _minSurfacePaintFramesBuffered;
      _showThumbnail = false;
      _scheduleFeedFrameReadyAfterSurfaceMount(
        player,
        generation: _attachGeneration,
      );
    } else {
      final key = _pooledKey;
      if (!_lastOpenWasCold &&
          key != null &&
          key.isNotEmpty &&
          _pool.isFrameReady(key) &&
          _hasRealFrame(player)) {
        _fastFeedReveal = true;
        _surfacePaintFrames = _minSurfacePaintFramesBuffered;
        _showThumbnail = false;
        _scheduleFeedFrameReadyAfterSurfaceMount(
          player,
          generation: _attachGeneration,
        );
      } else if (!_lastOpenWasCold &&
          key != null &&
          key.isNotEmpty &&
          _pool.isBufferPrimed(key) &&
          _hasRealFrame(player)) {
        _surfacePaintFrames = 0;
        _showThumbnail = false;
        _scheduleFeedFrameReadyAfterSurfaceMount(
          player,
          generation: _attachGeneration,
        );
      } else if (key != null &&
          key.isNotEmpty &&
          _fastFeedReveal &&
          _poolProvenSurfacePaint(key)) {
        _videoSurfaceVisible = false;
        _surfacePaintFrames = _minSurfacePaintFramesBuffered;
        _showThumbnail = false;
        _afterSurfaceMounted(
          player,
          paintTicks: _needsConstrainedStartGate ? 4 : 2,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isDisposed || _frameReady) {
            return;
          }
          if (_canShowVideo(player)) {
            _scheduleFeedFrameReadyAfterSurfaceMount(
              player,
              generation: _attachGeneration,
            );
          }
        });
      } else {
        _frameReady = false;
        _videoSurfaceVisible = false;
        _surfacePaintFrames = 0;
        _resetDimensionStability();
        _afterSurfaceMounted(
          player,
          paintTicks: _needsConstrainedStartGate ? 8 : 4,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isDisposed || _frameReady) {
            return;
          }
          if (_canShowVideo(player)) {
            _scheduleFeedFrameReadyAfterSurfaceMount(
              player,
              generation: _attachGeneration,
            );
          }
        });
      }
    }
  }

  /// One permanent full-size surface — single [Video] widget bound to the active
  /// slot. Never mount two surfaces (Honor/MTK log: Rendered 0/s, surface errors).
  ///
  /// On Honor/MTK [visible] only gates non-constrained devices. When constrained,
  /// keep opacity 1 as soon as the surface is mounted — opacity 0 makes the
  /// codec decode headless (Rendered 0/s, Discarded 30/s). The feed poster in
  /// [ReelsVideoScreen] masks until [onFeedVideoPainted].
  Widget _buildFeedVideoSurfaces({required bool visible}) {
    final controller =
        _pool.feedSlotVideoController(_activeFeedSlotIndex);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final opaque = _needsConstrainedStartGate || visible;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opaque ? 1.0 : 0.0,
          child: ClipRect(
            // Fill the reel slot with the same cover crop as the page poster.
            // Align+loose constraints previously let the surface letterbox,
            // which read as "shrinking from the sides" on unmask.
            child: SizedBox.expand(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  if (!kReleaseMode && visible) {
                    final screenW = MediaQuery.sizeOf(ctx).width;
                    if ((constraints.maxWidth - screenW).abs() > 1.0) {
                      debugPrint(
                        '[ReelSurface] WIDTH_MISMATCH key=${widget.playerPoolKey} '
                        'surface=${constraints.maxWidth.toStringAsFixed(1)} '
                        'screen=${screenW.toStringAsFixed(1)} '
                        'h=${constraints.maxHeight.toStringAsFixed(1)}',
                      );
                    }
                  }
                  final fit = _adaptiveFit(constraints);
                  return Video(
                    key: const ValueKey('reel_surface_feed'),
                    controller: controller,
                    fit: fit,
                    // When using contain, show black bars so non-standard-AR
                    // content sits on a clean background instead of transparent.
                    // Cover keeps the poster-through transparent fill.
                    fill: fit == BoxFit.contain
                        ? const Color(0xFF000000)
                        : const Color(0x00000000),
                    controls: NoVideoControls,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _attachPlayer(
    Player player, {
    required int generation,
    bool afterFlip = false,
    bool skipFrameWait = false,
  }) async {
    _bindPlayer(player, afterFlip: afterFlip);
    final analyticsId = widget.videoId;
    if (analyticsId != null && analyticsId.isNotEmpty) {
      _analytics.attachMediaKit(videoId: analyticsId, player: player);
    }
    _attachPlaybackListeners(player);
    _attachFrameWatchers(player);
    if (mounted && !_isDisposed) {
      setState(() {});
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _isDisposed) {
      return;
    }
    _onPlayerStateTick(player);
    if (skipFrameWait) {
      return;
    }
    if (_usesFeedVisibleChannel) {
      await _awaitFeedFrameOrAudio(player, generation: generation);
      return;
    }
    if (_canShowVideo(player)) {
      await _onFrameReady(player, generation: generation);
    } else if (!_strictSurfaceGate &&
        _pooledKey != null &&
        _pool.canInstantResume(_pooledKey!) &&
        _hasRealFrame(player)) {
      await _onFrameReady(player, generation: generation);
    }
  }

  Future<bool> _waitForFrameReady({
    required Player player,
    required int generation,
    required int timeoutMs,
  }) async {
    var waited = 0;
    var parityLogged = false;
    while (waited < timeoutMs &&
        mounted &&
        !_isDisposed &&
        _isCurrentAttach(generation)) {
      _trackDimensionStability(player);
      final parityAction = await ensureEvenMpvCropIfNeeded(player);
      if (!parityLogged && parityAction != MpvStabilizeAction.none) {
        parityLogged = true;
        final w = player.state.width;
        final h = player.state.height;
        final prevW = FeedSurfaceParityLock.evenWidth;
        final prevH = FeedSurfaceParityLock.evenHeight;
        // Post-hoc mpv crop only; native gate logs dimension_parity_benign_skip.
        _logPoster(
          'dimension_parity_mpv_crop',
          detail: 'prevSize=${prevW}x$prevH newSize=${w}x$h '
              'action=${parityAction.name}',
        );
      }
      if (_canShowVideo(player)) {
        await _onFrameReady(player, generation: generation);
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
      _onPlayerStateTick(player);
    }
    return _isCurrentAttach(generation) && _canShowVideo(player);
  }

  /// Warm Honor paths usually paint under ~300ms; cold decode often advances
  /// without paint by ~1–1.5s when ImageReader is churning — soft-recover then.
  static const int _earlyPaintStallMs = 850;

  bool _decodeProgressingWithoutPaint(Player player) {
    if (_canShowVideo(player)) {
      return false;
    }
    if (player.state.playing) {
      return true;
    }
    final posMs = player.state.position.inMilliseconds;
    return posMs >= _minPositionMsForFrame() ||
        (player.state.width != null &&
            player.state.height != null &&
            posMs > 0);
  }

  /// [enableEarlyPaintStall]: after [_earlyPaintStallMs], if decode is moving
  /// but paint is not, return early so callers can soft-recover instead of
  /// burning the full [_frameWaitTimeoutMs] ceiling.
  Future<({bool ready, bool earlyPaintStall})> _waitForFrameReadyWithRecovery({
    required Player player,
    required int generation,
    required String poolKey,
    bool enableEarlyPaintStall = false,
  }) async {
    final ceilingMs = _frameWaitTimeoutMs();
    final useEarly = enableEarlyPaintStall &&
        _usesFeedVisibleChannel &&
        _needsConstrainedStartGate &&
        ceilingMs > _earlyPaintStallMs;

    if (useEarly) {
      var frameReady = await _waitForFrameReady(
        player: player,
        generation: generation,
        timeoutMs: _earlyPaintStallMs,
      );
      if (frameReady) {
        return (ready: true, earlyPaintStall: false);
      }
      if (_isCurrentAttach(generation) &&
          _decodeProgressingWithoutPaint(player)) {
        _logPoster(
          'paint_stall_early_trigger',
          detail: 'waitedMs=$_earlyPaintStallMs',
        );
        return (ready: false, earlyPaintStall: true);
      }
      final remaining = ceilingMs - _earlyPaintStallMs;
      if (remaining > 0) {
        frameReady = await _waitForFrameReady(
          player: player,
          generation: generation,
          timeoutMs: remaining,
        );
      }
      if (frameReady) {
        return (ready: true, earlyPaintStall: false);
      }
      return (ready: false, earlyPaintStall: false);
    }

    var frameReady = await _waitForFrameReady(
      player: player,
      generation: generation,
      timeoutMs: ceilingMs,
    );
    if (frameReady) {
      return (ready: true, earlyPaintStall: false);
    }
    if (!_needsConstrainedStartGate) {
      return (ready: false, earlyPaintStall: false);
    }
    final fastScrollPath = _fastFeedReveal || _scrollBackCacheEligible(poolKey);
    // Soft nudge only — mid-wait threshold recycle rebuilds VideoOutput (same
    // as hard recycle) and is reserved for presentReel idle/proactive opens.
    if (!fastScrollPath &&
        _surfaceRecoveryAttempts == 0 &&
        _isCurrentAttach(generation)) {
      _surfaceRecoveryAttempts++;
      try {
        await player.setVolume(0);
      } catch (_) {}
      try {
        if (!player.state.playing) {
          await player.play();
        }
      } catch (_) {}
      frameReady = await _waitForFrameReady(
        player: player,
        generation: generation,
        timeoutMs: 3600,
      );
    }
    if (!frameReady) {
      return (ready: false, earlyPaintStall: false);
    }
    return (ready: true, earlyPaintStall: false);
  }

  /// Profile overlays: mount [Video] before decode/play (Honor Rendered 0/s).
  Future<void> _startStrictPlaybackAfterSurface({
    required Player player,
    required String poolKey,
    required int generation,
  }) async {
    if (!_isCurrentAttach(generation) || poolKey.isEmpty) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    if (!_userPaused) {
      await _pool.activateVisible(poolKey);
      return;
    }
    try {
      if (!player.state.playing) {
        await player.play();
      }
    } catch (_) {}
  }

  Future<List<VideoSourceCandidate>> _orderedPlaybackCandidates(
    NetworkClass network,
    bool isTablet,
  ) async {
    final rc = RemoteConfigService.instance;
    final cache = ReelsVideoCacheManager.instance.manager;
    final raw = _resolvedCandidates();
    await DeviceConstraints.instance.ensureInitialized();

    // Align open tier with prefetch: Wi-Fi / mobile prefer cached HD then
    // 720-first. Do NOT force this ladder on offline for Honor — skipping a
    // warm cached 360 for an uncached 720 caused 2–4s dead starts on fast scroll.
    if (network == NetworkClass.wifi || network == NetworkClass.mobile) {
      return _wifiQualityConstrainedOrder(raw, cache);
    }

    return _resolver.prioritizeForPlaybackFastStart(
      candidates: raw,
      network: network,
      cacheManager: cache,
      isTablet: isTablet,
      fastStartUncached: rc.reels360FirstUncached,
      hlsWifiEnabled: rc.reelsHlsWifiEnabled,
    );
  }

  /// Wi-Fi order for surface-sensitive (Honor/MTK) devices: prefer a cached HD
  /// tier for an instant, buffer-free start, then a 720 → 1080 → 360 quality
  /// ladder. High quality without leaning on 1080's heavier surface path.
  Future<List<VideoSourceCandidate>> _wifiQualityConstrainedOrder(
    List<VideoSourceCandidate> raw,
    dynamic cache,
  ) async {
    final mp4 =
        raw.where((c) => c.type == 'mp4_quality').toList(growable: false);
    VideoSourceCandidate? pick360;
    VideoSourceCandidate? pick720;
    VideoSourceCandidate? pick1080;
    for (final candidate in mp4) {
      final tier = _resolver.mp4Tier(candidate.url);
      pick360 ??= tier == '360' ? candidate : null;
      pick720 ??= tier == '720' ? candidate : null;
      pick1080 ??= tier == '1080' ? candidate : null;
    }

    final ordered = <VideoSourceCandidate>[];
    void add(VideoSourceCandidate? c) {
      if (c != null && !ordered.any((e) => e.url == c.url)) {
        ordered.add(c);
      }
    }

    final constrained =
        DeviceConstraints.instance.needsConstrainedSurfaceRecovery;
    // Probe HD tiers only for TTFB preference. Never elevate a ready 360 over an
    // uncached 720 — that produced clean but soft first-opens after stall clusters
    // when only 360 had finished downloading.
    final hdCandidates = <VideoSourceCandidate?>[
      if (!constrained) pick1080,
      pick720,
    ].whereType<VideoSourceCandidate>().toList();
    final readyResults = await Future.wait(
      hdCandidates.map((c) async =>
          await isPlaybackUrlCached(c.url, cacheManager: cache) ||
          await isPlaybackUrlPartiallyCached(c.url, cacheManager: cache)),
    );
    for (var i = 0; i < hdCandidates.length; i++) {
      if (readyResults[i]) {
        add(hdCandidates[i]);
        break; // Highest-quality ready HD tier first.
      }
    }
    // Uncached ladder: 720 first (fast + sharp), then 1080, then 360.
    add(pick720);
    if (!constrained) {
      add(pick1080);
    }
    add(pick360);
    if (constrained) {
      add(pick1080);
    }
    for (final candidate in raw) {
      add(candidate);
    }
    return ordered.isEmpty ? raw : ordered;
  }

  Future<bool> _awaitFeedFrameOrAudioPrimed(
    Player player, {
    required int generation,
  }) async {
    if (_frameReady && _videoSurfaceVisible) {
      return true;
    }
    await _awaitFeedFrameOrAudio(player, generation: generation);
    return _isCurrentAttach(generation) &&
        (_frameReady || _canShowVideo(player));
  }

  Future<void> _awaitFeedFrameOrAudio(
    Player player, {
    required int generation,
  }) async {
    if (_needsConstrainedStartGate && !player.state.playing) {
      await _pool.startMutedFeedDecode();
    }
    var waited = 0;
    // Qualcomm/Pixel produces a frame within 1s; constrained devices need
    // a slightly larger window for cold network opens but not 2s.
    final ceilingMs = _needsConstrainedStartGate ? 1600 : 1000;
    while (waited < ceilingMs &&
        mounted &&
        !_isDisposed &&
        _isCurrentAttach(generation)) {
      if (_canShowVideo(player)) {
        await _onFrameReady(player, generation: generation);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (_isDisposed) return;
      waited += 16;
      _onPlayerStateTick(player);
    }
    if (!_isCurrentAttach(generation)) {
      return;
    }
    if (_isCurrentAttach(generation) &&
        mounted &&
        !_isDisposed &&
        _canShowVideo(player)) {
      await _onFrameReady(player, generation: generation);
    }
  }

  Future<void> _loadVideo({String reason = 'load'}) async {
    if (_isDisposed) {
      return;
    }
    if (_isInitializing) {
      _pendingSwitchAfterInit = true;
      return;
    }
    final generation = _nextPlaybackGeneration();
    _isInitializing = true;
    final poolKey = _poolKey;
    _initializingForKey = poolKey;
    _lastSwitchTargetKey = poolKey;
    _lastSwitchAttemptMs = DateTime.now().millisecondsSinceEpoch;
    _switchCallCount++;
    _logSwitchDiag('switch_enter', reason: reason, key: poolKey, generation: generation);
    final startedAt = _lastSwitchAttemptMs;
    var bail = 'ok';
    if (_usesFeedVisibleChannel) {
      _prepareSwitchUiState(poolKey);
    } else {
      _resetFrameStateForKey(poolKey);
    }
    try {
      if (poolKey.isEmpty) {
        bail = 'empty_key';
        return;
      }
      if (_usesFeedVisibleChannel) {
        await _pool.ensureFeedPingPongInitialized();
        if (!_videoSurfaceMounted && mounted && !_isDisposed) {
          setState(() => _videoSurfaceMounted = true);
        } else {
          _videoSurfaceMounted = true;
        }

        // Tab return while this reel is still the feed-visible key — rebind the
        // surface and resume audio without Player.open (MTK surface churn).
        if (_pool.isFeedVisibleKey(poolKey) && _pool.canInstantResume(poolKey)) {
          final slotIndex = _pool.activeFeedSlotIndex;
          final player =
              _pool.feedSlotVideoController(slotIndex)?.player;
          if (player != null) {
            _pooledKey = poolKey;
            _attachGeneration = generation;
            await _attachPlayer(
              player,
              generation: generation,
              afterFlip: _pool.isFrameReady(poolKey),
            );
            if (!mounted || _isDisposed || generation != _playbackGeneration) {
              bail = 'gen_mismatch';
              return;
            }
            if (_pool.isFrameReady(poolKey) && _canShowVideo(player)) {
              await _onFrameReady(player, generation: generation);
              bail = 'instant_resume';
              return;
            }
          }
        }
      }

      await _openWithCandidates(
        generation: generation,
        poolKey: poolKey,
        onFailure: () {
          if (mounted && !_isDisposed && _isCurrentAttach(generation)) {
            setState(() => _showRetry = true);
          }
        },
      );
      if (generation != _playbackGeneration) {
        bail = 'stale_gen';
      } else if (_pooledKey != poolKey) {
        bail = 'no_attach';
      } else {
        bail = 'opened';
      }
    } finally {
      final attempted = _initializingForKey ?? _lastSwitchTargetKey;
      _isInitializing = false;
      _initializingForKey = null;
      _logSwitchDiag(
        'switch_exit',
        reason: reason,
        key: poolKey,
        generation: generation,
        elapsedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
        bail: bail,
      );
      _drainPendingSwitchAfterInit(attemptedKey: attempted);
    }
  }

  Future<String> _resolvePlaybackUrlForSource(
    VideoSourceCandidate source,
    NetworkClass network,
  ) async {
    if (source.url.toLowerCase().contains('.m3u8')) {
      return source.url;
    }
    return resolveBestPlaybackUrl(
      source.url,
      cacheManager: ReelsVideoCacheManager.instance.manager,
    );
  }

  /// Wait for the preferred URL to finish downloading (CacheManager only
  /// exposes files after a full download). Network-aware budget so first
  /// settle can win `file://` instead of cold HTTPS.
  ///
  /// Normal swipe budget is short (~500–800ms): blocking longer just delays
  /// the HTTPS fallback. Session-cold first open (empty cache, openCount==0)
  /// uses a longer budget so the parallel prefetch can land and avoid a cold
  /// HTTPS demux on first install.
  Future<bool> _awaitInFlightPlaybackBytes(
    String url, {
    required int generation,
  }) async {
    if (url.isEmpty || !url.toLowerCase().startsWith('http')) {
      return false;
    }
    final disk = ReelsVideoCacheManager.instance.manager;
    if (await isPlaybackUrlCached(url, cacheManager: disk)) {
      return true;
    }
    final cache = ReelsVideoCacheManager.instance;
    if (!cache.isQueuedOrInFlight(url)) {
      cache.prefetch(url, priority: 120, isTablet: false);
    }
    final network = await _networkPolicy.currentNetworkClass();
    final sessionCold = _pool.feedOpenCount == 0;
    final maxWaitMs = sessionCold
        ? switch (network) {
            NetworkClass.wifi => 2200,
            NetworkClass.mobile => 3000,
            NetworkClass.offline => 800,
          }
        : switch (network) {
            // Warm session: don't stall behind a cache that isn't landing.
            // Open HTTPS quickly instead of burning ~1.2s waiting.
            NetworkClass.wifi => 450,
            NetworkClass.mobile => 700,
            NetworkClass.offline => 350,
          };
    final started = DateTime.now().millisecondsSinceEpoch;
    // Chunked wait so swipe-away / generation bump can bail early.
    const sliceMs = 200;
    var waited = 0;
    while (waited < maxWaitMs) {
      if (!mounted ||
          _isDisposed ||
          generation != _playbackGeneration ||
          (_usesFeedVisibleChannel && _pool.isStaleFeedOpen(generation))) {
        return false;
      }
      if (await isPlaybackUrlCached(url, cacheManager: disk)) {
        break;
      }
      final slice = (maxWaitMs - waited).clamp(1, sliceMs);
      await cache.waitForUrl(url, maxWaitMs: slice);
      waited = DateTime.now().millisecondsSinceEpoch - started;
    }
    if (!mounted ||
        _isDisposed ||
        generation != _playbackGeneration ||
        (_usesFeedVisibleChannel && _pool.isStaleFeedOpen(generation))) {
      return false;
    }
    final ready = await isPlaybackUrlCached(url, cacheManager: disk);
    if (!kReleaseMode) {
      debugPrint(
        '[ReelsPoster] cache_wait '
        'ready=$ready waitedMs=${DateTime.now().millisecondsSinceEpoch - started} '
        'budgetMs=$maxWaitMs sessionCold=$sessionCold '
        'url=${url.length > 56 ? '${url.substring(0, 56)}…' : url}',
      );
    }
    return ready;
  }

  Future<void> _openWithCandidates({
    required int generation,
    required String poolKey,
    required VoidCallback onFailure,
  }) async {
    final network = await _networkPolicy.currentNetworkClass();
    final isTablet = mounted ? _isTabletLayout(context) : false;
    final cache = ReelsVideoCacheManager.instance.manager;
    final candidates = await _orderedPlaybackCandidates(network, isTablet);
    if (candidates.isEmpty) {
      onFailure();
      return;
    }

    _abortQualityCascade = false;
    // If any tier is already on disk, the cached candidate opens in ~66ms —
    // don't block behind a cache_wait for a higher uncached tier (that made
    // uncached-adjacent reels start ~1.8s late). Only wait when nothing is
    // cached, and even then the budget is short. Probe in parallel so this
    // gate adds negligible latency before the open.
    final cacheProbes = await Future.wait(
      candidates.map(
        (c) async => !c.url.toLowerCase().contains('.m3u8') &&
            await isPlaybackUrlCached(c.url, cacheManager: cache),
      ),
    );
    final anyCached = cacheProbes.any((v) => v);
    var waitedForCache = false;
    for (final source in candidates) {
      if (_failedSourceUrls.contains(source.url)) {
        continue;
      }
      if (!mounted || _isDisposed || generation != _playbackGeneration ||
          (_usesFeedVisibleChannel && _pool.isStaleFeedOpen(generation))) {
        return;
      }
      // Long wait only on the first preferred URL — don't stack budgets.
      // Skip entirely when a cached tier exists (it'll open instantly).
      if (!waitedForCache && !anyCached) {
        waitedForCache = true;
        await _awaitInFlightPlaybackBytes(
          source.url,
          generation: generation,
        );
        if (!mounted || _isDisposed || generation != _playbackGeneration ||
            (_usesFeedVisibleChannel && _pool.isStaleFeedOpen(generation))) {
          return;
        }
      } else {
        waitedForCache = true;
      }
      final opened = await _tryOpenCandidate(
        source: source,
        generation: generation,
        poolKey: poolKey,
        network: network,
        cache: cache,
      );
      if (opened) {
        return;
      }
      // Paint stall after a successful open is a surface failure — do not walk
      // the quality ladder (720→360→1080) on the same wedged ImageReader.
      if (_abortQualityCascade) {
        _abortQualityCascade = false;
        break;
      }
    }
    if (_isCurrentAttach(generation) && mounted && !_isDisposed &&
        !(_usesFeedVisibleChannel && _pool.isStaleFeedOpen(generation))) {
      onFailure();
    }
  }

  /// Returns true when decode/paint succeeded for [source].
  Future<bool> _tryOpenCandidate({
    required VideoSourceCandidate source,
    required int generation,
    required String poolKey,
    required NetworkClass network,
    required dynamic cache,
  }) async {
    try {
      final tier = _resolver.mp4Tier(source.url) ?? 'other';
      final isMp4 = !source.url.toLowerCase().contains('.m3u8');
      final cacheHit =
          isMp4 && await isPlaybackUrlCached(source.url, cacheManager: cache);
      final partialCache = !cacheHit &&
          isMp4 &&
          await isPlaybackUrlPartiallyCached(source.url, cacheManager: cache);
      _lastOpenCacheHit = cacheHit;
      _lastOpenPartialCache = partialCache;
      if (!cacheHit &&
          !partialCache &&
          _pool.hadRecentPaint(poolKey) &&
          isMp4) {
        final remoteCached = await isPlaybackUrlCached(
          source.url,
          cacheManager: cache,
        );
        if (remoteCached) {
          _lastOpenCacheHit = true;
        }
      }
      _resetDimensionStability();
      _surfaceRecoveryAttempts = 0;
      final playbackUrl = await _resolvePlaybackUrlForSource(source, network);
      _openStartedAt = DateTime.now();
      if (_usesFeedVisibleChannel) {
        await _ensureFeedSurfaceMountedBeforeOpen(generation: generation);
        if (!mounted || _isDisposed || generation != _playbackGeneration) {
          return false;
        }
      }
      final pooled = _usesFeedVisibleChannel
          ? await _pool.openVisibleReel(
              key: poolKey,
              sourceUrl: playbackUrl,
              openToken: generation,
            )
          : await _pool.acquire(
              key: poolKey,
              sourceUrl: playbackUrl,
              autoPlay: false,
            );
      if (pooled == null) {
        return false;
      }
      _lastOpenWasCold =
          _usesFeedVisibleChannel ? pooled.feedOpenedMedia : true;
      if (_usesFeedVisibleChannel &&
          (_pool.isFrameReady(poolKey) ||
              _pool.hadRecentPaint(poolKey) ||
              _pool.isBufferPrimed(poolKey) ||
              _lastOpenCacheHit ||
              _lastOpenPartialCache)) {
        _fastFeedReveal = true;
      }
      if (!mounted || _isDisposed || generation != _playbackGeneration) {
        return false;
      }
      _pooledKey = poolKey;
      _attachGeneration = generation;
      if (_usesFeedVisibleChannel) {
        _logPoster(
          'open_done',
          detail: 'key=$poolKey opened=${pooled.feedOpenedMedia} '
              'tier=$tier openCount=${_pool.feedOpenCount}',
        );
        await _pool.ensureFeedPingPongInitialized();
        final slotIndex =
            pooled.feedActiveSlotIndex ?? _pool.activeFeedSlotIndex;
        _activeFeedSlotIndex = slotIndex;
      }
      await _attachPlayer(
        pooled.player,
        generation: generation,
        afterFlip: _usesFeedVisibleChannel && !pooled.feedOpenedMedia,
        skipFrameWait: true,
      );
      if (_usesFeedVisibleChannel) {
        await _registerRenderSlot(pooled.player);
      }
      if (_usesFeedVisibleChannel && _needsConstrainedStartGate) {
        final prevW = FeedSurfaceParityLock.evenWidth;
        final prevH = FeedSurfaceParityLock.evenHeight;
        final parity = await ensureEvenMpvCropIfNeeded(pooled.player);
        if (parity != MpvStabilizeAction.none) {
          // Post-hoc mpv crop only; native gate logs dimension_parity_benign_skip.
          _logPoster(
            'dimension_parity_mpv_crop',
            detail: 'prevSize=${prevW}x$prevH '
                'newSize=${pooled.player.state.width}x${pooled.player.state.height} '
                'action=${parity.name}',
          );
        }
      }
      if (!_usesFeedVisibleChannel) {
        await _startStrictPlaybackAfterSurface(
          player: pooled.player,
          poolKey: poolKey,
          generation: generation,
        );
      }
      final fastPrimedOpen = _usesFeedVisibleChannel &&
          _fastFeedReveal &&
          _poolProvenSurfacePaint(poolKey);
      final waitResult = fastPrimedOpen
          ? (
              ready: await _awaitFeedFrameOrAudioPrimed(
                pooled.player,
                generation: generation,
              ),
              earlyPaintStall: false,
            )
          : await _waitForFrameReadyWithRecovery(
              player: pooled.player,
              generation: generation,
              poolKey: poolKey,
              enableEarlyPaintStall: true,
            );
      final openMs = _openStartedAt == null
          ? 0
          : DateTime.now().difference(_openStartedAt!).inMilliseconds;
      if (waitResult.ready) {
        ReelsPerf.emit(
          ReelsPerfEvent(
            name: 'open_complete',
            openMs: openMs,
            tier: tier,
            cacheHit: cacheHit || partialCache,
            partialCache: partialCache,
            flip: _usesFeedVisibleChannel && !pooled.feedOpenedMedia,
            coldOpen: pooled.feedOpenedMedia,
            extra: {'reel': widget.videoId},
          ),
        );
        return true;
      }
      // Early paint stall: decode is moving but paint is not — soft-recover now.
      // Do not short-circuit via decode_active (that skips soft recovery and
      // can end the switch before a real frame paints).
      if (!waitResult.earlyPaintStall &&
          !_needsConstrainedStartGate &&
          _isDecodeLikelyActive(pooled.player)) {
        await _onFrameReady(pooled.player, generation: generation);
        ReelsPerf.emit(
          ReelsPerfEvent(
            name: 'open_complete',
            openMs: openMs,
            tier: tier,
            cacheHit: cacheHit || partialCache,
            partialCache: partialCache,
            flip: _usesFeedVisibleChannel && !pooled.feedOpenedMedia,
            coldOpen: pooled.feedOpenedMedia,
            extra: {
              'reel': widget.videoId,
              'decode_active': true,
            },
          ),
        );
        return true;
      }
      // Successful open + paint timeout = surface stall, not a bad tier.
      // Soft-recover on the same Player (no native rebuild).
      if (_usesFeedVisibleChannel) {
        return _recoverPaintStallSameCandidate(
          playbackUrl: playbackUrl,
          generation: generation,
          poolKey: poolKey,
          tier: tier,
          cacheHit: cacheHit,
          partialCache: partialCache,
        );
      }
      _failedSourceUrls.add(source.url);
      _logPoster('open_fallback', detail: 'tier=$tier timeout try_next');
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'open_timeout',
          openMs: openMs,
          tier: tier,
          stuck: true,
          extra: {'reel': widget.videoId, 'fallback': true},
        ),
      );
      return false;
    } catch (e) {
      _failedSourceUrls.add(source.url);
      _logPoster('open_fallback', detail: 'err=$e try_next');
      debugPrint('ReelVideoPlayer source failed (${widget.videoId}): $e');
      return false;
    }
  }

  /// Soft-recover the feed surface on the same Player (play nudge only).
  /// Never rebuilds native surface — that is reserved for [_recoverFromRenderDeath].
  /// Never marks the URL failed or walks the quality ladder.
  Future<bool> _recoverPaintStallSameCandidate({
    required String playbackUrl,
    required int generation,
    required String poolKey,
    required String tier,
    required bool cacheHit,
    required bool partialCache,
  }) async {
    if (!_tryBeginSurfaceRecovery('paint_stall', generation)) {
      _abortQualityCascade = true;
      return false;
    }
    try {
      final action = await _pool.softRecoverFeedVisibleSurfaceForPaintStall(
        poolKey,
        openToken: generation,
      );
      _logPoster(
        'paint_stall_soft_recovery',
        detail: 'gen=$generation action=$action candidate=$playbackUrl',
      );
      if (!mounted ||
          _isDisposed ||
          generation != _playbackGeneration ||
          _pool.isStaleFeedOpen(generation)) {
        _abortQualityCascade = true;
        return false;
      }

      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
      _videoController = _pool.feedSlotVideoController(_activeFeedSlotIndex);

      var player = _activePlayer;
      if (player == null) {
        _abortQualityCascade = true;
        return false;
      }

      // If prefetch finished during the stall, promote HTTPS → file:// once
      // without a hard recycle (same open token).
      var openUrl = playbackUrl;
      if (playbackUrl.toLowerCase().startsWith('http')) {
        final local = await resolveBestPlaybackUrl(playbackUrl);
        if (local.toLowerCase().startsWith('file://') &&
            local != playbackUrl) {
          _logPoster(
            'paint_stall_promote_file',
            detail: 'gen=$generation fromHttps=true',
          );
          final recovered = await _pool.openVisibleReel(
            key: poolKey,
            sourceUrl: local,
            openToken: generation,
          );
          if (recovered != null &&
              mounted &&
              !_isDisposed &&
              generation == _playbackGeneration &&
              !_pool.isStaleFeedOpen(generation)) {
            openUrl = local;
            _lastOpenWasCold = recovered.feedOpenedMedia;
            _pooledKey = poolKey;
            _attachGeneration = generation;
            _activeFeedSlotIndex =
                recovered.feedActiveSlotIndex ?? _pool.activeFeedSlotIndex;
            _videoController =
                _pool.feedSlotVideoController(_activeFeedSlotIndex);
            player = recovered.player;
            await _attachPlayer(
              recovered.player,
              generation: generation,
              afterFlip: !recovered.feedOpenedMedia,
              skipFrameWait: true,
            );
            await _registerRenderSlot(recovered.player);
          }
        }
      }

      // Continue waiting on the same surface — no hard rebuild.
      final waitResult = await _waitForFrameReadyWithRecovery(
        player: player,
        generation: generation,
        poolKey: poolKey,
      );
      final openMs = _openStartedAt == null
          ? 0
          : DateTime.now().difference(_openStartedAt!).inMilliseconds;
      // Require a real frame_ready — decode-likely-active alone previously
      // ended the switch before paint and left black/garbled windows.
      if (waitResult.ready) {
        ReelsPerf.emit(
          ReelsPerfEvent(
            name: 'open_complete',
            openMs: openMs,
            tier: tier,
            cacheHit: cacheHit ||
                partialCache ||
                openUrl.toLowerCase().startsWith('file://'),
            partialCache: partialCache,
            flip: false,
            coldOpen: _lastOpenWasCold,
            extra: {
              'reel': widget.videoId,
              'paint_stall_soft_recovery': true,
              'action': action,
              'promoted_file': openUrl != playbackUrl,
            },
          ),
        );
        return true;
      }

      // One soft attempt used — stop ladder; settle/Retry owns the next try.
      _abortQualityCascade = true;
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'open_timeout',
          openMs: openMs,
          tier: tier,
          stuck: true,
          extra: {
            'reel': widget.videoId,
            'paint_stall': true,
            'fallback': false,
            'action': action,
          },
        ),
      );
      return false;
    } finally {
      _endSurfaceRecovery();
    }
  }

  void _logPoster(String event, {String? detail}) {
    if (kReleaseMode) {
      return;
    }
    final openCount =
        _usesFeedVisibleChannel ? _pool.feedOpenCount : 0;
    debugPrint(
      '[ReelsPoster] $event reel=${widget.videoId} gen=$_playbackGeneration '
      'openCount=$openCount thumb=$_showThumbnail frame=$_frameReady '
      'visible=$_videoSurfaceVisible ${detail ?? ''}',
    );
  }

  void _prepareSwitchUiState(String newKey) {
    if (_usesFeedVisibleChannel) {
      _revealGeneration++;
      _frameWatchGeneration++;
      _userPaused = false;
      _completionNotified = false;
      _showRetry = false;
      _frameTimeout?.cancel();
      _resetDimensionStability();
      _surfaceRecoveryAttempts = 0;
      _fastFeedReveal = false;
      if (newKey.isNotEmpty) {
        _pool.clearUserPaused(newKey);
        final liveSameReel = _pool.isFeedVisibleKey(newKey) &&
            _pool.canInstantResume(newKey) &&
            _pool.isFrameReady(newKey);
        if (liveSameReel) {
          _fastFeedReveal = true;
        } else {
          // Stale frame-ready from a prior visit must not skip the poster.
          _pool.invalidatePrimedFrame(newKey);
          if (_pool.hadRecentPaint(newKey) || _pool.isBufferPrimed(newKey)) {
            _fastFeedReveal = true;
          }
        }
      }
      final switching = (_pooledKey ?? '').isNotEmpty &&
          newKey.isNotEmpty &&
          _pooledKey != newKey;
      if (newKey.isNotEmpty && _fastFeedReveal && _pool.isFeedVisibleKey(newKey)) {
        _frameReady = false;
        _videoSurfaceVisible = false;
        _feedPosterUnmaskedAtMs = 0;
        _surfacePaintFrames = _minSurfacePaintFramesBuffered;
        _logPoster('switch_primede', detail: 'key=$newKey live');
      } else if (newKey.isNotEmpty && _fastFeedReveal) {
        // Cached / scroll-back: decode under poster, reveal only after paint.
        _frameReady = false;
        _videoSurfaceVisible = false;
        _feedPosterUnmaskedAtMs = 0;
        _surfacePaintFrames = _minSurfacePaintFramesBuffered;
        _logPoster('switch_cached', detail: 'key=$newKey');
      } else if (switching && _frameReady) {
        // Page poster stays visible under transparent player; hide video until paint.
        _frameReady = false;
        _videoSurfaceVisible = false;
        _showThumbnail = false;
        _surfacePaintFrames = 0;
        _resetDimensionStability();
        _logPoster('switch_defer_video', detail: 'to=$newKey');
      } else {
        _frameReady = false;
        _videoSurfaceVisible = false;
        _showThumbnail = false;
        _surfacePaintFrames = 0;
        _resetDimensionStability();
        _logPoster('switch_cold', detail: 'key=$newKey');
      }
      return;
    }
    final poolPrimed = _isPoolPrimedForKey(newKey);
    if (!poolPrimed) {
      _resetFrameStateForKey(newKey);
      return;
    }
    _frameWatchGeneration++;
    _userPaused = false;
    _completionNotified = false;
    _showRetry = false;
    _frameTimeout?.cancel();
    if (newKey.isNotEmpty) {
      _pool.clearUserPaused(newKey);
    }
    if (_pool.isFrameReady(newKey)) {
      _frameReady = true;
      _showThumbnail = false;
      _surfacePaintFrames = _minSurfacePaintFrames;
      return;
    }
    // Demux-ahead: surface stays mounted but poster stays until first paint.
    _frameReady = false;
    _showThumbnail = true;
    _surfacePaintFrames = 0;
  }

  Future<void> _switchVideo({String reason = 'switch'}) async {
    if (_isDisposed) {
      return;
    }
    if (_isInitializing) {
      _pendingSwitchAfterInit = true;
      _logSwitchDiag('switch_pending', reason: reason, key: _poolKey);
      return;
    }
    final oldKey = _pooledKey;
    final newKey = _poolKey;
    if (newKey.isEmpty) {
      return;
    }
    final generation = _nextPlaybackGeneration();
    _isInitializing = true;
    _initializingForKey = newKey;
    _lastSwitchTargetKey = newKey;
    _lastSwitchAttemptMs = DateTime.now().millisecondsSinceEpoch;
    _switchCallCount++;
    _logSwitchDiag('switch_enter', reason: reason, key: newKey, generation: generation);
    final startedAt = _lastSwitchAttemptMs;
    var bail = 'ok';
    _prepareSwitchUiState(newKey);
    try {
      if (!_usesFeedVisibleChannel &&
          oldKey != null &&
          oldKey.isNotEmpty &&
          oldKey != newKey) {
        await _pool.surrenderLease(oldKey);
      }
      if (!mounted || _isDisposed || generation != _playbackGeneration) {
        bail = 'gen_mismatch';
        return;
      }
      _detachAnalyticsAndListeners();

      if (_usesFeedVisibleChannel) {
        await _openWithCandidates(
          generation: generation,
          poolKey: newKey,
          onFailure: () {
            if (mounted && !_isDisposed && _isCurrentAttach(generation)) {
              setState(() => _showRetry = true);
            }
          },
        );
        if (generation != _playbackGeneration) {
          bail = 'stale_gen';
        } else if (_pooledKey != newKey) {
          bail = 'no_attach';
        } else {
          bail = 'opened';
        }
        return;
      }

      final cachedSource = _pool.sourceUrlForKey(newKey);
      if (cachedSource != null && _pool.canInstantResume(newKey)) {
        final pooled = await _pool.acquire(
          key: newKey,
          sourceUrl: cachedSource,
          autoPlay: false,
        );
        if (!mounted || _isDisposed || generation != _playbackGeneration) {
          bail = 'gen_mismatch';
          return;
        }
        _pooledKey = newKey;
        _attachGeneration = generation;
        await _attachPlayer(pooled.player, generation: generation);
        await _startStrictPlaybackAfterSurface(
          player: pooled.player,
          poolKey: newKey,
          generation: generation,
        );
        bail = 'instant_resume';
        return;
      }

      await _openWithCandidates(
        generation: generation,
        poolKey: newKey,
        onFailure: () {
          if (mounted && !_isDisposed && _isCurrentAttach(generation)) {
            setState(() => _showRetry = true);
          }
        },
      );
      if (generation != _playbackGeneration) {
        bail = 'stale_gen';
      } else if (_pooledKey != newKey) {
        bail = 'no_attach';
      } else {
        bail = 'opened';
      }
    } finally {
      final attempted = _initializingForKey ?? _lastSwitchTargetKey;
      _isInitializing = false;
      _initializingForKey = null;
      _logSwitchDiag(
        'switch_exit',
        reason: reason,
        key: newKey,
        generation: generation,
        elapsedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
        bail: bail,
      );
      _drainPendingSwitchAfterInit(attemptedKey: attempted);
    }
  }

  /// After a cancelled/superseded init, open the currently mounted reel.
  void _drainPendingSwitchAfterInit({String? attemptedKey}) {
    if (!_pendingSwitchAfterInit || _isDisposed || !mounted) {
      return;
    }
    _pendingSwitchAfterInit = false;
    final key = _poolKey;
    // Same key just attempted (success, fail, or stale) — do not immediately
    // re-schedule; rebuild noise must not storm switch_cold. A later
    // onPageChanged / ensureVisibleOpen may retry if still mismatched.
    if (key.isNotEmpty &&
        attemptedKey != null &&
        attemptedKey.isNotEmpty &&
        key == attemptedKey) {
      _logSwitchDiag('drain_skip_same_key', reason: 'drain', key: key);
      return;
    }
    // Settled reel already attached — restarting remasks and loops the intro.
    if (key.isNotEmpty &&
        _pooledKey == key &&
        _pool.isFeedVisibleKey(key) &&
        (_frameReady || _pool.isFrameReady(key))) {
      return;
    }
    if (_pooledKey == null && _usesFeedVisibleChannel) {
      unawaited(_loadVideo(reason: 'drain'));
    } else {
      unawaited(_switchVideo(reason: 'drain'));
    }
  }

  /// Poster URL safe for fresh uploads.
  ///
  /// When the ladder is ready, keep the reel/frame poster (matches video crop).
  /// Only fall back to grid cover before transcode — switching crops at unmask
  /// is what made feed items look like they "shrunk from the sides".
  String get _effectivePosterUrl {
    final primary = widget.thumbnailUrl.trim();
    final fallback = widget.posterFallbackUrl?.trim() ?? '';
    final primaryIsPendingThumb = primary.contains('thumb.webp') &&
        !widget.transcodeReady;
    if (primaryIsPendingThumb && fallback.isNotEmpty) {
      return fallback;
    }
    if (primary.isNotEmpty) {
      return primary;
    }
    return fallback;
  }

  bool get _effectiveBlurVisible {
    final blur = widget.blurThumbnailUrl?.trim() ?? '';
    if (blur.isEmpty) {
      return false;
    }
    return blur != _effectivePosterUrl;
  }

  String? get _effectiveBlurUrl {
    final blur = widget.blurThumbnailUrl?.trim() ?? '';
    if (blur.isEmpty || blur == _effectivePosterUrl) {
      return null;
    }
    return blur;
  }

  Future<void> _onRetryPressed() async {
    if (_isDisposed || _isInitializing) {
      return;
    }
    setState(() => _showRetry = false);
    final key = _pooledKey;
    if (key != null) {
      unawaited(_pool.release(key));
      _pooledKey = null;
    }
    _failedSourceUrls.clear();
    await _loadVideo();
  }

  Widget _buildThumbnail() {
    return ReelGaplessPoster(
      imageUrl: _effectivePosterUrl,
      blurUrl: _effectiveBlurVisible ? _effectiveBlurUrl : null,
      fallbackUrl: widget.posterFallbackUrl,
      cacheKey: 'reel_poster_${widget.videoId ?? _effectivePosterUrl}',
      fit: BoxFit.cover,
    );
  }

  Widget _buildRetryOverlay() {
    return Center(
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _onRetryPressed,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _activePlayer;
    final showVideo = _shouldShowVideoLayer(player);
    // Keep feed video transparent until reveal completes AND a real frame is
    // composited — never at frame_ready alone (logs: frame_ready 100ms,
    // surface_revealed 400ms; showing early paints a black surface over poster).
    final feedVideoVisible = _usesFeedVisibleChannel &&
        _videoSurfaceMounted &&
        _videoSurfaceVisible &&
        showVideo &&
        player != null &&
        _canShowVideo(player);
    // Honor/MTK: 1×1 strict gate never paints — keep full size, hide via opacity.
    final collapseSurface =
        _strictSurfaceGate && !showVideo && !_needsConstrainedStartGate;
    // Parent poster masks feed video until paint; Honor needs opaque surface from mount.
    final feedSurfaceMounted = _usesFeedVisibleChannel && _videoSurfaceMounted;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_usesFeedVisibleChannel && _videoSurfaceVisible)
          const ColoredBox(color: Colors.black),
        if (feedSurfaceMounted)
          _buildFeedVideoSurfaces(visible: feedVideoVisible),
        if (_usesFeedVisibleChannel)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => unawaited(togglePlayPause()),
              child: const SizedBox.expand(),
            ),
          )
        else if (_videoSurfaceMounted && _videoController != null)
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: collapseSurface ? 1 : double.infinity,
                  height: collapseSurface ? 1 : double.infinity,
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: _videoSurfaceVisible ? 1.0 : 0.0,
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final fit = _adaptiveFit(constraints);
                          return Video(
                            key: ValueKey('reel_surface_$_surfaceEpoch'),
                            controller: _videoController!,
                            fit: fit,
                            fill: fit == BoxFit.contain
                                ? const Color(0xFF000000)
                                : const Color(0x00000000),
                            controls: NoVideoControls,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!_usesFeedVisibleChannel && _showThumbnail)
          IgnorePointer(
            child: _buildThumbnail(),
          ),
        if (_showRetry) _buildRetryOverlay(),
        if (_showPlayPauseIcon)
          Center(
            child: Icon(
              _iconShowsPause
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white70,
              size: 72,
            ),
          ),
        if (widget.showProgressBar && player != null)
          ReelPlaybackProgressBar(
            player: player,
            previewPosterUrl: widget.thumbnailUrl.isNotEmpty
                ? widget.thumbnailUrl
                : widget.posterFallbackUrl,
            bottomInset: MediaQuery.paddingOf(context).bottom + 6,
          ),
      ],
    );
  }
}
