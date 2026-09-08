import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/modules/rewards/rewards_controller.dart';
import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zxing2/qrcode.dart';
import 'package:zxing2/zxing2.dart';

class PartnerScanScreen extends StatefulWidget {
  const PartnerScanScreen({super.key});

  @override
  State<PartnerScanScreen> createState() => _PartnerScanScreenState();
}

class _PartnerScanScreenState extends State<PartnerScanScreen> {
  late final RewardsController _controller;
  final _pasteController = TextEditingController();
  CameraController? _camera;
  bool _ownsController = false;
  bool _handling = false;
  bool _permissionDenied = false;
  bool _cameraReady = false;
  int _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<RewardsController>(tag: 'partner_rewards')) {
      _controller = Get.find<RewardsController>(tag: 'partner_rewards');
    } else {
      _controller = Get.put(RewardsController(), tag: 'partner_scan');
      _ownsController = true;
    }
    _startCamera();
  }

  Future<void> _startCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      await camera.startImageStream(_onCameraImage);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraReady = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cameraReady = false);
      }
    }
  }

  void _onCameraImage(CameraImage image) {
    _frameSkip++;
    if (_frameSkip % 12 != 0 || _handling) {
      return;
    }
    final payload = _decodeQr(image);
    if (payload == null || payload.isEmpty) {
      return;
    }
    _submit(payload);
  }

  String? _decodeQr(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      if (width < 16 || height < 16) {
        return null;
      }
      final pixels = Int32List(width * height);
      if (image.format.group == ImageFormatGroup.bgra8888 &&
          image.planes.isNotEmpty) {
        final bytes = image.planes.first.bytes;
        final stride = image.planes.first.bytesPerRow;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final i = y * stride + x * 4;
            if (i + 2 >= bytes.length) {
              continue;
            }
            final b = bytes[i];
            final g = bytes[i + 1];
            final r = bytes[i + 2];
            pixels[y * width + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
          }
        }
      } else if (image.planes.isNotEmpty) {
        final yPlane = image.planes.first;
        final bytes = yPlane.bytes;
        final stride = yPlane.bytesPerRow;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final luma = bytes[y * stride + x];
            pixels[y * width + x] =
                (0xFF << 24) | (luma << 16) | (luma << 8) | luma;
          }
        }
      } else {
        return null;
      }
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      return QRCodeReader().decode(bitmap).text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit(String raw) async {
    if (_handling || _controller.isScanning.value) {
      return;
    }
    _handling = true;
    await _camera?.pausePreview();
    final result = await _controller.scanPayload(raw);
    if (!mounted) {
      return;
    }
    if (result == null) {
      _handling = false;
      await _camera?.resumePreview();
      return;
    }
    await _showResult(result);
    if (!mounted) {
      return;
    }
    if (result.success) {
      navigateBack(result);
      return;
    }
    _handling = false;
    await _camera?.resumePreview();
  }

  Future<void> _showResult(RewardScanResult result) async {
    final remaining = result.deal?.quantityRemaining;
    final title = result.success ? 'reward_scan_success'.tr : 'error'.tr;
    final body =
        result.success
            ? (remaining == null
                ? 'reward_scan_success'.tr
                : 'reward_scan_success_remaining'.trParams({
                  'remaining': '$remaining',
                }))
            : (result.message ?? rewardErrorLocaleKey(result.errorCode).tr);
    await Get.dialog<void>(
      AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('ok'.tr)),
        ],
      ),
    );
    if (result.success) {
      await _controller.loadCurrentDeal();
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _pasteController.dispose();
    if (_ownsController) {
      Get.delete<RewardsController>(tag: 'partner_scan');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => navigateBack(),
        ),
        title: Text('reward_scan'.tr),
      ),
      body: Column(
        children: [
          Expanded(child: _preview()),
          _pasteBar(),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'reward_camera_denied'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: openAppSettings,
                child: Text('reward_open_settings'.tr),
              ),
            ],
          ),
        ),
      );
    }
    if (_cameraReady && _camera != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera!),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 16.h),
              child: Text(
                'reward_scan_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Text(
        'reward_scan_paste_hint'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 14.sp),
      ),
    );
  }

  Widget _pasteBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pasteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'reward_scan_paste_hint'.tr,
                  hintStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: () => _submit(_pasteController.text),
              child: Text('ok'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
