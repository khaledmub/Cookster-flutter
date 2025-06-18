import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urwaypayment/urwaypayment.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../../loaders/pulseLoader.dart';
import '../../../../../services/apiClient.dart';
import '../../../../promoteVideo/promoteVideoModel/promoteVideoModel.dart';
import '../../profile/profileControlller/profileController.dart';
import '../videoUploadSettingsModel/videoUploadSettingsModel.dart';

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
      // Load Arabic bad words
      final arabicData = await DefaultAssetBundle.of(
        Get.context!,
      ).loadString('assets/bad_words_arabic.txt');
      _badWordsArabic =
          arabicData
              .split('\n')
              .map((word) => word.trim().toLowerCase())
              .where((word) => word.isNotEmpty)
              .toList();

      // Load English bad words
      final englishData = await DefaultAssetBundle.of(
        Get.context!,
      ).loadString('assets/bad_words_english.txt');
      _badWordsEnglish =
          englishData
              .split('\n')
              .map((word) => word.trim().toLowerCase())
              .where((word) => word.isNotEmpty)
              .toList();
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
  var selectedLocationId = -1.obs;
  var selectedCityId = -1.obs;
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

  final step1key = GlobalKey<FormState>();
  final step2key = GlobalKey<FormState>();
  final step3key = GlobalKey<FormState>();

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

  void selectLocation(String location, int stateId) {
    selectedCountry.value = location;
    selectedLocationId = stateId;
    print("Selected Location: ${selectedCountry.value} (ID: $stateId)");
  }

  void selectCity(String location, int cityId) {
    selectedCity.value = location;
    selectedCityId = cityId;
    print("Selected Location: ${selectedCountry.value} (ID: $cityId)");
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

  void updateTitle(String title) {
    videoTitle.value = title;
  }

  void updateDescription(String description) {
    videoDescription.value = description;
  }

  void nextStep() {
    if (currentStep < 3) currentStep.value++;
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

  String errorMessage = "";

  Future<void> uploadVideo(File videoFile, BuildContext context) async {
    if (selectedCountry.value.isEmpty && selectedCity.value.isEmpty) {
      errorMessage = "select_country_city_error".tr;
    } else if (selectedCountry.value.isEmpty) {
      errorMessage = "select_country_error".tr;
    } else if (selectedCity.value.isEmpty) {
      errorMessage = "select_city_error".tr;
    }

    if (selectedCountry.value.isEmpty || selectedCity.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    print("Hello I am there");

    // Additional validation for sponsored videos
    if (entityDetails.value['is_sponsored'] == 1) {
      String? errorMessage;

      if (selectedVideoType.value.isEmpty) {
        errorMessage = "select_package_error".tr;
      } else if (selectedCountry.value.isEmpty) {
        errorMessage = "select_target_country_error".tr;
      } else if (selectedCities.isEmpty) {
        errorMessage = "select_target_city_error".tr;
      }

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Initiate payment for sponsored videos
      final orderId = "PRO_${DateTime.now().millisecondsSinceEpoch}";
      Map<String, dynamic>? paymentParams = await initiatePayment(
        orderId,
        context,
      );
      if (paymentParams == null) {
        print("Payment failed, aborting video upload.");
        return;
      }

      if (!await videoFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("video_file_not_exist_error".tr),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      print("uploading_video_label".tr);
      isVideoUploading.value = true;
      isUploadSuccessful.value = false;

      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        );
      } catch (e) {
        print("Error generating thumbnail: $e");
      }

      if (thumbnailPath == null) {
        print(
          "Warning: Thumbnail generation failed. Proceeding without thumbnail.",
        );
      }

      File? thumbnailFile = thumbnailPath != null ? File(thumbnailPath) : null;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Common.baseUrl}${EndPoints.uploadVideo}"),
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": token != null ? "Bearer $token" : "",
      });

      final sponsorType = selectedVideoType.value == "Basic" ? 1 : 2;

      request.fields['title'] = videoTitle.value;
      request.fields['description'] = videoDescription.value;
      request.fields['video_type'] = videoType.value;
      request.fields['tags'] = tagsList.join(',');
      request.fields['menu'] = menuList.join(',');
      request.fields['country'] = selectedLocationId.toString();
      request.fields['city'] = selectedCityId.toString();
      request.fields['location'] = "";
      request.fields['take_order'] = acceptOrder.value ? '1' : '0';
      request.fields['allow_comments'] = allowComments.value ? "1" : "0";
      request.fields['publish_type'] = publishType.value;
      request.fields['is_image'] = isImage.value;

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

      print("Is Image?: ${isImage}");

      AwesomeDialog? dialog;
      dialog = AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        dismissOnTouchOutside: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Obx(
              () => Text(
                '${'upload_complete_title'.tr} ${(uploadProgress.value * 100).toInt()}%',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      )..show();

      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();

      int bytesSent = 0;
      final streamWithProgress = videoStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            double progress = bytesSent / videoLength;
            uploadProgress.value = progress;
            sink.add(data);
          },
        ),
      );

      final videoMultipartFile = http.MultipartFile(
        'video',
        streamWithProgress,
        videoLength,
        filename: videoFile.path.split('/').last,
      );

      request.files.add(videoMultipartFile);
      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', thumbnailFile.path),
        );
      }

      try {
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        dialog.dismiss();

        if (response.statusCode == 201) {
          print("✅ Video uploaded successfully!");
          print("Response: ${response.body}");
          isVideoUploading.value = false;
          isUploadSuccessful.value = true;

          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            title: 'upload_complete_title'.tr,
            desc: 'upload_success_message'.tr,
            dismissOnTouchOutside: false,
            autoDismiss: true,
            onDismissCallback: (_) {
              resetController();
              Get.offAll(() => Landing());
            },
          )..show();

          Future.delayed(Duration(seconds: 2), () {
            resetController();
            Get.offAll(() => Landing(initialIndex: 3));
          });
        } else {
          print("❌ Failed to upload video. Status: ${response.statusCode}");
          print("Response: ${response.body}");
          isVideoUploading.value = false;
          isUploadSuccessful.value = false;

          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;

          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'upload_failed_title'.tr,
            desc: responseData['message'],
            // Display only the message
            btnOkOnPress: () {},
          )..show();
        }
      } catch (e) {
        print("❌ Error uploading video: $e");
        isVideoUploading.value = false;
        isUploadSuccessful.value = false;

        dialog.dismiss();

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error_title'.tr,
          desc: 'An error occurred: $e',
          btnOkOnPress: () {},
        )..show();
      }
    } else {
      // Handle non-sponsored video upload
      if (!await videoFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("video_file_not_exist_error".tr),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      print("uploading_video_label".tr);
      isVideoUploading.value = true;
      isUploadSuccessful.value = false;

      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        );
      } catch (e) {
        print("Error generating thumbnail: $e");
      }

      if (thumbnailPath == null) {
        print(
          "Warning: Thumbnail generation failed. Proceeding without thumbnail.",
        );
      }

      File? thumbnailFile = thumbnailPath != null ? File(thumbnailPath) : null;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Common.baseUrl}${EndPoints.uploadVideo}"),
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": token != null ? "Bearer $token" : "",
      });

      request.fields['title'] = videoTitle.value;
      request.fields['description'] = videoDescription.value;
      request.fields['video_type'] = videoType.value;
      request.fields['tags'] = tagsList.join(',');
      request.fields['menu'] = menuList.join(',');
      request.fields['country'] = selectedLocationId.toString();
      request.fields['city'] = selectedCityId.toString();
      request.fields['location'] = "";
      request.fields['take_order'] = acceptOrder.value ? '1' : '0';
      request.fields['allow_comments'] = allowComments.value ? "1" : "0";
      request.fields['publish_type'] = publishType.value;
      request.fields['is_image'] = isImage.value;

      print("Is Image?: ${isImage}");

      AwesomeDialog? dialog;
      dialog = AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        dismissOnTouchOutside: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Obx(
              () => Text(
                '${'upload_complete_title'.tr} ${(uploadProgress.value * 100).toInt()}%',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      )..show();

      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();

      int bytesSent = 0;
      final streamWithProgress = videoStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            double progress = bytesSent / videoLength;
            uploadProgress.value = progress;
            sink.add(data);
          },
        ),
      );

      final videoMultipartFile = http.MultipartFile(
        'video',
        streamWithProgress,
        videoLength,
        filename: videoFile.path.split('/').last,
      );

      request.files.add(videoMultipartFile);
      if (thumbnailFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', thumbnailFile.path),
        );
      }

      try {
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        dialog.dismiss();

        if (response.statusCode == 201) {
          print("✅ Video uploaded successfully!");
          print("Response: ${response.body}");
          isVideoUploading.value = false;
          isUploadSuccessful.value = true;

          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            title: 'upload_complete_title'.tr,
            desc: 'upload_success_message'.tr,
            dismissOnTouchOutside: false,
            autoDismiss: true,
            onDismissCallback: (_) {
              resetController();
              Get.offAll(() => Landing());
            },
          )..show();

          Future.delayed(Duration(seconds: 2), () {
            resetController();
            Get.offAll(() => Landing(initialIndex: 3));
          });
        } else {
          print("❌ Failed to upload video. Status: ${response.statusCode}");
          print("Response: ${response.body}");
          isVideoUploading.value = false;
          isUploadSuccessful.value = false;

          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;

          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'upload_failed_title'.tr,
            desc: responseData['message'],
            btnOkOnPress: () {},
          )..show();
        }
      } catch (e) {
        print("❌ Error uploading video: $e");
        isVideoUploading.value = false;
        isUploadSuccessful.value = false;

        dialog.dismiss();

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error_title'.tr,
          desc: 'An error occurred: $e',
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
        currency: "USD",
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("form_unknown_error".tr)));
          return null;
        }
      } else {
        throw Exception("Invalid response format: $response");
      }
    } catch (e) {
      print("PRINTING ERROR: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("payment_cancelled".tr)));
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
    videoTitle.value = "";
    titleController.text = "";
    videoDescription.value = "";
    descriptionController.text = "";
    videoType.value = "";
    tagsList.clear();
    menuList.clear();
    selectedLocationId = -1;
    acceptOrder.value = false;
    allowComments.value = true;
    publishType.value = "2";
    isVideoUploading.value = false;
    isUploadSuccessful.value = false;
    selectedCountry.value = "";
    selectedCity.value = "";
    currentStep.value = 1;
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
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text("fetch_site_settings_error".tr),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error fetching site settings: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("fetch_site_settings_error_message".tr),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void onInit() async {
    titleController.text = videoTitle.value;
    descriptionController.text = videoDescription.value;
    _loadBadWords();
    // await fetchSiteSettings();
    print("Fetching entities");
    await fetchEntity();
    super.onInit();
  }


  @override
  void dispose() {
    print('EditVideoView dispose: Disposing controllers');
    titleController.dispose();
    descriptionController.dispose();
    // tagFocusNode.dispose();
    super.dispose();
  }
}

void showLocationDialog(BuildContext context, {int? initialCountryId}) {
  final VideoAddController controller = Get.find();
  final ProfileController profileController = Get.find();
  final CityController cityController = Get.find<CityController>();

  print("Initial Country ID: $initialCountryId");

  Map<String, int> countryMap = {};
  List<String> countryName =
      profileController.videoUploadSettings.value!.countries!.map((country) {
        countryMap[country.name!] = country.id!;
        return country.name!;
      }).toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;
  RxString selectedCountryName =
      (controller.selectedCountry.value.isNotEmpty
              ? controller.selectedCountry.value
              : '')
          .obs;

  // Set the initial selected country if provided
  if (initialCountryId != null) {
    String? countryNameForId =
        countryMap.entries
            .firstWhere(
              (entry) => entry.value == initialCountryId,
              orElse: () => MapEntry('', 0),
            )
            .key;
    if (countryNameForId.isNotEmpty) {
      selectedCountryName.value = countryNameForId;
    }
  }

  // Filter countries based on search input
  void filterCountries(String query) {
    if (query.isEmpty) {
      filteredCountryName.value = countryName;
    } else {
      filteredCountryName.value =
          countryName
              .where(
                (country) =>
                    country.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
            /// **Header (Title + Close Button)**
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.black),
                    SizedBox(width: 8.w),
                    Text(
                      "select_country_label".tr,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// **Search Field**
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'search_country_placeholder'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: (value) => filterCountries(value),
            ),
            SizedBox(height: 16.h),

            /// **Scrollable Location List**
            Container(
              height: 230.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(filteredCountryName.length, (
                      index,
                    ) {
                      String country = filteredCountryName[index];
                      bool isSelected = selectedCountryName.value == country;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              selectedCountryName.value = country;
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 200.w,
                                    ),
                                    child: Text(
                                      country,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 20.w,
                                    height: 20.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ColorUtils.primaryColor,
                                        width: 2,
                                      ),
                                      color:
                                          isSelected
                                              ? ColorUtils.primaryColor
                                              : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < filteredCountryName.length - 1)
                            Divider(
                              height: 1.h,
                              thickness: 1.r,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            /// **Submit Button**
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCountryName.value.isNotEmpty
                        ? () async {
                          int? selectedId =
                              countryMap[selectedCountryName.value];
                          if (selectedId != null) {
                            controller.selectLocation(
                              selectedCountryName.value,
                              selectedId,
                            );
                            await cityController.fetchCities(selectedId);
                            Get.back(); // Close the country dialog
                            showCityDialog(context);
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  "Submit".tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showCityDialog(BuildContext context, {int? initialCityId}) {
  final VideoAddController controller = Get.find();
  final CityController cityController = Get.find<CityController>();

  print("Initial City ID: $initialCityId");

  Map<String, int> cityMap = {};
  List<String> cityName =
      cityController.cityList.map((city) {
        cityMap[city.name!] = city.id!;
        return city.name!;
      }).toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCityName = cityName.obs;
  RxString selectedCityName =
      (controller.selectedCity.value.isNotEmpty
              ? controller.selectedCity.value
              : '')
          .obs;

  // Set the initial selected city if provided
  if (initialCityId != null) {
    String? cityNameForId =
        cityMap.entries
            .firstWhere(
              (entry) => entry.value == initialCityId,
              orElse: () => MapEntry('', 0),
            )
            .key;
    if (cityNameForId.isNotEmpty) {
      selectedCityName.value = cityNameForId;
    }
  }

  // Filter cities based on search input
  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityName.value = cityName;
    } else {
      filteredCityName.value =
          cityName
              .where((city) => city.toLowerCase().contains(query.toLowerCase()))
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Obx(
        () => Container(
          width: 350.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child:
              cityController.isLoading.value
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// **Header (Title + Close Button)**
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.black),
                              SizedBox(width: 8.w),
                              Text(
                                "select_city_dialog_label".tr,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => Get.back(),
                            child: Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      /// **Search Field**
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'search_city_placeholder'.tr,
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(
                              color: ColorUtils.primaryColor,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10.h,
                            horizontal: 12.w,
                          ),
                        ),
                        onChanged: (value) => filterCities(value),
                      ),
                      SizedBox(height: 16.h),

                      /// **Scrollable Location List**
                      Container(
                        height: 230.h,
                        child: SingleChildScrollView(
                          child: Obx(
                            () => Column(
                              children: List.generate(filteredCityName.length, (
                                index,
                              ) {
                                String city = filteredCityName[index];
                                bool isSelected =
                                    selectedCityName.value == city;

                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        selectedCityName.value = city;
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: 200.w,
                                              ),
                                              child: Text(
                                                city,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 20.w,
                                              height: 20.w,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      ColorUtils.primaryColor,
                                                  width: 2,
                                                ),
                                                color:
                                                    isSelected
                                                        ? ColorUtils
                                                            .primaryColor
                                                        : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (index < filteredCityName.length - 1)
                                      Divider(
                                        height: 1.h,
                                        thickness: 1.r,
                                        color: Colors.grey.shade300,
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      /// **Submit Button**
                      Obx(
                        () => ElevatedButton(
                          onPressed:
                              selectedCityName.value.isNotEmpty
                                  ? () {
                                    int? selectedId =
                                        cityMap[selectedCityName.value];
                                    if (selectedId != null) {
                                      controller.selectCity(
                                        selectedCityName.value,
                                        selectedId,
                                      );
                                      print("SUBMITTED CITY ID: $selectedId");
                                      Get.back(); // Close the city dialog
                                    }
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            minimumSize: Size(double.infinity, 44.h),
                          ),
                          child: Text(
                            "Submit".tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    ),
  );
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
  AwesomeDialog(
    context: Get.context!,
    dialogType: DialogType.success,
    animType: AnimType.scale,
    title: "success_title".tr,
    desc: "upload_success_message".tr,
    autoDismiss: true,
    // Automatically dismiss the dialog
    onDismissCallback: (type) {
      // Navigate to Landing screen after dialog is dismissed
    },
  )..show();

  // Optional: Add a delay before navigation if you want the dialog to be visible briefly
  Future.delayed(Duration(seconds: 3), () {
    Get.offAll(() => Landing());
  });
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
