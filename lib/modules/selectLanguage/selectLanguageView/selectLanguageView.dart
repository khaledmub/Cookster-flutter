import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/auth/signIn/signInView/signInView.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:cookster/modules/selectLanguage/selectController/selectLanguageController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appUtils/colorUtils.dart';

class SelectLanguageView extends StatefulWidget {
  const SelectLanguageView({super.key});

  @override
  State<SelectLanguageView> createState() => _SelectLanguageViewState();
}

class _SelectLanguageViewState extends State<SelectLanguageView> {
  final LanguageController languageController = Get.put(LanguageController());
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
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    return Scaffold(
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

            // Your main content goes here
            Column(
              spacing: 12.h,

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
                                languageController.selectedTempLanguage.value ==
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
                                languageController.selectedTempLanguage.value ==
                                "Arabic",
                            onTap:
                                () =>
                                    languageController.selectLanguage("Arabic"),
                          ),
                        ),
                        SizedBox(height: 4),

                        AppButton(
                          text: "Save".tr,
                          onTap: () async {
                            await languageController.applyLanguageChange().then(
                              (_) {
                                Get.offAll(SignInView());
                              },
                            );
                          },
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              // Conditionally set left or right based on language
              left: isRtl ? null : 16,
              right: isRtl ? 16 : null,
              top: 20,
              // Assuming .h is from a package like flutter_screenutil, replace with 20 if not using it
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  try {
                    print("Tapped");
                    Get.back();
                  } catch (e) {
                    print(e);
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

            // Center Logo
            AppCenterIcon(),
          ],
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
            SvgPicture.asset(imagePath, height: 50.h), // Adjust flag size
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
}
