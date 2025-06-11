import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import '../latestVideoEditorController/videoRecordController.dart';

class VideoRecordScreen extends StatefulWidget {
  @override
  _VideoRecordScreenState createState() => _VideoRecordScreenState();
}

class _VideoRecordScreenState extends State<VideoRecordScreen>
    with SingleTickerProviderStateMixin {
  late VideoRecordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoRecordController(
      onStateChanged: () => setState(() {}),
      animationController: AnimationController(
        vsync: this,
        duration: Duration(seconds: 15),
      ),
    );
    _controller
        .initializeCamera()
        .then((_) {
          setState(() {});
        })
        .catchError((e) {
          print("Camera initialization error: $e");
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.cameraController == null ||
        !_controller.cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Camera Preview
          Center(child: CameraPreview(_controller.cameraController!)),
          // Bottom Duration Buttons
          Positioned(
            left: 10,
            bottom: 100,
            child: Row(
              children: [
                _durationButton(15),
                SizedBox(width: 10),
                _durationButton(30),
              ],
            ),
          ),
          // Bottom Record Button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap:
                      _controller.isRecording
                          ? _controller.stopRecording
                          : _controller.startRecording,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_controller.isRecording)
                        AnimatedBuilder(
                          animation: _controller.timerAnimation,
                          builder: (context, child) {
                            return SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: _controller.timerAnimation.value,
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation(Colors.red),
                              ),
                            );
                          },
                        ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Duration Button Widget
  Widget _durationButton(int duration) {
    return GestureDetector(
      onTap: () {
        if (!_controller.isRecording) {
          setState(() {
            _controller.selectedDuration = duration;
            _controller.updateTimerDuration();
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color:
              _controller.selectedDuration == duration
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${duration}s',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
