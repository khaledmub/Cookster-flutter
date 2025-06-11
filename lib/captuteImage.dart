import 'package:cookster/services/imageEditScreen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class CameraCaptureControllerX extends GetxController {
  CameraController? cameraCtrl;
  RxBool isFlashOn = false.obs;
  RxInt selectedCameraIndex = 0.obs;
  Rx<File?> capturedImageFile = Rx<File?>(null);
  RxBool isCameraInitialized = false.obs;
  RxString errorMessage = ''.obs;

  Future<void> initCamera(List<CameraDescription> cameras) async {
    try {
      // Check camera permission
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          errorMessage.value =
              'Camera permission denied. Please enable it in settings.';
          isCameraInitialized.value = false;
          update();
          return;
        }
      }

      // Check if cameras are available
      if (cameras.isEmpty) {
        errorMessage.value = 'No cameras available on this device.';
        isCameraInitialized.value = false;
        update();
        return;
      }

      // Ensure valid camera index
      if (selectedCameraIndex.value >= cameras.length) {
        selectedCameraIndex.value = 0;
      }

      // Initialize camera
      cameraCtrl = CameraController(
        cameras[selectedCameraIndex.value],
        ResolutionPreset.medium,
        // Changed to medium to reduce initialization time
        enableAudio: false,
      );

      // Add timeout to prevent hanging
      await cameraCtrl!.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Camera initialization timed out');
        },
      );

      isCameraInitialized.value = true;
      errorMessage.value = '';
      update();
    } catch (e) {
      errorMessage.value = 'Failed to initialize camera: $e';
      isCameraInitialized.value = false;
      update();
      print('Camera initialization error: $e');
    }
  }

  void toggleFlash() async {
    if (cameraCtrl == null || !cameraCtrl!.value.isInitialized) return;
    try {
      isFlashOn.value = !isFlashOn.value;
      await cameraCtrl!.setFlashMode(
        isFlashOn.value ? FlashMode.torch : FlashMode.off,
      );
      update();
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle flash: $e');
    }
  }

  void switchCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty || cameras.length < 2) return;
    try {
      selectedCameraIndex.value = selectedCameraIndex.value == 0 ? 1 : 0;
      isCameraInitialized.value = false;
      update();

      if (cameraCtrl != null) {
        await cameraCtrl!.dispose();
      }

      await initCamera(cameras);
    } catch (e) {
      errorMessage.value = 'Failed to switch camera: $e';
      isCameraInitialized.value = false;
      update();
    }
  }

  void captureImage() async {
    if (cameraCtrl == null || !cameraCtrl!.value.isInitialized) {
      Get.snackbar('Error', 'Camera is not initialized');
      return;
    }
    try {
      final file = await cameraCtrl!.takePicture();
      capturedImageFile.value = File(file.path);
      update();
      Get.to(() => ImageEditScreen(imagePath: file.path));
    } catch (e) {
      Get.snackbar('Error', 'Failed to capture image: $e');
    }
  }

  @override
  void onClose() {
    cameraCtrl?.dispose();
    super.onClose();
  }
}

class CameraCaptureScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const CameraCaptureScreen({Key? key, required this.cameras})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CameraCaptureControllerX());
    controller.initCamera(cameras);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        // Display error message if initialization fails
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Retry initialization or open settings
                    if (controller.errorMessage.value.contains('permission')) {
                      openAppSettings();
                    } else {
                      controller.initCamera(cameras);
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Show loading indicator while initializing
        if (!controller.isCameraInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        // Camera UI when initialized
        return Stack(
          children: [
            // Centered Camera Preview with 9:16 aspect ratio
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CameraPreview(controller.cameraCtrl!),
              ),
            ),

            // Top controls
            Positioned(
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
                    onPressed: controller.toggleFlash,
                  ),

                  // Rotate camera
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => controller.switchCamera(cameras),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: controller.captureImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 4),
                    ),
                    child: const Center(
                      child: Icon(Icons.camera, color: Colors.black, size: 40),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom "POST" button
            // Positioned(
            //   bottom: 30,
            //   left: 0,
            //   right: 0,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Text(
            //         'post'.tr,
            //         style: TextStyle(
            //           color: Colors.white,
            //           fontWeight: FontWeight.bold,
            //           fontSize: 18,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        );
      }),
    );
  }
}
