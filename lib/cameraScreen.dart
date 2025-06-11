import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

import 'basicVideoEditor/basicVideoEditor.dart';

class CameraControllerX extends GetxController {
  CameraController? cameraCtrl;
  RxBool isRecording = false.obs;
  RxBool isFlashOn = false.obs;
  RxInt selectedDuration = 15.obs; // Default 15s
  RxInt selectedCameraIndex = 0.obs;
  RxInt remainingTime = 15.obs;
  Rx<File?> recordedVideoFile = Rx<File?>(null);
  Timer? _timer;

  List<int> availableDurations = [10 * 60, 60, 15]; // 10m, 60s, 15s

  void initCamera(List<CameraDescription> cameras) {
    if (cameras.isNotEmpty) {
      cameraCtrl = CameraController(
        cameras[selectedCameraIndex.value],
        ResolutionPreset.high,
        enableAudio: true,
      );

      cameraCtrl!.initialize().then((_) {
        update();
      });
    }
  }

  void toggleFlash() {
    isFlashOn.value = !isFlashOn.value;
    cameraCtrl?.setFlashMode(isFlashOn.value ? FlashMode.torch : FlashMode.off);
    update();
  }

  void switchCamera(List<CameraDescription> cameras) {
    selectedCameraIndex.value = selectedCameraIndex.value == 0 ? 1 : 0;

    if (cameraCtrl != null) {
      cameraCtrl!.dispose();
    }

    cameraCtrl = CameraController(
      cameras[selectedCameraIndex.value],
      ResolutionPreset.high,
      enableAudio: true,
    );

    cameraCtrl!.initialize().then((_) {
      update();
    });
  }

  void selectDuration(int duration) {
    selectedDuration.value = duration;
    remainingTime.value = duration;
    update();
  }

  void startRecording() {
    if (cameraCtrl != null && !isRecording.value) {
      cameraCtrl!.startVideoRecording();
      isRecording.value = true;

      // Start timer
      remainingTime.value = selectedDuration.value; // Reset remaining time
      const oneSecond = Duration(seconds: 1);
      _timer = Timer.periodic(oneSecond, (timer) {
        if (remainingTime.value > 0) {
          remainingTime.value--;
          update(); // Update UI with new remaining time
        } else {
          timer.cancel();
          stopRecording();
        }
      });
    }
  }

  void stopRecording() async {
    if (cameraCtrl != null && isRecording.value) {
      final file = await cameraCtrl!.stopVideoRecording();
      isRecording.value = false;
      recordedVideoFile.value = File(file.path);
      _timer?.cancel(); // Cancel the timer if recording is stopped manually
      remainingTime.value = selectedDuration.value; // Reset remaining time
      update();
      Get.to(() => VideoTextEditor(videoFile: File(file.path)));

      // Navigate to playback screen
      // Get.to(() => VideoPlaybackScreen(videoPath: file.path));
    }
  }

  // Function to pick a video from the gallery
  Future<void> pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      // Navigate to the playback screen with the selected video
      Get.to(() => VideoTextEditor(videoFile: File(video.path)));
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    cameraCtrl?.dispose();
    super.onClose();
  }
}

class CameraScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  CameraScreen({Key? key, required this.cameras}) : super(key: key);

  final CameraControllerX controller = Get.put(CameraControllerX());

  @override
  Widget build(BuildContext context) {
    controller.initCamera(cameras);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GetBuilder<CameraControllerX>(
        builder: (controller) {
          if (controller.cameraCtrl == null ||
              !controller.cameraCtrl!.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              // Centered Camera Preview with 9:16 aspect ratio
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ClipRect(child: CameraPreview(controller.cameraCtrl!)),
                ),
              ),

              // Top controls (conditionally shown when not recording)
              Obx(
                () =>
                    !controller.isRecording.value
                        ? Positioned(
                          top: 40,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Close button
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),

                              // Flashlight button
                              IconButton(
                                icon: Icon(
                                  controller.isFlashOn.value
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => controller.toggleFlash(),
                              ),

                              // Rotate camera
                              IconButton(
                                icon: const Icon(
                                  Icons.flip_camera_ios,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed:
                                    () => controller.switchCamera(cameras),
                              ),
                            ],
                          ),
                        )
                        : const SizedBox.shrink(),
              ),

              // Countdown timer display (visible only when recording)
              Obx(
                () =>
                    controller.isRecording.value
                        ? Positioned(
                          top: 100,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              _formatDuration(
                                Duration(
                                  seconds: controller.remainingTime.value,
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),

              // Bottom controls
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Duration options (hide during recording)
                    Obx(
                      () =>
                          !controller.isRecording.value
                              ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 60s
                                    _buildDurationOption(
                                      '60s',
                                      controller.selectedDuration.value == 60,
                                      () => controller.selectDuration(60),
                                    ),
                                    const SizedBox(width: 20),

                                    // 15s
                                    _buildDurationOption(
                                      '15s',
                                      controller.selectedDuration.value == 15,
                                      () => controller.selectDuration(15),
                                    ),
                                  ],
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 20),

                    // Small preview windows for multiple cameras
                    Stack(
                      children: [
                        // Record button (centered)
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              if (controller.isRecording.value) {
                                controller.stopRecording();
                              } else {
                                controller.startRecording();
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                border: Border.all(
                                  color:
                                      controller.isRecording.value
                                          ? Colors.white
                                          : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                              child: Center(
                                child: Obx(
                                  () =>
                                      controller.isRecording.value
                                          ? const Icon(
                                            Icons.stop,
                                            color: Colors.white,
                                            size: 40,
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Gallery picker (hide during recording)
                        Obx(
                          () =>
                              !controller.isRecording.value
                                  ? Align(
                                    alignment: Alignment.bottomRight,
                                    child: GestureDetector(
                                      onTap: () {
                                        controller.pickVideoFromGallery();
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(right: 32),
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.photo_library,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom "POST" button (hide during recording)
              // Obx(
              //   () =>
              //       !controller.isRecording.value
              //           ? Positioned(
              //             bottom: 50,
              //             left: 0,
              //             right: 0,
              //             child: Row(
              //               mainAxisAlignment: MainAxisAlignment.center,
              //               children: [
              //                 Text(
              //                   'post'.tr,
              //                   style: TextStyle(
              //                     color: Colors.white,
              //                     fontWeight: FontWeight.bold,
              //                     fontSize: 18,
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           )
              //           : const SizedBox.shrink(),
              // ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDurationOption(
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class VideoPlaybackScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlaybackScreen({Key? key, required this.videoPath})
    : super(key: key);

  @override
  _VideoPlaybackScreenState createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize()
          .then((_) {
            setState(() {
              _duration = _controller.value.duration;
              _isVideoReady = true;
              // Start playing automatically like in original code
              _controller.play();
              _isPlaying = true;
            });
          })
          .catchError((error) {
            print('Error initializing video: $error');
          });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _position = _controller.value.position;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Recorded Video', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed:
                _isVideoReady
                    ? () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Video posted!')));
                    }
                    : null,
            child: Text(
              'POST',
              style: TextStyle(
                color: _isVideoReady ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isVideoReady)
              Container(
                color: Colors.white,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
              )
            else
              CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            if (_isVideoReady) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        min: 0.0,
                        max: _duration.inSeconds.toDouble(),
                        activeColor: Colors.red,
                        inactiveColor: Colors.grey.shade600,
                        onChanged: (value) {
                          final position = Duration(seconds: value.toInt());
                          _controller.seekTo(position);
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.replay_10, color: Colors.white, size: 36),
                    onPressed: () {
                      final position = _position - Duration(seconds: 10);
                      _controller.seekTo(
                        position > Duration.zero ? position : Duration.zero,
                      );
                    },
                  ),
                  SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: Colors.white,
                      size: 56,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                        _isPlaying = !_isPlaying;
                      });
                    },
                  ),
                  SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.forward_10, color: Colors.white, size: 36),
                    onPressed: () {
                      final position = _position + Duration(seconds: 10);
                      _controller.seekTo(
                        position < _duration ? position : _duration,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
