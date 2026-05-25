import 'dart:async';
import 'dart:io';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/services/video_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../appUtils/appUtils.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../uploadVideoWidgets/uploadVideoStep1.dart';
import '../uploadVideoWidgets/uploadVideoStep2.dart';
import '../uploadVideoWidgets/uploadVideoStep3.dart';

class VideoPreviewScreen extends StatefulWidget {
  final String? isImage;
  final File videoFile;

  const VideoPreviewScreen({
    super.key,
    required this.videoFile,
    this.isImage,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  final VideoAddController videoAddController = Get.find();
  static const double _navBarHeight = 56;

  String _language = 'en';
  int _currentStep = 1;
  late final Worker _stepWorker;

  final List<String> _stepTitles = [
    "video_information_label".tr,
    "add_type_tag_label".tr,
    "publish_label".tr,
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = videoAddController.currentStep.value;
    _stepWorker = ever(videoAddController.currentStep, (step) {
      final next = step is int ? step : (step as num).toInt();
      if (mounted && _currentStep != next) {
        setState(() => _currentStep = next);
      }
    });
    unawaited(_loadLanguage());
    videoAddController.isImage.value =
        (widget.isImage == null || widget.isImage!.isEmpty)
            ? "0"
            : widget.isImage!;
    videoAddController.loadLocationData();
    unawaited(VideoSettingsService.instance.load());
    unawaited(videoAddController.prepareThumbnail(widget.videoFile));
  }

  @override
  void dispose() {
    _stepWorker.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _language == 'ar';

    return WillPopScope(
      onWillPop: () => videoAddController.onWillPop(context),
      child: Scaffold(
        // Keep the form area full-height; only lift the nav bar above the keyboard.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(gradient: ColorUtils.goldGradient),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: isRtl ? null : 16,
                          right: isRtl ? 16 : null,
                          child: InkWell(
                            onTap: () async {
                              if (await videoAddController.onWillPop(
                                Get.context!,
                              )) {
                                Get.back();
                              }
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE6BE00),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back,
                                  color: ColorUtils.darkBrown,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppCenterIcon(),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: _UploadStepper(
                      currentStep: _currentStep,
                      stepTitles: _stepTitles,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: _navBarHeight + 16),
                      child: IndexedStack(
                        index: _currentStep - 1,
                        sizing: StackFit.loose,
                        children: [
                          UploadVideoStep1(
                            key: const ValueKey('upload_step_1'),
                            videoFile: widget.videoFile,
                          ),
                          const UploadVideoStep2(
                            key: ValueKey('upload_step_2'),
                          ),
                          const UploadVideoStep3(
                            key: ValueKey('upload_step_3'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _UploadNavBarOverlay(videoFile: widget.videoFile),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nav bar pinned above the keyboard — isolated rebuild (does not shrink the form).
class _UploadNavBarOverlay extends StatelessWidget {
  const _UploadNavBarOverlay({required this.videoFile});

  final File videoFile;

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Obx(() {
            final controller = Get.find<VideoAddController>();
            final step = controller.currentStep.value;
            final isBusy =
                controller.isVideoUploading.value ||
                controller.isCompressing.value;
            final buttonLabel = controller.isCompressing.value
                ? "compressing_video".tr
                : controller.isVideoUploading.value
                    ? "uploading_video_label".tr
                    : step < 3
                        ? "next_button".tr
                        : "upload_video_button".tr;

            return _UploadNavBar(
              controller: controller,
              videoFile: videoFile,
              currentStep: step,
              isBusy: isBusy,
              buttonLabel: buttonLabel,
            );
          }),
        ),
      ),
    );
  }
}

class _UploadStepper extends StatelessWidget {
  const _UploadStepper({
    required this.currentStep,
    required this.stepTitles,
  });

  final int currentStep;
  final List<String> stepTitles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: List.generate(3, (index) {
                final isCompleted = currentStep > index + 1;
                final isActive = currentStep == index + 1;
                return Expanded(
                  child: Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 4,
                            color: currentStep > index
                                ? ColorUtils.primaryColor
                                : ColorUtils.greyTextFieldBorderColor,
                          ),
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ColorUtils.primaryColor),
                              color: isCompleted || isActive
                                  ? ColorUtils.primaryColor
                                  : Colors.white,
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 20,
                                  )
                                : Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isActive
                                            ? Colors.black
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (index < 2)
                        Expanded(
                          child: Container(
                            height: 4,
                            color: currentStep > index + 1
                                ? ColorUtils.primaryColor
                                : ColorUtils.greyTextFieldBorderColor,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Row(
            children: [
              for (final title in stepTitles)
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadNavBar extends StatelessWidget {
  const _UploadNavBar({
    required this.controller,
    required this.videoFile,
    required this.currentStep,
    required this.isBusy,
    required this.buttonLabel,
  });

  final VideoAddController controller;
  final File videoFile;
  final int currentStep;
  final bool isBusy;
  final String buttonLabel;

  @override
  Widget build(BuildContext buildContext) {
    return Row(
      children: [
        if (currentStep > 1) ...[
          Expanded(
            child: AppButton(
              text: "back_button".tr,
              onTap: controller.previousStep,
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: AppButton(
            text: buttonLabel,
            onTap: isBusy ? null : () => _onPrimaryTap(buildContext),
          ),
        ),
      ],
    );
  }

  void _onPrimaryTap(BuildContext buildContext) {
    if (controller.currentStep.value == 1) {
      if (controller.step1key.currentState!.validate()) {
        controller.nextStep();
      } else {
        _showError(buildContext, "step1_invalid_form_error".tr);
      }
    } else if (controller.currentStep.value == 2) {
      if (controller.step2key.currentState!.validate()) {
        controller.nextStep();
      } else {
        _showError(buildContext, "step2_invalid_form_error".tr);
      }
    } else {
      controller.uploadVideo(videoFile, buildContext);
    }
  }

  void _showError(BuildContext buildContext, String message) {
    ScaffoldMessenger.of(buildContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
