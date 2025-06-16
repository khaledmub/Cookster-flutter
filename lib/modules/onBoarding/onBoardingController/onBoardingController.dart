import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appRoutes/appRoutes.dart';
import '../../../services/apiClient.dart';
import '../onBoardingModel/onBoardingModel.dart';

class OnboardingController extends GetxController {
  final PageController pageController = PageController();
  var currentPage = 0.obs;
  var onboardingData = OnBoardingModel().obs;
  var isLoading = true.obs;

  @override
  void onInit() async {
    super.onInit();
    await checkIfOnboardingCompleted();
  }

  Future<void> checkIfOnboardingCompleted() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasCompletedOnboarding =
        prefs.getBool('onboarding_completed') ?? false;
    String? authToken = prefs.getString('auth_token');

    print("Auth Token: $authToken"); // ✅ Debug auth token
    print(
      "Onboarding Completed: $hasCompletedOnboarding",
    ); // ✅ Debug onboarding status

    if (authToken != null && authToken.isNotEmpty) {
      print("Navigating to Landing Screen");
      Get.offAllNamed(AppRoutes.landing);
    } else if (hasCompletedOnboarding) {
      print("Navigating to Sign-In Screen");
      Get.offAllNamed(AppRoutes.landing);
    } else {
      print("Showing Onboarding Screen");
      fetchOnboardingData();
    }
  }

  void nextPage() async {
    if (currentPage.value < (onboardingData.value.screens?.length ?? 1) - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    } else {
      await completeOnboarding();
      Get.offAllNamed(AppRoutes.landing);
    }
  }

  void skip() async {
    await completeOnboarding();
    Get.offAllNamed(AppRoutes.landing);
  }

  Future<void> completeOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  Future<void> fetchOnboardingData() async {
    try {
      print("Fetching onboarding data..."); // ✅ Step 1: Function started
      isLoading(true);

      print(
        "Calling API: ${EndPoints.onBoarding}",
      ); // ✅ Step 2: API call started
      var response = await ApiClient.getRequest('${EndPoints.onBoarding}');

      print(
        "Response received with status: ${response.statusCode}",
      ); // ✅ Step 3: Response received

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        print(
          "Decoded JSON Response: $jsonResponse",
        ); // ✅ Step 4: JSON decoding

        onboardingData.value = OnBoardingModel.fromJson(jsonResponse);
        print(
          "Onboarding data successfully assigned",
        ); // ✅ Step 5: Model assigned
      } else {
        print(
          "Error: Failed to load onboarding data",
        ); // ✅ Step 6: Error handling
        Get.snackbar("Error", "Failed to load onboarding data");
      }
    } catch (e) {
      print("Exception caught: $e"); // ✅ Step 7: Exception handling
      Get.snackbar("Error", "Something went wrong");
    } finally {
      isLoading(false);
      print("Loading state set to false"); // ✅ Step 8: Loading finished
    }
  }
}
