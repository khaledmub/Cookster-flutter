import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:update_available/update_available.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/video_settings_service.dart';
import '../landingTabs/add/videoUploadSettingsModel/videoUploadSettingsModel.dart';

class NavBarController extends GetxController {
  static const _dismissedLocalVersionKey = 'update_prompt_dismissed_local_version';
  static const _dismissedAtKey = 'update_prompt_dismissed_at_ms';
  static const _snoozeDuration = Duration(days: 7);

  var selectedIndex = 0.obs;
  var videoUploadSettings = Rxn<VideoUploadSettings>();

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  var availabilityText = ''.obs;

  Future<void> getVideoUploadSettings() async {
    try {
      final settings = await VideoSettingsService.instance.load();
      videoUploadSettings.value = settings;
    } catch (e) {
      debugPrint('Error fetching video upload settings: $e');
    }
  }

  Future<void> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;
      debugPrint(
        'Update check: local=$localVersion '
        '(build ${packageInfo.buildNumber})',
      );

      final availability = await getUpdateAvailability(
        // Prefer SA store listing for Cookster's primary market.
        iosAppStoreRegion: GetPlatform.isIOS ? 'sa' : null,
      );

      availabilityText.value = switch (availability) {
        UpdateAvailable() => "There's an update available!",
        NoUpdateAvailable() => "There's no update available!",
        UnknownAvailability() =>
          "Sorry, couldn't determine if there is or not an available update!",
      };
      debugPrint('Update check result: ${availabilityText.value}');

      if (availability is! UpdateAvailable) {
        return;
      }

      if (await _isUpdatePromptSnoozed(localVersion)) {
        debugPrint(
          'Update prompt snoozed for local version $localVersion',
        );
        return;
      }

      final context = Get.context;
      if (context == null) {
        return;
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.info,
        animType: AnimType.bottomSlide,
        title: 'update_title'.tr,
        desc: 'update_description'.tr,
        btnCancelOnPress: () {
          unawaited(_snoozeUpdatePrompt(localVersion));
        },
        btnOkOnPress: () async {
          // Opening the store counts as acknowledging the prompt so it does
          // not immediately reappear if the user returns without updating.
          await _snoozeUpdatePrompt(localVersion);
          final storeUrl = _getStoreUrl();
          if (storeUrl.isEmpty) {
            return;
          }
          final url = Uri.parse(storeUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            Get.snackbar('Error', 'Could not open store URL');
          }
        },
        btnOkText: 'update_now'.tr,
        btnCancelText: 'cancel'.tr,
      ).show();
    } catch (e) {
      debugPrint('Error checking for update: $e');
    }
  }

  Future<bool> _isUpdatePromptSnoozed(String localVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedLocalVersionKey);
    final dismissedAtMs = prefs.getInt(_dismissedAtKey);
    if (dismissedVersion != localVersion || dismissedAtMs == null) {
      return false;
    }
    final dismissedAt =
        DateTime.fromMillisecondsSinceEpoch(dismissedAtMs, isUtc: true);
    return DateTime.now().toUtc().difference(dismissedAt) < _snoozeDuration;
  }

  Future<void> _snoozeUpdatePrompt(String localVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedLocalVersionKey, localVersion);
    await prefs.setInt(
      _dismissedAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  String _getStoreUrl() {
    const androidStoreUrl =
        'https://play.google.com/store/apps/details?id=com.cookster.cooksterapp';
    const iosStoreUrl =
        'https://apps.apple.com/us/app/cookster-%D9%83%D9%88%D9%83%D8%B3%D8%AA%D8%B1/id6746804733';

    if (GetPlatform.isAndroid) {
      return androidStoreUrl;
    }
    if (GetPlatform.isIOS) {
      return iosStoreUrl;
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    getVideoUploadSettings();
  }
}
