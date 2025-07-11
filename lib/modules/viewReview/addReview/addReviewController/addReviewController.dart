import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Added for JSON decoding
import '../../../../services/apiClient.dart';

class AddReviewController extends GetxController {
  final String professionalId;
  var rating = 0.0.obs;
  var characterCount = 0.obs;
  final int maxCharacters = 500;
  var language = 'en'.obs;
  var isLoading = false.obs;
  final TextEditingController reviewController = TextEditingController();
  final FocusNode reviewFocusNode = FocusNode();

  AddReviewController({required this.professionalId});

  @override
  void onInit() {
    super.onInit();
    _loadLanguage();
    reviewController.addListener(() {
      characterCount.value = reviewController.text.length;
    });
  }

  @override
  void onClose() {
    reviewController.dispose();
    reviewFocusNode.dispose();
    super.onClose();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    language.value = prefs.getString('language') ?? 'en';
  }

  void submitReview(BuildContext context) async {
    if (rating.value == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("please_select_rating".tr),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("please_enter_review".tr),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    isLoading.value = true;

    final Map<String, dynamic> reviewData = {
      'reviewed_user_id': professionalId,
      'rating': rating.value,
      'review': reviewController.text,
    };

    try {
      final response = await ApiClient.postRequest(
        EndPoints.addReview,
        reviewData,
      );

      // Decode the response body
      final responseBody = jsonDecode(response.body);
      final String message = responseBody['message'] ?? "No message provided";
      final bool status = responseBody['status'] ?? false;

      print(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: status ? Colors.green : Colors.red,
        ),
      );

      if (status && response.statusCode == 200) {
        Get.back();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"), // Fallback message for exceptions
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }
}