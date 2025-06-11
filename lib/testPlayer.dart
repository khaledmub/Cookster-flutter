import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'appUtils/apiEndPoints.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    try {
      String fullUrl = '${Common.videoUrl}/${widget.videoUrl}';
      print('Loading video from: $fullUrl');

      _videoPlayerController = VideoPlayerController.network(fullUrl);
      await _videoPlayerController.initialize().timeout(Duration(seconds: 30));

      print('Video initialized: ${_videoPlayerController.value.isInitialized}');
      print('Video duration: ${_videoPlayerController.value.duration}');
      print('Video size: ${_videoPlayerController.value.size}');

      if (!_videoPlayerController.value.isInitialized) {
        throw Exception('Video failed to initialize');
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Video Error: $errorMessage',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      _videoPlayerController.addListener(() {
        if (_videoPlayerController.value.hasError) {
          setState(() {
            errorMessage = _videoPlayerController.value.errorDescription;
          });
          print('Playback error: ${errorMessage}');
        }
      });

      setState(() {});
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        errorMessage = e.toString();
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
    return Scaffold(
      appBar: AppBar(title: Text('Chewie Video Player')),
      body: Center(
        child:
            errorMessage != null
                ? Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Error: $errorMessage',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
                : _chewieController != null &&
                    _videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Loading Video...'),
                  ],
                ),
      ),
    );
  }
}
