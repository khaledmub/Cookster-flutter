import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoPlay;
  final dynamic isImage;
  final VoidCallback? onTap;
  final String? videoId;
  final String? hlsUrl;
  final List<String> qualityMp4Urls;
  final bool useMediaKit;
  final bool fillScreen;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPlaybackReady;
  /// Stable pool key for feeds (e.g. reels) so the decoder is reused across swipes.
  final String? playerPoolKey;
  /// When true, video paints but does not capture pointers (PageView scroll + chrome).
  final bool passThroughPointers;
  /// Reels: solid black while buffering — no low-res API thumbnail flash.
  final bool hideThumbnail;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isImage,
    this.autoPlay = true,
    this.onTap,
    this.videoId,
    this.hlsUrl,
    this.qualityMp4Urls = const [],
    this.useMediaKit = true,
    this.fillScreen = false,
    this.onVideoCompleted,
    this.onPlaybackReady,
    this.playerPoolKey,
    this.passThroughPointers = false,
    this.hideThumbnail = false,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  final VideoSourceResolver _resolver = const VideoSourceResolver();
  final VideoPlayerPool _legacyPool = VideoPlayerPool.instance;
  final MediaKitPlayerPool _mediaKitPool = MediaKitPlayerPool.instance;
  final VideoAnalyticsTracker _analyticsTracker = VideoAnalyticsTracker();

  VideoPlayerController? _legacyController;
  VideoController? _mediaKitVideoController;
  bool _isInitialized = false;
  bool _showIcon = false;
  bool _isDisposed = false;
  String? _pooledKey;
  double _videoAspectRatio = 9 / 16;
  StreamSubscription<bool>? _mediaKitPlayingSub;
  StreamSubscription<bool>? _mediaKitCompletedSub;
  VoidCallback? _legacyCompletionListener;
  bool _userPaused = false;
  bool _completionNotified = false;
  bool _videoFrameVisible = false;

  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeart = false;
  Offset _heartPosition = Offset.zero;
  late final Color _heartColor;
  int _candidateIndex = 0;
  final Set<String> _failedSourceUrls = <String>{};

  final List<Color> _heartColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.deepOrange,
    Colors.yellow,
    Colors.amber,
    Colors.lime,
  ];

  bool get _isPlaying {
    if (!_isInitialized || _isDisposed || !widget.autoPlay) {
      return false;
    }
    if (widget.useMediaKit) {
      return _mediaKitVideoController?.player.state.playing ?? false;
    }
    return _legacyController?.value.isPlaying ?? false;
  }

  bool _isInitializing = false;
  int _playbackGeneration = 0;
  int _frameWaitGeneration = 0;
  bool _mediaKitSurfaceReady = false;

  String get _poolKey =>
      widget.playerPoolKey ?? widget.videoId ?? widget.videoUrl;

  bool _hasRenderableFrame(Player player) {
    final width = player.state.width ?? 0;
    final height = player.state.height ?? 0;
    if (width <= 0 || height <= 0) {
      return false;
    }
    final key = _pooledKey;
    if (key != null && _mediaKitPool.isFrameReady(key)) {
      return true;
    }
    return player.state.position > const Duration(milliseconds: 32);
  }

  /// Best-effort wait for decoder metadata. Never throws — blocking here used
  /// to stall attach for 12s while the pool had already started audio.
  Future<void> _primeVideoDimensions(Player player) async {
    const maxWait = Duration(milliseconds: 400);
    const step = Duration(milliseconds: 16);
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      final width = player.state.width ?? 0;
      final height = player.state.height ?? 0;
      if (width > 0 && height > 0) {
        _videoAspectRatio = width / height;
        return;
      }
      await Future<void>.delayed(step);
    }
  }

  Future<void> _markVideoFrameVisible(Player player) async {
    if (_videoFrameVisible || !mounted || _isDisposed) {
      return;
    }
    _videoFrameVisible = true;
    final key = _pooledKey;
    if (key != null) {
      await _mediaKitPool.unmuteAndPlay(key);
    }
    widget.onPlaybackReady?.call();
    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  Future<void> _scheduleVideoFrameVisible(Player player) async {
    final gen = ++_frameWaitGeneration;
    if (_videoFrameVisible || !mounted || _isDisposed) {
      return;
    }

    if (_hasRenderableFrame(player)) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && !_isDisposed && gen == _frameWaitGeneration) {
        await _markVideoFrameVisible(player);
      }
      return;
    }

    final completer = Completer<void>();
    StreamSubscription<Duration>? positionSub;
    Timer? giveUp;

    void checkFrame() {
      if (completer.isCompleted) {
        return;
      }
      if (!mounted || _isDisposed || gen != _frameWaitGeneration) {
        completer.complete();
        return;
      }
      if (_hasRenderableFrame(player)) {
        completer.complete();
      }
    }

    positionSub = player.stream.position.listen((_) => checkFrame());
    giveUp = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    await positionSub.cancel();
    giveUp.cancel();

    if (!mounted || _isDisposed || gen != _frameWaitGeneration) {
      return;
    }
    if (_hasRenderableFrame(player)) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && !_isDisposed && gen == _frameWaitGeneration) {
        await _markVideoFrameVisible(player);
      }
    }
  }

  void _notifyCompleted() {
    if (_completionNotified || !widget.autoPlay || _userPaused) {
      return;
    }
    _completionNotified = true;
    widget.onVideoCompleted?.call();
  }

  void _attachMediaKitPlaybackListeners(Player player) {
    _mediaKitCompletedSub?.cancel();
    _mediaKitPlayingSub?.cancel();
    _completionNotified = false;

    _mediaKitCompletedSub = player.stream.completed.listen((completed) {
      if (completed && mounted && !_isDisposed && !_userPaused) {
        _notifyCompleted();
      }
    });
    _mediaKitPlayingSub = player.stream.playing.listen((playing) {
      if (playing && mounted && !_isDisposed) {
        unawaited(_scheduleVideoFrameVisible(player));
      } else if (!playing && mounted && !_isDisposed && _userPaused) {
        _videoFrameVisible = false;
        setState(() {});
      }
    });
  }

  void _attachLegacyCompletionListener(VideoPlayerController controller) {
    _legacyCompletionListener?.call();
    void listener() {
      if (!controller.value.isInitialized || _userPaused) {
        return;
      }
      final duration = controller.value.duration;
      if (duration <= Duration.zero) {
        return;
      }
      if (controller.value.position >= duration - const Duration(milliseconds: 300)) {
        _notifyCompleted();
      }
    }
    controller.addListener(listener);
    _legacyCompletionListener = () => controller.removeListener(listener);
  }

  void _detachPlaybackListeners() {
    _mediaKitCompletedSub?.cancel();
    _mediaKitCompletedSub = null;
    _mediaKitPlayingSub?.cancel();
    _mediaKitPlayingSub = null;
    _legacyCompletionListener?.call();
    _legacyCompletionListener = null;
  }

  void _detachMediaKitSurfaceSync() {
    _detachPlaybackListeners();
    _mediaKitSurfaceReady = false;
    _mediaKitVideoController = null;
    _isInitialized = false;
    _videoFrameVisible = false;
    _completionNotified = false;
    _userPaused = false;
  }

  Future<void> _attachMediaKitSurface(Player player, {String? videoId}) async {
    _mediaKitVideoController = VideoController(player);
    final analyticsId = videoId ?? widget.videoId;
    if (analyticsId != null && analyticsId.isNotEmpty) {
      _analyticsTracker.attachMediaKit(videoId: analyticsId, player: player);
    }
    _attachMediaKitPlaybackListeners(player);
    _mediaKitSurfaceReady = true;
    if (mounted && !_isDisposed) {
      setState(() => _isInitialized = true);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _isDisposed) {
      return;
    }
    unawaited(_primeVideoDimensions(player));
    await _startMediaKitPlayback(fastPath: _canSkipToFrame(player));
  }

  bool _canSkipToFrame(Player player) {
    final key = _pooledKey;
    if (key != null && key.isNotEmpty && _mediaKitPool.isFrameReady(key)) {
      return true;
    }
    return _hasRenderableFrame(player);
  }

  Future<void> _startMediaKitPlayback({bool fastPath = false}) async {
    if (!widget.autoPlay || _isDisposed || !mounted) {
      return;
    }
    final key = _pooledKey;
    if (key == null) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _isDisposed || !widget.autoPlay) {
      return;
    }
    await _mediaKitPool.setActive(key);
    if (!mounted || _isDisposed) {
      return;
    }
    final player = _mediaKitVideoController?.player;
    if (player == null) {
      return;
    }
    if (fastPath && _hasRenderableFrame(player)) {
      await _markVideoFrameVisible(player);
      return;
    }
    unawaited(_scheduleVideoFrameVisible(player));
  }

  bool get _shouldShowVideoSurface =>
      widget.autoPlay &&
      _isInitialized &&
      !_isDisposed &&
      ((widget.useMediaKit &&
              _mediaKitSurfaceReady &&
              _mediaKitVideoController != null) ||
          (!widget.useMediaKit && _legacyController != null));

  @override
  void initState() {
    super.initState();
    _heartColor = _heartColors[Random().nextInt(_heartColors.length)];
    _initializeHeartAnimation();
    if (widget.autoPlay) {
      _initializeVideoPlayer();
    }
  }

  void _initializeHeartAnimation() {
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _heartScaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeart = false);
        _heartAnimationController.reset();
      }
    });
  }

  Future<void> _initializeVideoPlayer() async {
    if (_isDisposed || !widget.autoPlay || _isInitializing) {
      return;
    }
    final generation = ++_playbackGeneration;
    _isInitializing = true;
    try {
    final candidates = _resolver.resolveCandidates(
      hlsUrl: widget.hlsUrl,
      mp4Url: widget.videoUrl,
      qualityMp4Urls: widget.qualityMp4Urls,
    );
    if (candidates.isEmpty) return;

    _pooledKey = _poolKey;
    for (var i = 0; i < candidates.length; i++) {
      final source = candidates[i];
      if (_failedSourceUrls.contains(source.url)) continue;
      try {
        await _initWithSource(source.url);
        _candidateIndex = i;
        if (!mounted ||
            _isDisposed ||
            generation != _playbackGeneration ||
            !widget.autoPlay) {
          return;
        }
        if (!widget.autoPlay) {
          await _releaseCurrentPlayer();
          return;
        }
        if (!widget.useMediaKit) {
          setState(() => _isInitialized = true);
        }
        return;
      } catch (e) {
        _failedSourceUrls.add(source.url);
        debugPrint('Video source failed (${source.type}): $e');
        await _releaseCurrentPlayer();
      }
    }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _releaseCurrentPlayer() async {
    final generation = ++_playbackGeneration;
    final key = _pooledKey;
    _mediaKitPlayingSub?.cancel();
    _mediaKitPlayingSub = null;
    _detachPlaybackListeners();
    _analyticsTracker.detach();

    // Drop the video surface synchronously so we never paint into a disposed
    // MediaKit output while the pool release runs asynchronously.
    if (mounted && !_isDisposed) {
      setState(() {
        _detachMediaKitSurfaceSync();
        _legacyController = null;
        _pooledKey = null;
      });
    } else {
      _detachMediaKitSurfaceSync();
      _legacyController = null;
      _pooledKey = null;
    }

    await WidgetsBinding.instance.endOfFrame;

    if (key == null) {
      return;
    }
    if (widget.useMediaKit) {
      await _mediaKitPool.release(key);
    } else {
      await _legacyPool.release(key);
    }
    if (generation != _playbackGeneration) {
      return;
    }
  }

  Future<void> _initWithSource(String sourceUrl) async {
    final key = _pooledKey ?? _poolKey;
    if (key.isEmpty) {
      throw StateError('Missing video pool key');
    }
    _pooledKey = key;

    if (widget.useMediaKit) {
      // Pool.acquire honors widget.autoPlay AND pool._activeKey so the page
      // change handler (or initializeVideoPlayer's reconciliation) doesn't
      // race with us here.
      final pooled = await _mediaKitPool.acquire(
        key: key,
        sourceUrl: sourceUrl,
        autoPlay: false,
      );
      if (!mounted || _isDisposed) {
        await _mediaKitPool.release(key);
        return;
      }
      await _attachMediaKitSurface(pooled.player);
      if (!mounted || _isDisposed) {
        await _mediaKitPool.release(key);
        return;
      }
    } else {
      final pooled = await _legacyPool.acquire(
        key: key,
        sourceUrl: sourceUrl,
        autoPlay: widget.autoPlay,
      );
      if (!mounted || _isDisposed) {
        await _legacyPool.release(key);
        return;
      }
      _legacyController = pooled.controller;
      final value = _legacyController!.value;
      if (value.isInitialized && value.aspectRatio > 0) {
        _videoAspectRatio = value.aspectRatio;
      }
      if (widget.videoId != null && widget.videoId!.isNotEmpty) {
        _analyticsTracker.attach(
          videoId: widget.videoId!,
          controller: _legacyController!,
        );
      }
      _attachLegacyCompletionListener(_legacyController!);
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_isInitialized || _isDisposed || !mounted) {
      return;
    }
    setState(() => _showIcon = true);
    final key = _pooledKey;
    if (key == null) {
      return;
    }
    if (_isPlaying) {
      _userPaused = true;
      if (widget.useMediaKit) {
        await _mediaKitPool.pause(key);
      } else {
        await _legacyPool.pause(key);
      }
    } else {
      _userPaused = false;
      _completionNotified = false;
      if (widget.useMediaKit) {
        await _mediaKitPool.setActive(key);
      } else {
        await _legacyPool.setActive(key);
      }
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showIcon = false);
      }
    });
  }

  void _onDoubleTap(TapDownDetails details) {
    setState(() {
      _heartPosition = details.localPosition;
      _showHeart = true;
    });
    _heartAnimationController.forward();
    widget.onTap?.call();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final videoChanged = widget.videoId != oldWidget.videoId ||
        widget.videoUrl != oldWidget.videoUrl ||
        widget.hlsUrl != oldWidget.hlsUrl;

    if (videoChanged) {
      _failedSourceUrls.clear();
      if (widget.autoPlay) {
        unawaited(_switchToVideo());
      } else {
        unawaited(_releaseCurrentPlayer());
      }
      return;
    }

    if (widget.autoPlay && !oldWidget.autoPlay) {
      if (!_isInitialized && !_isDisposed) {
        unawaited(_initializeVideoPlayer());
      } else if (_isInitialized) {
        final key = _pooledKey;
        if (key != null) {
          if (widget.useMediaKit) {
            unawaited(_mediaKitPool.setActive(key));
          } else {
            unawaited(_legacyPool.setActive(key));
          }
        }
      }
      return;
    }

    if (!widget.autoPlay && oldWidget.autoPlay) {
      unawaited(_releaseCurrentPlayer());
      return;
    }
  }

  Future<void> _switchToVideo() async {
    if (_isDisposed || !widget.autoPlay || _isInitializing) {
      return;
    }
    final generation = ++_playbackGeneration;
    _isInitializing = true;
    _videoFrameVisible = false;
    _frameWaitGeneration++;
    _completionNotified = false;
    final previousKey = _pooledKey;
    final newKey = _poolKey;
    if (newKey.isEmpty) {
      _isInitializing = false;
      return;
    }
    try {
      // Silence the outgoing reel before opening/priming the next (pool work can take seconds).
      await _mediaKitPool.pauseAll();
      _detachPlaybackListeners();
      _analyticsTracker.detach();

      final candidates = _resolver.resolveCandidates(
        hlsUrl: widget.hlsUrl,
        mp4Url: widget.videoUrl,
        qualityMp4Urls: widget.qualityMp4Urls,
      );
      if (candidates.isEmpty) {
        return;
      }

      _pooledKey = newKey;

      for (var i = 0; i < candidates.length; i++) {
        final source = candidates[i];
        if (_failedSourceUrls.contains(source.url)) {
          continue;
        }
        try {
          if (widget.useMediaKit) {
            final pooled = await _mediaKitPool.acquire(
              key: newKey,
              sourceUrl: source.url,
              autoPlay: false,
            );
            if (!mounted || _isDisposed || generation != _playbackGeneration) {
              return;
            }

            final samePlayer = _mediaKitVideoController?.player == pooled.player;
            if (!samePlayer) {
              if (mounted && !_isDisposed) {
                setState(_detachMediaKitSurfaceSync);
              } else {
                _detachMediaKitSurfaceSync();
              }
              await WidgetsBinding.instance.endOfFrame;
              await _attachMediaKitSurface(
                pooled.player,
                videoId: widget.videoId,
              );
            } else {
              final analyticsId = widget.videoId;
              if (analyticsId != null && analyticsId.isNotEmpty) {
                _analyticsTracker.attachMediaKit(
                  videoId: analyticsId,
                  player: pooled.player,
                );
              }
              _attachMediaKitPlaybackListeners(pooled.player);
              _mediaKitSurfaceReady = true;
              _isInitialized = true;
              if (mounted) {
                setState(() {});
              }
              await WidgetsBinding.instance.endOfFrame;
              if (!mounted ||
                  _isDisposed ||
                  generation != _playbackGeneration) {
                return;
              }
              await _startMediaKitPlayback(
                fastPath: _canSkipToFrame(pooled.player),
              );
            }

            if (previousKey != null &&
                previousKey != newKey &&
                previousKey.isNotEmpty) {
              unawaited(_mediaKitPool.release(previousKey));
            }

            if (!mounted || _isDisposed || generation != _playbackGeneration) {
              return;
            }
          } else {
            await _releaseCurrentPlayer();
            await _initWithSource(source.url);
          }
          _candidateIndex = i;
          if (!mounted ||
              _isDisposed ||
              generation != _playbackGeneration ||
              !widget.autoPlay) {
            return;
          }
          if (!widget.useMediaKit) {
            setState(() => _isInitialized = true);
          }
          return;
        } catch (e) {
          _failedSourceUrls.add(source.url);
          debugPrint(
            'Video source failed (${widget.videoId}, ${source.type}): $e',
          );
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playbackGeneration++;
    _detachPlaybackListeners();
    _analyticsTracker.detach();
    _detachMediaKitSurfaceSync();
    _legacyController = null;
    final key = _pooledKey;
    _pooledKey = null;
    if (key != null) {
      if (widget.useMediaKit) {
        unawaited(_mediaKitPool.release(key));
      } else {
        unawaited(_legacyPool.release(key));
      }
    }
    _heartAnimationController.dispose();
    super.dispose();
  }

  Widget _buildVideoSurface() {
    if (!_shouldShowVideoSurface) {
      return _buildThumbnailPlaceholder(showSpinner: widget.autoPlay && !_isInitialized);
    }
    if (widget.useMediaKit && _mediaKitVideoController != null) {
      return RepaintBoundary(
        child: SizedBox.expand(
          child: Video(
            key: const ValueKey<String>('media_kit_surface'),
            controller: _mediaKitVideoController!,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),
        ),
      );
    }
    if (_legacyController != null) {
      return RepaintBoundary(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _legacyController!.value.size.width,
            height: _legacyController!.value.size.height,
            child: VideoPlayer(_legacyController!),
          ),
        ),
      );
    }
    return _buildThumbnailPlaceholder();
  }

  Widget _buildThumbnailPlaceholder({bool showSpinner = true}) {
    if (widget.hideThumbnail) {
      return Container(color: Colors.black);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final (memW, memH) = fullScreenPosterMemCacheSize(context);
        return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: CachedNetworkImage(
            imageUrl: widget.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: memW,
            memCacheHeight: memH,
            errorWidget: (context, url, error) => const SizedBox(),
          ),
        ),
        Container(
          color: Colors.black.withOpacity(0.3),
          child: showSpinner
              ? const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
      },
    );
  }

  Widget _buildVideoContent() {
    final surface = Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoSurface(),
        if (!_videoFrameVisible &&
            _isInitialized &&
            !widget.hideThumbnail)
          _buildThumbnailPlaceholder(showSpinner: false),
      ],
    );
  if (widget.fillScreen) {
      return SizedBox.expand(child: surface);
    }
    return AspectRatio(aspectRatio: _videoAspectRatio, child: surface);
  }

  Widget _wrapVideoGestures(Widget child) {
    if (widget.passThroughPointers) {
      return child;
    }
    return GestureDetector(
      onDoubleTapDown: _onDoubleTap,
      onTap: _togglePlayPause,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final heartColor = _heartColor;

    return Stack(
      alignment: Alignment.center,
      children: [
          if (widget.isImage == 1)
            _wrapVideoGestures(
              Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.videoUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (context, url, error) => const SizedBox(),
                  ),
                ),
              ),
            )
          else
            _wrapVideoGestures(
              widget.fillScreen
                  ? SizedBox.expand(child: _buildVideoContent())
                  : _buildVideoContent(),
            ),
          if (_showIcon && _isInitialized)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 64,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          if (_showHeart)
            Positioned(
              left: _heartPosition.dx - 30,
              top: _heartPosition.dy - 30,
              child: AnimatedBuilder(
                animation: _heartAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartScaleAnimation.value,
                    child: FadeTransition(
                      opacity: _heartOpacityAnimation,
                      child: Icon(Icons.favorite, color: heartColor, size: 60),
                    ),
                  );
                },
              ),
            ),
          if (_isInitialized && widget.isImage == 0 && !widget.useMediaKit)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
                child: VideoProgressIndicator(
                  _legacyController!,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: ColorUtils.primaryColor,
                    bufferedColor: Colors.grey.shade500,
                    backgroundColor: Colors.grey.shade800,
                  ),
                ),
              ),
            ),
        ],
      );
  }
}
