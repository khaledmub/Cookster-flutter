import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/onBoarding/onBoardingModel/onBoardingModel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../loaders/pulseLoader.dart';
import '../onBoardingController/onBoardingController.dart';

class OnBoarding extends StatefulWidget {
  const OnBoarding({super.key});

  @override
  State<OnBoarding> createState() => _OnBoardingState();
}

class _OnBoardingState extends State<OnBoarding> {
  final OnboardingController controller = Get.put(
    OnboardingController(),
    permanent: true,
  );

  @override
  Widget build(BuildContext context) {

    // Determine text direction based on locale
    final bool isRtl = Get.locale?.languageCode == 'ar';

    return Obx(() {
      final OnBoardingModel onboardingModel = controller.onboardingData.value;

      // If data isn't loaded yet, show a simple loading state
      if (onboardingModel.screens == null) {
        return const Scaffold(
          body: Center(
            child: PulseLogoLoader(
              logoPath: "assets/images/appIcon.png",
              size: 80,
            ),
          ),
        );
      }

      final List<Map<String, String>> onboardingData =
          onboardingModel.screens!.map((screen) {
            return {
              "title": screen.title ?? "",
              "sub_title": screen.subTitle ?? "",
              "short_description": screen.shortDescription ?? "",
              "image": screen.image ?? "",
            };
          }).toList();

      return PopScope(
        canPop: false, // Prevent default pop until custom logic is applied
        onPopInvoked: (didPop) async {
          // If didPop is true, the pop action was already performed, so skip
          if (didPop) return;

          final shouldPop = await _showExitConfirmationDialog(context);
          if (shouldPop) {
            // Allow the app to exit (or handle custom exit logic)
            // Note: SystemNavigator.pop() might be needed for app exit
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          }
        },

        child: Scaffold(
          backgroundColor: ColorUtils.secondaryColor,
          body: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewPadding.bottom + 20,
            ),
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                // Fixed swipe logic for RTL
                final bool swipeLeft =
                    details.primaryVelocity! > 0; // Swipe from left to right
                final bool swipeRight =
                    details.primaryVelocity! < 0; // Swipe from right to left

                if (isRtl) {
                  // RTL: Swipe left -> next page, Swipe right -> previous page
                  if (swipeLeft) {
                    if (controller.currentPage.value <
                        onboardingData.length - 1) {
                      controller.pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      controller.nextPage();
                    }
                  } else if (swipeRight) {
                    if (controller.currentPage.value > 0) {
                      controller.pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                } else {
                  // LTR: Swipe left -> previous page, Swipe right -> next page
                  if (swipeLeft) {
                    if (controller.currentPage.value > 0) {
                      controller.pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  } else if (swipeRight) {
                    if (controller.currentPage.value <
                        onboardingData.length - 1) {
                      controller.pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      controller.nextPage();
                    }
                  }
                }
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                child: Stack(
                  children: [
                    Directionality(
                      textDirection:
                          isRtl ? TextDirection.rtl : TextDirection.ltr,
                      child: PageView.builder(
                        controller: controller.pageController,
                        // Remove reverse parameter - let Directionality handle RTL behavior
                        itemCount: onboardingData.length,
                        onPageChanged: (index) {
                          controller.currentPage.value = index;
                        },
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(bottom: Get.height * 0.35),
                            child: CachedNetworkImage(
                              imageUrl:
                                  '${Common.imageScreen}/${onboardingData[index]["image"]}',
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              errorWidget:
                                  (context, url, error) =>
                                      const Icon(Icons.error),
                              imageBuilder: (context, imageProvider) {
                                final stream = imageProvider.resolve(
                                  ImageConfiguration.empty,
                                );
                                stream.addListener(
                                  ImageStreamListener((
                                    imageInfo,
                                    synchronousCall,
                                  ) {
                                    if (synchronousCall) {
                                      debugPrint(
                                        "Image loaded from cache: ${onboardingData[index]["image"]}",
                                      );
                                    } else {
                                      debugPrint(
                                        "Image fetched from network: ${onboardingData[index]["image"]}",
                                      );
                                    }
                                  }),
                                );

                                return Image(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              ColorUtils.primaryColor.withOpacity(0.5),
                              ColorUtils.primaryColor,
                              ColorUtils.secondaryColor,
                            ],
                            stops: const [0.0, 0.1, 0.2, 0.3, 1.0],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ColorUtils.primaryColor.withOpacity(0.8),
                              ColorUtils.secondaryColor.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: Get.height * 0.05,
                      left: 20,
                      right: 20,
                      child: Obx(() {
                        int index = controller.currentPage.value;
                        return Column(
                          children: [
                            Text(
                              onboardingData[index]["title"]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isRtl ? 40.sp : 50.sp,
                                color: ColorUtils.darkBrown,
                                // fontWeight: FontWeight.w500,
                                fontFamily: isRtl ? "Aref" : "Signature",
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              onboardingData[index]["short_description"]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            AppButton(
                              text:
                                  controller.currentPage.value ==
                                          onboardingData.length - 1
                                      ? "continue".tr
                                      : "Next".tr,
                              onTap: () {
                                controller.nextPage();
                              },
                            ),
                          ],
                        );
                      }),
                    ),

                    Positioned(
                      top: 50,
                      right: isRtl ? null : 20,
                      left: isRtl ? 20 : null,
                      child: Obx(
                        () =>
                            controller.currentPage.value <
                                    onboardingData.length - 1
                                ? InkWell(
                                  onTap: controller.skip,
                                  child: Container(
                                    width: 80, // Specific width
                                    height: 35, // Specific height
                                    // padding: EdgeInsets.symmetric(
                                    //   horizontal: 12.w,
                                    //   vertical: 4.h,
                                    // ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          blurRadius: 4.r,
                                          offset: Offset(0, 2.h),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      // Center content in container
                                      children: [
                                        Text(
                                          "Skip".tr,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                        ),
                                        // SizedBox(width: 4.w),
                                        Icon(
                                          isRtl
                                              ? Icons.chevron_left_rounded
                                              : Icons.chevron_right_rounded,
                                          size: 18.sp,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox(),
                      ),
                    ),

                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SmoothPageIndicator(
                          controller: controller.pageController,
                          count: onboardingData.length,
                          textDirection:
                              isRtl ? TextDirection.rtl : TextDirection.ltr,
                          effect: ExpandingDotsEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            activeDotColor: ColorUtils.primaryColor,
                            dotColor: ColorUtils.grey,
                            expansionFactor: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
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
      btnOkColor: ColorUtils.primaryColor,
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
