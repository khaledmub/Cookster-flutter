import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signUpOtpController.dart';

class SignUpOtpView extends StatefulWidget {
  const SignUpOtpView({super.key});

  @override
  State<SignUpOtpView> createState() => _SignUpOtpViewState();
}

class _SignUpOtpViewState extends State<SignUpOtpView> {
  final List<FocusNode> _otpFocusNodes = List.generate(5, (_) => FocusNode());
  String _language = 'en';

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    Get.put(SignUpOtpController());
  }

  @override
  void dispose() {
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    final SignUpOtpController controller = Get.find();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorUtils.primaryColor,
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: Get.height,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: ColorUtils.goldGradient,
                    ),
                  ),
                  Column(
                    spacing: 12.h,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Positioned(
                            left: isRtl ? null : 16,
                            right: isRtl ? 16 : null,
                            top: 20,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Get.back();
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
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 4.h),
                              height: 50.h,
                              width: 50.h,
                              child: Image.asset(
                                "assets/images/appIconC.png",
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32.0,
                          ),
                          child: Column(
                            spacing: 10.h,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 20.h),
                              Text(
                                "verify_email".tr,
                                style: TextStyle(
                                  color: ColorUtils.darkBrown,
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "signup_otp_sent".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              _buildOtpInput(controller),
                              SizedBox(height: 10.h),
                              Obx(
                                () => AppButton(
                                  text: "verify_otp".tr,
                                  onTap: () async {
                                    if (!controller.isLoading.value) {
                                      await controller.verifyOtp();
                                    }
                                  },
                                  isLoading: controller.isLoading.value,
                                ),
                              ),
                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput(SignUpOtpController controller) {
    final defaultPinTheme = PinTheme(
      width: 50.w,
      height: 50.h,
      textStyle: TextStyle(
        fontSize: 20.sp,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10.r),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: ColorUtils.primaryColor),
      borderRadius: BorderRadius.circular(10.r),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(color: Colors.white),
    );

    return Column(
      children: [
        Pinput(
          length: 5,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: submittedPinTheme,
          controller: controller.otpController,
          focusNode: _otpFocusNodes[0],
          keyboardType: TextInputType.number,
          onChanged: (value) {
            controller.otpValue.value = value;
          },
          onCompleted: (pin) {
            if (!controller.isLoading.value) {
              controller.verifyOtp();
            }
          },
        ),
        SizedBox(height: 10.h),
        Obx(
          () => TextButton(
            onPressed: controller.isLoading.value
                ? null
                : () async {
                    await controller.resendOtp();
                  },
            child: Text(
              "Resend OTP to ${controller.email}",
              style: TextStyle(
                color: ColorUtils.darkBrown,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
