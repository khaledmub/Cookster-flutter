import 'dart:io';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
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
  String? isImage;
  final File videoFile;

  VideoPreviewScreen({Key? key, required this.videoFile, this.isImage})
    : super(key: key);

  @override
  _VideoPreviewScreenState createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  final VideoAddController videoAddController = Get.find();

  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLanguage();

    videoAddController.isImage.value =
        (widget.isImage == null || widget.isImage == "")
            ? "0"
            : widget.isImage!;
    // videoAddController.tagsList.value = []; // Set tagsList to an empty list

    videoAddController.loadLocationData();
  }

  // @override
  // void dispose() {
  //   super.dispose();
  // }

  final List<String> stepTitles = [
    "video_information_label".tr,
    "add_type_tag_label".tr,
    "publish_label".tr,
  ];

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    return WillPopScope(
      onWillPop: () => videoAddController.onWillPop(context),
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(gradient: ColorUtils.goldGradient),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 30.h),

                  /// **App Bar with Back Button & Logo**
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
                              // Get the VideoAddController instance
                              final VideoAddController controller = Get.find();

                              // Check if it's safe to pop using the onWillPop function
                              if (await controller.onWillPop(Get.context!)) {
                                Get.back();
                              }
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6BE00),
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
                  SizedBox(height: 20),

                  /// **Horizontal Stepper with Connecting Lines**
                  Column(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Obx(() {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Column(
                              spacing: 8,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(3, (index) {
                                      bool isCompleted =
                                          videoAddController.currentStep.value >
                                          index + 1;
                                      bool isActive =
                                          videoAddController
                                              .currentStep
                                              .value ==
                                          index + 1;

                                      return Expanded(
                                        child: Row(
                                          children: [
                                            if (index > 0)
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  height: 4,
                                                  color:
                                                      videoAddController
                                                                  .currentStep
                                                                  .value >
                                                              index
                                                          ? ColorUtils
                                                              .primaryColor
                                                          : ColorUtils
                                                              .greyTextFieldBorderColor,
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
                                                    border: Border.all(
                                                      color:
                                                          ColorUtils
                                                              .primaryColor,
                                                    ),
                                                    color:
                                                        isCompleted
                                                            ? ColorUtils
                                                                .primaryColor
                                                            : (isActive
                                                                ? ColorUtils
                                                                    .primaryColor
                                                                : Colors.white),
                                                  ),
                                                  child:
                                                      isCompleted
                                                          ? Icon(
                                                            Icons.check,
                                                            color: Colors.black,
                                                            size: 20,
                                                          )
                                                          : Center(
                                                            child: Text(
                                                              "${index + 1}",
                                                              style: TextStyle(
                                                                fontSize: 16.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color:
                                                                    isActive
                                                                        ? Colors
                                                                            .black
                                                                        : Colors
                                                                            .grey[600],
                                                              ),
                                                            ),
                                                          ),
                                                ),
                                              ],
                                            ),
                                            if (index < 2)
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  height: 4,
                                                  color:
                                                      videoAddController
                                                                  .currentStep
                                                                  .value >
                                                              index + 1
                                                          ? ColorUtils
                                                              .primaryColor
                                                          : ColorUtils
                                                              .greyTextFieldBorderColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stepTitles[0],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        stepTitles[1],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        stepTitles[2],
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
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  /// **Step Content**
                  Obx(() {
                    if (videoAddController.currentStep.value == 1) {
                      return UploadVideoStep1(videoFile: widget.videoFile);
                    } else if (videoAddController.currentStep.value == 2) {
                      return UploadVideoStep2();
                    } else {
                      return uploadVideoStep3();
                    }
                  }),
                  SizedBox(height: 16),

                  /// **Navigation Buttons (Back & Next/Publish)**
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Obx(() {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (videoAddController.currentStep.value > 1)
                              Expanded(
                                child: AppButton(
                                  text: "back_button".tr,
                                  onTap: () {
                                    videoAddController.previousStep();
                                  },
                                ),
                              )
                            else
                              SizedBox.shrink(),
                            videoAddController.currentStep.value > 1
                                ? SizedBox(width: 16)
                                : SizedBox.shrink(),
                            Expanded(
                              child: Obx(() => AppButton(
                                text:
                                    videoAddController.isCompressing.value
                                        ? "compressing_video".tr
                                        : videoAddController.isVideoUploading.value
                                            ? "uploading_video_label".tr
                                            : videoAddController.currentStep.value < 3
                                                ? "next_button".tr
                                                : "upload_video_button".tr,
                                onTap: (videoAddController.isVideoUploading.value || videoAddController.isCompressing.value)
                                    ? null
                                    : () {
                                  if (videoAddController.currentStep.value ==
                                      1) {
                                    if (videoAddController
                                        .step1key
                                        .currentState!
                                        .validate()) {
                                      videoAddController.nextStep();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("step1_invalid_form_error".tr),
                                          backgroundColor: Colors.red.withOpacity(0.8),
                                          behavior: SnackBarBehavior.floating,
                                          action: SnackBarAction(
                                            label: "error_title".tr,
                                            textColor: Colors.white,
                                            onPressed: () {
                                              // Optional: Add action functionality here
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (videoAddController
                                          .currentStep
                                          .value ==
                                      2) {
                                    if (videoAddController
                                        .step2key
                                        .currentState!
                                        .validate()) {
                                      videoAddController.nextStep();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("step2_invalid_form_error".tr),
                                          backgroundColor: Colors.red.withOpacity(0.8),
                                          behavior: SnackBarBehavior.floating, // Optional: makes it appear at the bottom
                                          action: SnackBarAction(
                                            label: "error_title".tr, // Using the translated title as the action label
                                            textColor: Colors.white,
                                            onPressed: () {
                                              // Optional: Add action functionality here
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (videoAddController
                                          .currentStep
                                          .value ==
                                      3) {
                                    videoAddController.uploadVideo(
                                      widget.videoFile,
                                      context,
                                    );
                                  }
                                },
                              )),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
