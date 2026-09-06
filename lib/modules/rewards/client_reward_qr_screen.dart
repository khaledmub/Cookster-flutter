import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/modules/rewards/rewards_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClientRewardQrScreen extends StatefulWidget {
  const ClientRewardQrScreen({super.key});

  @override
  State<ClientRewardQrScreen> createState() => _ClientRewardQrScreenState();
}

class _ClientRewardQrScreenState extends State<ClientRewardQrScreen> {
  late final RewardsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(RewardsController(), tag: 'client_reward_qr');
    _controller.loadMyCode();
  }

  @override
  void dispose() {
    Get.delete<RewardsController>(tag: 'client_reward_qr');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorUtils.darkBrown),
          onPressed: () => navigateBack(),
        ),
        title: Text(
          'reward_qr_title'.tr,
          style: TextStyle(
            color: ColorUtils.darkBrown,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isCodeLoading.value && _controller.myCode.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: ColorUtils.darkBrown),
          );
        }
        final error = _controller.codeError.value;
        if (error != null && _controller.myCode.value == null) {
          return _MessageState(
            text: error,
            onRetry: _controller.loadMyCode,
          );
        }
        final code = _controller.myCode.value;
        if (code == null || !code.eligible) {
          return _MessageState(
            text: 'reward_qr_unavailable'.tr,
            onRetry: _controller.loadMyCode,
          );
        }
        return RefreshIndicator(
          color: ColorUtils.darkBrown,
          onRefresh: _controller.loadMyCode,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            children: [
              Text(
                'reward_qr_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColorUtils.grey,
                  fontSize: 14.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 28.h),
              Center(
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: ColorUtils.primaryColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: QrImageView(
                    data: code.payload,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'reward_qr_refresh_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorUtils.grey, fontSize: 12.sp),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _MessageState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorUtils.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: onRetry,
              child: Text('retry_button'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
