import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
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
    this.onPlaybackReady,
    this.onVideoCompleted,
  });

  final String thumbnailUrl;
  final String? posterFallbackUrl;
  final String? blurThumbnailUrl;
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
  final MediaKitPlayerPool _pool = MediaKitPlayerPool.instance;
  final VideoAnalyticsTracker _analytics = VideoAnalyticsTracker();

  VideoController? _videoController;
  String? _pooledKey;
  /// Once true, [Video] with [Key('reel_surface')] stays in the tree across swipes.
  bool _videoSurfaceMounted = false;

  bool _showThumbnail = true;
  bool _frameReady = false;
  bool _showRetry = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  bool _completionNotified = false;
  bool _userPaused = false;
  bool _showPlayPauseIcon = false;
  bool _iconShowsPause = false;
  int _playbackGeneration = 0;
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo());
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final videoChanged = widget.videoId != oldWidget.videoId ||
        widget.videoUrl != oldWidget.videoUrl ||
        widget.hlsUrl != oldWidget.hlsUrl ||
        widget.playerPoolKey != oldWidget.playerPoolKey;
    if (videoChanged) {
      _failedSourceUrls.clear();
      unawaited(_switchVideo());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
      } else {
        unawaited(_pool.surrenderLease(key));
      }
    }
    super.dispose();
  }

  bool _hasRealFrame(Player player, [Duration? position]) {
    final pos = position ?? player.state.position;
    return player.state.width != null && pos.inMilliseconds > 32;
  }

  bool _canShowVideo(Player player, [Duration? position]) {
    // Only hide the poster once the active [Video] surface has a real frame.
    // Off-screen warm-up can buffer demux without rendering (renderFps=0).
    return _hasRealFrame(player, position);
  }

  void _resetFrameStateForKey(String key) {
    _frameWatchGeneration++;
    _userPaused = false;
    if (key.isNotEmpty) {
      _pool.clearUserPaused(key);
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
      unawaited(_onFrameReady(player));
    }
  }

  Future<void> _activateAudibleIfNeeded() async {
    final key = _pooledKey;
    if (key == null || _userPaused || !mounted || _isDisposed) {
      return;
    }
    if (_pool.isActiveAudible(key)) {
      return;
    }
    await _pool.activateVisible(key);
  }

  Future<void> _onFrameReady(Player player) async {
    if (!mounted || _isDisposed) {
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
    await _activateAudibleIfNeeded();
    widget.onPlaybackReady?.call();
    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  /// Called after page settle to fix audio when returning to a cached reel.
  Future<void> syncAudibleIfNeeded() async {
    final key = _pooledKey;
    if (key == null || key.isEmpty || _userPaused) {
      return;
    }
    await _activateAudibleIfNeeded();
    if (!mounted || _isDisposed || _pooledKey != key) {
      return;
    }
    if (!_pool.isActiveAudible(key)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _activateAudibleIfNeeded();
    }
  }

  Future<void> togglePlayPause() async {
    final key = _pooledKey;
    final player = _videoController?.player;
    if (key == null || player == null || _isDisposed) {
      return;
    }
    _iconHideTimer?.cancel();
    if (_userPaused) {
      _userPaused = false;
      _pool.clearUserPaused(key);
      _iconShowsPause = false;
      if (!player.state.playing) {
        try {
          await player.play();
        } catch (_) {}
      }
      await _pool.activateVisible(key);
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
        unawaited(_onFrameReady(player));
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
        unawaited(_onFrameReady(player));
        return;
      }
      _onPlayerStateTick(player);
    });
  }

  void _attachPlaybackListeners(Player player) {
    _playingSub?.cancel();
    _completedSub?.cancel();
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

  void _bindPlayer(Player player) {
    if (_videoController?.player == player) {
      return;
    }
    _videoController = VideoController(player);
    _videoSurfaceMounted = true;
  }

  Future<void> _attachPlayer(Player player) async {
    _bindPlayer(player);
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
    final key = _pooledKey;
    if (key == null) {
      return;
    }
    await _pool.prepareVisiblePlayback(key);
    if (!mounted || _isDisposed) {
      return;
    }
    _onPlayerStateTick(player);
    if (_canShowVideo(player)) {
      await _onFrameReady(player);
    } else {
      // Cached pool hit: frame already decoded — unmute after attach settles.
      await _activateAudibleIfNeeded();
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
      _pooledKey = _poolKey;

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

  Future<void> _openWithCandidates({
    required int generation,
    required String poolKey,
    required VoidCallback onFailure,
  }) async {
    final candidates = _resolver.resolveCandidates(
      hlsUrl: widget.hlsUrl,
      mp4Url: widget.videoUrl,
      qualityMp4Urls: widget.qualityMp4Urls,
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
        final pooled = await _pool.acquire(
          key: poolKey,
          sourceUrl: source.url,
          autoPlay: true,
        );
        if (!mounted || _isDisposed || generation != _playbackGeneration) {
          return;
        }
        await _attachPlayer(pooled.player);
        return;
      } catch (e) {
        _failedSourceUrls.add(source.url);
        debugPrint('ReelVideoPlayer source failed (${widget.videoId}): $e');
      }
    }
    onFailure();
  }

  Future<void> _switchVideo() async {
    if (_isDisposed || _isInitializing) {
      return;
    }
    final newKey = _poolKey;
    final generation = ++_playbackGeneration;
    _isInitializing = true;
    _resetFrameStateForKey(newKey);
    try {
      if (newKey.isEmpty) {
        return;
      }
      _detachAnalyticsAndListeners();
      _pooledKey = newKey;

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
            if (widget.blurThumbnailUrl != null &&
                widget.blurThumbnailUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.blurThumbnailUrl!,
                fit: BoxFit.cover,
                memCacheWidth: memW,
                memCacheHeight: memH,
                filterQuality: FilterQuality.low,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            if (widget.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: memW,
                memCacheHeight: memH,
                errorWidget: (context, url, error) {
                  final fallback = widget.posterFallbackUrl;
                  if (fallback == null ||
                      fallback.isEmpty ||
                      fallback == widget.thumbnailUrl) {
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
            if (_isInitializing &&
                !_showRetry &&
                !(_pooledKey != null && _pool.isFrameReady(_pooledKey!)))
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_videoSurfaceMounted && _videoController != null)
          RepaintBoundary(
            child: Video(
              key: const Key('reel_surface'),
              controller: _videoController!,
              fit: BoxFit.cover,
              controls: NoVideoControls,
            ),
          )
        else
          const ColoredBox(color: Colors.black),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showThumbnail ? 1.0 : 0.0,
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
