import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/video/video_analytics_tracker.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:flutter/material.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoPlay;
  final dynamic isImage;
  final VoidCallback? onTap; // Added onTap parameter
  final String? videoId;
  final String? hlsUrl;
  final ValueChanged<VideoPlayerController>? onVideoControllerReady;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isImage,
    this.autoPlay = true,
    this.onTap, // Added onTap parameter
    this.videoId,
    this.hlsUrl,
    this.onVideoControllerReady,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  final VideoPlayerPool _pool = VideoPlayerPool.instance;
  final VideoSourceResolver _resolver = const VideoSourceResolver();
  final VideoAnalyticsTracker _analyticsTracker = VideoAnalyticsTracker();
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _showIcon = false;
  bool _isDisposed = false; // Track disposal state
  String? _pooledKey;
  double _videoAspectRatio = 9 / 16;

  // Heart animation variables
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeart = false;
  Offset _heartPosition = Offset.zero;
  int _colorIndex = 0;

  // List of heart colors to cycle through
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


  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _initializeHeartAnimation();
  }

  void _initializeHeartAnimation() {
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut,
    ));

    _heartOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeart = false;
        });
        _heartAnimationController.reset();
      }
    });
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final candidates = _resolver.resolveCandidates(
        hlsUrl: widget.hlsUrl,
        mp4Url: widget.videoUrl,
      );
      if (candidates.isEmpty) {
        return;
      }
      final source = candidates.first;
      _pooledKey = widget.videoId ?? widget.videoUrl;
      final pooled = await _pool.acquire(
        key: _pooledKey!,
        sourceUrl: source.url,
        autoPlay: false,
      );
      if (!mounted || _isDisposed) {
        if (_pooledKey != null) {
          await _pool.release(_pooledKey!);
        }
        return;
      }
      _videoPlayerController = pooled.controller;
      final value = _videoPlayerController.value;
      if (value.isInitialized && value.aspectRatio > 0) {
        _videoAspectRatio = value.aspectRatio;
      }
      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            isLive: true,
            videoPlayerController: _videoPlayerController,
            aspectRatio: _videoAspectRatio,
            autoPlay: widget.autoPlay,
            looping: true,
            allowFullScreen: true,
            showControls: false,
            errorBuilder: (context, errorMessage) {
              return const Center(
                child: Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            },
          );
          _isInitialized = true;
        });
        widget.onVideoControllerReady?.call(_videoPlayerController);
        _analyticsTracker.attach(
          videoId: widget.videoId ?? widget.videoUrl,
          controller: _videoPlayerController,
        );
        if (widget.autoPlay && _pooledKey != null) {
          await _pool.setActive(_pooledKey!);
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    if (_isInitialized &&
        _chewieController != null &&
        !_isDisposed &&
        mounted) {
      setState(() {
        _showIcon = true;
        if (_chewieController!.isPlaying) {
          _chewieController!.pause();
        } else {
          final pooledKey = _pooledKey;
          if (pooledKey != null) {
            _pool.setActive(pooledKey);
          } else {
            _chewieController!.play();
          }
        }
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showIcon = false;
          });
        }
      });
    }
  }

  void _onDoubleTap(TapDownDetails details) {
    // Get the tap position
    setState(() {
      _heartPosition = details.localPosition;
      _showHeart = true;
    });

    // Start heart animation
    _heartAnimationController.forward();

    // Call the original onTap callback if provided
    widget.onTap?.call();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized || _isDisposed) return;
    final pooledKey = _pooledKey;
    if (pooledKey == null) return;

    if (widget.autoPlay && !oldWidget.autoPlay) {
      _pool.setActive(pooledKey);
    } else if (!widget.autoPlay && oldWidget.autoPlay) {
      _pool.pause(pooledKey);
      _videoPlayerController.setVolume(0.0);
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Set disposal flag
    _analyticsTracker.markSkippedIfNeeded();
    _chewieController?.pause(); // Pause before disposing
    _chewieController?.dispose();
    final pooledKey = _pooledKey;
    if (pooledKey != null) {
      _pool.release(pooledKey);
    }
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color _currentHeartColor = _heartColors[Random().nextInt(_heartColors.length)];

    return FocusDetector(
      onFocusLost: () {
        if (_isInitialized &&
            _chewieController != null &&
            !_isDisposed &&
            mounted) {
          _chewieController!.pause();
        }
      },
      onFocusGained: () {
        if (_isInitialized &&
            _chewieController != null &&
            !_isDisposed &&
            mounted) {
          if (widget.autoPlay) {
            final pooledKey = _pooledKey;
            if (pooledKey != null) {
              _pool.setActive(pooledKey);
            } else {
              _chewieController!.play();
            }
          }
        }
      },
      onVisibilityLost: () {},
      onVisibilityGained: () {},
      onForegroundLost: () {},
      onForegroundGained: () {},
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTapDown: _onDoubleTap,
            onTap: _togglePlayPause,
            child: AspectRatio(
              aspectRatio: _videoAspectRatio,
              child: _isInitialized && _chewieController != null
                  ? RepaintBoundary(
                      child: Chewie(controller: _chewieController!),
                    )
                  : Shimmer.fromColors(
                      baseColor: Colors.grey.shade800,
                      highlightColor: Colors.grey.shade600,
                      child: Container(
                        color: Colors.black,
                        width: double.infinity,
                        height: double.infinity,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // Play/Pause Icon
          if (_showIcon && _isInitialized && _chewieController != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                _chewieController!.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 64.0,
                color: Colors.white.withOpacity(0.7),
              ),
            ),

          // Heart Animation
          if (_showHeart)
            Positioned(
              left: _heartPosition.dx - 30, // Center the heart on tap position
              top: _heartPosition.dy - 30,
              child: AnimatedBuilder(
                animation: _heartAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartScaleAnimation.value,
                    child: Opacity(
                      opacity: _heartOpacityAnimation.value,
                      child: Icon(
                        Icons.favorite,
                        color: _currentHeartColor,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Lightweight progress indicator to reduce rebuild lag.
          if (_isInitialized &&
              _chewieController != null &&
              widget.isImage == 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
                child: VideoProgressIndicator(
                  _chewieController!.videoPlayerController,
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
      ),
    );
  }
}