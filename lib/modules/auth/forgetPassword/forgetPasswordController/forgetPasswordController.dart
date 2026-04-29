import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../appRoutes/appRoutes.dart';
import '../../../../services/apiClient.dart';

class ForgotPasswordController extends GetxController {
  var isObscure = true.obs;
  var isConfirmObscure = true.obs;

  void toggleObscure() {
    isObscure.value = !isObscure.value;
  }

  void toggleConfirmObscure() {
    isConfirmObscure.value = !isConfirmObscure.value;
  }

  final TextEditingController emailController = TextEditingController();
  final otpController = TextEditingController();
  var otpValue = ''.obs;
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String userName = '';
  var isLoading = false.obs;
  var isOtpSent = false.obs;
  var isOtpVerified = false.obs; // New state for OTP verification
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String? _userId; // Store user_id from verifyEmail response
  int? _medium; // Store medium from verifyEmail response
  String? _token; // Store token from verifyOtp response
  String? _lastRequestedEmail;

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'email_required_error'.tr;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'email_invalid_error'.tr;
    return null;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'password_required_error'.tr;
    } else if (password.length < 8) {
      return 'password_length_error'.tr;
    } else if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'password_uppercase_error'.tr;
    } else if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'password_special_char_error'.tr;
    }
    return null; // Password is valid
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'confirm_password'.tr;
    if (value != newPasswordController.text) return 'passwords_do_not_match'.tr;
    return null;
  }

  // Step 1: Verify Email (Backend sends OTP automatically)
  Future<bool> verifyEmail() async {
    if (!formKey.currentState!.validate()) return false;

    isLoading.value = true;
    final endpoint =
        EndPoints.verifyEmail; // e.g., 'forgot_password/verify_email'
    final email = emailController.text.trim();
    _lastRequestedEmail = email;

    try {
      // Some backend deployments expect medium=1 for email while others accept
      // medium=2; we try both before failing.
      Future<bool> tryVerifyWithMedium(int medium) async {
        final response = await ApiClient.postRequest(endpoint, {
          'email': email,
          'medium': medium,
        });
        final data = jsonDecode(response.body);
        print("Verify Email Response (medium=$medium): $data");

        if (response.statusCode == 200 && data['status'] == true) {
          // Store user_id and medium for OTP verification
          _userId =
              data['user']?['id']?.toString() ??
              data['user_id']?.toString() ??
              data['id']?.toString();
          _medium =
              data['medium'] is int
                  ? data['medium']
                  : int.tryParse('${data['medium'] ?? medium}') ?? medium;

          if (_userId == null || _userId!.isEmpty) {
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] ??
                      'Could not start reset flow. Please try again.',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return false;
          }

          isOtpSent.value = true; // Indicate OTP has been sent
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ??
                    'OTP sent to $email. Please check inbox/spam.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return true; // OTP is sent by backend, proceed to OTP input
        }
        return false;
      }

      final sentWithEmailMedium = await tryVerifyWithMedium(1);
      if (sentWithEmailMedium) return true;

      final sentWithAltMedium = await tryVerifyWithMedium(2);
      if (sentWithAltMedium) return true;

      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(
          content: Text('Failed to send OTP. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String get lastRequestedEmail => _lastRequestedEmail ?? emailController.text.trim();

  // Step 2: Verify OTP
  Future<bool> verifyOtp() async {
    String code = otpController.text;
    if (code.length != 5) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (_userId == null || _medium == null) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text(
            'User ID or medium not available. Please verify email again.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    isLoading.value = true;
    final endpoint = EndPoints.verifyCode; // e.g., 'forgot_password/verify_otp'

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': _userId,
        'code': code,
        'medium': _medium,
      });

      final data = jsonDecode(response.body);
      print("Verify OTP Response: $data");

      if (response.statusCode == 200 && data['status'] == true) {
        // Save token if provided
        if (data['token'] != null) {
          _token = data['token'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _token!);
        }

        isOtpVerified.value = true; // Indicate OTP is verified
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'OTP verified successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Invalid OTP'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Step 3: Reset Password
  Future<bool> resetPassword() async {
    if (!formKey.currentState!.validate()) return false;

    isLoading.value = true;
    final endpoint =
        EndPoints.updatePassword; // e.g., 'forgot_password/reset_password'

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': _userId,
        'password': newPasswordController.text.trim(),
      });

      final data = jsonDecode(response.body);
      print("Reset Password Response: $data");

      if (response.statusCode == 200 && data['status'] == true) {
        String token = data['token'];
        Map<String, dynamic> user = data['user'];

        print(user['image']);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setInt('entity', user['entity']);
        await prefs.setString('user_id', user['id']);
        await prefs.setString('user_image', user['image'] ?? '');

        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Password reset successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Get.offAllNamed(AppRoutes.landing);
        return true;
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to reset password'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();

    super.onClose();
  }
}
