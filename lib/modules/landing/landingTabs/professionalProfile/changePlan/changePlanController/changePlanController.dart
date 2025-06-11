import 'dart:convert';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../../../../../../services/apiClient.dart';
import '../../profileControlller/professionalProfileController.dart';
import '../changePlanModel/changePlanModel.dart';

class ChangePlanController extends GetxController {
  var packagesList = ChangePlanModel().obs;
  var isLoading = false.obs;
  var selectedPackageId = ''.obs;
  var isProfileCreating = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Fetch data when the controller is initialized
    fetchChangePlanPackages();
  }

  // Fetch change plan packages using GET request
  Future<void> fetchChangePlanPackages() async {
    try {
      isLoading.value = true;
      final response = await ApiClient.getRequest(EndPoints.changePlanPackages);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        packagesList.value = ChangePlanModel.fromJson(jsonData);
      } else {
        print('Failed to load packages: ${response.statusCode}');
        Get.snackbar('Error', 'Failed to load packages');
      }
    } catch (e) {
      print('Error fetching packages: $e');
      Get.snackbar('Error', 'An error occurred while fetching packages');
    } finally {
      isLoading.value = false;
    }
  }

  // Select a package
  void selectPackage(String packageId) {
    selectedPackageId.value = packageId;
  }

  // Submit the selected package
  Future<void> submitForm({
    required String packageId,
    required paymentParams,
  }) async {
    final ProfessionalProfileController profileController = Get.find();
    try {
      isProfileCreating.value = true;
      final response = await ApiClient.postRequest(
        EndPoints.subscribe,
        // Assuming EndPoints.subscribe is the endpoint for subscription
        {
          'package_id': packageId,
          "PaymentId": paymentParams["PaymentId"]?.toString() ?? "",
          "TranId": paymentParams["TranId"]?.toString() ?? "",
          "ECI": paymentParams["ECI"]?.toString() ?? "",
          "TrackId": paymentParams["TrackId"]?.toString() ?? "",
          "RRN": paymentParams["RRN"]?.toString() ?? "",
          "cardBrand": paymentParams["cardBrand"]?.toString() ?? "",
          "amount": paymentParams["amount"]?.toString() ?? "",
          "maskedPAN": paymentParams["maskedPAN"]?.toString() ?? "",
          "PaymentType": paymentParams["PaymentType"]?.toString() ?? "",
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // Assuming the API returns a success message or status
        if (jsonData['status'] == true) {
          var message = jsonData['message'];

          await profileController.getUserDetails();
          Get.to(Landing(initialIndex: 3));
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          Get.snackbar(
            'Error',
            jsonData['message'] ?? 'Failed to subscribe to package',
          );
        }
      } else {
        print('Failed to subscribe: ${response.statusCode}');
        Get.snackbar('Error', 'Failed to subscribe to package');
      }
    } catch (e) {
      print('Error subscribing to package: $e');
      Get.snackbar('Error', 'An error occurred while subscribing to package');
    } finally {
      isProfileCreating.value = false;
    }
  }
}
