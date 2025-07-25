import 'dart:async';
import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:update_available/update_available.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../services/apiClient.dart';
import '../../../services/appConfig/app_config_service.dart';
import '../landingTabs/add/videoUploadSettingsModel/videoUploadSettingsModel.dart';

class NavBarController extends GetxController {
  var selectedIndex = 0.obs;
  var videoUploadSettings = Rxn<VideoUploadSettings>();

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  var availabilityText = ''.obs;

  Future<void> getVideoUploadSettings() async {
    try {
      var response = await ApiClient.getRequest(EndPoints.videoTypes);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        videoUploadSettings.value = VideoUploadSettings.fromJson(data);
      } else {
        print("Error fetching video settings: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching video upload settings: $e");
    }
  }

  Future<void> checkForUpdate() async {
    try {
      // Step 1: Check for update using the update_available package
      print("Step 1: Checking for update availability");
      final availability = await getUpdateAvailability();

      String availabilityText = switch (availability) {
        UpdateAvailable() => "There's an update available!",
        NoUpdateAvailable() => "There's no update available!",
        UnknownAvailability() =>
          "Sorry, couldn't determine if there is or not an available update!",
      };

      // Show AwesomeDialog based on update availability
      if (availability is UpdateAvailable) {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.info,
          animType: AnimType.bottomSlide,
          title: 'update_title'.tr,
          desc: 'update_description'.tr,
          btnCancelOnPress: () {
            // Handle cancel button press
            print("Update cancelled by user");
          },
          btnOkOnPress: () async {
            // Handle update button press
            final storeUrl = _getStoreUrl();
            if (storeUrl.isNotEmpty) {
              final Uri url = Uri.parse(storeUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                Get.snackbar('Error', 'Could not open store URL');
              }
            }
          },
          btnOkText: 'update_now'.tr,
          btnCancelText: 'cancel'.tr,
        ).show();
      } else {
        // AwesomeDialog(
        //   context: Get.context!,
        //   dialogType: DialogType.info,
        //   animType: AnimType.bottomSlide,
        //   title: 'update_title'.tr,
        //   desc: 'update_description'.tr,
        //   btnCancelOnPress: () {
        //     // Handle cancel button press
        //     print("Update cancelled by user");
        //   },
        //   btnOkOnPress: () async {
        //     // Handle update button press
        //     final storeUrl = _getStoreUrl();
        //     if (storeUrl.isNotEmpty) {
        //       final Uri url = Uri.parse(storeUrl);
        //       if (await canLaunchUrl(url)) {
        //         await launchUrl(url, mode: LaunchMode.externalApplication);
        //       } else {
        //         Get.snackbar('Error', 'Could not open store URL');
        //       }
        //     }
        //   },
        //   btnOkText: 'update_now'.tr,
        //   btnCancelText: 'cancel'.tr,
        // ).show();
      }

      print("This is the update value check here: $availabilityText");
    } catch (e) {
      print("Step 14: Error checking for update: $e");
      // Get.snackbar(
      //   'Error',
      //   'Failed to check for updates. Please try again later.',
      // );
    }
  }

  String _getStoreUrl() {
    // Store URLs for Cookster app
    const androidStoreUrl =
        'https://play.google.com/store/apps/details?id=com.cookster.cooksterapp';
    const iosStoreUrl =
        'https://apps.apple.com/us/app/cookster-%D9%83%D9%88%D9%83%D8%B3%D8%AA%D8%B1/id6746804733';

    if (GetPlatform.isAndroid) {
      return androidStoreUrl;
    } else if (GetPlatform.isIOS) {
      return iosStoreUrl;
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    // Fetch video settings and check for updates sequentially
    getVideoUploadSettings();
  }
}
