import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/appUtils/form_snackbar.dart';
import 'package:cookster/core/navigation/upload_form_route.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urwaypayment/urwaypayment.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../../loaders/pulseLoader.dart';
import '../../../../../appBindings/app_bindings.dart';
import '../../../../../services/apiClient.dart';
import '../../../../../services/video_settings_service.dart';
import '../../../../../services/video_processing_service.dart';
import '../../../../../services/urway_response_config.dart';
import '../../../../promoteVideo/promoteVideoModel/promoteVideoModel.dart';
import '../../professionalProfile/profileControlller/professionalProfileController.dart';
import '../../profile/profileControlller/profileController.dart';

enum VisibilityOption { public, onlyFollowers, private }

extension VisibilityOptionExtension on VisibilityOption {
  int get value {
    switch (this) {
      case VisibilityOption.onlyFollowers:
        return 1;
      case VisibilityOption.public:
        return 2;
      case VisibilityOption.private:
        return 3;
    }
  }
}

class VideoAddController extends GetxController {
  /// GetBuilder ids — narrow rebuilds on the upload form (avoid whole-screen Obx).
  static const idUploadNav = 'upload_nav';
  static const idUploadTags = 'upload_tags';
  static const idUploadLocation = 'upload_location';
  static const idUploadSponsor = 'upload_sponsor';
  static const idUploadVideoType = 'upload_video_type';

  var currentStep = 1.obs; // Step tracking
  var selectedVisibility = VisibilityOption.public.obs; // Default to Public
  var selectedCountry = "".obs;
  var selectedCity = "".obs;
  var selectedDays = 1.obs;
  var selectedVideoType = "Basic".obs;
  var siteSettings = Rxn<SiteSettings>();
  List<String> _badWordsArabic = [];
  List<String> _badWordsEnglish = [];

  void setVideoType(String type) {
    selectedVideoType.value = type;
    print("Selected Video Type: $type");
  }

  Future<void> _loadBadWords() async {
    try {
      // Load Arabic bad words from remote URL
      final arabicResponse = await http.get(
        Uri.parse('https://cookster.org/badwords/ar.txt'),
      );

      if (arabicResponse.statusCode == 200) {
        final arabicData = arabicResponse.body;
        _badWordsArabic =
            arabicData
                .split('\n')
                .map((word) => word.trim().toLowerCase())
                .where((word) => word.isNotEmpty)
                .toList();
      } else {
        print('Failed to load Arabic bad words: ${arabicResponse.statusCode}');
      }

      // Load English bad words from remote URL
      final englishResponse = await http.get(
        Uri.parse('https://cookster.org/badwords/en.txt'),
      );

      if (englishResponse.statusCode == 200) {
        final englishData = englishResponse.body;
        _badWordsEnglish =
            englishData
                .split('\n')
                .map((word) => word.trim().toLowerCase())
                .where((word) => word.isNotEmpty)
                .toList();
      } else {
        print(
          'Failed to load English bad words: ${englishResponse.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading bad words: $e');
    }
  }

  String? checkBadWords(BuildContext context, String? value) {
    if (value == null || value.isEmpty)
      return null; // Skip if empty (handled by validator)

    final normalizedValue = value.trim().toLowerCase();
    if (_badWordsArabic.any((word) => normalizedValue.contains(word)) ||
        _badWordsEnglish.any((word) => normalizedValue.contains(word))) {
      return "bad_word_error".tr; // Translated error message
    }
    return null;
  }

  var isImage = "0".obs;

  final CityController cityController = Get.put(CityController());

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController videoTypeController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  final TextEditingController menuController = TextEditingController();
  var isUploadSuccessful = false.obs; // New variable to track success
  var uploadProgress = 0.0.obs;
  /// After bytes finish uploading: keep dialog open until playback is ready.
  var isPreparingPlayback = false.obs;
  int _lastUploadProgressPercent = -1;
  /// Bumps whenever the user abandons the form / starts a new attempt so an
  /// in-flight multipart + processing poll must not finish navigation.
  int _uploadSession = 0;
  http.Client? _uploadHttpClient;
  File? _cachedThumbnail;
  Future<File?>? _thumbnailInFlight;
  var selectedCountryId = 0.obs;

  int get visibilityValue => selectedVisibility.value.value;

  void setLocation(String location) => selectedCountry.value = location;

  var videoTitle = "".obs;
  var videoType = "".obs;
  var videoDescription = "".obs;
  var tagsList = <String>[].obs;
  var videoTypeError = "".obs;
  var menuList = <String>[].obs;
  var acceptOrder = false.obs;
  var publishType = "2".obs;
  var allowComments = true.obs;
  final RxInt selectedLocationId = (-1).obs;
  final RxInt selectedCityId = (-1).obs;
  var selectedSponsorCountryName = "".obs;
  var selectedSponsorLocationId = 0.obs;
  var selectedCities = <String>[].obs;
  var selectedCityIds = <int>[].obs;

  void toggleCity(String city, int cityId) {
    if (selectedCities.contains(city)) {
      selectedCities.remove(city);
      selectedCityIds.remove(cityId);
    } else {
      selectedCities.add(city);
      selectedCityIds.add(cityId);
    }
    print(
      "Selected Cities: ${selectedCities.toList()} (IDs: ${selectedCityIds.toList()})",
    );
  }

  final entityDetails = Rx<Map<String, dynamic>>({});

  Future<void> fetchEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? entityDetailsJson = prefs.getString('entity_details');
    entityDetails.value =
        entityDetailsJson != null ? jsonDecode(entityDetailsJson) : {};
    print('Fetched entity_details: ${entityDetails.value}');
  }

