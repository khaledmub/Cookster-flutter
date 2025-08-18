import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/auth/signIn/signInController/signInController.dart';
import 'package:cookster/modules/initLanguageSelection/initLanguageView.dart';
import 'package:cookster/modules/promoteVideo/promoteVideoController/promoteVideoController.dart';
import 'package:cookster/modules/selectLanguage/selectLanguageView/selectLanguageView.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../appUtils/colorUtils.dart';
import '../../authSocailButton.dart';
import '../../forgetPassword/forgetPasswordView/forgetPasswordView.dart';
import '../../privacyPolicy/privacyPolicy.dart';

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  late FocusNode emailFocusNode;
  late FocusNode passwordFocusNode;
  final _emailKey = GlobalKey<FormFieldState>();
  final _passwordFieldKey = GlobalKey<FormFieldState>();
  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  final PromoteVideoController promoteVideoController = Get.put(
    PromoteVideoController(),
  );

  @override
  void initState() {
    super.initState();
    emailFocusNode = FocusNode();
    passwordFocusNode = FocusNode();
    _loadLanguage();
  }

  @override
  void dispose() {
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    final LogInController logInController = Get.put(LogInController());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorUtils.primaryColor,
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: logInController.formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Background
                            Container(
                              decoration: const BoxDecoration(
                                gradient: ColorUtils.goldGradient,
                              ),
                            ),
                            // Main content
                            Column(
                              children: [
                                SizedBox(height: 2.h),
                                // your header and content
                                buildFormContent(logInController),
                              ],
                            ),

                            // Positioned(
                            //   left: isRtl ? null : 16,
                            //   right: isRtl ? 16 : null,
                            //   top: 10.h,
                            //   child: GestureDetector(
                            //     behavior: HitTestBehavior.opaque,
                            //     onTap: () {
                            //       try {
                            //         print("Tapped");
                            //
                            //         // Check if there's a stack to go back to
                            //         if (Get.key.currentState!.canPop()) {
                            //           Get.back();
                            //         } else {
                            //           // Navigate to landing page if no stack behind
                            //           Get.offAllNamed(
                            //             AppRoutes.landing,
                            //           ); // or Get.offAll(LandingPage())
                            //         }
                            //       } catch (e) {
                            //         print(e);
                            //       }
                            //     },
                            //     child: Container(
                            //       height: 40,
                            //       width: 40,
                            //       decoration: const BoxDecoration(
                            //         color: Color(0xFFE6BE00),
                            //         shape: BoxShape.circle,
                            //       ),
                            //       child: Center(
                            //         child: Icon(
                            //           isRtl
                            //               ? Icons.arrow_back
                            //               : Icons.arrow_back,
                            //           color: ColorUtils.darkBrown,
                            //           size: 24,
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            // ),
                            AppCenterIcon(),
                            Positioned(
                              right: isRtl ? null : 16,
                              left: isRtl ? 16 : null,
                              child: InkWell(
                                onTap: () {
                                  Get.to(SelectLanguageView());
                                },
                                child: Container(
                                  margin: EdgeInsets.symmetric(vertical: 6.h),
                                  height: 50.h,
                                  width: 50.h,
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.language,
                                    color: ColorUtils.darkBrown,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildFormContent(LogInController logInController) {
    return SingleChildScrollView(
      child: Column(
        spacing: 10.h,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // SizedBox(height: 2),
          // SizedBox(
          //   width: double.infinity,
          //   child: Stack(
          //     alignment: Alignment.center,
          //
          //     children: [
          //       Container(
          //         height: 50.h,
          //         width: 50.h,
          //         child: Image.asset("assets/images/appIconC.png"),
          //       ),
          //     ],
          //   ),
          // ),
          SizedBox(height: 60.h),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
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
                    "sign in now".tr,
                    style: TextStyle(
                      color: ColorUtils.darkBrown,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'signInSubtitle'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  AppUtils.customPasswordTextField(
                    controller: logInController.emailController,
                    validator: logInController.validateEmail,
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,

                    labelText: "Email".tr,
                    svgIconPath: "assets/icons/email.svg",
                    textInputAction: TextInputAction.next,
                    isPasswordField: false,
                    fieldKey: _emailKey,
                  ),
                  Obx(() {
                    return AppUtils.customPasswordTextField(
                      svgIconPath: "assets/icons/password.svg",

                      obscureText: logInController.isObscure.value,
                      labelText: "password".tr,
                      validator: logInController.validatePassword,
                      controller: logInController.passwordController,
                      focusNode: passwordFocusNode,
                      fieldKey: _passwordFieldKey,
                      toggleObscureText:
                          logInController.togglePasswordVisibility,
                      isPasswordField: true,
                      onSubmitted: (_) async {
                        await logInController.loginUser();
                        //
                      },
                    );
                  }),
                  InkWell(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();

                      // Save 1 to SharedPreferences when the button is tapped
                      await prefs.setInt('google_sign_in', 0);
                      Get.to(ForgetPasswordView());
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "forget_password".tr,
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => AppButton(
                      text: "sign in",
                      onTap: () async {
                        if (!logInController.isLoading.value) {
                          if (logInController.formKey.currentState!
                              .validate()) {
                            final prefs = await SharedPreferences.getInstance();

                            await prefs.setInt('google_sign_in', 0);

                            await logInController.loginUser();
                          }
                        }
                      },
                      isLoading:
                          logInController.isLoading.value, // Pass loading state
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
          Text(
            "or sign in with".tr,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (Platform.isAndroid) // Only show on iOS devices
                  SocialButton(
                    backgroundColor: Color(0xFF3C79E6).withOpacity(0.2),
                    iconPath: 'assets/images/google.png',
                    onTap: () async {
                      // Get instance of SharedPreferences
                      final prefs = await SharedPreferences.getInstance();

                      // Save 1 to SharedPreferences when the button is tapped
                      await prefs.setInt('google_sign_in', 1);

                      // Call the Google sign-in function
                      await logInController.signInWithGoogle();
                    },
                  ),
                if (Platform.isAndroid) // Only show on iOS devices
                  SizedBox(width: 16),
                // Spacing between buttons
                if (Platform.isIOS) // Only show on iOS devices
                  SocialButton(
                    backgroundColor: Colors.black.withOpacity(0.2),
                    iconPath: 'assets/images/apple.png',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();

                      // Save 1 to SharedPreferences when the button is tapped
                      await prefs.setInt('google_sign_in', 1);

                      await logInController.signInWithApple();
                    },
                  ),
                // if (Platform.isIOS) SizedBox(width: 16),
                // // Add spacing if Apple button is shown
                // SocialButton(
                //   backgroundColor: Color(0xFF3C79E6).withOpacity(0.2),
                //
                //   iconPath: 'assets/images/facebook.png',
                //   onTap: () async {
                //     if (kDebugMode) {
                //       print('Facebook Clicked');
                //     }
                //     await logInController.signInWithFacebook();
                //   },
                // ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  height: 2,
                  color: Colors.black,
                  fontSize: 12.sp,
                ),
                children: [
                  TextSpan(text: "by-continue-agree".tr),
                  TextSpan(
                    text: "terms-conditions".tr,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(PolicyScreen(pageType: 3));
                          },
                  ),
                  TextSpan(text: "read-our".tr),
                  TextSpan(
                    text: "privacy-policy".tr,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(PolicyScreen(pageType: 2));
                          },
                  ),
                  TextSpan(text: "learn-data-share".tr),
                ],
              ),
            ),
          ),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 12.sp),
              children: [
                TextSpan(text: "no-account".tr),
                TextSpan(
                  text: "sign-up".tr,
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () async {
                          final prefs = await SharedPreferences.getInstance();

                          await prefs.setInt('google_sign_in', 0);
                          Get.toNamed(AppRoutes.signUp);

                          if (kDebugMode) {
                            print("Navigate to Sign Up screen");
                          }
                        },
                ),
              ],
            ),
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 12.sp),
              children: [
                TextSpan(text: "enquiry_contact_us".tr),
                TextSpan(
                  text: "contact_us".tr,
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () async {
                          // Get email from controller
                          final String? email =
                              promoteVideoController
                                  .siteSettings
                                  .value
                                  ?.settings
                                  ?.email;

                          if (email == null || email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email address not available'),
                              ),
                            );
                            return;
                          }

                          // Create the mailto URL
                          final Uri emailUri = Uri(
                            scheme: 'mailto',
                            path: email,
                            queryParameters: {
                              'subject': '', // Pre-fill subject
                            },
                          );

                          // Launch the mail app
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No email app found'),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ],
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
