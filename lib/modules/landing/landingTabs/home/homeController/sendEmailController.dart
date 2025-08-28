import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../../../../services/apiClient.dart';

class EmailController extends GetxController {
  // Text Editing Controllers
  final videoIdController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final messageController = TextEditingController();

  // Form Key
  final formKey = GlobalKey<FormState>();

  // Loading state
  var isLoading = false.obs;

  // Validation method
  String? validateField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '${fieldName.toLowerCase()}_is_required'.tr;
    }
    if (fieldName == 'Email' && !GetUtils.isEmail(value)) {
      return 'please_enter_a_valid_email'.tr;
    }
    if (fieldName == 'Phone' && !GetUtils.isPhoneNumber(value)) {
      return 'please_enter_a_valid_phone_number'.tr;
    }
    return null;
  }

  // POST request to submit user data
  Future<void> submitUserData(String videoId) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      isLoading.value = true;

      final data = {
        'video_id': videoId,
        'name': nameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
        'message': messageController.text,
      };

      final response = await ApiClient.postRequest(EndPoints.submitEmail, data);

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message =
            responseBody['message'] ?? 'user_data_submitted_successfully'.tr;
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          title: 'success'.tr,
          desc: message,
          btnOkOnPress: () {
            Get.back();
          },
          btnOkText: 'ok'.tr,
        ).show();

        nameController.clear();
        emailController.clear();
        phoneController.clear();
        messageController.clear();
      } else {
        final errorMessage =
            responseBody['message'] ??
            'failed_to_submit_data'.trParams({
              'statusCode': response.statusCode.toString(),
            });
        Get.snackbar(
          'error'.tr,
          errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'an_error_occurred'.trParams({'error': e.toString()}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    // Dispose controllers when controller is removed
    videoIdController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    messageController.dispose();
    super.onClose();
  }
}
