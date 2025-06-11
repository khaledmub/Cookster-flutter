import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/sendEmailController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SendEmailContact extends StatefulWidget {
  String videoId;

  SendEmailContact({super.key, required this.videoId});

  @override
  State<SendEmailContact> createState() => _SendEmailContactState();
}

class _SendEmailContactState extends State<SendEmailContact> {
  late FocusNode videoIdFocusNode;
  late FocusNode nameFocusNode;
  late FocusNode emailFocusNode;
  late FocusNode phoneFocusNode;
  late FocusNode messageNode;
  final _nameKey = GlobalKey<FormFieldState>();
  final _emailKey = GlobalKey<FormFieldState>();
  final _phoneKey = GlobalKey<FormFieldState>();
  final _messageKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    videoIdFocusNode = FocusNode();
    nameFocusNode = FocusNode();
    emailFocusNode = FocusNode();
    phoneFocusNode = FocusNode();
    messageNode = FocusNode();
  }

  @override
  void dispose() {
    videoIdFocusNode.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    phoneFocusNode.dispose();
    messageNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EmailController userController = Get.put(EmailController());

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
                    spacing: 8.h,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 2),
                      SizedBox(
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 16,
                              child: InkWell(
                                onTap: () async {
                                  Get.back();
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
                                      Icons.arrow_back
,
                                      color: ColorUtils.darkBrown,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 40.h,
                              width: 40.h,
                              child: Image.asset("assets/images/appIconC.png"),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Form(
                            key: userController.formKey,
                            child: Column(
                              spacing: 10.h,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 20.h),
                                Text(
                                  "send_email".tr,
                                  style: TextStyle(
                                    color: ColorUtils.darkBrown,
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "provide_your_details_for_contact".tr,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                _buildUserInputFields(userController),
                                SizedBox(height: 10.h),
                                Obx(
                                  () => AppButton(
                                    text: "submit_details".tr,
                                    onTap: () async {
                                      if (!userController.isLoading.value) {
                                        await userController.submitUserData(
                                          widget.videoId,
                                        );
                                      }
                                    },
                                    isLoading: userController.isLoading.value,
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
    );
  }

  Widget _buildUserInputFields(EmailController controller) {
    return Column(
      children: [
        SizedBox(height: 10.h),
        AppUtils.customPasswordTextField(
          controller: controller.nameController,
          validator: (value) => controller.validateField(value, 'Name'),
          focusNode: nameFocusNode,
          keyboardType: TextInputType.name,
          labelText: "name".tr,
          svgIconPath: "assets/icons/editProfile.svg",
          textInputAction: TextInputAction.next,
          isPasswordField: false,
          fieldKey: _nameKey,
        ),
        SizedBox(height: 10.h),
        AppUtils.customPasswordTextField(
          controller: controller.emailController,
          validator: (value) => controller.validateField(value, 'Email'),
          focusNode: emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          labelText: "email".tr,
          svgIconPath: "assets/icons/email.svg",
          textInputAction: TextInputAction.next,
          isPasswordField: false,
          fieldKey: _emailKey,
        ),
        SizedBox(height: 10.h),
        AppUtils.customPasswordTextField(
          controller: controller.phoneController,
          validator: (value) => controller.validateField(value, 'Phone'),
          focusNode: phoneFocusNode,
          keyboardType: TextInputType.phone,
          labelText: "phone".tr,
          svgIconPath: "assets/icons/phone.svg",
          textInputAction: TextInputAction.done,
          isPasswordField: false,
          fieldKey: _phoneKey,
        ),
        SizedBox(height: 10.h),
        AppUtils.customPasswordTextField(
          maxLines: 3,
          controller: controller.messageController,
          validator: (value) => controller.validateField(value, 'Message'),
          focusNode: messageNode,
          // keyboardType: TextInputType.text,
          labelText: "message".tr,
          svgIconPath: "assets/icons/chat.svg",
          textInputAction: TextInputAction.done,
          isPasswordField: false,
          fieldKey: _messageKey,
        ),
      ],
    );
  }
}
