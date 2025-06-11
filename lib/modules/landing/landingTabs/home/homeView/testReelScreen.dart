import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

class TestReelScreen extends StatefulWidget {
  @override
  _TestReelScreenState createState() => _TestReelScreenState();
}

class _TestReelScreenState extends State<TestReelScreen> {
  late PageController _pageController;
  List<VideoPlayerController> _videoControllers = [];
  int _currentPage = 0;

  // Sample video data (replace with your actual data source)
  final List<Map<String, String>> _videoData = [
    {
      'videoUrl': 'https://cookster.org/storage/videos/17436730341.mp4',
      'title': 'Big Buck Bunny',
      'userName': 'User1',
    },
    {
      'videoUrl': 'https://cookster.org/storage/videos/17436730341.mp4',
      'title': 'Nature Adventure',
      'userName': 'User2',
    },
    {
      'videoUrl': 'https://cookster.org/storage/videos/17436730341.mp4',
      'title': 'Cooking Tutorial',
      'userName': 'User3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeVideoControllers();
  }

  Future<void> _initializeVideoControllers() async {
    for (var video in _videoData) {
      final controller = VideoPlayerController.network(
        video['videoUrl']!,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _videoControllers.add(controller);
      await controller.initialize();
      controller.setLooping(true);

      // Preload video by seeking to end and back
      await controller.seekTo(controller.value.duration);
      await controller.seekTo(Duration.zero);

      if (_videoControllers.indexOf(controller) == _currentPage) {
        controller.play();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });

    // Pause all videos except the current one
    for (int i = 0; i < _videoControllers.length; i++) {
      if (i == index) {
        _videoControllers[i].play();
      } else {
        _videoControllers[i].pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _videoControllers.isEmpty
              ? Center(child: CircularProgressIndicator())
              : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videoData.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return VideoReelItem(
                    controller: _videoControllers[index],
                    title: _videoData[index]['title']!,
                    userName: _videoData[index]['userName']!,
                    isPlaying: _currentPage == index,
                  );
                },
              ),
    );
  }
}

class VideoReelItem extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final String userName;
  final bool isPlaying;

  VideoReelItem({
    required this.controller,
    required this.title,
    required this.userName,
    required this.isPlaying,
  });

  @override
  _VideoReelItemState createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem> {
  bool _showPlayPauseIcon = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        // Video Player
        GestureDetector(
          onTap: _togglePlayPause,
          child: SizedBox.expand(
            child:
                widget.controller.value.isInitialized
                    ? VideoPlayer(widget.controller)
                    : Center(child: CircularProgressIndicator()),
          ),
        ),

        // Play/Pause Icon
        if (_showPlayPauseIcon && widget.controller.value.isInitialized)
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(8),
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 64.0,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),

        // Video Info
        Positioned(
          bottom: 20.h,
          left: 10.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                widget.title,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Progress Bar
        Positioned(
          bottom: 0,
          child: VideoProgressBar(controller: widget.controller),
        ),
      ],
    );
  }

  void _togglePlayPause() {
    setState(() {
      _showPlayPauseIcon = true;
      if (widget.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });

    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }
}

class VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  VideoProgressBar({required this.controller});

  @override
  _VideoProgressBarState createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double _progress = 0.0;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (widget.controller.value.isInitialized && mounted) {
        setState(() {
          _progress =
              widget.controller.value.position.inMilliseconds /
              widget.controller.value.duration.inMilliseconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 5.h,
      child: LinearProgressIndicator(
        value: _progress.clamp(0.0, 1.0),
        backgroundColor: Colors.grey.withOpacity(0.5),
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
