import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  _VideoRecorderScreenState createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  String? _videoPath;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
      );
      setState(() {
        _initializeControllerFuture = _controller.initialize();
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _recordVideo() async {
    try {
      if (_initializeControllerFuture == null) return;
      await _initializeControllerFuture;

      if (_controller.value.isRecordingVideo) {
        final XFile video = await _controller.stopVideoRecording();
        setState(() {
          _videoPath = video.path;
          _videoPlayerController = VideoPlayerController.file(File(_videoPath!))
            ..initialize().then((_) {
              setState(() {});
              _videoPlayerController!.play();
            });
        });
      } else {
        await _controller.startVideoRecording();
        setState(() {});
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Recorder')),
      body: Column(
        children: [
          Expanded(
            child: _videoPath == null
                ? (_initializeControllerFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(
                      child: CircularProgressIndicator());
                }
              },
            ))
                : _videoPlayerController != null &&
                _videoPlayerController!.value.isInitialized
                ? Center(
              child: AspectRatio(
                aspectRatio:
                _videoPlayerController!.value.aspectRatio,
                child: ClipRect(
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            )
                : Container(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _recordVideo,
              child: Text(
                _controller.value.isRecordingVideo
                    ? 'Stop Recording'
                    : _videoPath == null
                    ? 'Start Recording'
                    : 'Record New Video',
              ),
            ),
          ),
          const SizedBox(height: 30),
          if (_videoPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _videoPath = null;
                    _videoPlayerController?.dispose();
                    _videoPlayerController = null;
                  });
                },
                child: const Text('Clear Video'),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(home: VideoRecorderScreen()));
}