import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/modules/rewards/rewards_controller.dart';
import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class PartnerScanScreen extends StatefulWidget {
  const PartnerScanScreen({super.key});

  @override
  State<PartnerScanScreen> createState() => _PartnerScanScreenState();
}

class _PartnerScanScreenState extends State<PartnerScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  late final RewardsController _controller;
  bool _ownsController = false;
  bool _handling = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<RewardsController>(tag: 'partner_rewards')) {
      _controller = Get.find<RewardsController>(tag: 'partner_rewards');
    } else {
      _controller = Get.put(RewardsController(), tag: 'partner_scan');
      _ownsController = true;
    }
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionDenied = !status.isGranted;
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    if (_ownsController) {
      Get.delete<RewardsController>(tag: 'partner_scan');
    }
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || _controller.isScanning.value) {
      return;
    }
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );
    if (raw.isEmpty) {
      return;
    }
    _handling = true;
    await _scanner.stop();
    final result = await _controller.scanPayload(raw);
    if (!mounted) {
      return;
    }
    if (result == null) {
      _handling = false;
      await _scanner.start();
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
    await _scanner.start();
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
            : (result.message ??
                rewardErrorLocaleKey(result.errorCode).tr);
    await Get.dialog<void>(
      AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('ok'.tr),
          ),
        ],
      ),
    );
    if (result.success) {
      await _controller.loadCurrentDeal();
    }
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
      body:
          _permissionDenied
              ? Center(
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
              )
              : Stack(
                children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: _onDetect,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 40.h),
                      child: Text(
                        'reward_scan_hint'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
