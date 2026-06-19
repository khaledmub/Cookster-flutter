import 'dart:async';

import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/services/feature_flags/remote_config_service.dart';
import 'package:cookster/core/widgets/reel_gapless_poster.dart';
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
    this.onVideoCompleted,
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
  final VoidCallback? onVideoCompleted;

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
  /// Frames after [Video] is in the tree — avoids trusting demux-only pool state.
  int _surfacePaintFrames = 0;
  bool _showRetry = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
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
    debugPrint(
      '[ReelVideoPlayer] init hash=$hashCode live=$_liveInstances '
      'key=$_poolKey feedChannel=$_usesFeedVisibleChannel',
    );
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.addListener(_onFeedActiveSlotChanged);
      _pool.feedSurfaceGeneration.addListener(_onFeedSurfaceBumped);
      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }
        unawaited(_loadVideo());
      });
      return;
    }
    unawaited(_loadVideo());
  }

  /// Re-open feed playback after a route overlay silenced the pool (visit profile, etc.).
  Future<void> resumeAfterRouteOverlay() async {
    if (_isDisposed || !_usesFeedVisibleChannel || !mounted) {
      return;
    }
    _failedSourceUrls.clear();
    await _loadVideo();
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
    setState(() {});
  }

  void _onFeedSurfaceBumped() {
    if (!mounted || _isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    _videoSurfaceVisible = false;
    _frameReady = false;
    _surfacePaintFrames = 0;
    _resetDimensionStability();
    final key = _pooledKey;
    if (key != null && key.isNotEmpty) {
      _pool.invalidatePrimedFrame(key);
    }
    final player = _activePlayer;
    if (player != null) {
      _afterSurfaceMounted(
        player,
        paintTicks: _needsConstrainedStartGate ? 10 : 4,
      );
    }
    _logPoster('surface_bumped', detail: 'key=$key');
    setState(() {});
  }

  /// Hide video surface when a reel switch is committed — not during partial scroll.
  void deferSurfaceForSwipe() {
    if (_isDisposed || !_usesFeedVisibleChannel) {
      return;
    }
    _revealGeneration++;
    if (_videoSurfaceVisible) {
      _videoSurfaceVisible = false;
    }
    if (_frameReady) {
      _frameReady = false;
    }
    _surfacePaintFrames = 0;
    _logPoster('swipe_hide_surface');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final videoChanged = widget.videoId != oldWidget.videoId ||
        widget.videoUrl != oldWidget.videoUrl ||
        widget.hlsUrl != oldWidget.hlsUrl ||
        widget.playerPoolKey != oldWidget.playerPoolKey;
    if (videoChanged || _pooledKey != _poolKey) {
      _revealGeneration++;
      _videoSurfaceVisible = false;
      _frameReady = false;
      _failedSourceUrls.clear();
      if (mounted) {
        setState(() {});
      }
      unawaited(_switchVideo());
    }
  }

  @override
  void dispose() {
    _liveInstances--;
    debugPrint(
      '[ReelVideoPlayer] dispose hash=$hashCode live=$_liveInstances '
      'key=${_pooledKey ?? _poolKey}',
    );
    _isDisposed = true;
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.removeListener(_onFeedActiveSlotChanged);
      _pool.feedSurfaceGeneration.removeListener(_onFeedSurfaceBumped);
    }
    _playbackGeneration++;
    _cancelFrameWatch();
    _frameTimeout?.cancel();
    _iconHideTimer?.cancel();
    _detachAnalyticsAndListeners();
    final key = _pooledKey;
    _pooledKey = null;
    _videoController = null;
    if (key != null) {
      if (widget.releaseOnDispose) {
        unawaited(_pool.release(key));
      } else if (!_usesFeedVisibleChannel) {
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
      return 96;
    }
    return 8;
  }

  bool _hasRealFrame(Player player, [Duration? position]) {
    final pos = position ?? player.state.position;
    if (player.state.width == null) {
      return false;
    }
    return pos.inMilliseconds > _minPositionMsForFrame();
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

  bool _dimensionsSettledFor(int ms) {
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _lastDimensionChangeMs;
    return elapsed >= ms;
  }

  void _trackDimensionStability(Player player) {
    final width = player.state.width;
    final height = player.state.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    if (width == _stableFrameWidth && height == _stableFrameHeight) {
      _dimensionStableTicks++;
    } else {
      _lastDimensionChangeMs = DateTime.now().millisecondsSinceEpoch;
      final hadStableDims = _stableFrameWidth != null && _stableFrameHeight != null;
      _stableFrameWidth = width;
      _stableFrameHeight = height;
      _dimensionStableTicks = 0;
      if (hadStableDims &&
          _needsConstrainedStartGate &&
          (_videoSurfaceVisible || _frameReady)) {
        _revealGeneration++;
        _videoSurfaceVisible = false;
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
    if (_lastOpenCacheHit || _lastOpenPartialCache) {
      return _minDimensionStableTicksCached;
    }
    return _minDimensionStableTicksConstrained;
  }

  int _requiredSurfacePaintFrames() {
    final key = _pooledKey;
    if (_needsConstrainedStartGate) {
      if (_lastOpenWasCold) {
        return _minSurfacePaintFramesConstrained;
      }
      if (_lastOpenCacheHit || _lastOpenPartialCache) {
        return _minSurfacePaintFrames + 2;
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

  void _onPlayerStateTick(Player player) {
    if (!mounted || _isDisposed || _frameReady) {
      return;
    }
    _trackDimensionStability(player);
    if (_canShowVideo(player)) {
      unawaited(_onFrameReady(player, generation: _attachGeneration));
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

    if (_needsConstrainedStartGate) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!_isCurrentAttach(generation) ||
          revealGen != _revealGeneration ||
          !mounted ||
          _isDisposed) {
        _logPoster('surface_reveal_aborted', detail: 'stale_after_delay');
        return;
      }
      for (var i = 0; i < 3; i++) {
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
      while (polled < 2800) {
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
        final posMs = player.state.position.inMilliseconds;
        if (posMs >= startPosMs + 120 &&
            _canShowVideo(player) &&
            _dimensionsSettledFor(280)) {
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
          unawaited(_pool.recoverFeedVisibleSurface(key));
        }
        if (mounted && !_isDisposed) {
          setState(() {});
        }
        return;
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 80));
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
    _videoSurfaceVisible = true;
    _logPoster(
      'surface_revealed',
      detail: '${player.state.width}x${player.state.height} '
          'pos=${player.state.position.inMilliseconds}ms',
    );
    setState(() {});
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
    _logPoster(
      'frame_ready',
      detail: 'key=$key ${player.state.width}x${player.state.height} '
          'pos=${player.state.position.inMilliseconds}ms',
    );

    await _revealVideoSurface(generation: generation, player: player);
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    if (!_videoSurfaceVisible) {
      return;
    }

    if (key != null) {
      _pool.markFrameReadyFromSurface(key);
    }
    await _resumeAudibleAfterReveal(key: key, generation: generation);
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    unawaited(_maybeUpgradeToCached1080(generation: generation));
  }

  Future<void> _maybeUpgradeToCached1080({required int generation}) async {
    if (_upgradeInFlight ||
        !_usesFeedVisibleChannel ||
        !_isCurrentAttach(generation) ||
        !mounted ||
        _isDisposed) {
      return;
    }
    if (_pool.feedSingleSlotMode) {
      return;
    }
    final context = this.context;
    if (_isTabletLayout(context)) {
      return;
    }
    final network = await _networkPolicy.currentNetworkClass();
    if (network != NetworkClass.wifi) {
      return;
    }
    final poolKey = _pooledKey;
    if (poolKey == null || poolKey.isEmpty) {
      return;
    }
    final currentUrl = _pool.sourceUrlForKey(poolKey);
    if (currentUrl != null && _resolver.mp4Tier(currentUrl) == '1080') {
      return;
    }
    final tier1080 = await _resolver.cached1080Candidate(_resolvedCandidates());
    if (tier1080 == null || !_isCurrentAttach(generation)) {
      return;
    }
    _upgradeInFlight = true;
    try {
      final playbackUrl = await _resolvePlaybackUrlForSource(tier1080, network);
      final upgradeGen = ++_playbackGeneration;
      final pooled = await _pool.openVisibleReel(
        key: poolKey,
        sourceUrl: playbackUrl,
        openToken: upgradeGen,
      );
      if (!_isCurrentAttach(upgradeGen) || !mounted || _isDisposed) {
        return;
      }
      _attachGeneration = upgradeGen;
      _activeFeedSlotIndex = pooled.feedActiveSlotIndex ?? _pool.activeFeedSlotIndex;
      ReelsPerf.log(
        'upgrade reel=${widget.videoId} tier=1080 cache=hit flip=${!pooled.feedOpenedMedia}',
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
        unawaited(_onFrameReady(player, generation: _attachGeneration));
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
        unawaited(_onFrameReady(player, generation: _attachGeneration));
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
      _videoController = VideoController(player);
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
    _afterSurfaceMounted(player);
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
      _surfacePaintFrames = _minSurfacePaintFramesBuffered;
      _showThumbnail = false;
      unawaited(_onFrameReady(player, generation: _attachGeneration));
    } else {
      final key = _pooledKey;
      if (!_lastOpenWasCold &&
          key != null &&
          key.isNotEmpty &&
          _pool.isFrameReady(key) &&
          _hasRealFrame(player)) {
        _surfacePaintFrames = _minSurfacePaintFramesBuffered;
        _showThumbnail = false;
        unawaited(_onFrameReady(player, generation: _attachGeneration));
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
            unawaited(_onFrameReady(player, generation: _attachGeneration));
          }
        });
      }
    }
  }

  /// One permanent full-size surface — single [Video] widget bound to the active
  /// slot. Never mount two surfaces (Honor/MTK log: Rendered 0/s, surface errors).
  Widget _buildFeedVideoSurfaces({required bool visible}) {
    final controller =
        _pool.feedSlotVideoController(_activeFeedSlotIndex);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: visible ? 1.0 : 0.0,
          child: ClipRect(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: RepaintBoundary(
                  child: Video(
                    key: const ValueKey('reel_surface_feed'),
                    controller: controller,
                    fit: BoxFit.cover,
                    controls: NoVideoControls,
                  ),
                ),
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
    while (waited < timeoutMs &&
        mounted &&
        !_isDisposed &&
        _isCurrentAttach(generation)) {
      _trackDimensionStability(player);
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

  Future<bool> _waitForFrameReadyWithRecovery({
    required Player player,
    required int generation,
    required String poolKey,
  }) async {
    var frameReady = await _waitForFrameReady(
      player: player,
      generation: generation,
      timeoutMs: _frameWaitTimeoutMs(),
    );
    if (frameReady ||
        !DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
      return frameReady;
    }
    while (!frameReady &&
        _surfaceRecoveryAttempts < _maxSurfaceRecoveryAttempts &&
        _isCurrentAttach(generation) &&
        mounted &&
        !_isDisposed) {
      _surfaceRecoveryAttempts++;
      if (_usesFeedVisibleChannel) {
        await _recoverFeedSurface(
          player: player,
          poolKey: poolKey,
          generation: generation,
        );
      } else {
        await _recoverStrictSurface(
          player: player,
          poolKey: poolKey,
          generation: generation,
        );
      }
      frameReady = await _waitForFrameReady(
        player: player,
        generation: generation,
        timeoutMs: 2800,
      );
    }
    return frameReady;
  }

  Future<void> _recoverFeedSurface({
    required Player player,
    required String poolKey,
    required int generation,
  }) async {
    if (!_isCurrentAttach(generation) || poolKey.isEmpty) {
      return;
    }
    _surfacePaintFrames = 0;
    _resetDimensionStability();
    await _pool.recoverFeedVisibleSurface(poolKey);
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    _afterSurfaceMounted(player, paintTicks: 8);
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'surface_recovery_attempt',
        retry: true,
        extra: {
          'attempt': _surfaceRecoveryAttempts,
          'reel': widget.videoId,
        },
      ),
    );
  }

  Future<void> _remountStrictVideoSurface(Player player) async {
    if (_isDisposed || !mounted || _usesFeedVisibleChannel) {
      return;
    }
    _videoController = null;
    _videoSurfaceMounted = false;
    _surfaceEpoch++;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (_isDisposed || !mounted) {
      return;
    }
    _videoController = VideoController(player);
    _videoSurfaceMounted = true;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
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

  Future<void> _recoverStrictSurface({
    required Player player,
    required String poolKey,
    required int generation,
  }) async {
    if (!_isCurrentAttach(generation) || poolKey.isEmpty) {
      return;
    }
    _surfacePaintFrames = 0;
    _resetDimensionStability();
    await _remountStrictVideoSurface(player);
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    try {
      await player.pause();
      await player.seek(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 48));
      await _startStrictPlaybackAfterSurface(
        player: player,
        poolKey: poolKey,
        generation: generation,
      );
    } catch (_) {}
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
      return;
    }
    _afterSurfaceMounted(player, paintTicks: 8);
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'surface_recovery_attempt',
        retry: true,
        extra: {
          'attempt': _surfaceRecoveryAttempts,
          'reel': widget.videoId,
          'mode': 'strict',
        },
      ),
    );
  }

  Future<List<VideoSourceCandidate>> _orderedPlaybackCandidates(
    NetworkClass network,
    bool isTablet,
  ) async {
    final rc = RemoteConfigService.instance;
    final cache = ReelsVideoCacheManager.instance.manager;
    var candidates = await _resolver.prioritizeForPlaybackFastStart(
      candidates: _resolvedCandidates(),
      network: network,
      cacheManager: cache,
      isTablet: isTablet,
      fastStartUncached: rc.reels360FirstUncached,
      hlsWifiEnabled: rc.reelsHlsWifiEnabled,
    );
    await DeviceConstraints.instance.ensureInitialized();
    if (!DeviceConstraints.instance.prefer360ColdOpen) {
      return candidates;
    }
    var hasCachedMp4 = false;
    for (final candidate in candidates) {
      if (candidate.type != 'mp4_quality') {
        continue;
      }
      if (await isPlaybackUrlCached(candidate.url, cacheManager: cache) ||
          await isPlaybackUrlPartiallyCached(candidate.url, cacheManager: cache)) {
        hasCachedMp4 = true;
        break;
      }
    }
    if (hasCachedMp4) {
      return candidates;
    }
    final tier360 = candidates
        .where((c) => _resolver.mp4Tier(c.url) == '360')
        .toList(growable: false);
    if (tier360.isEmpty) {
      return candidates;
    }
    final rest = candidates
        .where((c) => _resolver.mp4Tier(c.url) != '360')
        .toList(growable: false);
    return [...tier360, ...rest];
  }

  Future<void> _awaitFeedFrameOrAudio(
    Player player, {
    required int generation,
  }) async {
    var waited = 0;
    while (waited < 3200 &&
        mounted &&
        !_isDisposed &&
        _isCurrentAttach(generation)) {
      if (_canShowVideo(player)) {
        await _onFrameReady(player, generation: generation);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
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

  Future<void> _loadVideo() async {
    if (_isDisposed || _isInitializing) {
      return;
    }
    final generation = ++_playbackGeneration;
    _isInitializing = true;
    final poolKey = _poolKey;
    if (_usesFeedVisibleChannel) {
      _prepareSwitchUiState(poolKey);
    } else {
      _resetFrameStateForKey(poolKey);
    }
    try {
      if (poolKey.isEmpty) {
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
              return;
            }
            await _pool.resumeFeedVisible(poolKey);
            return;
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
    } finally {
      _isInitializing = false;
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

    final source = candidates.first;
    if (_failedSourceUrls.contains(source.url)) {
      onFailure();
      return;
    }
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
      _resetDimensionStability();
      _surfaceRecoveryAttempts = 0;
      final playbackUrl = await _resolvePlaybackUrlForSource(source, network);
      _openStartedAt = DateTime.now();
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
      _lastOpenWasCold =
          _usesFeedVisibleChannel ? pooled.feedOpenedMedia : true;
      if (!mounted || _isDisposed || generation != _playbackGeneration) {
        return;
      }
      _pooledKey = poolKey;
      _attachGeneration = generation;
      if (_usesFeedVisibleChannel) {
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
      if (!_usesFeedVisibleChannel) {
        await _startStrictPlaybackAfterSurface(
          player: pooled.player,
          poolKey: poolKey,
          generation: generation,
        );
      }
      final frameReady = await _waitForFrameReadyWithRecovery(
        player: pooled.player,
        generation: generation,
        poolKey: poolKey,
      );
      final openMs = _openStartedAt == null
          ? 0
          : DateTime.now().difference(_openStartedAt!).inMilliseconds;
      if (frameReady) {
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
        return;
      }
      _failedSourceUrls.add(source.url);
      ReelsPerf.emit(
        ReelsPerfEvent(
          name: 'open_timeout',
          openMs: openMs,
          tier: tier,
          stuck: true,
          extra: {'reel': widget.videoId},
        ),
      );
    } catch (e) {
      _failedSourceUrls.add(source.url);
      debugPrint('ReelVideoPlayer source failed (${widget.videoId}): $e');
    }
    if (_isCurrentAttach(generation) && mounted && !_isDisposed) {
      onFailure();
    }
  }

  void _logPoster(String event, {String? detail}) {
    if (kReleaseMode) {
      return;
    }
    debugPrint(
      '[ReelsPoster] $event reel=${widget.videoId} '
      'thumb=$_showThumbnail frame=$_frameReady visible=$_videoSurfaceVisible '
      '${detail ?? ''}',
    );
  }

  void _prepareSwitchUiState(String newKey) {
    if (_usesFeedVisibleChannel && _videoSurfaceMounted) {
      _revealGeneration++;
      _frameWatchGeneration++;
      _userPaused = false;
      _completionNotified = false;
      _showRetry = false;
      _frameTimeout?.cancel();
      _resetDimensionStability();
      _surfaceRecoveryAttempts = 0;
      if (newKey.isNotEmpty) {
        _pool.clearUserPaused(newKey);
        _pool.invalidatePrimedFrame(newKey);
      }
      final switching = (_pooledKey ?? '').isNotEmpty &&
          newKey.isNotEmpty &&
          _pooledKey != newKey;
      if (newKey.isNotEmpty &&
          _pool.isFrameReady(newKey) &&
          _pool.isFeedVisibleKey(newKey)) {
        _frameReady = true;
        _showThumbnail = false;
        _surfacePaintFrames = _minSurfacePaintFrames;
        _logPoster('switch_primede', detail: 'key=$newKey');
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

  Future<void> _switchVideo() async {
    if (_isDisposed) {
      return;
    }
    final oldKey = _pooledKey;
    final newKey = _poolKey;
    if (newKey.isEmpty) {
      return;
    }
    final generation = ++_playbackGeneration;
    _isInitializing = true;
    _prepareSwitchUiState(newKey);
    try {
      if (!_usesFeedVisibleChannel &&
          oldKey != null &&
          oldKey.isNotEmpty &&
          oldKey != newKey) {
        await _pool.surrenderLease(oldKey);
      }
      if (!mounted || _isDisposed || generation != _playbackGeneration) {
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
    } finally {
      _isInitializing = false;
    }
  }

  /// Poster URL safe for fresh uploads
  String get _effectivePosterUrl {
    final primary = widget.thumbnailUrl.trim();
    final fallback = widget.posterFallbackUrl?.trim() ?? '';
    final primaryIsPendingThumb = primary.contains('thumb.webp') &&
        !widget.transcodeReady;
    if (primaryIsPendingThumb && fallback.isNotEmpty) {
      return fallback;
    }
    if (!widget.transcodeReady && fallback.isNotEmpty) {
      return fallback;
    }
    if (primary.isNotEmpty) {
      return primary;
    }
    return fallback;
  }

  bool get _effectiveBlurVisible {
    final blur = widget.blurThumbnailUrl;
    return widget.transcodeReady &&
        blur != null &&
        blur.isNotEmpty;
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
      blurUrl: _effectiveBlurVisible ? widget.blurThumbnailUrl : null,
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
    // Honor/MTK: 1×1 strict gate never paints — keep full size, hide via opacity.
    final collapseSurface =
        _strictSurfaceGate && !showVideo && !_needsConstrainedStartGate;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_videoSurfaceVisible) const ColoredBox(color: Colors.black),
        if (_usesFeedVisibleChannel && _videoSurfaceMounted)
          _buildFeedVideoSurfaces(visible: _videoSurfaceVisible),
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
                      child: Video(
                        key: ValueKey('reel_surface_$_surfaceEpoch'),
                        controller: _videoController!,
                        fit: BoxFit.cover,
                        controls: NoVideoControls,
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
      ],
    );
  }
}