  Future<void> loadLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!Get.isRegistered<CityController>()) {
      Get.put(CityController());
    }

    // Load stored country and city from SharedPreferences
    String storedCountry = prefs.getString('currentCountry') ?? 'Unknown';
    String storedCity = prefs.getString('currentCity') ?? 'Unknown';
    final storedState = prefs.getString('currentState') ?? '';
    final storedCountryId =
        int.tryParse(prefs.getString('currentCountryId') ?? '') ?? 0;
    final storedCityId =
        int.tryParse(prefs.getString('currentCityId') ?? '') ?? 0;

    // Update the controller with the stored values
    selectedCountry.value = storedCountry;
    selectedCity.value = storedCity;

    if (storedCountryId > 0) {
      selectedLocationId.value = storedCountryId;
      selectedCountryId.value = storedCountryId;
    }
    if (storedCityId > 0) {
      selectedCityId.value = storedCityId;
    }

    if (storedCountry == 'Unknown' || storedCountry.trim().isEmpty) {
      return;
    }

    final ready = await ensureLocationIdsReady(
      alternateCityName: storedState,
    );
    if (!ready) {
      // Keep displayed GPS names — never wipe them to Unknown on a cold
      // settings/city race (that caused "select city" after first install).
      return;
    }
    await _persistResolvedLocationIds(prefs);
  }

  String _normalizeLocationName(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '');
  }

  bool _locationNamesMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final left = _normalizeLocationName(a);
    final right = _normalizeLocationName(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    // GPS sometimes returns longer labels than the API catalog.
    if (left.length >= 3 && right.length >= 3) {
      return left.contains(right) || right.contains(left);
    }
    return false;
  }

  Future<void> _persistResolvedLocationIds(SharedPreferences prefs) async {
    if (selectedLocationId.value > 0) {
      await prefs.setString(
        'currentCountryId',
        selectedLocationId.value.toString(),
      );
    }
    if (selectedCityId.value > 0) {
      await prefs.setString('currentCityId', selectedCityId.value.toString());
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().currentCityId.value =
            selectedCityId.value.toString();
      }
    }
  }

  /// Resolves country/city display names to API ids (required for upload).
  ///
  /// GPS prefs are always English (`en_US` placemarks). The app UI language may
  /// be Arabic, so we retry against an English settings/city list when needed.
  Future<bool> ensureLocationIdsReady({String? alternateCityName}) async {
    final profileController = Get.find<ProfileController>();
    final cityController = Get.isRegistered<CityController>()
        ? Get.find<CityController>()
        : Get.put(CityController());
    final prefs = await SharedPreferences.getInstance();

    alternateCityName ??= prefs.getString('currentState');

    // Seed from prefs if the form was reset before loadLocationData finished.
    if (selectedCountry.value.trim().isEmpty ||
        selectedCountry.value == 'Unknown') {
      final stored = prefs.getString('currentCountry');
      if (stored != null && stored.trim().isNotEmpty) {
        selectedCountry.value = stored;
      }
    }
    if (selectedCity.value.trim().isEmpty || selectedCity.value == 'Unknown') {
      final stored = prefs.getString('currentCity');
      if (stored != null && stored.trim().isNotEmpty) {
        selectedCity.value = stored;
      }
    }
    final storedCountryId =
        int.tryParse(prefs.getString('currentCountryId') ?? '') ?? 0;
    final storedCityId =
        int.tryParse(prefs.getString('currentCityId') ?? '') ?? 0;
    if (selectedLocationId.value <= 0 && storedCountryId > 0) {
      selectedLocationId.value = storedCountryId;
      selectedCountryId.value = storedCountryId;
    }
    if (selectedCityId.value <= 0 && storedCityId > 0) {
      selectedCityId.value = storedCityId;
    }

    if (selectedLocationId.value > 0 &&
        selectedCountryId.value > 0 &&
        selectedCityId.value > 0) {
      final country = selectedCountry.value.trim();
      final city = selectedCity.value.trim();
      if (country.isNotEmpty &&
          city.isNotEmpty &&
          country != 'Unknown' &&
          city != 'Unknown') {
        await _persistResolvedLocationIds(prefs);
        return true;
      }
    }

    Future<bool> resolveOnce({String? acceptLanguage}) async {
      await VideoSettingsService.instance.load(
        forceRefresh: acceptLanguage != null,
        acceptLanguage: acceptLanguage,
      );
      final countries = profileController.videoUploadSettings.value?.countries;
      if (countries == null || countries.isEmpty) return false;

      final country = selectedCountry.value.trim();
      final city = selectedCity.value.trim();
      if (country.isEmpty ||
          city.isEmpty ||
          country == 'Unknown' ||
          city == 'Unknown') {
        return false;
      }

      int? countryId = selectedLocationId.value > 0
          ? selectedLocationId.value
          : null;
      if (countryId == null || countryId <= 0) {
        for (final c in countries) {
          if (_locationNamesMatch(c.name, country) && c.id != null) {
            countryId = c.id;
            break;
          }
        }
      }
      if (countryId == null || countryId <= 0) return false;

      selectedLocationId.value = countryId;
      selectedCountryId.value = countryId;

      final needsCities = cityController.loadedCountryId != countryId ||
          cityController.cityList.isEmpty;
      if (needsCities) {
        await cityController.fetchCities(
          countryId,
          acceptLanguage: acceptLanguage,
        );
      }
      // First-install races: city endpoint can return empty once — retry.
      if (cityController.cityList.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await cityController.fetchCities(
          countryId,
          acceptLanguage: acceptLanguage,
        );
      }
      if (cityController.cityList.isEmpty) return false;

      if (selectedCityId.value > 0 &&
          cityController.cityList.any(
            (c) =>
                c.id == selectedCityId.value &&
                (_locationNamesMatch(c.name, city) ||
                    _locationNamesMatch(c.name, alternateCityName)),
          )) {
        return true;
      }

      for (final candidate in <String?>[city, alternateCityName]) {
        if (candidate == null ||
            candidate.trim().isEmpty ||
            candidate == 'Unknown') {
          continue;
        }
        for (final c in cityController.cityList) {
          if (_locationNamesMatch(c.name, candidate) && c.id != null) {
            selectedCityId.value = c.id!;
            if (!_locationNamesMatch(selectedCity.value, c.name) &&
                c.name != null &&
                c.name!.trim().isNotEmpty) {
              // Keep GPS label in UI; id is what upload needs.
            }
            return true;
          }
        }
      }
      return false;
    }

    if (await resolveOnce()) {
      await _persistResolvedLocationIds(prefs);
      return true;
    }
    // GPS placemarks are English — retry API catalog in English when the
    // active UI language did not match (common on Arabic first install).
    if (await resolveOnce(acceptLanguage: 'en')) {
      await _persistResolvedLocationIds(prefs);
      return true;
    }
    return false;
  }

  void validateSelectedCountry() {
    unawaited(ensureLocationIdsReady());
  }

  // Not GlobalKeys — those lived on this persistent GetX controller and
  // reactivated disposed Form elements across upload sessions.
  bool Function()? validateStep1Form;
  bool Function()? validateStep2Form;

  void initializeTags(List<String> tags) {
    tagsList.clear();
    tagsList.addAll(
      tags.take(5).where((tag) => tag.isNotEmpty),
    ); // Limit to 5 non-empty tags
  }

  double calculateBasePrice() {
    if (siteSettings.value == null || siteSettings.value!.settings == null) {
      return 0.0;
    }

    final days = selectedDays.value;
    final numberOfCities =
        selectedCities.length; // Get the number of selected cities
    if (numberOfCities == 0) {
      print("No cities selected, returning base price as 0");
      return 0.0;
    }
    final settings = siteSettings.value!.settings!;
    final price =
        selectedVideoType.value == "Basic"
            ? (settings.basicSponsoredVideoPrice is num
                ? settings.basicSponsoredVideoPrice.toDouble()
                : double.tryParse(
                      settings.basicSponsoredVideoPrice?.toString() ?? "0",
                    ) ??
                    0.0)
            : (settings.premiumSponsoredVideoPrice is num
                ? settings.premiumSponsoredVideoPrice.toDouble()
                : double.tryParse(
                      settings.premiumSponsoredVideoPrice?.toString() ?? "0",
                    ) ??
                    0.0);

    // Updated formula: price * number of cities * days
    final basePrice = price * numberOfCities * days;
    print(
      "Base Price Calculation: Price (SAR $price) * Cities ($numberOfCities) * Days ($days) = SAR $basePrice",
    );
    return basePrice;
  }

  double calculateTotalPrice() {
    if (siteSettings.value == null || siteSettings.value!.settings == null) {
      return 0.0;
    }

    final basePrice = calculateBasePrice();
    double totalPrice = basePrice;

    if (entityDetails.value['subscription_required'] == 1) {
      final settings = siteSettings.value!.settings!;
      final discountPercentage =
          settings.sponsorVideoDiscount is num
              ? settings.sponsorVideoDiscount.toDouble()
              : double.tryParse(
                    settings.sponsorVideoDiscount?.toString() ?? "0",
                  ) ??
                  0.0;
      final discountAmount = basePrice * (discountPercentage / 100);
      totalPrice -= discountAmount;
    }

    final finalPrice = totalPrice < 0 ? 0.0 : totalPrice;
    print(
      "Calculated Total Price: SAR $finalPrice (Base: $basePrice, Discount: ${entityDetails.value['subscription_required'] == 1 ? (siteSettings.value!.settings!.sponsorVideoDiscount ?? 0) : 0}%)",
    );
    return finalPrice;
  }

  double calculateDiscountAmount() {
    if (entityDetails.value['subscription_required'] != 1 ||
        siteSettings.value == null ||
        siteSettings.value!.settings == null) {
      return 0.0;
    }

    final basePrice = calculateBasePrice();
    final settings = siteSettings.value!.settings!;
    final discountPercentage =
        settings.sponsorVideoDiscount is num
            ? settings.sponsorVideoDiscount.toDouble()
            : double.tryParse(
                  settings.sponsorVideoDiscount?.toString() ?? "0",
                ) ??
                0.0;
    return basePrice * (discountPercentage / 100);
  }

  bool hasUnsavedChanges() {
    return videoTitle.value.isNotEmpty ||
        videoDescription.value.isNotEmpty ||
        videoType.value.isNotEmpty ||
        tagsList.isNotEmpty ||
        menuList.isNotEmpty ||
        selectedCountry.value.isNotEmpty;
  }

  Future<bool> onWillPop(BuildContext context) async {
    // Leaving during upload/processing — always abandon that attempt.
    if (isVideoUploading.value || isPreparingPlayback.value) {
      resetController();
      return true;
    }

    if (hasUnsavedChanges()) {
      bool shouldPop = false;

      await Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Container(
            width: 350.w,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 50.w,
                ),
                SizedBox(height: 16.h),
                Text(
                  "discard_changes_title".tr,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "discard_changes_message".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.back(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                      ),
                      child: Text(
                        "stay_button".tr,
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        shouldPop = true;
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primaryColor,
                      ),
                      child: Text(
                        "discard_button".tr,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (shouldPop) {
        resetController();
        return true;
      }
      return false;
    }

    resetController();
    return true;
  }

  /// Aborts multipart upload + processing poll so leaving the form cannot
  /// still navigate to profile when a previous attempt finishes later.
  void cancelPendingUpload() {
    _uploadSession++;
    isPreparingPlayback.value = false;
    isVideoUploading.value = false;
    isCompressing.value = false;
    _closeUploadHttpClient();
  }

  void _closeUploadHttpClient() {
    final client = _uploadHttpClient;
    _uploadHttpClient = null;
    try {
      client?.close();
    } catch (_) {}
  }

  bool _isUploadSessionActive(int session) => session == _uploadSession;

  int _beginUploadSession() {
    cancelPendingUpload();
    final session = _uploadSession;
    _uploadHttpClient = http.Client();
    return session;
  }

  void selectLocation(String location, int stateId) {
    selectedCountry.value = location;
    selectedLocationId.value = stateId;
    selectedCountryId.value = stateId;
    // Changing country invalidates the previous city selection.
    selectedCity.value = '';
    selectedCityId.value = -1;
    update([idUploadLocation]);
    print("Selected Location: ${selectedCountry.value} (ID: $stateId)");
    unawaited(SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('currentCountryId', stateId.toString());
      await prefs.remove('currentCityId');
    }));
  }

  void selectCity(String location, int cityIdValue) {
    selectedCity.value = location;
    selectedCityId.value = cityIdValue;
    update([idUploadLocation]);
    print("Selected City: ${selectedCity.value} (ID: $cityIdValue)");
    unawaited(SharedPreferences.getInstance().then(_persistResolvedLocationIds));
  }

  void setVisibility(VisibilityOption option) {
    selectedVisibility.value = option;
    publishType.value = selectedVisibility.value.value.toString();
    print(publishType);
  }

  void setVisibilityFromInt(int? visibilityValue) {
    switch (visibilityValue) {
      case 1:
        selectedVisibility.value = VisibilityOption.onlyFollowers;
        break;
      case 2:
        selectedVisibility.value = VisibilityOption.public;
        break;
      case 3:
        selectedVisibility.value = VisibilityOption.private;
        break;
      default:
        selectedVisibility.value = VisibilityOption.public;
    }
  }

  void toggleComments() {
    allowComments.value = !allowComments.value;
  }

  void toggleSwitch() {
    acceptOrder.value = !acceptOrder.value;
  }

  void syncFormTextFromControllers() {
    videoTitle.value = titleController.text;
    videoDescription.value = descriptionController.text;
  }

  void nextStep() {
    if (currentStep.value == 1) {
      syncFormTextFromControllers();
    }
    if (currentStep.value < 3) {
      currentStep.value++;
    }
    if (currentStep.value == 3) {
      validateSelectedCountry();
    }
  }

  /// Pre-generate thumbnail off the upload button critical path.
  Future<void> prepareThumbnail(File videoFile) async {
    await ensureThumbnail(videoFile);
  }

  Future<File?> ensureThumbnail(File videoFile) async {
    if (_cachedThumbnail != null && await _cachedThumbnail!.exists()) {
      return _cachedThumbnail;
    }
    // Photo uploads already are the cover — don't run video thumbnail extract.
    if (_isSupportedImageFormat(videoFile)) {
      _cachedThumbnail = videoFile;
      return _cachedThumbnail;
    }
    _thumbnailInFlight ??= _generateThumbnail(videoFile);
    try {
      _cachedThumbnail = await _thumbnailInFlight;
      return _cachedThumbnail;
    } finally {
      _thumbnailInFlight = null;
    }
  }

  Future<File?> _generateThumbnail(File videoFile) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        quality: 50,
      );
      if (thumbnailPath == null) return null;
      return File(thumbnailPath);
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  void _reportUploadProgress(double progress) {
    final percent = (progress * 100).floor().clamp(0, 100);
    if (percent == _lastUploadProgressPercent) return;
    _lastUploadProgressPercent = percent;
    uploadProgress.value = progress;
  }

  void _resetUploadProgressTracking() {
    _lastUploadProgressPercent = -1;
    uploadProgress.value = 0;
    isPreparingPlayback.value = false;
  }

  Widget _uploadProgressDialogBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        SizedBox(height: 16),
        Obx(
          () => Text(
            isPreparingPlayback.value
                ? 'processing_video'.tr
                : '${'uploading_video_label'.tr}${(uploadProgress.value * 100).toInt()}%',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Keeps the progress card up through upload + (for videos) server processing
  /// until the reel is watchable, then opens profile.
  Future<void> _completeSuccessfulUpload({
    required AwesomeDialog dialog,
    required String responseBody,
    required bool isPhotoUpload,
    required int uploadSession,
  }) async {
    if (!_isUploadSessionActive(uploadSession)) {
      try {
        dialog.dismiss();
      } catch (_) {}
      return;
    }

    isUploadSuccessful.value = true;
    uploadProgress.value = 1.0;

    final uploadedID =
        VideoProcessingService.extractVideoIdFromUploadResponse(responseBody);

    // Fast-forward: as soon as the bytes are uploaded, close the card and return
    // to the profile — no in-dialog "Processing" wait. The freshly uploaded
    // video shows up on the profile grid as a live "processing" tile (spinner
    // overlay, not openable). The profile's real-time watcher + the background
    // poll below flip it to a playable poster the instant the server transcode
    // is watch-ready, so the correct cover appears and it only opens when ready.
    try {
      dialog.dismiss();
    } catch (_) {}

    if (!_isUploadSessionActive(uploadSession)) {
      isPreparingPlayback.value = false;
      isVideoUploading.value = false;
      return;
    }

    isPreparingPlayback.value = false;
    isVideoUploading.value = false;

    _scheduleThumbnailProcessingPoll(
      responseBody,
      waitForTranscode: !isPhotoUpload,
    );
    await _finishUploadAndOpenProfile(
      uploadedVideoId: uploadedID,
      waitForVideoTranscode: false,
      uploadSession: uploadSession,
    );
  }

  /// Reloads the active profile so the new upload appears on the profile tab.
  Future<void> _refreshProfileAfterUpload() async {
    ensureLandingProfileControllers();
    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getInt('entity') ?? 0;
    if (entity == 2) {
      await Get.find<ProfessionalProfileController>().getUserDetails();
    } else {
      await Get.find<ProfileController>().getUserDetails();
    }
  }

  /// Drop stale decoders/posters from upload preview, open profile tab, refresh.
  Future<void> _finishUploadAndOpenProfile({
    String? uploadedVideoId,
    bool waitForVideoTranscode = false,
    int? uploadSession,
  }) async {
    if (uploadSession != null && !_isUploadSessionActive(uploadSession)) {
      return;
    }

    try {
      // Invalidate any in-flight Home remount/teardown before wiping the pool so
      // a late releaseAll cannot dispose players recreated after this upload.
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().claimReelPoolSession();
      }
      MediaKitPlayerPool.instance.pauseAllImmediate();
      await MediaKitPlayerPool.instance.disposeAllWithTimeout();
      await MediaKitPlayerPool.instance.awaitOperationsIdle(
        timeout: const Duration(milliseconds: 1500),
      );
    } catch (_) {}
    // Camera / ExoPlayer still releasing after capture — opening a reel too
    // early abandoned BufferQueues and left the first profile open stuck.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (uploadSession != null && !_isUploadSessionActive(uploadSession)) {
      return;
    }

    // Prefer ready mp4/hls before landing on profile so the first tile open
    // is a real video, not a cover-only “photo” state.
    if (waitForVideoTranscode &&
        uploadedVideoId != null &&
        uploadedVideoId.isNotEmpty) {
      try {
        await VideoProcessingService.pollUntilSettled(
          uploadedVideoId,
          waitForTranscode: true,
          shouldContinue: uploadSession == null
              ? null
              : () => _isUploadSessionActive(uploadSession),
        ).timeout(const Duration(seconds: 12), onTimeout: () => null);
      } catch (_) {}
    }

    if (uploadSession != null && !_isUploadSessionActive(uploadSession)) {
      return;
    }

    // Land on profile tab. Nav index must be set before offAll so the new Landing
    // does not flash home, and Landing must not show a blank placeholder.
    if (Get.isRegistered<NavBarController>()) {
      Get.find<NavBarController>().selectedIndex.value = 3;
    }
    // Keep profile controllers across offAll (permanent) so this refresh sticks.
    ensureLandingProfileControllers();
    // Allow the upload form route to leave (absorb window may still be on).
    UploadFormPopGuard.active?.allowUserPop();
    try {
      await _refreshProfileAfterUpload().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {}

    await Get.offAll(
      () => Landing(initialIndex: 3),
      binding: LandingBinding(),
    );
    if (Get.isRegistered<HomeController>()) {
      // Upload disposeAll'd the shared pool while silenced for capture. Mark the
      // home feed for a hard remount the moment the user opens Home — never leave
      // mute/capture gates stuck after offAll. HomeController is permanent so
      // offAll does not onClose→releaseAll race this remount.
      Get.find<HomeController>().clearMediaCaptureGatesAfterLandingReset();
    }
    resetController();
    // Soft refresh again so Obx rebuilds on the mounted profile tab.
    try {
      await _refreshProfileAfterUpload().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {}
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () async {
        try {
          await _refreshProfileAfterUpload();
        } catch (_) {}
      }),
    );
  }

  void previousStep() {
    if (currentStep > 1) currentStep.value--;
  }

  void addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !tagsList.contains(tag) && tagsList.length < 5) {
      tagsList.add(tag);
    }
  }

  void addMenuItem(String menu) {
    menu = menu.trim();
    if (menu.isNotEmpty && !menuList.contains(menu) && menuList.length < 15) {
      menuList.add(menu);
    }
  }

  void removeTag(String tag) {
    tagsList.remove(tag);
  }

  var isVideoUploading = false.obs;
  var isCompressing = false.obs;

  // Front-end cap to keep multipart request safely under backend/nginx limits.
  // Backend guidance: nginx 300m, PHP upload_max_filesize 256M -> cap to ~250MB.
  static const int _clientMaxVideoBytes = 250 * 1024 * 1024; // 250 MiB

  void _scheduleThumbnailProcessingPoll(String responseBody, {bool waitForTranscode = true}) {
    final videoId =
        VideoProcessingService.extractVideoIdFromUploadResponse(responseBody);
    if (videoId != null) {
      VideoProcessingService.scheduleBackgroundPoll(
        videoId,
        waitForTranscode: waitForTranscode,
      );
    }
  }
  static const Set<String> _supportedVideoExtensions = {
    'mp4',
    'mov',
    'm4v',
    '3gp',
    'mkv',
    'avi',
    'webm',
    'mpeg',
    'mpg',
  };

  static const Set<String> _supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  MediaType _resolveUploadMediaType(String filePath, {required bool asImage}) {
    final extension = filePath.split('.').last.toLowerCase();
    if (asImage || _supportedImageExtensions.contains(extension)) {
      switch (extension) {
        case 'png':
          return MediaType('image', 'png');
        case 'webp':
          return MediaType('image', 'webp');
        case 'heic':
        case 'heif':
          return MediaType('image', 'heic');
        case 'jpg':
        case 'jpeg':
        default:
          return MediaType('image', 'jpeg');
      }
    }
    return _resolveVideoMediaType(filePath);
  }

  MediaType _resolveVideoMediaType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'm4v':
        return MediaType('video', 'x-m4v');
      case '3gp':
        return MediaType('video', '3gpp');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'avi':
        return MediaType('video', 'x-msvideo');
      case 'webm':
        return MediaType('video', 'webm');
      case 'mpeg':
      case 'mpg':
        return MediaType('video', 'mpeg');
      case 'mp4':
      default:
        return MediaType('video', 'mp4');
    }
  }

  bool _isSupportedVideoFormat(File videoFile) {
    final extension = videoFile.path.split('.').last.toLowerCase();
    return _supportedVideoExtensions.contains(extension);
  }

  bool _isSupportedImageFormat(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return _supportedImageExtensions.contains(extension);
  }

  bool _isSupportedUploadFile(File file, {required bool asImage}) {
    if (asImage) {
      return _isSupportedImageFormat(file) || _isSupportedVideoFormat(file);
    }
    return _isSupportedVideoFormat(file);
  }

  Future<File> _compressVideoIfNeeded(File videoFile, BuildContext context) async {
    // Per backend fix request: do not compress videos.
    // We enforce the allowed size via _clientMaxVideoBytes in uploadVideo().
    return videoFile;
  }

  String errorMessage = "";

  Future<void> uploadVideo(
    File videoFile,
    BuildContext context, {
    bool uploadAsImage = false,
  }) async {
    if (isVideoUploading.value || isCompressing.value) return;
    final imageUploadFlag = uploadAsImage ? '1' : '0';
    isImage.value = imageUploadFlag;
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().reinforceMediaCaptureSilence();
    }
    syncFormTextFromControllers();
    _resetUploadProgressTracking();
    if (!_isSupportedUploadFile(videoFile, asImage: uploadAsImage)) {
      showFormSnackBar(
        context,
        uploadAsImage
            ? 'Unsupported image format. Please use JPG, PNG, or WEBP.'
            : 'Unsupported video format. Please use MP4, MOV, MKV, AVI, WEBM, M4V, 3GP, MPEG, or MPG.',
      );
      return;
    }

    final bool isSponsored = entityDetails.value['is_sponsored'] == 1;
    if (!isSponsored) {
      // Resolve display names → ids first. On first app open the upload
      // settings / city list are still loading, so a name that is already
      // shown as selected has no id yet; awaiting this loads them and prevents
      // the false "select city" error on the first attempt.
      final locationReady = await ensureLocationIdsReady();

      if (!locationReady) {
        final country = selectedCountry.value.trim();
        final city = selectedCity.value.trim();
        final countryMissing = country.isEmpty ||
            country == 'Unknown' ||
            selectedLocationId.value <= 0;
        final cityMissing =
            city.isEmpty || city == 'Unknown' || selectedCityId.value <= 0;

        if (countryMissing && cityMissing) {
          errorMessage = "select_country_city_error".tr;
        } else if (countryMissing) {
          errorMessage = "select_country_error".tr;
        } else if (cityMissing) {
          errorMessage = "select_city_error".tr;
        } else {
          errorMessage = "select_country_city_error".tr;
        }

        showFormSnackBar(context, errorMessage);
        return;
      }
    }

    if (videoType.value.isEmpty) {
      showFormSnackBar(context, "select_video_type".tr);
      return;
    }

    // Additional validation for sponsored videos
    if (isSponsored) {
      String? errorMessage;

      if (selectedVideoType.value.isEmpty) {
        errorMessage = "select_package_error".tr;
      } else if (selectedCountry.value.isEmpty) {
        errorMessage = "select_target_country_error".tr;
      } else if (selectedCities.isEmpty) {
        errorMessage = "select_target_city_error".tr;
      }

      if (errorMessage != null) {
        showFormSnackBar(context, errorMessage);
        return;
      }

      if (!await ensureLocationIdsReady()) {
        showFormSnackBar(context, "select_country_city_error".tr);
        return;
      }

      if (!await videoFile.exists()) {
        showFormSnackBar(context, "video_file_not_exist_error".tr);
        return;
      }

      // Enforce client-side size cap before paying/uploading to avoid nginx 413.
      if (imageUploadFlag != "1") {
        final videoSize = await videoFile.length();
        print("Video size check: ${(videoSize / 1024 / 1024).toStringAsFixed(1)} MB");
        if (videoSize > _clientMaxVideoBytes) {
          showFormSnackBar(context, 'video_too_large_error'.tr);
          return;
        }
      }

      // Initiate payment for sponsored videos (only after size validation).
      final orderId = "PRO_${DateTime.now().millisecondsSinceEpoch}";
      Map<String, dynamic>? paymentParams = await initiatePayment(
        orderId,
        context,
      );
      if (paymentParams == null) {
        print("Payment failed, aborting video upload.");
        return;
      }

      print("uploading_video_label".tr);
      final uploadSession = _beginUploadSession();
      isVideoUploading.value = true;
      isUploadSuccessful.value = false;

      final File? thumbnailFile = await ensureThumbnail(videoFile);
      if (thumbnailFile == null) {
        print(
          "Warning: Thumbnail generation failed. Proceeding without thumbnail.",
        );
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Common.baseUrl}${EndPoints.uploadVideo}"),
      );

      final sponsorType = selectedVideoType.value == "Basic" ? 1 : 2;

      request.fields['title'] = videoTitle.value;
      request.fields['description'] = videoDescription.value;
      request.fields['video_type'] = videoType.value;
      request.fields['tags'] = tagsList.join(',');
      request.fields['menu'] = menuList.join(',');
      request.fields['country'] = selectedLocationId.value.toString();
      request.fields['city'] = selectedCityId.value.toString();
      request.fields['location'] = "";
      request.fields['take_order'] = acceptOrder.value ? '1' : '0';
      request.fields['allow_comments'] = allowComments.value ? "1" : "0";
      request.fields['publish_type'] = publishType.value;
      request.fields['is_image'] = imageUploadFlag;

      if (entityDetails.value['is_sponsored'] == 1) {
        request.fields['sponsor_type'] = sponsorType.toString();
        request.fields['cities'] = selectedCityIds.join(",");
        request.fields['days'] = selectedDays.value.toString();
        request.fields['total_price'] = calculateTotalPrice().toString();
        // Add payment parameters to the payload
        request.fields['PaymentId'] =
            paymentParams["PaymentId"]?.toString() ?? "";
        request.fields['TranId'] = paymentParams["TranId"]?.toString() ?? "";
        request.fields['ECI'] = paymentParams["ECI"]?.toString() ?? "";
        request.fields['TrackId'] = paymentParams["TrackId"]?.toString() ?? "";
        request.fields['RRN'] = paymentParams["RRN"]?.toString() ?? "";
        request.fields['cardBrand'] =
            paymentParams["cardBrand"]?.toString() ?? "";
        request.fields['amount'] = paymentParams["amount"]?.toString() ?? "";
        request.fields['maskedPAN'] =
            paymentParams["maskedPAN"]?.toString() ?? "";
        request.fields['PaymentType'] =
            paymentParams["PaymentType"]?.toString() ?? "";
      }

      print("Is Image?: $imageUploadFlag");

      AwesomeDialog? dialog;
      dialog = AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        dismissOnTouchOutside: false,
        body: _uploadProgressDialogBody(),
      )..show();

      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();

      int bytesSent = 0;
      final streamWithProgress = videoStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            _reportUploadProgress(bytesSent / videoLength);
            sink.add(data);
          },
        ),
      );

      final videoMultipartFile = http.MultipartFile(
        'video',
        streamWithProgress,
        videoLength,
        filename: videoFile.path.split('/').last,
        contentType: _resolveUploadMediaType(
          videoFile.path,
          asImage: imageUploadFlag == '1',
        ),
      );

      request.files.add(videoMultipartFile);
      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', thumbnailFile.path),
        );
      }

      try {
        if (!_isUploadSessionActive(uploadSession)) {
          try {
            dialog.dismiss();
          } catch (_) {}
          return;
        }

        var response = await ApiClient.sendMultipartRequest(
          request,
          client: _uploadHttpClient,
          timeout: const Duration(minutes: 10),
        );

        if (!_isUploadSessionActive(uploadSession)) {
          try {
            dialog.dismiss();
          } catch (_) {}
          return;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          print("✅ Video uploaded successfully!");
          print("Response: ${response.body}");
          await _completeSuccessfulUpload(
            dialog: dialog,
            responseBody: response.body,
            isPhotoUpload: imageUploadFlag == '1',
            uploadSession: uploadSession,
          );
          return;
        } else {
          print("❌ Failed to upload video. Status: ${response.statusCode}");
          print("Response: ${response.body}");
          try {
            dialog.dismiss();
          } catch (_) {}
          isVideoUploading.value = false;
          isUploadSuccessful.value = false;

          String errorMsg;
          try {
            final responseData =
                jsonDecode(response.body) as Map<String, dynamic>;
            errorMsg = responseData['message'] ?? 'Upload failed (${response.statusCode})';
          } catch (_) {
            errorMsg = 'Server error (${response.statusCode}). Please try again later.';
          }

          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'upload_failed_title'.tr,
            desc: errorMsg,
            btnOkOnPress: () {},
          )..show();
        }
      } catch (e) {
        try {
          dialog.dismiss();
        } catch (_) {}
        // Aborted by leaving the form / cancelPendingUpload — not a user error.
        if (!_isUploadSessionActive(uploadSession)) {
          isVideoUploading.value = false;
          isPreparingPlayback.value = false;
          return;
        }
        print("❌ Error uploading video: $e");
        isVideoUploading.value = false;
        isUploadSuccessful.value = false;
        isPreparingPlayback.value = false;

        String userMsg = 'upload_error_generic'.tr;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('413') || errStr.contains('entity too large') || errStr.contains('connection reset')) {
          userMsg = 'video_too_large_error'.tr;
        } else if (errStr.contains('timeout') || errStr.contains('timed out')) {
          userMsg = 'upload_timeout_error'.tr;
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'upload_failed_title'.tr,
          desc: userMsg,
          btnOkOnPress: () {},
        )..show();
      }
    } else {
      // Handle non-sponsored video upload
      if (!await videoFile.exists()) {
        showFormSnackBar(context, "video_file_not_exist_error".tr);
        return;
      }

      // Enforce client-side size cap before uploading to avoid nginx 413.
      if (imageUploadFlag != "1") {
        final videoSize = await videoFile.length();
        print("Video size check: ${(videoSize / 1024 / 1024).toStringAsFixed(1)} MB");
        if (videoSize > _clientMaxVideoBytes) {
          showFormSnackBar(context, 'video_too_large_error'.tr);
          return;
        }
      }

      print("uploading_video_label".tr);
      final uploadSession = _beginUploadSession();
      isVideoUploading.value = true;
      isUploadSuccessful.value = false;

      final File? thumbnailFile = await ensureThumbnail(videoFile);
      if (thumbnailFile == null) {
        print(
          "Warning: Thumbnail generation failed. Proceeding without thumbnail.",
        );
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Common.baseUrl}${EndPoints.uploadVideo}"),
      );

      request.fields['title'] = videoTitle.value;
      request.fields['description'] = videoDescription.value;
      request.fields['video_type'] = videoType.value;
      request.fields['tags'] = tagsList.join(',');
      request.fields['menu'] = menuList.join(',');
      request.fields['country'] = selectedLocationId.value.toString();
      request.fields['city'] = selectedCityId.value.toString();
      request.fields['location'] = "";
      request.fields['take_order'] = acceptOrder.value ? '1' : '0';
      request.fields['allow_comments'] = allowComments.value ? "1" : "0";
      request.fields['publish_type'] = publishType.value;
      request.fields['is_image'] = imageUploadFlag;

      print(
        "Upload payload location: country=${selectedLocationId.value} city=${selectedCityId.value} video_type=${videoType.value}",
      );
      print("Is Image?: $imageUploadFlag");

      AwesomeDialog? dialog;
      dialog = AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        dismissOnTouchOutside: false,
        body: _uploadProgressDialogBody(),
      )..show();

      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();

      int bytesSent = 0;
      final streamWithProgress = videoStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            _reportUploadProgress(bytesSent / videoLength);
            sink.add(data);
          },
        ),
      );

      final videoMultipartFile = http.MultipartFile(
        'video',
        streamWithProgress,
        videoLength,
        filename: videoFile.path.split('/').last,
        contentType: _resolveUploadMediaType(
          videoFile.path,
          asImage: imageUploadFlag == '1',
        ),
      );

      request.files.add(videoMultipartFile);
      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', thumbnailFile.path),
        );
      }

      try {
        if (!_isUploadSessionActive(uploadSession)) {
          try {
            dialog.dismiss();
          } catch (_) {}
          return;
        }

        var response = await ApiClient.sendMultipartRequest(
          request,
          client: _uploadHttpClient,
          timeout: const Duration(minutes: 10),
        );

        if (!_isUploadSessionActive(uploadSession)) {
          try {
            dialog.dismiss();
          } catch (_) {}
          return;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          print("✅ Video uploaded successfully!");
          print("Response: ${response.body}");
          await _completeSuccessfulUpload(
            dialog: dialog,
            responseBody: response.body,
            isPhotoUpload: imageUploadFlag == '1',
            uploadSession: uploadSession,
          );
        } else {
          print("❌ Failed to upload video. Status: ${response.statusCode}");
          print("Response: ${response.body}");
          try {
            dialog.dismiss();
          } catch (_) {}
          isVideoUploading.value = false;
          isUploadSuccessful.value = false;

          String userMsg;
          try {
            final responseData =
                jsonDecode(response.body) as Map<String, dynamic>;
            userMsg = responseData['message'] ?? 'Upload failed (${response.statusCode})';
          } catch (_) {
            userMsg = 'Server error (${response.statusCode}). Please try again later.';
          }

          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'upload_failed_title'.tr,
            desc: userMsg,
            btnOkOnPress: () {},
          )..show();
        }
      } catch (e) {
        try {
          dialog.dismiss();
        } catch (_) {}
        // Aborted by leaving the form / cancelPendingUpload — not a user error.
        if (!_isUploadSessionActive(uploadSession)) {
          isVideoUploading.value = false;
          isPreparingPlayback.value = false;
          return;
        }
        print("❌ Error uploading video: $e");
        isVideoUploading.value = false;
        isUploadSuccessful.value = false;
        isPreparingPlayback.value = false;

        String userMsg = 'upload_error_generic'.tr;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('413') || errStr.contains('entity too large') || errStr.contains('connection reset')) {
          userMsg = 'video_too_large_error'.tr;
        } else if (errStr.contains('timeout') || errStr.contains('timed out')) {
          userMsg = 'upload_timeout_error'.tr;
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'upload_failed_title'.tr,
          desc: userMsg,
          btnOkOnPress: () {},
        )..show();
      }
    }
  }

  Future<void> updateVideo(
    String videoId, {
    String? title,
    String? description,
    String? videoType,
    String? tags,
    String? menu,

    int? publishType,
    int? allowComments,
    int? takeOrder,

    int? country,
    int? city,
  }) async {
    if (videoId.isEmpty) {
      Get.snackbar("Error", "Video ID is required");
      return;
    }

    final Map<String, dynamic> data = {
      'video_id': videoId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (videoType != null && videoType.isNotEmpty) 'video_type': videoType,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      if (menu != null && menu.isNotEmpty) 'menu': menu,
      if (publishType != null) 'publish_type': publishType.toString(),
      if (allowComments != null) 'allow_comments': allowComments.toString(),
      if (takeOrder != null) 'take_order': takeOrder.toString(),
      if (country != null) 'country': country.toString(),
      if (city != null) 'city': city.toString(),
    };

    try {
      AwesomeDialog? dialog = AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.noHeader,
        dismissOnTouchOutside: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("updating_video_label".tr, style: TextStyle(fontSize: 16)),
          ],
        ),
      )..show();

      final response = await ApiClient.postRequest(
        '${EndPoints.editVideo}',
        data,
      );

      dialog.dismiss();

      if (response.statusCode == 201) {
        print("✅ Video updated successfully!");
        print("Response: ${response.body}");
        if (Get.isRegistered<ProfileController>()) {
          unawaited(Get.find<ProfileController>().getUserDetails());
        }
        if (Get.isRegistered<ProfessionalProfileController>()) {
          unawaited(Get.find<ProfessionalProfileController>().getUserDetails());
        }
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.success,
          title: 'update_complete_title'.tr,
          desc: 'update_success_message'.tr,
          dismissOnTouchOutside: false,
          autoDismiss: true,
          autoHide: const Duration(seconds: 2),
          // Dialog will hide after 2 seconds
          onDismissCallback: (_) {
            resetController();
            Get.back();
          },
        )..show();
        // Get.delete<VideoAddController>();

        // Future.delayed(Duration(seconds: 2), () {
        //   resetController();
        //   // Get.offAll(() => Landing(initialIndex: 3));
        // });
      } else {
        print("❌ Failed to update video. Status: ${response.statusCode}");
        print("Response: ${response.body}");
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'update_failed_title'.tr,
          desc: '${'update_failed_message'.tr} ${response.statusCode}',
          btnOkOnPress: () {},
        )..show();
      }
    } catch (e) {
      print("❌ Error updating video: $e");
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'Error',
        desc: 'An error occurred: $e',
        btnOkOnPress: () {},
      )..show();
    }
  }

  Future<Map<String, dynamic>?> initiatePayment(
      String orderId,
      BuildContext context,
      ) async {
    try {
      String response = await Payment.makepaymentService(
        context: context,
        country: selectedCountry.value,
        action: "1",
        currency: "SAR",
        amt: calculateTotalPrice().toString(),
        customerEmail: "",
        trackid: orderId,
        udf1: "",
        udf2: "",
        udf3: Directionality.of(context) == TextDirection.rtl ? "AR" : "EN",
        udf4: "",
        udf5: "",
        metadata: '{"orderId":"$orderId","source":"FlutterApp"}',
        cardToken: "",
        address: "",
        city: "",
        state: "",
        tokenizationType: "0",
        zipCode: "",
        tokenOperation: "",
      );

      print("Raw Response: $response");

      if (response.isNotEmpty && response.trim().startsWith('{')) {
        Map<String, dynamic> jsonResponse = jsonDecode(response);
        print("PRINTING PAYMENT RESPONSE");
        print(jsonResponse);

        String? result = jsonResponse["Result"]?.toString().toLowerCase();
        String? responseCode = jsonResponse["ResponseCode"]?.toString();
        final paymentParams = {
          "PaymentId": jsonResponse["PaymentId"]?.toString() ?? "",
          "TranId": jsonResponse["TranId"]?.toString() ?? "",
          "ECI": jsonResponse["ECI"]?.toString() ?? "",
          "TrackId": jsonResponse["TrackId"]?.toString() ?? "",
          "RRN": jsonResponse["RRN"]?.toString() ?? "",
          "cardBrand": jsonResponse["cardBrand"]?.toString() ?? "",
          "amount": jsonResponse["amount"]?.toString() ?? "",
          "maskedPAN": jsonResponse["maskedPAN"]?.toString() ?? "",
          "PaymentType": jsonResponse["PaymentType"]?.toString() ?? "",
        };

        print("PRINTING THE RESULT: $result");

        if (result == "successful") {
          print("Payment successful, proceeding with video upload.");
          return paymentParams;
        } else {
          // Use ResponseConfig to get the error message
          ResponseConfig responseConfig = ResponseConfig();
          String errorMessage = responseConfig.respCode[responseCode] ??
              "form_unknown_error".tr;
          showFormSnackBar(context, errorMessage);
          return null;
        }
      } else {
        throw Exception("Invalid response format: $response");
      }
    } catch (e) {
      print("PRINTING ERROR: $e");
      showFormSnackBar(context, "payment_cancelled".tr);
      return null;
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (status.isGranted) return true;
      status = await Permission.videos.request();
      return status.isGranted;
    }
    return true;
  }

  void resetController() {
    print("Resetting controller...");
    cancelPendingUpload();
    validateStep1Form = null;
    validateStep2Form = null;
    videoTitle.value = "";
    titleController.text = "";
    videoDescription.value = "";
    descriptionController.text = "";
    videoType.value = "";
    tagsList.clear();
    menuList.clear();
    selectedLocationId.value = -1;
    selectedCityId.value = -1;
    selectedCountryId.value = 0;
    acceptOrder.value = false;
    allowComments.value = true;
    publishType.value = "2";
    isVideoUploading.value = false;
    isUploadSuccessful.value = false;
    isImage.value = "0";
    selectedCountry.value = "";
    selectedCity.value = "";
    currentStep.value = 1;
    _cachedThumbnail = null;
    _thumbnailInFlight = null;
    _resetUploadProgressTracking();
  }

  Future<void> fetchSiteSettings() async {
    try {
      final response = await ApiClient.getRequest('${EndPoints.siteSettings}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        siteSettings.value = SiteSettings.fromJson(jsonData);
        print(
          "Site Settings Fetched: ${siteSettings.value?.settings?.toJson()}",
        );
      } else {
        print("Failed to fetch site settings: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching site settings: $e");
    }
  }

  void _bindUploadFormRebuilds() {
    ever<int>(currentStep, (_) => update([idUploadNav]));
    ever<bool>(isVideoUploading, (_) => update([idUploadNav]));
    ever<bool>(isCompressing, (_) => update([idUploadNav]));
    ever<List<String>>(tagsList, (_) => update([idUploadTags]));
    ever<String>(selectedCountry, (_) => update([idUploadLocation]));
    ever<String>(selectedCity, (_) => update([idUploadLocation]));
    ever<Map<String, dynamic>>(entityDetails, (_) => update([idUploadSponsor]));
    ever<String>(videoType, (_) => update([idUploadVideoType]));
    ever<String>(videoTypeError, (_) => update([idUploadVideoType]));
  }

  @override
  void onInit() {
    super.onInit();
    titleController.text = videoTitle.value;
    descriptionController.text = videoDescription.value;
    unawaited(_loadBadWords());
    _bindUploadFormRebuilds();
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(fetchSiteSettings());
    unawaited(fetchEntity());
  }

  @override
  void onClose() {
    cancelPendingUpload();
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}

void showWaitingDialog() {
  AwesomeDialog(
    context: Get.context!,
    dialogType: DialogType.noHeader,
    animType: AnimType.scale,
    dismissOnTouchOutside: false,
    dismissOnBackKeyPress: false,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
        SizedBox(height: 16),
        Text("uploading_video_label".tr, style: TextStyle(fontSize: 16)),
      ],
    ),
  )..show();
}

void showSuccessDialog() {
  // Dead path — do not Get.offAll on a timer. A 3s delayed offAll here used to
  // nuke the upload/editor stack if this helper was ever invoked.
  AwesomeDialog(
    context: Get.context!,
    dialogType: DialogType.success,
    animType: AnimType.scale,
    title: "success_title".tr,
    desc: "upload_success_message".tr,
    autoDismiss: true,
    btnOkOnPress: () {},
  )..show();
}

void showErrorDialog() {
  AwesomeDialog(
    context: Get.context!,
    dialogType: DialogType.error,
    animType: AnimType.scale,
    title: "Error",
    desc: "Failed to upload video. Please try again!",
    btnOkOnPress: () {},
  )..show();
}
