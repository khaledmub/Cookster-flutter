import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/i18n/api_message_localizer.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../appBindings/app_bindings.dart';
import '../../../../services/apiClient.dart';
import '../signUpController/signUpController.dart';

class SignUpOtpController extends GetxController {
  final otpController = TextEditingController();
  var otpValue = ''.obs;
  var isLoading = false.obs;
  final deliveryNotice = ''.obs;

  Map<String, dynamic>? user;
  String email = '';
  String? deviceToken;
  bool _otpSentOnRegister = false;
  String _otpDelivery = '';
  bool _registrationResumed = false;
  bool _autoResendAttempted = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      user = args['user'] as Map<String, dynamic>?;
      email = (args['email'] as String?)?.trim() ?? '';
      deviceToken = args['deviceToken'] as String?;
      _otpSentOnRegister = args['otpSent'] == true;
      _otpDelivery = args['otpDelivery']?.toString() ?? '';
      _registrationResumed = args['resumed'] == true;
    }
    _refreshDeliveryNotice();
    if (user != null && email.isNotEmpty) {
      unawaited(_ensureRegistrationOtpDelivered());
    }
  }

  void _refreshDeliveryNotice() {
    if (_registrationResumed) {
      deliveryNotice.value = 'registration_resumed_notice'.tr;
      return;
    }
    switch (_otpDelivery) {
      case 'failed':
        deliveryNotice.value = 'otp_delivery_failed'.tr;
        break;
      case 'queued':
        deliveryNotice.value = 'otp_delivery_queued'.tr;
        break;
      case 'sent':
        deliveryNotice.value = '';
        break;
      default:
        if (!_otpSentOnRegister) {
          deliveryNotice.value = 'otp_delivery_failed'.tr;
        } else {
          deliveryNotice.value = '';
        }
    }
  }

  void _applyDeliveryFromResponse(Map<String, dynamic> data) {
    if (data.containsKey('otp_sent')) {
      _otpSentOnRegister = data['otp_sent'] == true;
    }
    final delivery = data['otp_delivery']?.toString();
    if (delivery != null && delivery.isNotEmpty) {
      _otpDelivery = delivery;
    } else if (_otpSentOnRegister) {
      _otpDelivery = 'sent';
    }
    _refreshDeliveryNotice();
  }

  Future<void> _ensureRegistrationOtpDelivered() async {
    if (_autoResendAttempted) {
      return;
    }
    _autoResendAttempted = true;

    final needsResend =
        !_otpSentOnRegister || _otpDelivery == 'failed' || _otpDelivery.isEmpty;
    if (!needsResend) {
      return;
    }

    await resendOtp(
      showSuccessOnDelivery: false,
      fromAutoRetry: true,
    );
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = Colors.red,
  }) {
    final ctx = Get.context;
    if (ctx == null || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> verifyOtp() async {
    final currentUser = user;
    if (currentUser == null) {
      _showSnackBar('otp_error_generic'.tr);
      return;
    }

    final code = otpController.text;
    if (code.length != 5) {
      _showSnackBar('otp_complete_error'.tr);
      return;
    }

    isLoading.value = true;
    final endpoint = EndPoints.verifyRegistrationOtp;

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': currentUser['id'].toString(),
        'code': code,
      });

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == true) {
        final token = data['token'] as String;
        final verifiedUser =
            (data['user'] as Map<String, dynamic>?) ?? currentUser;

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('auth_token', token);
        ApiClient.setAuthToken(token);
        await prefs.setInt('entity', verifiedUser['entity'] as int);
        await prefs.setString('user_id', verifiedUser['id'].toString());
        await prefs.setString(
          'user_image',
          verifiedUser['image']?.toString() ?? '',
        );
        if (verifiedUser['entity_details'] != null) {
          await prefs.setString(
            'entity_details',
            jsonEncode(verifiedUser['entity_details']),
          );
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(verifiedUser['id'].toString())
            .set({
              'id': verifiedUser['id'],
              'system_id': verifiedUser['system_id'],
              'name': verifiedUser['name'],
              'email': verifiedUser['email'],
              'phone': verifiedUser['phone'],
              'dob': verifiedUser['dob'],
              'image': verifiedUser['image'],
              'entity': verifiedUser['entity'],
              'status': verifiedUser['status'],
              'created_at': verifiedUser['created_at'],
              'updated_at': verifiedUser['updated_at'],
              'uuid': deviceToken,
            });

        if (Get.isRegistered<SignUpController>()) {
          Get.find<SignUpController>().clearForm();
        }

        showSuccessDialog();
      } else {
        _showSnackBar(
          ApiMessageLocalizer.localize(
            data['message'],
            fallbackLocaleKey: 'otp_invalid',
          ),
        );
      }
    } catch (e) {
      _showSnackBar('otp_error_generic'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp({
    bool showSuccessOnDelivery = true,
    bool fromAutoRetry = false,
  }) async {
    final currentUser = user;
    if (currentUser == null) {
      _showSnackBar('otp_error_generic'.tr);
      return;
    }

    isLoading.value = true;
    final endpoint = EndPoints.resendRegistrationOtp;

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'user_id': currentUser['id'].toString(),
      });

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == true) {
        _applyDeliveryFromResponse(data);

        final delivered = _otpSentOnRegister && _otpDelivery == 'sent';
        if (showSuccessOnDelivery && delivered) {
          _showSnackBar(
            ApiMessageLocalizer.localize(
              data['message'],
              fallbackLocaleKey: 'otp_resent_success',
            ),
            backgroundColor: Colors.green,
          );
        } else if (!delivered && !fromAutoRetry) {
          _showSnackBar(
            ApiMessageLocalizer.localize(
              data['message'],
              fallbackLocaleKey: 'otp_delivery_failed',
            ),
          );
        }
      } else {
        _showSnackBar(
          ApiMessageLocalizer.localize(
            data['message'],
            fallbackLocaleKey: 'otp_resend_failed',
          ),
        );
      }
    } catch (e) {
      _showSnackBar('otp_error_generic'.tr);
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
      title: 'success_title'.tr,
      desc: 'account created successfully'.tr,
      btnOkText: 'ok'.tr,
      btnOkOnPress: () {
        Get.offAll(
          () => Landing(initialIndex: 0),
          binding: LandingBinding(),
        );
      },
    )..show();
  }
}
