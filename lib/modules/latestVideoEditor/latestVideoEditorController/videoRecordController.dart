import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../basicVideoEditor/basicVideoEditor.dart'; // Add this dependency

class VideoRecordController {
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isRecording = false;
  int selectedDuration = 15;
  String? videoPath;
  final VoidCallback onStateChanged;
  final AnimationController animationController;
  late Animation<double> timerAnimation;

  VideoRecordController({
    required this.onStateChanged,
    required this.animationController,
  }) {
    timerAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(animationController);
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        print('No cameras available');
        return;
      }
      cameraController = CameraController(
        cameras![0],
        ResolutionPreset.medium,
        enableAudio: true,
        fps: 30,
      );
      await cameraController!.initialize();
      onStateChanged();
      print('Camera initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> startRecording() async {
    if (cameraController != null && !isRecording) {
      await cameraController!.startVideoRecording();
      isRecording = true;
      animationController.reset();
      animationController.forward();
      onStateChanged();

      await Future.delayed(Duration(seconds: selectedDuration));
      if (isRecording) stopRecording();
    }
  }

  Future<void> stopRecording() async {
    if (cameraController != null && isRecording) {
      final XFile video = await cameraController!.stopVideoRecording();
      animationController.stop();
      isRecording = false;
      videoPath = video.path;
      onStateChanged();

      // Directly navigate to preview screen with raw video file
      final File videoFile = File(video.path);
      if (videoFile.existsSync()) {
        print('Navigating to preview with raw video: ${videoFile.path}');
        Get.to(() => VideoTextEditor(videoFile: videoFile));
      } else {
        print('Recorded video file not found');
        Get.snackbar(
          'Error',
          'Failed to access recorded video',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> pauseRecording() async {
    if (cameraController != null && isRecording) {
      await cameraController!.pauseVideoRecording();
      animationController.stop();
      onStateChanged();
      print('Recording paused');
    }
  }

  Future<void> resumeRecording() async {
    if (cameraController != null && isRecording) {
      await cameraController!.resumeVideoRecording();
      animationController.forward();
      onStateChanged();
      print('Recording resumed');
    }
  }

  void flipCamera() async {
    if (cameraController != null && !isRecording) {
      final newCamera =
          cameras![cameraController!.description == cameras![0] ? 1 : 0];
      await cameraController!.dispose();
      cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: true,
        fps: 30,
      );
      await cameraController!.initialize();
      onStateChanged();
    }
  }

  void updateTimerDuration() {
    animationController.duration = Duration(seconds: selectedDuration);
  }

  void dispose() {
    cameraController?.dispose();
    animationController.dispose();
  }
}
