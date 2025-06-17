import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:cookster/modules/selectLanguage/selectController/selectLanguageController.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

import '../../../appUtils/colorUtils.dart';
import '../auth/signUp/signUpController/signUpController.dart';
import '../onBoarding/onBoardingController/onBoardingController.dart';
import '../onBoarding/onBoardingView/onBoardingView.dart';

class InitLanguageView extends StatefulWidget {
  const InitLanguageView({super.key});

  @override
  State<InitLanguageView> createState() => _InitLanguageViewState();
}

class _InitLanguageViewState extends State<InitLanguageView> {
  final LanguageController languageController = Get.put(LanguageController());

  // Save initLanguage flag to SharedPreferences
  Future<void> _saveInitLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('initLanguage', true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop until custom logic is applied
      onPopInvoked: (didPop) async {
        // If didPop is true, the pop action was already performed, so skip
        if (didPop) return;

        final shouldPop = await _showExitConfirmationDialog(context);
        if (shouldPop) {
          // Explicitly exit the app if the user confirms
          SystemNavigator.pop();
        }
      },

      child: Scaffold(
        backgroundColor: ColorUtils.secondaryColor,
        appBar: AppBar(
          backgroundColor: ColorUtils.primaryColor,
          toolbarHeight: 0,
          elevation: 0,
        ),
        body: SizedBox(
          height: Get.height,
          child: Stack(
            children: [
              // Background Gradient
              Container(
                height: Get.height,
                decoration: const BoxDecoration(
                  gradient: ColorUtils.goldGradient,
                ),
              ),

              // Main content
              Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                // crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 90),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40.r),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        spacing: 10.h,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 20.h),
                          Text(
                            "Language Selection".tr,
                            style: TextStyle(
                              color: ColorUtils.darkBrown,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'changeLanguageDescription'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Obx(
                            () => _buildLanguageOption(
                              language: "English".tr,
                              imagePath: "assets/icons/english.svg",
                              isSelected:
                                  languageController
                                      .selectedTempLanguage
                                      .value ==
                                  "English",
                              onTap:
                                  () => languageController.selectLanguage(
                                    "English",
                                  ),
                            ),
                          ),
                          Obx(
                            () => _buildLanguageOption(
                              language: "Arabic".tr,
                              imagePath: "assets/icons/arabic.svg",
                              isSelected:
                                  languageController
                                      .selectedTempLanguage
                                      .value ==
                                  "Arabic",
                              onTap:
                                  () => languageController.selectLanguage(
                                    "Arabic",
                                  ),
                            ),
                          ),
                          SizedBox(height: 4),

                          AppButton(
                            text: "continue".tr,
                            onTap: () async {
                              await languageController.applyLanguageChange();
                              await _saveInitLanguage(); // Save initLanguage flag


                              // Get.put(OnboardingController(), permanent: true);
                              Get.offAll(() => const OnBoarding());
                            },
                          ),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AppCenterIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String language,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? ColorUtils.primaryColor
                  : Colors.yellow.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            SvgPicture.asset(imagePath, height: 50.h),
            SizedBox(height: 8),
            Text(
              language,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    bool shouldExit = false;

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: "exit_app".tr,
      desc: "are_you_sure_you_want_to_exit_the_app".tr,
      btnOkText: "Yes".tr,
      btnCancelText: "No".tr,
      btnCancelColor: Colors.grey,
      btnOkOnPress: () {
        shouldExit = true;
      },
      btnCancelOnPress: () {
        shouldExit = false;
      },
      dismissOnTouchOutside: false,
    ).show();

    return shouldExit;
  }
}
