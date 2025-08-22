import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoPlay;
  final dynamic isImage;
  final VoidCallback? onTap; // Added onTap parameter

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isImage,
    this.autoPlay = true,
    this.onTap, // Added onTap parameter
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _showIcon = false;
  bool _isDisposed = false; // Track disposal state

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
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    try {
      await _videoPlayerController.initialize();
      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            isLive: true,
            videoPlayerController: _videoPlayerController,
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
          _chewieController!.play();
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
  void dispose() {
    _isDisposed = true; // Set disposal flag
    _chewieController?.pause(); // Pause before disposing
    _chewieController?.dispose();
    _videoPlayerController.dispose();
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
          print('Focus Lost: Video paused.');
        }
      },
      onFocusGained: () {
        if (_isInitialized &&
            _chewieController != null &&
            !_isDisposed &&
            mounted) {
          if (widget.autoPlay) {
            _chewieController!.play();
            print('Focus Gained: Video playing.');
          }
        }
      },
      onVisibilityLost: () {
        print('Visibility Lost.');
      },
      onVisibilityGained: () {
        print('Visibility Gained.');
      },
      onForegroundLost: () {
        print('Foreground Lost.');
      },
      onForegroundGained: () {
        print('Foreground Gained.');
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTapDown: _onDoubleTap,
            onTap: _togglePlayPause,
            child: _isInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : Container(
              color: Colors.black,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl,
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

          // Video Progress Slider
          if (_isInitialized &&
              _chewieController != null &&
              widget.isImage == 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return StreamBuilder<Duration>(
                    stream: _isDisposed
                        ? null
                        : Stream.periodic(
                      const Duration(milliseconds: 200),
                          (_) => _chewieController!
                          .videoPlayerController.value.position,
                    ),
                    builder: (context, snapshot) {
                      if (_isDisposed ||
                          !_isInitialized ||
                          _chewieController == null) {
                        return Slider(
                          value: 0,
                          max: 1,
                          onChanged: null,
                          thumbColor: ColorUtils.primaryColor,
                          activeColor: ColorUtils.primaryColor,
                          inactiveColor: Colors.grey,
                        );
                      }
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _chewieController!
                          .videoPlayerController.value.duration ??
                          Duration.zero;
                      final isInitialized = _chewieController!
                          .videoPlayerController.value.isInitialized;

                      if (!isInitialized || duration == Duration.zero) {
                        return Slider(
                          value: 0,
                          max: 1,
                          onChanged: null,
                          thumbColor: ColorUtils.primaryColor,
                          activeColor: ColorUtils.primaryColor,
                          inactiveColor: Colors.grey,
                        );
                      }

                      return SliderTheme(
                        data: SliderThemeData(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 0,
                          ),
                          trackHeight: 2,
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble(),
                          max: duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            if (!_isDisposed && mounted) {
                              _chewieController!.seekTo(
                                Duration(seconds: value.toInt()),
                              );
                            }
                          },
                          thumbColor: ColorUtils.primaryColor,
                          activeColor: ColorUtils.primaryColor,
                          inactiveColor: Colors.grey,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}