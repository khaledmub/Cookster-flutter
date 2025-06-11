import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/modules/landing/landingTabs/reportContent/reportContentController/reportContentController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../appUtils/appUtils.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';

class ReportContentView extends StatefulWidget {
  final String videoId;

  const ReportContentView({super.key, required this.videoId});

  @override
  State<ReportContentView> createState() => _ReportContentViewState();
}

class _ReportContentViewState extends State<ReportContentView> {
  final ReportContentController reportContentController = Get.put(
    ReportContentController(),
  );
  final TextEditingController commentController = TextEditingController();
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
    // TODO: implement initState
    super.initState();
    _loadLanguage();
  }


  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (reportContentController.showTextField.value) {
      // If on the comments screen, go back to categories
      reportContentController.showTextField.value = false;
      return false; // Prevent default back navigation
    } else {
      // If on the categories screen, allow default back navigation
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    return WillPopScope(
      onWillPop: _onWillPop, // Override back button behavior
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ColorUtils.primaryColor,
          toolbarHeight: 0,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: ColorUtils.goldGradient,
              ),
            ),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          // Conditionally set left or right based on language
                          left: isRtl ? null : 16,
                          right: isRtl ? 16 : null,
                          top: 10.h,

                          // Assuming .h is from a package like flutter_screenutil, replace with 20 if not using it
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (reportContentController.showTextField.value) {
                                // If on comments screen, go back to categories
                                reportContentController.showTextField.value =
                                    false;
                              } else {
                                // If on categories screen, exit the page
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
                                  // Use right chevron for Arabic, left chevron for English
                                  isRtl ? Icons.arrow_back : Icons.arrow_back,
                                  color: ColorUtils.darkBrown,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),

                       AppCenterIcon()
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      textAlign: TextAlign.center,
                      'help-understand-problem'.tr,
                      style: TextStyle(
                        color: ColorUtils.darkBrown,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40.r),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 20,
                      ),
                      child: Obx(() {
                        return reportContentController.isLoading.value
                            ? Center(
                              child: PulseLogoLoader(
                                logoPath: "assets/images/appIconC.png",
                              ),
                            )
                            : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: 16),
                                Text(
                                  textAlign: TextAlign.center,
                                  reportContentController.showTextField.value
                                      ? "additional-comments".tr
                                      : "why-not-see-video".tr,
                                  style: TextStyle(
                                    color: ColorUtils.darkBrown,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: Get.height * 0.5,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        if (!reportContentController
                                            .showTextField
                                            .value)
                                          Column(
                                            children:
                                                reportContentController
                                                    .reportContent
                                                    .value
                                                    .categories!
                                                    .map(
                                                      (reason) => RadioListTile<
                                                        String
                                                      >(
                                                        title: Text(
                                                          reason.name!,
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Colors.black,
                                                          ),
                                                        ),

                                                        value: reason.id!,
                                                        groupValue:
                                                            reportContentController
                                                                .selectedReasonId
                                                                .value,
                                                        onChanged: (
                                                          String? value,
                                                        ) {
                                                          reportContentController
                                                              .setSelectedReason(
                                                                value!,
                                                              );
                                                        },
                                                        activeColor:
                                                            ColorUtils
                                                                .primaryColor,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .zero, // Add this line to remove padding
                                                      ),
                                                    )
                                                    .toList(),
                                          )
                                        else
                                          Column(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        15.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.grey[300]!,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: commentController,
                                                  maxLines: 8,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "provide-report-details"
                                                            .tr
                                                            .tr,
                                                    contentPadding:
                                                        EdgeInsets.all(16),
                                                    border: InputBorder.none,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 10.h),
                                              Text(
                                                "report-community-standards".tr,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Obx(() {
                                  return AppButton(
                                    isLoading:
                                        reportContentController
                                            .isReportSubmitting
                                            .value,
                                    text:
                                        reportContentController
                                                .showTextField
                                                .value
                                            ? "submit-report".tr
                                            : "continue".tr,
                                    onTap: () async {
                                      if (!reportContentController
                                          .showTextField
                                          .value) {
                                        if (reportContentController
                                                .selectedReasonId
                                                .value !=
                                            null) {
                                          reportContentController
                                              .showTextField
                                              .value = true;
                                        } else {
                                          AwesomeDialog(
                                            context: context,
                                            dialogType: DialogType.error,
                                            animType: AnimType.bottomSlide,
                                            title: "error".tr,
                                            desc: "select-reason".tr,
                                            btnOkText: "ok".tr,
                                            btnOkOnPress: () {},
                                          ).show();
                                        }
                                      } else {
                                        if (commentController.text
                                            .trim()
                                            .isEmpty) {
                                          AwesomeDialog(
                                            context: context,
                                            dialogType: DialogType.error,
                                            animType: AnimType.bottomSlide,
                                            title: "error".tr,
                                            desc: "comment-required".tr,
                                            btnOkText: "ok".tr,
                                            btnOkOnPress: () {},
                                          ).show();
                                        } else {
                                          await reportContentController
                                              .submitReport(
                                                widget.videoId,
                                                commentController.text.trim(),
                                              );
                                        }
                                      }
                                    },
                                  );
                                }),
                              ],
                            );
                      }),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
