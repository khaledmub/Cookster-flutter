import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart'; // Import pinput package
import 'package:shared_preferences/shared_preferences.dart';
import '../forgetPasswordController/forgetPasswordController.dart';

class ForgetPasswordView extends StatefulWidget {
  const ForgetPasswordView({super.key});

  @override
  State<ForgetPasswordView> createState() => _ForgetPasswordViewState();
}

class _ForgetPasswordViewState extends State<ForgetPasswordView> {
  late FocusNode emailFocusNode;
  late FocusNode newPasswordFocusNode;
  late FocusNode confirmPasswordFocusNode;
  final _emailKey = GlobalKey<FormFieldState>();
  final _newPasswordKey = GlobalKey<FormFieldState>();
  final _confirmPasswordKey = GlobalKey<FormFieldState>();
  final List<FocusNode> _otpFocusNodes = List.generate(5, (_) => FocusNode());
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
    emailFocusNode = FocusNode();
    newPasswordFocusNode = FocusNode();
    confirmPasswordFocusNode = FocusNode();
    Get.put(ForgotPasswordController()); // Initialize controller
  }

  @override
  void dispose() {
    emailFocusNode.dispose();
    newPasswordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // Handle back button press (device or custom)
  Future<bool> _handleBackPress(ForgotPasswordController controller) async {
    if (controller.isOtpVerified.value) {
      // If on password reset step, go back to OTP step
      controller.isOtpVerified.value = false;
      controller.isOtpSent.value = true;
      return false; // Prevent default back navigation
    } else if (controller.isOtpSent.value) {
      // If on OTP step, go back to email step
      controller.isOtpSent.value = false;
      return false; // Prevent default back navigation
    }
    return true; // Allow default back navigation if on email step
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    final ForgotPasswordController controller = Get.find();

    String _getForgotPasswordMessage(ForgotPasswordController controller) {
      if (!controller.isOtpSent.value) {
        return "enter_email".tr;
      } else if (controller.isOtpSent.value &&
          !controller.isOtpVerified.value) {
        return "otp_sent".tr;
      } else {
        return "enter_new_password".tr;
      }
    }

    return WillPopScope(
      onWillPop: () async => await _handleBackPress(controller),
      child: Scaffold(
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
                            // Back Button on the Left
                            Positioned(
                              left: isRtl ? null : 16,
                              right: isRtl ? 16 : null,
                              top: 20,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  try {
                                    print("Tapped");
                                    // Handle custom back button tap
                                    bool shouldPop = await _handleBackPress(
                                      controller,
                                    );
                                    if (shouldPop) {
                                      Get.back();
                                    }
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
                                      isRtl
                                          ? Icons.arrow_back

                                          : Icons.arrow_back
,
                                      color: ColorUtils.darkBrown,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Center Logo
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
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40.r),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Form(
                              key: controller.formKey,
                              child: Column(
                                spacing: 10.h,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 20.h),
                                  Text(
                                    "forget_password".tr,
                                    style: TextStyle(
                                      color: ColorUtils.darkBrown,
                                      fontSize: 30.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Obx(() {
                                    return Text(
                                      textAlign: TextAlign.center,
                                      _getForgotPasswordMessage(controller),
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    );
                                  }),
                                  Obx(
                                    () =>
                                        controller.isOtpVerified.value
                                            ? _buildPasswordInputs(controller)
                                            : controller.isOtpSent.value
                                            ? _buildOtpInput(controller)
                                            : AppUtils.customPasswordTextField(
                                              controller:
                                                  controller.emailController,
                                              validator:
                                                  controller.validateEmail,
                                              focusNode: emailFocusNode,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              labelText: "Email".tr,
                                              svgIconPath:
                                                  "assets/icons/email.svg",
                                              textInputAction:
                                                  TextInputAction.done,
                                              isPasswordField: false,
                                              fieldKey: _emailKey,
                                            ),
                                  ),
                                  SizedBox(height: 10.h),
                                  Obx(
                                    () => AppButton(
                                      text:
                                          controller.isOtpVerified.value
                                              ? "reset_password".tr
                                              : controller.isOtpSent.value
                                              ? "verify_otp".tr
                                              : "verify_email".tr,
                                      onTap: () async {
                                        if (!controller.isLoading.value) {
                                          if (controller.isOtpVerified.value) {
                                            bool success =
                                                await controller
                                                    .resetPassword();
                                            // Handle success if needed
                                          } else if (controller
                                              .isOtpSent
                                              .value) {
                                            bool success =
                                                await controller.verifyOtp();
                                            // Handle success if needed
                                          } else {
                                            bool success =
                                                await controller.verifyEmail();
                                            // UI updates automatically
                                          }
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInput(ForgotPasswordController controller) {
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

    return Pinput(
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
    );
  }

  Widget _buildPasswordInputs(ForgotPasswordController controller) {
    return Column(
      children: [
        AppUtils.customPasswordTextField(
          obscureText: controller.isObscure.value,
          controller: controller.newPasswordController,
          validator: controller.validatePassword,
          focusNode: newPasswordFocusNode,
          keyboardType: TextInputType.text,
          toggleObscureText: controller.toggleObscure,
          labelText: "Enter New Password".tr,
          svgIconPath: "assets/icons/password.svg",
          textInputAction: TextInputAction.next,
          isPasswordField: true,
          fieldKey: _newPasswordKey,
        ),
        SizedBox(height: 10.h),
        AppUtils.customPasswordTextField(
          obscureText: controller.isConfirmObscure.value,
          toggleObscureText: controller.toggleConfirmObscure,
          controller: controller.confirmPasswordController,
          validator: controller.validateConfirmPassword,
          focusNode: confirmPasswordFocusNode,
          keyboardType: TextInputType.text,
          labelText: "confirm_password".tr,
          svgIconPath: "assets/icons/password.svg",
          textInputAction: TextInputAction.done,
          isPasswordField: true,
          fieldKey: _confirmPasswordKey,
        ),
      ],
    );
  }
}
