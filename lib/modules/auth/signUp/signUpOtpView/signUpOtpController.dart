import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/apiClient.dart';
import '../signUpController/signUpController.dart';

class SignUpOtpController extends GetxController {
  final otpController = TextEditingController();
  var otpValue = ''.obs;
  var isLoading = false.obs;

  late Map<String, dynamic> user;
  late String email;
  late String? deviceToken;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      user = args['user'];
      email = args['email'];
      deviceToken = args['deviceToken'];
    }
  }

  Future<void> verifyOtp() async {
    String code = otpController.text;
    if (code.length != 5) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    isLoading.value = true;
    final endpoint = EndPoints.verifyRegistrationOtp;

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': user['id'].toString(),
        'code': code,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        // Officially authenticate the user
        String token = data['token'];
        Map<String, dynamic> verifiedUser = data['user'] ?? user;

        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('auth_token', token);
        await prefs.setInt('entity', verifiedUser['entity']);
        await prefs.setString('user_id', verifiedUser['id']);
        await prefs.setString('user_image', verifiedUser['image'] ?? '');
        if (verifiedUser['entity_details'] != null) {
          await prefs.setString(
            'entity_details',
            jsonEncode(verifiedUser['entity_details']),
          );
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(verifiedUser['id'])
            .set({
              "id": verifiedUser['id'],
              "system_id": verifiedUser['system_id'],
              "name": verifiedUser['name'],
              "email": verifiedUser['email'],
              "phone": verifiedUser['phone'],
              "dob": verifiedUser['dob'],
              "image": verifiedUser['image'],
              "entity": verifiedUser['entity'],
              "status": verifiedUser['status'],
              "created_at": verifiedUser['created_at'],
              "updated_at": verifiedUser['updated_at'],
              "uuid": deviceToken,
            });

        // Clear SignUp Form
        if (Get.isRegistered<SignUpController>()) {
          Get.find<SignUpController>().clearForm();
        }

        // Show Success
        showSuccessDialog();

      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Invalid OTP'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp() async {
    isLoading.value = true;
    final endpoint = EndPoints.resendRegistrationOtp;

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': user['id'].toString(),
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'OTP resent successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to resend OTP'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    otpController.dispose();
    super.onClose();
  }

  void showSuccessDialog() {
    AwesomeDialog(
      context: Get.context!,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: "success_title".tr,
      desc: "account created successfully".tr,
      btnOkText: "ok".tr,
      btnOkOnPress: () {
        Get.offAll(Landing(initialIndex: 0));
      },
    )..show();
  }
}
