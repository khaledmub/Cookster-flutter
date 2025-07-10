import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddReviewController extends GetxController {
  final String professionalId;
  var rating = 0.0.obs;
  var characterCount = 0.obs;
  final int maxCharacters = 500;
  var language = 'en'.obs;
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

  void submitReview(BuildContext context) {
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

    // TODO: Implement review submission logic
    print("Professional ID: $professionalId");
    print("Rating: ${rating.value}");
    print("Review: ${reviewController.text}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("review_submitted_successfully".tr),
        backgroundColor: Colors.green,
      ),
    );

    Get.back();
  }
}
