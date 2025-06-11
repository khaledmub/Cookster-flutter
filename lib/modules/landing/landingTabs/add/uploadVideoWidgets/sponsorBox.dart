import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../../../../../appUtils/colorUtils.dart';
import '../../../../auth/signUp/signUpController/cityController.dart';
import '../../profile/profileControlller/profileController.dart';

class SponsorBox extends StatelessWidget {
  const SponsorBox({super.key});

  @override
  Widget build(BuildContext context) {
    final VideoAddController controller = Get.find();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "sponsor_data_label".tr,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            "select_days_label".tr,
            style: TextStyle(
              color: ColorUtils.darkBrown,
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Obx(
            () => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                border: Border.all(color: ColorUtils.grey),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButton<int>(
                value: controller.selectedDays.value,
                isExpanded: true,
                underline: SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: ColorUtils.darkBrown),
                items: List.generate(30, (index) {
                  final days = index + 1;
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text(
                      '$days ${days > 1 ? 'days'.tr : 'day'.tr}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: ColorUtils.darkBrown,
                      ),
                    ),
                  );
                }),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    controller.selectedDays.value = newValue;
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            "select_plan".tr,
            style: TextStyle(
              color: ColorUtils.darkBrown,
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Obx(
            () => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                border: Border.all(color: ColorUtils.grey),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButton<String>(
                value: controller.selectedVideoType.value,
                isExpanded: true,
                underline: SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: ColorUtils.darkBrown),
                items: [
                  DropdownMenuItem<String>(
                    value: 'Basic',
                    child: Text(
                      controller.siteSettings.value != null &&
                              controller.siteSettings.value!.settings != null
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
                      controller.siteSettings.value != null &&
                              controller.siteSettings.value!.settings != null
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
                    controller.setVideoType(newValue);
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 10.h),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "select_target_country_label".tr,
                style: TextStyle(
                  color: ColorUtils.darkBrown,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 10.h),
              InkWell(
                onTap: () => showLocationDialog(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFFBDBDBD).withOpacity(0.3),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset("assets/icons/state.svg"),
                      SizedBox(width: 8.w),
                      Obx(
                        () => Text(
                          controller.selectedCountry.value.isEmpty
                              ? "select_target_country_placeholder".tr
                              : controller.selectedCountry.value,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "select_target_city_label".tr,
                style: TextStyle(
                  color: ColorUtils.darkBrown,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 10.h),
              InkWell(
                onTap: () => showCityDialog(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFFBDBDBD).withOpacity(0.3),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset("assets/icons/state.svg"),
                      SizedBox(width: 8.w),
                      Obx(() {
                        if (controller.selectedCities.isEmpty) {
                          return Text(
                            "select_target_city_placeholder".tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.black,
                            ),
                          );
                        }
                        var cityNames = controller.selectedCities.join(", ");
                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 220.w),
                          child: IntrinsicWidth(
                            child: Text(
                              cityNames.isEmpty
                                  ? "select_target_city_placeholder".tr
                                  : cityNames,
                              overflow: TextOverflow.ellipsis,
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
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Obx(
            () => Align(
              alignment: AlignmentDirectional.bottomEnd,
              // Adapts to RTL: bottom-right in LTR, bottom-left in RTL
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                // Add padding for spacing from edges
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  // End: right in LTR, left in RTL (we'll adjust for Arabic)
                  children: [
                    Text(
                      '${'total_price_label'.tr}  ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.calculateBasePrice().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: ColorUtils.darkBrown,
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection:
                          TextDirection
                              .ltr, // Force LTR for numbers and currency
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
                        mainAxisAlignment: MainAxisAlignment.end,
                        // End: right in LTR, left in RTL
                        children: [
                          Text(
                            '${'discount_label'.tr} ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                            // Inherit directionality for translated text (RTL for Arabic)
                          ),
                          Text(
                            '(${controller.siteSettings.value!.settings!.sponsorVideoDiscount}%): ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection:
                                TextDirection.ltr, // LTR for percentage
                          ),
                          Text(
                            Get.locale?.languageCode == 'ar'
                                ? '-ر.س ${controller.calculateDiscountAmount().toStringAsFixed(2)}'
                                : '-SAR ${controller.calculateDiscountAmount().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection:
                                TextDirection
                                    .ltr, // LTR for currency and amount
                          ),
                        ],
                      ),
                    Text(
                      '${'sub_total_label'.tr}  ${controller.siteSettings.value!.settings!.currencySymbol} ${controller.calculateTotalPrice().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: ColorUtils.darkBrown,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection:
                          TextDirection
                              .ltr, // Force LTR for numbers and currency
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showLocationDialog(BuildContext context) {
    final VideoAddController controller = Get.find();
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
                      children: List.generate(
                        filteredCountryName.length,
                        (index) => InkWell(
                          onTap: () async {
                            controller.selectLocation(
                              filteredCountryName[index],
                              countryMap[filteredCountryName[index]]!,
                            );
                            Navigator.pop(context);
                            await cityController.fetchCities(
                              countryMap[filteredCountryName[index]]!,
                            );
                            showCityDialog(context);
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

  void showCityDialog(BuildContext context) {
    final VideoAddController controller = Get.find();
    final CityController cityController = Get.put(CityController());

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
                    borderSide: BorderSide(color: ColorUtils.primaryColor),
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
                        (index) => InkWell(
                          onTap: () {
                            controller.toggleCity(
                              filteredCityName[index],
                              cityMap[filteredCityName[index]]!,
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  filteredCityName[index],
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight:
                                        controller.selectedCities.contains(
                                              filteredCityName[index],
                                            )
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                ),
                                Checkbox(
                                  value: controller.selectedCities.contains(
                                    filteredCityName[index],
                                  ),
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      controller.toggleCity(
                                        filteredCityName[index],
                                        cityMap[filteredCityName[index]]!,
                                      );
                                    }
                                  },
                                  activeColor: ColorUtils.primaryColor,
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
}
