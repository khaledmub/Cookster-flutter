import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
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
  static const _frameTimeoutDuration = Duration(seconds: 2);
  static const _thumbnailFadeDuration = Duration(milliseconds: 150);

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
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;

  final Set<String> _failedSourceUrls = <String>{};

  String get _poolKey =>
      widget.playerPoolKey ?? widget.videoId ?? widget.videoUrl;

  /// Feed keeps pool leases + fast resume; profile opens fresh (strict poster gate).
  bool get _strictSurfaceGate => widget.releaseOnDispose;

  /// Home/profile reels: one [Player] surface, swap media on swipe (no pause).
  bool get _usesFeedVisibleChannel => !widget.releaseOnDispose;

  @override
  void initState() {
    super.initState();
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.addListener(_onFeedActiveSlotChanged);
      _activeFeedSlotIndex = _pool.activeFeedSlotIndex;
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

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final videoChanged = widget.videoId != oldWidget.videoId ||
        widget.videoUrl != oldWidget.videoUrl ||
        widget.hlsUrl != oldWidget.hlsUrl ||
        widget.playerPoolKey != oldWidget.playerPoolKey;
    if (videoChanged || _pooledKey != _poolKey) {
      _failedSourceUrls.clear();
      unawaited(_switchVideo());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_usesFeedVisibleChannel) {
      _pool.feedActiveSlotIndexNotifier.removeListener(_onFeedActiveSlotChanged);
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

  bool _hasRealFrame(Player player, [Duration? position]) {
    final pos = position ?? player.state.position;
    if (player.state.width == null) {
      return false;
    }
    final minMs = _usesFeedVisibleChannel ? 1 : 32;
    return pos.inMilliseconds > minMs;
  }

  /// Frames the surface must composite after a decoded frame before we trust
  /// the GL texture has painted. On Android/Impeller the player position
  /// advances a few frames before the texture actually paints — hiding the
  /// poster on position alone shows a black surface (worse at 720p). Requiring
  /// a couple of composited frames closes that black-flash window.
  static const int _minSurfacePaintFrames = 2;
  static const int _minSurfacePaintFramesBuffered = 1;

  int _requiredSurfacePaintFrames() {
    final key = _pooledKey;
    if (!_strictSurfaceGate &&
        key != null &&
        key.isNotEmpty &&
        _pool.isBufferPrimed(key) &&
        !_pool.isFrameReady(key)) {
      return _minSurfacePaintFramesBuffered;
    }
    return _minSurfacePaintFrames;
  }

  bool _canShowVideo(Player player, [Duration? position]) {
    if (!_videoSurfaceMounted ||
        _surfacePaintFrames < _requiredSurfacePaintFrames()) {
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
    _frameWatchGeneration++;
    _userPaused = false;
    _surfacePaintFrames = 0;
    if (key.isNotEmpty) {
      _pool.clearUserPaused(key);
      if (_strictSurfaceGate) {
        _pool.invalidatePrimedFrame(key);
      }
    }
    _showThumbnail = true;
    _frameReady = false;
    _showRetry = false;
    _completionNotified = false;
    _frameTimeout?.cancel();
    _frameTimeout = Timer(_frameTimeoutDuration, () {
      if (!mounted || _isDisposed || _frameReady) {
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
    _frameTimeout?.cancel();
    _frameTimeout = null;
  }

  void _onPlayerStateTick(Player player) {
    if (!mounted || _isDisposed || _frameReady) {
      return;
    }
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

  Future<void> _onFrameReady(Player player, {required int generation}) async {
    if (!_isCurrentAttach(generation) || !mounted || _isDisposed) {
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
    if (key != null) {
      _pool.markFrameReadyFromSurface(key);
    }
    if (key != null && !_userPaused) {
      if (_usesFeedVisibleChannel) {
        if (!_pool.isActiveAudible(key)) {
          await _pool.feedResumeAudibleWhenReady(key);
        }
      } else if (!_pool.isActiveAudible(key)) {
        await _ensureAudibleForKey(key, generation: generation);
      }
    }
    if (!_isCurrentAttach(generation)) {
      return;
    }
    widget.onPlaybackReady?.call();
    if (mounted && !_isDisposed) {
      setState(() {});
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
      if (!_showThumbnail && _canShowVideo(player, pos)) {
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
      final pos = player.state.position;
      if (_canShowVideo(player, pos)) {
        unawaited(_onFrameReady(player, generation: _attachGeneration));
        return;
      }
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
    if (afterFlip && _hasRealFrame(player)) {
      _surfacePaintFrames = _minSurfacePaintFramesBuffered;
      _showThumbnail = false;
      unawaited(_onFrameReady(player, generation: _attachGeneration));
    } else {
      _frameReady = false;
      _surfacePaintFrames = 0;
      _afterSurfaceMounted(player, paintTicks: 4);
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

  /// One permanent full-size surface for the feed — MTK cannot repaint after
  /// reparenting or dual decoders (renderFps=0).
  Widget _buildFeedVideoSurfaces() {
    final controller = _pool.feedSlotVideoController(0);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
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
    );
  }

  Future<void> _attachPlayer(
    Player player, {
    required int generation,
    bool afterFlip = false,
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
    _resetFrameStateForKey(_poolKey);
    try {
      if (_poolKey.isEmpty) {
        return;
      }
      if (_usesFeedVisibleChannel) {
        await _pool.ensureFeedPingPongInitialized();
        if (!_videoSurfaceMounted && mounted && !_isDisposed) {
          setState(() => _videoSurfaceMounted = true);
        } else {
          _videoSurfaceMounted = true;
        }
      }

      await _openWithCandidates(
        generation: generation,
        poolKey: _poolKey,
        onFailure: () {
          if (mounted && !_isDisposed) {
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
    return source.url.toLowerCase().contains('.m3u8')
        ? source.url
        : resolveCachedPlaybackUrl(
            source.url,
            cacheManager: DefaultCacheManager(),
          );
  }

  Future<void> _openWithCandidates({
    required int generation,
    required String poolKey,
    required VoidCallback onFailure,
  }) async {
    final network = await _networkPolicy.currentNetworkClass();
    final candidates = _resolver.prioritizeForNetwork(
      _resolver.resolveCandidates(
        hlsUrl: widget.hlsUrl,
        mp4Url: widget.videoUrl,
        qualityMp4Urls: widget.qualityMp4Urls,
      ),
      network,
    );
    if (candidates.isEmpty) {
      onFailure();
      return;
    }

    for (final source in candidates) {
      if (_failedSourceUrls.contains(source.url)) {
        continue;
      }
      try {
        final playbackUrl = await _resolvePlaybackUrlForSource(source, network);
        final pooled = _usesFeedVisibleChannel
            ? await _pool.openVisibleReel(
                key: poolKey,
                sourceUrl: playbackUrl,
                openToken: generation,
              )
            : await _pool.acquire(
                key: poolKey,
                sourceUrl: playbackUrl,
                autoPlay: true,
              );
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
          afterFlip: false,
        );
        return;
      } catch (e) {
        _failedSourceUrls.add(source.url);
        debugPrint('ReelVideoPlayer source failed (${widget.videoId}): $e');
      }
    }
    onFailure();
  }

  void _prepareSwitchUiState(String newKey) {
    if (_usesFeedVisibleChannel && _videoSurfaceMounted) {
      _frameWatchGeneration++;
      _userPaused = false;
      _completionNotified = false;
      _showRetry = false;
      _frameTimeout?.cancel();
      if (newKey.isNotEmpty) {
        _pool.clearUserPaused(newKey);
      }
      _frameReady = false;
      _showThumbnail = false;
      _surfacePaintFrames = 0;
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
    // Demux-ahead from scroll preload: keep the surface, skip poster flash.
    _frameReady = false;
    _showThumbnail = false;
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
            if (mounted && !_isDisposed) {
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
          autoPlay: true,
        );
        if (!mounted || _isDisposed || generation != _playbackGeneration) {
          return;
        }
        _pooledKey = newKey;
        _attachGeneration = generation;
        await _attachPlayer(pooled.player, generation: generation);
        return;
      }

      await _openWithCandidates(
        generation: generation,
        poolKey: newKey,
        onFailure: () {
          if (mounted && !_isDisposed) {
            setState(() => _showRetry = true);
          }
        },
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// Poster URL safe for fresh uploads (skip CDN thumb.webp until transcode ready).
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final (memW, memH) = fullScreenPosterMemCacheSize(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (_effectiveBlurVisible)
              CachedNetworkImage(
                imageUrl: widget.blurThumbnailUrl!,
                fit: BoxFit.cover,
                memCacheWidth: memW,
                memCacheHeight: memH,
                filterQuality: FilterQuality.low,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            if (_effectivePosterUrl.isNotEmpty)
              CachedNetworkImage(
                key: ValueKey(
                  'reel_poster_${widget.videoId ?? _effectivePosterUrl}',
                ),
                imageUrl: _effectivePosterUrl,
                fit: BoxFit.cover,
                memCacheWidth: memW,
                memCacheHeight: memH,
                placeholder: (_, __) => const ColoredBox(color: Colors.black),
                errorWidget: (context, url, error) {
                  final fallback = widget.posterFallbackUrl;
                  if (fallback == null ||
                      fallback.isEmpty ||
                      fallback == _effectivePosterUrl) {
                    return const SizedBox.shrink();
                  }
                  return CachedNetworkImage(
                    imageUrl: fallback,
                    fit: BoxFit.cover,
                    memCacheWidth: memW,
                    memCacheHeight: memH,
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  );
                },
              ),
            // Poster is the loading state — a second spinner on top reads as a
            // duplicate load phase after the feed skeleton already disappeared.
          ],
        );
      },
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
    final hidePoster = _frameReady || showVideo;
    // MTK/Oppo: 1×1 surface never paints (renderFps=0). Feed uses full size from mount.
    final collapseSurface = _strictSurfaceGate && !showVideo;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_usesFeedVisibleChannel && _videoSurfaceMounted)
          _buildFeedVideoSurfaces(),
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
                    child: Video(
                      key: const Key('reel_surface'),
                      controller: _videoController!,
                      fit: BoxFit.cover,
                      controls: NoVideoControls,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_showThumbnail || !hidePoster)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: hidePoster ? 0.0 : 1.0,
              duration: _thumbnailFadeDuration,
              curve: Curves.easeOut,
              child: _buildThumbnail(),
            ),
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
