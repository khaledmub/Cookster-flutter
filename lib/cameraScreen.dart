import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  bool _cameraInitStarted = false;
  bool _isStarting = false;
  bool _isStopping = false;

  List<int> availableDurations = [10 * 60, 60, 15]; // 10m, 60s, 15s

  void initCamera(List<CameraDescription> cameras) {
    // build() calls this every frame — never recreate an open camera.
    if (_cameraInitStarted || cameras.isEmpty) return;
    _cameraInitStarted = true;
    final index = selectedCameraIndex.value.clamp(0, cameras.length - 1);
    cameraCtrl = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );

    cameraCtrl!.initialize().then((_) {
      update();
    }).catchError((Object e) {
      debugPrint('Camera init failed: $e');
      _cameraInitStarted = false;
      cameraCtrl = null;
    });
  }

  void toggleFlash() {
    isFlashOn.value = !isFlashOn.value;
    cameraCtrl?.setFlashMode(isFlashOn.value ? FlashMode.torch : FlashMode.off);
    update();
  }

  void switchCamera(List<CameraDescription> cameras) {
    if (cameras.length < 2 ||
        isRecording.value ||
        _isStarting ||
        _isStopping) {
      return;
    }
    selectedCameraIndex.value = selectedCameraIndex.value == 0 ? 1 : 0;

    final previous = cameraCtrl;
    cameraCtrl = null;
    previous?.dispose();

    final index = selectedCameraIndex.value.clamp(0, cameras.length - 1);
    cameraCtrl = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    _cameraInitStarted = true;

    cameraCtrl!.initialize().then((_) {
      update();
    }).catchError((Object e) {
      debugPrint('Camera switch failed: $e');
      cameraCtrl = null;
      _cameraInitStarted = false;
    });
  }

  void selectDuration(int duration) {
    if (isRecording.value) return;
    selectedDuration.value = duration;
    remainingTime.value = duration;
    update();
  }

  Future<void> startRecording() async {
    final ctrl = cameraCtrl;
    if (ctrl == null ||
        !ctrl.value.isInitialized ||
        isRecording.value ||
        _isStarting ||
        _isStopping ||
        ctrl.value.isRecordingVideo) {
      return;
    }

    _isStarting = true;
    try {
      await ctrl.startVideoRecording();
      isRecording.value = true;
      remainingTime.value = selectedDuration.value;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingTime.value > 0) {
          remainingTime.value--;
          update();
        } else {
          timer.cancel();
          unawaited(stopRecording());
        }
      });
      update();
    } catch (e) {
      debugPrint('startRecording failed: $e');
      isRecording.value = false;
      _timer?.cancel();
      _timer = null;
      remainingTime.value = selectedDuration.value;
      update();
    } finally {
      _isStarting = false;
    }
  }

  /// [navigateToEditor] false when discarding (close / leave) so an abandoned
  /// take never continues into the editor / upload form.
  Future<void> stopRecording({bool navigateToEditor = true}) async {
    final ctrl = cameraCtrl;
    if (ctrl == null || _isStopping) return;

    final uiSaysRecording = isRecording.value;
    final nativeRecording =
        ctrl.value.isInitialized && ctrl.value.isRecordingVideo;
    if (!uiSaysRecording && !nativeRecording) return;

    _isStopping = true;
    _timer?.cancel();
    _timer = null;
    // Clear UI immediately so taps / max-duration timer cannot re-enter stop.
    isRecording.value = false;
    update();

    XFile? file;
    try {
      if (ctrl.value.isInitialized && ctrl.value.isRecordingVideo) {
        file = await ctrl.stopVideoRecording();
      }
    } on CameraException catch (e) {
      debugPrint('stopRecording ignored: ${e.code} ${e.description}');
    } catch (e) {
      debugPrint('stopRecording failed: $e');
    } finally {
      remainingTime.value = selectedDuration.value;
      _isStopping = false;
      isRecording.value = false;
      update();
    }

    if (file == null || !navigateToEditor) return;
    recordedVideoFile.value = File(file.path);
    Get.to(() => VideoTextEditor(videoFile: File(file!.path)));
  }

  Future<void> discardAndClose(BuildContext context) async {
    await stopRecording(navigateToEditor: false);
    recordedVideoFile.value = null;
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  // Function to pick a video from the gallery
  Future<void> pickVideoFromGallery() async {
    if (isRecording.value || _isStarting || _isStopping) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp4',
        'mov',
        'm4v',
        '3gp',
        'mkv',
        'avi',
        'webm',
        'mpeg',
        'mpg',
      ],
    );

    final pickedPath = result?.files.single.path;
    if (pickedPath != null && pickedPath.isNotEmpty) {
      Get.to(() => VideoTextEditor(videoFile: File(pickedPath)));
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _timer = null;
    final ctrl = cameraCtrl;
    cameraCtrl = null;
    if (ctrl != null) {
      () async {
        try {
          if (ctrl.value.isInitialized && ctrl.value.isRecordingVideo) {
            await ctrl.stopVideoRecording();
          }
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }();
    }
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
                                onPressed: () =>
                                    unawaited(controller.discardAndClose(context)),
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
                                unawaited(controller.stopRecording());
                              } else {
                                unawaited(controller.startRecording());
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
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
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
              _controller.play();
              _isPlaying = true;
            });
          })
          .catchError((error) {
            debugPrint('Error initializing video: $error');
          });

    _controller.addListener(() {
      if (mounted) {
        _position.value = _controller.value.position;
      }
    });
  }

  @override
  void dispose() {
    _position.dispose();
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
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
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
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _position,
                  builder: (context, position, _) {
                    return Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: Slider(
                            value: position.inSeconds.toDouble(),
                            min: 0.0,
                            max: _duration.inSeconds.toDouble(),
                            activeColor: Colors.red,
                            inactiveColor: Colors.grey.shade600,
                            onChanged: (value) {
                              _controller.seekTo(
                                Duration(seconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.replay_10, color: Colors.white, size: 36),
                    onPressed: () {
                      final position = _position.value - const Duration(seconds: 10);
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
                      final position = _position.value + const Duration(seconds: 10);
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
