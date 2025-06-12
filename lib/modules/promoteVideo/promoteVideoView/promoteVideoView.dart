import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/auth/signUp/signUpController/signUpController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appUtils/colorUtils.dart';
import '../../landing/landingTabs/profile/profileControlller/profileController.dart';
import '../promoteVideoController/promoteVideoController.dart';

class PromoteVideoView extends StatefulWidget {
  final List<dynamic>? videos;

  const PromoteVideoView({super.key, required this.videos});

  @override
  State<PromoteVideoView> createState() => _PromoteVideoViewState();
}

class _PromoteVideoViewState extends State<PromoteVideoView> {
  final PromoteVideoController controller = Get.find();
  final SignUpController signUpController = Get.find();
  final CityController cityController = Get.put(CityController());
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
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadLanguage();
    controller.resetController();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: ColorUtils.primaryColor,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: ColorUtils.goldGradient),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 80.h),
                Text(
                  'promote_your_video'.tr,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.darkBrown,
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.videos == null || widget.videos!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No videos available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      else
                        Column(
                          children:
                              widget.videos!.map((video) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${'video_title_label'.tr}: ${video.title}',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.darkBrown,
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        "select_days_label".tr,
                                        style: TextStyle(
                                          color: ColorUtils.darkBrown,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      Obx(
                                        () => Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: ColorUtils.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: DropdownButton<int>(
                                            value: controller.getDays(video.id),
                                            isExpanded: true,
                                            underline: SizedBox(),
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: ColorUtils.darkBrown,
                                            ),
                                            items:
                                                controller.daysOptions.map((
                                                  days,
                                                ) {
                                                  return DropdownMenuItem<int>(
                                                    value: days,
                                                    child: Text(
                                                      '$days ${days > 1 ? 'days'.tr : 'day'.tr}',
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                        color:
                                                            ColorUtils
                                                                .darkBrown,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                            onChanged: (int? newValue) {
                                              if (newValue != null) {
                                                controller.setDays(
                                                  video.id,
                                                  newValue,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        "select_plan".tr,
                                        style: TextStyle(
                                          color: ColorUtils.darkBrown,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      Obx(
                                        () => Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: ColorUtils.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            value:
                                                controller
                                                    .selectedVideoType
                                                    .value,
                                            isExpanded: true,
                                            underline: SizedBox(),
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: ColorUtils.darkBrown,
                                            ),
                                            items: [
                                              DropdownMenuItem<String>(
                                                value: 'Basic',
                                                child: Text(
                                                  controller
                                                                  .siteSettings
                                                                  .value !=
                                                              null &&
                                                          controller
                                                                  .siteSettings
                                                                  .value!
                                                                  .settings !=
                                                              null
                                                      ? '${"Basic".tr} - ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.siteSettings.value!.settings!.basicSponsoredVideoPrice ?? 0}'
                                                      : 'Basic - SAR Loading...',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    color: ColorUtils.darkBrown,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem<String>(
                                                value: 'Premium',
                                                child: Text(
                                                  controller
                                                                  .siteSettings
                                                                  .value !=
                                                              null &&
                                                          controller
                                                                  .siteSettings
                                                                  .value!
                                                                  .settings !=
                                                              null
                                                      ? '${"Premium".tr} - ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.siteSettings.value!.settings!.premiumSponsoredVideoPrice ?? 0}'
                                                      : 'Premium - SAR Loading...',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    color: ColorUtils.darkBrown,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                controller.setVideoType(
                                                  newValue,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "select_target_country_label".tr,
                                            style: TextStyle(
                                              color: ColorUtils.darkBrown,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          SizedBox(height: 10.h),
                                          InkWell(
                                            onTap:
                                                () =>
                                                    showLocationDialog(context),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12.w,
                                                vertical: 16.h,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Color(
                                                    0xFFBDBDBD,
                                                  ).withOpacity(0.3),
                                                  width: 0.8,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                              ),
                                              child: Row(
                                                children: [
                                                  SvgPicture.asset(
                                                    "assets/icons/state.svg",
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Obx(
                                                    () => Text(
                                                      controller
                                                              .selectedCountry
                                                              .value
                                                              .isEmpty
                                                          ? "select_target_country_label"
                                                              .tr
                                                          : controller
                                                              .selectedCountry
                                                              .value,
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10.h),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "select_target_city_label".tr,
                                            style: TextStyle(
                                              color: ColorUtils.darkBrown,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          SizedBox(height: 10.h),
                                          InkWell(
                                            onTap:
                                                () => showCityDialog(context),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12.w,
                                                vertical: 16.h,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Color(
                                                    0xFFBDBDBD,
                                                  ).withOpacity(0.3),
                                                  width: 0.8,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                              ),
                                              child: Row(
                                                children: [
                                                  SvgPicture.asset(
                                                    "assets/icons/state.svg",
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Obx(() {
                                                    if (controller
                                                        .selectedCities
                                                        .isEmpty) {
                                                      return Text(
                                                        "select_target_city_placeholder"
                                                            .tr,
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
                                                          color: Colors.black,
                                                        ),
                                                      );
                                                    }
                                                    var cityNames = controller
                                                        .selectedCities
                                                        .join(", ");
                                                    return ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                            maxWidth: 220.w,
                                                          ),
                                                      child: IntrinsicWidth(
                                                        child: Text(
                                                          cityNames.isEmpty
                                                              ? "Select target City"
                                                              : cityNames,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          maxLines: 1,
                                                          style: TextStyle(
                                                            fontSize: 14.sp,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                  Spacer(),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          Obx(
                                            () =>
                                                controller.validationErrors["cities"] !=
                                                            null &&
                                                        controller
                                                            .validationErrors["cities"]!
                                                            .isNotEmpty
                                                    ? Padding(
                                                      padding: EdgeInsets.only(
                                                        top: 4.h,
                                                        left: 16.w,
                                                      ),
                                                      child: Text(
                                                        controller
                                                            .validationErrors["cities"]!
                                                            .first,
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12.sp,
                                                        ),
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                          Obx(
                                            () =>
                                                signUpController
                                                        .cityError
                                                        .value
                                                        .isNotEmpty
                                                    ? Padding(
                                                      padding: EdgeInsets.only(
                                                        top: 4.h,
                                                        left: 16.w,
                                                      ),
                                                      child: Text(
                                                        signUpController
                                                            .cityError
                                                            .value,
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12.sp,
                                                        ),
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10.h),
                                      Obx(
                                        () => Align(
                                          alignment:
                                              AlignmentDirectional.bottomEnd,
                                          // Adapts to RTL: bottom-right in LTR, bottom-left in RTL
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                            ),
                                            // Padding for spacing
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              // End: right in LTR, left in RTL
                                              children: [
                                                Text(
                                                  '${'total_price_label'.tr} ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.calculateBasePrice(video.id).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    color: ColorUtils.darkBrown,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textDirection:
                                                      TextDirection
                                                          .ltr, // LTR for numbers and currency
                                                ),
                                                if (controller
                                                            .entityDetails
                                                            .value['subscription_required'] ==
                                                        1 &&
                                                    controller
                                                            .siteSettings
                                                            .value
                                                            ?.settings
                                                            ?.sponsorVideoDiscount !=
                                                        null)
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    // End: right in LTR, left in RTL
                                                    children: [
                                                      Text(
                                                        '${'discount'.tr} ',
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        // Inherit directionality for RTL text
                                                      ),
                                                      Text(
                                                        '(${controller.siteSettings.value!.settings!.sponsorVideoDiscount}%): ',
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        textDirection:
                                                            TextDirection
                                                                .ltr, // LTR for percentage
                                                      ),
                                                      Text(
                                                        Get.locale?.languageCode ==
                                                                'ar'
                                                            ? '${controller.calculateDiscountAmount(video.id).toStringAsFixed(2)} ${controller.siteSettings.value!.settings!.currencySymbol} '
                                                            : '${controller.siteSettings.value!.settings!.currencySymbol} ${controller.calculateDiscountAmount(video.id).toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        textDirection:
                                                            TextDirection
                                                                .ltr, // LTR for currency and amount
                                                      ),
                                                    ],
                                                  ),
                                                Text(
                                                  '${'sub_total_label'.tr} ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.calculateTotalPrice(video.id).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    color: ColorUtils.darkBrown,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textDirection:
                                                      TextDirection
                                                          .ltr, // LTR for numbers and currency
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                    ],
                  ),
                ),
                Obx(() {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppButton(
                      text: "promote_video".tr,
                      isLoading: controller.isLoading.value,
                      onTap: () async {
                        print(
                          controller
                              .siteSettings
                              .value
                              ?.settings
                              ?.currencySymbol,
                        );
                        bool success = await controller.initiatePayment(
                          widget.videos!.first.id,
                          context,
                        );
                        if (success) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                }),
                SizedBox(height: 20.h),
              ],
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
                    isRtl ? Icons.arrow_back : Icons.arrow_back,
                    color: ColorUtils.darkBrown,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          AppCenterIcon(),
        ],
      ),
    );
  }

  void showLocationDialog(BuildContext context) {
    final PromoteVideoController controller = Get.find();
    final ProfileController profileController = Get.find();
    final CityController cityController = Get.put(CityController());

    Map<String, int> countryMap = {};
    List<String> countryName =
        profileController.videoUploadSettings.value!.countries!.map((country) {
          countryMap[country.name!] = country.id!;
          return country.name!;
        }).toList();

    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCountryName = countryName.obs;
    RxString selectedCountryName =
        (controller.selectedCountry.value.isNotEmpty
                ? controller.selectedCountry.value
                : '')
            .obs;

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
                        "Select Country".tr,
                        style: TextStyle(
                          fontSize: 14.sp,
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
                      children: List.generate(filteredCountryName.length, (
                        index,
                      ) {
                        String country = filteredCountryName[index];
                        bool isSelected = selectedCountryName.value == country;

                        return InkWell(
                          onTap: () {
                            selectedCountryName.value = country;
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 200.w),
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
                        );
                      }),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
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
                              Get.back();
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

  void showCityDialog(BuildContext context) {
    final PromoteVideoController controller = Get.find();
    final CityController cityController = Get.put(CityController());

    Map<String, int> cityMap = {};
    List<String> cityName =
        cityController.cityList.map((city) {
          cityMap[city.name!] = city.id!;
          return city.name!;
        }).toList();

    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCityName = cityName.obs;
    RxList<String> selectedCities = controller.selectedCities.toList().obs;

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
                                  "select_cities_dialog_label".tr,
                                  style: TextStyle(
                                    fontSize: 14.sp,
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
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          height: 230.h,
                          child: SingleChildScrollView(
                            child: Obx(
                              () => Column(
                                children: List.generate(
                                  filteredCityName.length,
                                  (index) {
                                    String city = filteredCityName[index];
                                    bool isSelected = selectedCities.contains(
                                      city,
                                    );

                                    return InkWell(
                                      onTap: () {
                                        if (isSelected) {
                                          selectedCities.remove(city);
                                        } else {
                                          selectedCities.add(city);
                                        }
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
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                if (value != null) {
                                                  if (value) {
                                                    selectedCities.add(city);
                                                  } else {
                                                    selectedCities.remove(city);
                                                  }
                                                }
                                              },
                                              activeColor:
                                                  ColorUtils.primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Obx(
                          () => ElevatedButton(
                            onPressed:
                                selectedCities.isNotEmpty
                                    ? () {
                                      // Update controller with selected cities
                                      for (String city in selectedCities) {
                                        controller.toggleCity(
                                          city,
                                          cityMap[city]!,
                                        );
                                      }
                                      Get.back();
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
}
