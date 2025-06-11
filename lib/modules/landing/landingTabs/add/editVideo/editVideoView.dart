import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../appUtils/appUtils.dart';
import '../../profile/profileControlller/profileController.dart';

class EditVideoView extends StatefulWidget {
  final List<dynamic>? videos;

  const EditVideoView({super.key, this.videos});

  @override
  State<EditVideoView> createState() => _EditVideoViewState();
}

class _EditVideoViewState extends State<EditVideoView> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<FormFieldState> videoTypeKey = GlobalKey<FormFieldState>();
  final CityController cityController = Get.find();
  final GlobalKey<FormFieldState> tagKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Add form key
  final FocusNode tagFocusNode = FocusNode();

  // Store original values for comparison
  late final String originalTitle;
  late final String originalDescription;
  late final List<String> originalTags;
  late final String originalVideoType;
  late final int originalPublishType;
  late final bool originalAllowComments;
  late final bool originalTakeOrder;
  late final int? originalCountry;
  late final int? originalCity;

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  Future<int> getEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('entity') ?? 0;
  }

  int entity = -1;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    final VideoAddController controller = Get.find();

    if (widget.videos!.isNotEmpty) {
      final videoData = widget.videos!.first;

      // Store original values
      originalTitle = videoData.title?.trim() ?? '';
      originalDescription = videoData.description?.trim() ?? '';
      originalTags =
          videoData.tags != null && videoData.tags.isNotEmpty
              ? videoData.tags
                  .split(',')
                  .map((tag) => tag.trim())
                  .toList()
                  .cast<String>()
              : <String>[];
      originalVideoType = videoData.videoType.toString();
      originalPublishType = videoData.publishType ?? 0;
      originalAllowComments = videoData.allowComments == 1;
      originalTakeOrder = videoData.takeOrder == 1;
      originalCountry = videoData.country;
      originalCity = videoData.city;

      // Initialize controllers with original values
      titleController = TextEditingController(text: originalTitle);
      descriptionController = TextEditingController(text: originalDescription);

      // Initialize tags
      if (originalTags.isNotEmpty) {
        controller.initializeTags(originalTags);
      }

      // Set visibility and comments
      controller.setVisibilityFromInt(videoData.publishType);
      controller.allowComments.value = originalAllowComments;
      controller.acceptOrder.value = originalTakeOrder;

      // Initialize country and city
      initializeCountryAndCity(videoData);
      _initializeEntity(controller);
    }
  }

  @override
  void dispose() {
    print('EditVideoView dispose: Disposing controllers and focus node');
    // FocusScope.of(context).unfocus(); // Ensure no fields are focused
    tagFocusNode.unfocus(); // Explicitly un-focus tag field
    titleController.dispose();
    descriptionController.dispose();
    tagFocusNode.dispose();

    super.dispose();
  }

  // Method to validate all form fields
  bool _validateForm() {
    bool isValid = true;
    final VideoAddController controller = Get.find();

    // Debug logging
    print('Form key state: ${_formKey.currentState}');
    print('Tag key state: ${tagKey.currentState}');
    print('Video type key state: ${videoTypeKey.currentState}');

    // Validate form fields
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      isValid = false;
    }

    // Validate tags
    if (tagKey.currentState != null && !tagKey.currentState!.validate()) {
      isValid = false;
    }

    // Validate video type using controller value instead of videoTypeKey
    if (controller.videoType.value.isEmpty ||
        controller.videoType.value == '0') {
      _showValidationError('Please select a video type');
      isValid = false;
    }

    // Additional custom validations
    if (titleController.text.trim().isEmpty) {
      _showValidationError('Title is required');
      isValid = false;
    }

    if (controller.tagsList.isEmpty) {
      _showValidationError('tag_error'.tr);
      isValid = false;
    }

    return isValid;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 20, left: 10, right: 10),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Method to check if any values have changed
  bool hasChanges() {
    final VideoAddController controller = Get.find();

    // Get current values
    String currentTitle = titleController.text.trim();
    String currentDescription = descriptionController.text.trim();
    List<String> currentTags = List<String>.from(controller.tagsList);
    String currentVideoType = controller.videoType.value;
    int currentPublishType = int.tryParse(controller.publishType.value) ?? 0;
    bool currentAllowComments = controller.allowComments.value;
    bool currentTakeOrder = controller.acceptOrder.value;
    int? currentCountry =
        controller.selectedLocationId > 0
            ? controller.selectedLocationId
            : null;
    int? currentCity =
        controller.selectedCityId > 0 ? controller.selectedCityId : null;

    // Compare with original values
    bool titleChanged = currentTitle != originalTitle;
    bool descriptionChanged = currentDescription != originalDescription;
    bool tagsChanged = !_listEquals(currentTags, originalTags);
    bool videoTypeChanged = currentVideoType != originalVideoType;
    bool publishTypeChanged = currentPublishType != originalPublishType;
    bool allowCommentsChanged = currentAllowComments != originalAllowComments;
    bool takeOrderChanged = currentTakeOrder != originalTakeOrder;
    bool countryChanged = currentCountry != originalCountry;
    bool cityChanged = currentCity != originalCity;

    return titleChanged ||
        descriptionChanged ||
        tagsChanged ||
        videoTypeChanged ||
        publishTypeChanged ||
        allowCommentsChanged ||
        takeOrderChanged ||
        countryChanged ||
        cityChanged;
  }

  // Helper method to compare lists
  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _initializeEntity(VideoAddController controller) async {
    final entityValue = await getEntity();
    setState(() {
      entity = entityValue;
    });
  }

  Future<void> initializeCountryAndCity(dynamic videoData) async {
    final VideoAddController controller = Get.find();
    final ProfileController profileController = Get.find();

    // Populate countryMap
    Map<String, int> countryMap = {};
    profileController.videoUploadSettings.value?.countries?.forEach((country) {
      countryMap[country.name!] = country.id!;
    });

    // Set initial country
    String? countryNameForId =
        countryMap.entries
            .firstWhere(
              (entry) => entry.value == videoData.country,
              orElse: () => MapEntry('', 0),
            )
            .key;

    if (countryNameForId.isNotEmpty && videoData.country != null) {
      controller.selectLocation(countryNameForId, videoData.country);
      // Fetch cities for the selected country
      await cityController.fetchCities(videoData.country);
    } else {
      controller.selectLocation('', 0); // Reset if no valid country
    }

    // Set initial city
    if (videoData.city != null && cityController.cityList.isNotEmpty) {
      String? cityNameForId =
          cityController.cityList
              .firstWhere((city) => city.id == videoData.city)
              .name;

      if (cityNameForId != null) {
        controller.selectCity(cityNameForId, videoData.city);
      } else {
        controller.selectCity('', 0); // Reset if no valid city
      }
    } else {
      controller.selectCity('', 0); // Reset if no valid city
    }
  }

  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      'Building EditVideoView, scaffoldMessengerKey: $_scaffoldMessengerKey',
    );
    final VideoAddController controller = Get.find();
    final ProfileController profileController = Get.find();
    final videoData = widget.videos!.first;

    String getFieldValue(String? value) {
      return value?.trim().isNotEmpty == true ? value! : '';
    }

    controller.videoType.value = videoData.videoType.toString();

    // Video Type Mapping
    Map<String, int> videoTypeMap = {};
    List<String> videoTypeNames = [];
    String? initialVideoTypeName;

    if (profileController.videoUploadSettings.value?.videoTypes?.values !=
        null) {
      videoTypeNames =
          profileController.videoUploadSettings.value!.videoTypes!.values!.map((
            videoType,
          ) {
            videoTypeMap[videoType.name!] = videoType.id!;
            return videoType.name!;
          }).toList();

      if (videoData.videoType != null) {
        final matchingVideoType = videoTypeMap.entries.firstWhere(
          (entry) => entry.value == videoData.videoType,
          orElse: () => MapEntry('', 0),
        );
        initialVideoTypeName =
            matchingVideoType.key.isEmpty ? null : matchingVideoType.key;
      }
    }

    bool isRtl = _language == 'ar';

    return Obx(
      () =>
          cityController.isLoading.value
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : WillPopScope(
                onWillPop: () async {
                  print('System back button pressed');
                  if (mounted) {
                    FocusScope.of(context).unfocus(); // Un-focus all fields
                    Get.back();
                    return true; // Allow navigation
                  }
                  return false; // Prevent navigation if not mounted
                },
                child: Scaffold(
                  key: _scaffoldMessengerKey,
                  appBar: AppBar(
                    toolbarHeight: 0,
                    elevation: 0,
                    backgroundColor: ColorUtils.primaryColor,
                  ),
                  body: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: ColorUtils.goldGradient,
                        ),
                      ),
                      SingleChildScrollView(
                        child: Form(
                          // Wrap with Form widget
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Center(
                                    child: InkWell(
                                      onTap: () {},
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 20),
                                        height: 50.h,
                                        width: 50.h,
                                        child: Image.asset(
                                          "assets/images/appIconC.png",
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    // Conditionally set left or right based on language
                                    left: isRtl ? null : 16,
                                    right: isRtl ? 16 : null,
                                    top: 20,
                                    // Assuming .h is from a package like flutter_screenutil, replace with 20 if not using it
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        try {
                                          print("Tapped");
                                          Get.back();
                                        } catch (e) {
                                          print(e);
                                        }
                                      },
                                      child: Container(
                                        height: 40,
                                        width: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE6BE00),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            // Use right chevron for Arabic, left chevron for English
                                            isRtl
                                                ? Icons.arrow_back
                                                : Icons.arrow_back,
                                            color: ColorUtils.darkBrown,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40.r),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Column(
                                    spacing: 10.h,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(height: 20.h),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Edit Video".tr,
                                            style: TextStyle(
                                              color: ColorUtils.darkBrown,
                                              fontSize: 22.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Title field with validation
                                      TextFormField(
                                        controller: titleController,
                                        decoration: InputDecoration(
                                          labelText: 'Enter title'.tr,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          // Check for empty input
                                          if (value == null || value.isEmpty) {
                                            return "video_title_error".tr;
                                          }
                                          // Check for bad words
                                          final badWordError = controller
                                              .checkBadWords(context, value);
                                          if (badWordError != null) {
                                            return badWordError;
                                          }
                                          return null;
                                        },
                                      ),

                                      // Description field with validation
                                      TextFormField(
                                        controller: descriptionController,
                                        decoration: InputDecoration(
                                          labelText: 'enter_description'.tr,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        maxLines: 3,
                                        validator: (value) {
                                          if (value != null &&
                                              value.trim().isNotEmpty) {
                                            // Check minimum length

                                            // Check for bad words
                                            final badWordError = controller
                                                .checkBadWords(context, value);
                                            if (badWordError != null) {
                                              return badWordError;
                                            }
                                          }
                                          return null; // Empty description is valid
                                        },
                                      ),

                                      // Video type dropdown with validation
                                      DropdownFlutter<String>(
                                        key: videoTypeKey,
                                        initialItem: initialVideoTypeName,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Please select a video type";
                                          }
                                          return null;
                                        },
                                        closedHeaderPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                        decoration: CustomDropdownDecoration(
                                          closedBorderRadius:
                                              BorderRadius.circular(8),
                                          expandedBorderRadius:
                                              BorderRadius.circular(8),
                                          closedFillColor: Colors.transparent,
                                          closedBorder: Border.all(
                                            color: const Color(
                                              0xFFBDBDBD,
                                            ).withOpacity(0.3),
                                            width: 0.8,
                                          ),
                                          closedSuffixIcon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                          ),
                                        ),
                                        hintText: "Select video type",
                                        items: videoTypeNames,
                                        onChanged: (String? selectedValue) {
                                          if (selectedValue != null) {
                                            int? selectedId =
                                                videoTypeMap[selectedValue];
                                            controller.videoType.value =
                                                selectedId.toString();
                                            // Trigger validation
                                            videoTypeKey.currentState
                                                ?.validate();
                                          }
                                        },
                                      ),

                                      // Tags field with validation
                                      AppUtils.customPasswordTextField(
                                        fieldKey: tagKey,
                                        labelText: "Enter Tag Here".tr,
                                        controller: controller.tagController,
                                        focusNode: tagFocusNode,
                                        validator: (value) {
                                          if (value != null &&
                                              value.isNotEmpty) {
                                            final badWordError = controller
                                                .checkBadWords(context, value);
                                            if (badWordError != null) {
                                              return badWordError;
                                            }
                                          }

                                          if (controller.tagsList.isEmpty) {
                                            return "tag_error".tr;
                                          }

                                          return null;
                                        },
                                        onChanged: (value) {
                                          if (value.contains(",")) {
                                            controller.addTag(
                                              value.replaceAll(",", "").trim(),
                                            );
                                            controller.tagController.clear();
                                            tagKey.currentState?.validate();
                                          }
                                        },
                                        onSubmitted: (value) {
                                          final cleanedValue = value.trim();
                                          final badWordError = controller
                                              .checkBadWords(
                                                context,
                                                cleanedValue,
                                              );

                                          if (cleanedValue.isNotEmpty &&
                                              badWordError == null) {
                                            controller.addTag(cleanedValue);
                                          }

                                          controller.tagController.clear();
                                          tagKey.currentState?.validate();
                                        },
                                        textInputAction: TextInputAction.done,
                                      ),
                                      Wrap(
                                        spacing: 8.0,
                                        children:
                                            controller.tagsList.map((tag) {
                                              return Chip(
                                                backgroundColor:
                                                    ColorUtils
                                                        .greyTextFieldBorderColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                labelStyle: TextStyle(
                                                  fontSize: 12.sp,
                                                ),
                                                label: Text(tag),
                                                deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                                onDeleted: () {
                                                  controller.tagsList.remove(
                                                    tag,
                                                  );
                                                  tagKey.currentState
                                                      ?.validate();
                                                },
                                              );
                                            }).toList(),
                                      ),
                                      if (controller.tagsList.length == 5)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            "Only 5 tags are allowed.",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                      Wrap(
                                        spacing: 0.w,
                                        runSpacing: 0.h,
                                        alignment: WrapAlignment.start,
                                        children: [
                                          buildRadioOption(
                                            "public_option".tr,
                                            VisibilityOption.public,
                                            controller,
                                          ),
                                          buildRadioOption(
                                            "only_followers_option".tr,
                                            VisibilityOption.onlyFollowers,
                                            controller,
                                          ),
                                          buildRadioOption(
                                            "private_option".tr,
                                            VisibilityOption.private,
                                            controller,
                                          ),
                                        ],
                                      ),
                                      Divider(
                                        color: const Color(0xFFD5D5D5),
                                        thickness: 0.2,
                                      ),
                                      Obx(
                                        () => buildToggleOption(
                                          icon: "assets/icons/comment.svg",
                                          title: "Allow Comments".tr,
                                          value: controller.allowComments.value,
                                          onChanged:
                                              (value) =>
                                                  controller.toggleComments(),
                                        ),
                                      ),
                                      Divider(
                                        color: const Color(0xFFD5D5D5),
                                        thickness: 0.2,
                                      ),
                                      if (entity == 2)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "want_to_take_orders".tr,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Obx(() {
                                              return Switch(
                                                activeColor:
                                                    Colors.yellow.shade700,
                                                value:
                                                    controller
                                                        .acceptOrder
                                                        .value,
                                                onChanged: (value) {
                                                  controller.toggleSwitch();
                                                },
                                              );
                                            }),
                                          ],
                                        ),

                                      buildClickableOption(
                                        icon: Icons.location_on,
                                        title: "Location",
                                        videoData: videoData,
                                        onCountryTap: () {
                                          showLocationDialog(
                                            context,
                                            initialCountryId: videoData.country,
                                          );
                                          print(
                                            "Country ID: ${videoData.country}",
                                          );
                                        },
                                        onCityTap: () {
                                          if (controller
                                              .selectedCountry
                                              .value
                                              .isEmpty) {
                                            Get.snackbar(
                                              'Error',
                                              'Please select a country first',
                                            );
                                            return;
                                          }
                                          showCityDialog(
                                            context,
                                            initialCityId: videoData.city,
                                          );
                                          print("City ID: ${videoData.city}");
                                        },
                                        context: context,
                                      ),

                                      SizedBox(height: 20.h),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: AppButton(
                                  text: "Update",
                                  isLoading:
                                      controller.isUploadSuccessful.value,
                                  onTap: () async {
                                    if (!_validateForm()) {
                                      print('Form validation failed');
                                      return;
                                    }

                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: AppButton(
                                        text: "Update",
                                        isLoading:
                                            controller.isUploadSuccessful.value,
                                        onTap: () async {
                                          if (!_validateForm()) {
                                            print('Form validation failed');
                                            return;
                                          }

                                          if (!hasChanges()) {
                                            if (mounted) {
                                              // Still check mounted to ensure widget is active
                                              print(
                                                'Showing no changes snackbar',
                                              );
                                              Get.snackbar(
                                                'No Changes', // Title
                                                'No changes were made to the video.',
                                                // Message
                                                snackPosition:
                                                    SnackPosition.TOP,
                                                // Display at the top
                                                backgroundColor: Colors.orange,
                                                colorText: Colors.white,
                                                margin: const EdgeInsets.only(
                                                  top: 20,
                                                  left: 10,
                                                  right: 10,
                                                ),
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                                isDismissible: true,
                                                dismissDirection:
                                                    DismissDirection.horizontal,
                                                mainButton: TextButton(
                                                  onPressed: () {
                                                    print(
                                                      'Dismissing no changes snackbar',
                                                    );
                                                    Get.closeCurrentSnackbar();
                                                  },
                                                  child: const Text(
                                                    'Dismiss',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              print(
                                                'Widget not mounted, skipping no changes snackbar',
                                              );
                                            }
                                            return;
                                          }

                                          // Print all values before calling updateVideo
                                          print('Video ID: ${videoData.id}');
                                          print(
                                            'Title: ${titleController.text}',
                                          );
                                          print(
                                            'Video Type: ${controller.videoType}',
                                          );
                                          print(
                                            'Take Order: ${videoData.takeOrder}',
                                          );
                                          print(
                                            'Title: ${titleController.text.isNotEmpty ? titleController.text : null}',
                                          );
                                          print(
                                            'Description: ${descriptionController.text.isNotEmpty ? descriptionController.text : null}',
                                          );
                                          print(
                                            'Tags: ${controller.tagsList.isNotEmpty ? controller.tagsList.join(',') : null}',
                                          );
                                          print(
                                            'Publish Type: ${int.tryParse(controller.publishType.value)}',
                                          );
                                          print(
                                            'Allow Comments: ${controller.allowComments.value ? 1 : 0}',
                                          );
                                          print(
                                            'Country ID: ${controller.selectedLocationId > 0 ? controller.selectedLocationId : null}',
                                          );
                                          print(
                                            'City ID: ${controller.selectedCityId > 0 ? controller.selectedCityId : null}',
                                          );

                                          // Perform the update
                                          try {
                                            await controller.updateVideo(
                                              takeOrder:
                                                  controller.acceptOrder.value
                                                      ? 1
                                                      : 0,
                                              videoType:
                                                  controller.videoType.value,
                                              videoData.id,
                                              title:
                                                  titleController
                                                          .text
                                                          .isNotEmpty
                                                      ? titleController.text
                                                      : null,
                                              description:
                                                  descriptionController
                                                          .text
                                                          .isNotEmpty
                                                      ? descriptionController
                                                          .text
                                                      : null,
                                              tags:
                                                  controller.tagsList.isNotEmpty
                                                      ? controller.tagsList
                                                          .join(',')
                                                      : null,
                                              publishType: int.tryParse(
                                                controller.publishType.value,
                                              ),
                                              allowComments:
                                                  controller.allowComments.value
                                                      ? 1
                                                      : 0,
                                              country:
                                                  controller.selectedLocationId >
                                                          0
                                                      ? controller
                                                          .selectedLocationId
                                                      : null,
                                              city:
                                                  controller.selectedCityId > 0
                                                      ? controller
                                                          .selectedCityId
                                                      : null,
                                            );

                                            if (mounted &&
                                                controller
                                                    .isUploadSuccessful
                                                    .value) {
                                              print(
                                                'Update successful, navigating back',
                                              );
                                              // Get.back();
                                            } else if (mounted) {
                                              print(
                                                'Update failed, showing error snackbar',
                                              );
                                              Get.snackbar(
                                                'Error',
                                                'Failed to update video',
                                                snackPosition:
                                                    SnackPosition.TOP,
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                                margin: const EdgeInsets.only(
                                                  top: 20,
                                                  left: 10,
                                                  right: 10,
                                                ),
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                                isDismissible: true,
                                                dismissDirection:
                                                    DismissDirection.horizontal,
                                              );
                                            }
                                          } catch (e) {
                                            print('Error during update: $e');
                                            if (mounted) {
                                              Get.snackbar(
                                                'Error',
                                                'Error: $e',
                                                snackPosition:
                                                    SnackPosition.TOP,
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                                margin: const EdgeInsets.only(
                                                  top: 20,
                                                  left: 10,
                                                  right: 10,
                                                ),
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                                isDismissible: true,
                                                dismissDirection:
                                                    DismissDirection.horizontal,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    );

                                    // Perform the update
                                    try {
                                      await controller.updateVideo(
                                        takeOrder:
                                            controller.acceptOrder.value
                                                ? 1
                                                : 0,
                                        videoType: controller.videoType.value,
                                        videoData.id,
                                        title:
                                            titleController.text.isNotEmpty
                                                ? titleController.text
                                                : null,
                                        description:
                                            descriptionController
                                                    .text
                                                    .isNotEmpty
                                                ? descriptionController.text
                                                : null,
                                        tags:
                                            controller.tagsList.isNotEmpty
                                                ? controller.tagsList.join(',')
                                                : null,
                                        publishType: int.tryParse(
                                          controller.publishType.value,
                                        ),
                                        allowComments:
                                            controller.allowComments.value
                                                ? 1
                                                : 0,
                                        country:
                                            controller.selectedLocationId > 0
                                                ? controller.selectedLocationId
                                                : null,
                                        city:
                                            controller.selectedCityId > 0
                                                ? controller.selectedCityId
                                                : null,
                                      );

                                      if (mounted &&
                                          controller.isUploadSuccessful.value) {
                                        print(
                                          'Update successful, navigating back',
                                        );
                                        Get.back();
                                      } else if (mounted &&
                                          _scaffoldMessengerKey.currentState !=
                                              null) {
                                        print(
                                          'Update failed, showing error snackbar',
                                        );
                                        _scaffoldMessengerKey.currentState!
                                            .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Failed to update video',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(
                                                  bottom: 20,
                                                  left: 10,
                                                  right: 10,
                                                ),
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                              ),
                                            );
                                      }
                                    } catch (e) {
                                      print('Error during update: $e');
                                      if (mounted &&
                                          _scaffoldMessengerKey.currentState !=
                                              null) {
                                        _scaffoldMessengerKey.currentState!
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error: $e',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                margin: const EdgeInsets.only(
                                                  bottom: 20,
                                                  left: 10,
                                                  right: 10,
                                                ),
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  },
                                ),
                              ),
                              SizedBox(height: 40.h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget buildRadioOption(
    String title,
    VisibilityOption option,
    VideoAddController ctrl,
  ) {
    return ListTileTheme(
      // horizontalTitleGap: 1,
      child: GestureDetector(
        onTap: () => ctrl.setVisibility(option),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Obx(
              () => Radio<VisibilityOption>(
                fillColor: MaterialStateColor.resolveWith(
                  (states) => ColorUtils.primaryColor,
                ),
                activeColor: Colors.yellow.shade700,
                value: option,
                groupValue: ctrl.selectedVisibility.value,
                onChanged: (value) {
                  ctrl.setVisibility(value!);
                },
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildToggleOption({
    required String icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              icon,
              color: ColorUtils.greyTextFieldBorderColor,
              height: 15.h,
            ),
            SizedBox(width: 16.w),
            Text(
              title,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Switch(
          value: value,
          activeColor: Colors.yellow.shade700,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget buildClickableOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required dynamic videoData,
    required Function() onCountryTap,
    required Function() onCityTap,
  }) {
    final VideoAddController controller = Get.find();
    return Column(
      children: [
        InkWell(
          onTap: onCountryTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(icon, color: ColorUtils.greyTextFieldBorderColor),
                    SizedBox(width: 16.w),
                    Text(
                      'select_country_label'.tr,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Obx(
                  () => Text(
                    controller.selectedCountry.value.isEmpty
                        ? "select_country_label".tr
                        : controller.selectedCountry.value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color:
                          controller.selectedCountry.value.isEmpty
                              ? Colors.grey
                              : Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: onCityTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(icon, color: ColorUtils.greyTextFieldBorderColor),
                    SizedBox(width: 16.w),
                    Text(
                      'select_city_label'.tr,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Obx(
                  () => Text(
                    controller.selectedCity.value.isEmpty
                        ? "select_city_label".tr
                        : controller.selectedCity.value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color:
                          controller.selectedCity.value.isEmpty
                              ? Colors.grey
                              : Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void showLocationDialog(BuildContext context, {int? initialCountryId}) {
    final VideoAddController controller = Get.find();
    final ProfileController profileController = Get.find();
    final CityController cityController = Get.find<CityController>();

    Map<String, int> countryMap = {};
    List<String> countryName =
        profileController.videoUploadSettings.value!.countries!.map((country) {
          countryMap[country.name!] = country.id!;
          return country.name!;
        }).toList();

    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCountryName = countryName.obs;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.black),
                      SizedBox(width: 8.w),
                      Text(
                        "select_country_dialog_label".tr,
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
              Container(
                height: 230.h,
                child: SingleChildScrollView(
                  child: Obx(
                    () => Column(
                      children: List.generate(
                        filteredCountryName.length,
                        (index) => InkWell(
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              controller.selectLocation(
                                filteredCountryName[index],
                                countryMap[filteredCountryName[index]]!,
                              );
                              Get.back();
                              await cityController.fetchCities(
                                countryMap[filteredCountryName[index]]!,
                              );
                              if (cityController.cityList.isNotEmpty) {
                                showCityDialog(context);
                              } else {
                                Get.snackbar(
                                  'Error',
                                  'No cities available for this country',
                                );
                              }
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  filteredCountryName[index],
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight:
                                        controller.selectedCountry.value ==
                                                filteredCountryName[index]
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color: Colors.black,
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
                                        controller.selectedCountry.value ==
                                                filteredCountryName[index]
                                            ? ColorUtils.primaryColor
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  void showCityDialog(BuildContext context, {int? initialCityId}) {
    final VideoAddController controller = Get.find();
    final CityController cityController = Get.find<CityController>();

    Map<String, int> cityMap = {};
    List<String> cityName =
        cityController.cityList.map((city) {
          cityMap[city.name!] = city.id!;
          return city.name!;
        }).toList();

    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCityName = cityName.obs;

    void filterCities(String query) {
      if (query.isEmpty) {
        filteredCityName.value = cityName;
      } else {
        filteredCityName.value =
            cityName
                .where(
                  (city) => city.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
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
                          enabled: cityName.isNotEmpty,
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          height: 230.h,
                          child:
                              cityName.isEmpty
                                  ? Center(child: Text("No cities available"))
                                  : SingleChildScrollView(
                                    child: Obx(
                                      () => Column(
                                        children: List.generate(
                                          filteredCityName.length,
                                          (index) => InkWell(
                                            onTap: () {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    controller.selectCity(
                                                      filteredCityName[index],
                                                      cityMap[filteredCityName[index]]!,
                                                    );
                                                    Get.back();
                                                  });
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12.h,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    filteredCityName[index],
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      fontWeight:
                                                          controller
                                                                      .selectedCity
                                                                      .value ==
                                                                  filteredCityName[index]
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 20.w,
                                                    height: 20.w,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            ColorUtils
                                                                .primaryColor,
                                                        width: 2,
                                                      ),
                                                      color:
                                                          controller
                                                                      .selectedCity
                                                                      .value ==
                                                                  filteredCityName[index]
                                                              ? ColorUtils
                                                                  .primaryColor
                                                              : Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
