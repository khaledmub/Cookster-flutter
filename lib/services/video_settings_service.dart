import 'dart:convert';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoUploadSettingsModel/videoUploadSettingsModel.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:get/get.dart';

/// Single in-flight fetch + in-memory cache for `GET videos/settings`.
class VideoSettingsService extends GetxService {
  static VideoSettingsService get instance => Get.find<VideoSettingsService>();

  final Rxn<VideoUploadSettings> settings = Rxn<VideoUploadSettings>();
  Future<VideoUploadSettings?>? _inFlight;

  Future<VideoUploadSettings?> load({bool forceRefresh = false}) async {
    if (!forceRefresh && settings.value != null) {
      return settings.value;
    }
    if (!forceRefresh && _inFlight != null) {
      return _inFlight;
    }

    _inFlight = _fetch();
    try {
      return await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<VideoUploadSettings?> _fetch() async {
    try {
      final response = await ApiClient.getRequest(EndPoints.videoTypes);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final parsed = VideoUploadSettings.fromJson(data);
        _applySettings(parsed);
        return parsed;
      }
    } catch (e) {
      if (Get.isLogEnable) {
        print('VideoSettingsService error: $e');
      }
    }
    return settings.value;
  }

  void _applySettings(VideoUploadSettings parsed) {
    settings.value = parsed;
    _syncToControllers(parsed);
  }

  void _syncToControllers(VideoUploadSettings parsed) {
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().videoUploadSettings.value = parsed;
    }
    if (Get.isRegistered<ProfessionalProfileController>()) {
      Get.find<ProfessionalProfileController>().videoUploadSettings.value =
          parsed;
    }
    if (Get.isRegistered<NavBarController>()) {
      Get.find<NavBarController>().videoUploadSettings.value = parsed;
    }
  }
}
