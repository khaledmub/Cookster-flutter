import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoPlay;
  final dynamic isImage;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isImage,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    try {
      await _videoPlayerController.initialize();
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: widget.autoPlay,
          looping: true,
          showControls: false,
          // Custom controls will be implemented
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'Error loading video',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          },
        );
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    if (_isInitialized && _chewieController != null) {
      setState(() {
        _showIcon = true;
        if (_chewieController!.isPlaying) {
          _chewieController!.pause();
        } else {
          _chewieController!.play();
        }
      });
      // Hide the play/pause icon after 1 second
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showIcon = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _togglePlayPause,
          child:
              _isInitialized && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(
                    color: Colors.black,
                    child: Center(
                      child: CachedNetworkImage(imageUrl: widget.thumbnailUrl),
                    ),
                  ),
        ),
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

        if (_isInitialized && _chewieController != null && widget.isImage == 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StatefulBuilder(
              builder: (context, setState) {
                bool isThumbTapped = false; // Track thumb interaction state

                return StreamBuilder<Duration>(
                  stream: Stream.periodic(
                    const Duration(milliseconds: 200),
                    (_) =>
                        _chewieController!.videoPlayerController.value.position,
                  ),
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration =
                        _chewieController!
                            .videoPlayerController
                            .value
                            .duration ??
                        Duration.zero;
                    final isInitialized =
                        _chewieController!
                            .videoPlayerController
                            .value
                            .isInitialized;

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
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: isThumbTapped ? 0.0 : 6.0,
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
                          _chewieController!.seekTo(
                            Duration(seconds: value.toInt()),
                          );
                        },
                        // onChangeStart: (_) {
                        //   setState(() {
                        //     isThumbTapped = true;
                        //   });
                        // },
                        // onChangeEnd: (_) {
                        //   setState(() {
                        //     isThumbTapped = false;
                        //   });
                        // },
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
    );
  }
}
