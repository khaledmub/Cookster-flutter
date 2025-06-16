import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../../../appUtils/apiEndPoints.dart';
import '../../../services/apiClient.dart';
import '../landingTabs/add/videoUploadSettingsModel/videoUploadSettingsModel.dart';

class NavBarController extends GetxController {
  var selectedIndex = 0.obs;
  var videoUploadSettings = Rxn<VideoUploadSettings>();

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  Future<void> getVideoUploadSettings() async {
    try {
      var response = await ApiClient.getRequest(EndPoints.videoTypes).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Get.offAllNamed('/noInternet');
          throw TimeoutException("The connection has timed out!");
        },
      );

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

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    getVideoUploadSettings();
  }
}
