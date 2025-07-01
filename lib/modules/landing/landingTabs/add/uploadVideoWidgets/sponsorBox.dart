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
                () => Column(
              children: [
                // Basic Sponsored Video Card
                Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: controller.selectedVideoType.value == 'Basic'
                        ? ColorUtils.darkBrown.withOpacity(0.05)
                        : Colors.white,
                    border: Border.all(
                      color: controller.selectedVideoType.value == 'Basic'
                          ? ColorUtils.darkBrown
                          : ColorUtils.grey.withOpacity(0.3),
                      width: controller.selectedVideoType.value == 'Basic' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => controller.setVideoType('Basic'),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Price Row with Radio Button
                                Row(
                                  children: [
                                    // Custom Radio Button


                                    // Title and Price Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title with Badge
                                          Row(
                                            children: [
                                              Text(
                                                "Basic".tr,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: ColorUtils.darkBrown,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),

                                            ],
                                          ),

                                          // SizedBox(height: 4.h),

                                          // Price
                                          Text(
                                            controller.siteSettings.value != null &&
                                                controller.siteSettings.value!.settings != null
                                                ? '${controller.siteSettings.value!.settings!.currencySymbol} ${controller.siteSettings.value!.settings!.basicSponsoredVideoPrice ?? 0}'
                                                : 'SAR Loading...',
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              color: ColorUtils.darkBrown,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 20.w,
                                      height: 20.h,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: controller.selectedVideoType.value == 'Basic'
                                              ? ColorUtils.darkBrown
                                              : ColorUtils.grey,
                                          width: 2,
                                        ),
                                        color: controller.selectedVideoType.value == 'Basic'
                                            ? ColorUtils.darkBrown
                                            : Colors.transparent,
                                      ),
                                      child: controller.selectedVideoType.value == 'Basic'
                                          ? Icon(
                                        Icons.check,
                                        size: 12.sp,
                                        color: Colors.white,
                                      )
                                          : null,
                                    ),

                                  ],
                                ),

                                // SizedBox(height: 12.h),

                                // Description
                                Text(
                                  textAlign: TextAlign.justify,
                                  "basic_description".tr,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: ColorUtils.darkBrown.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Premium Sponsored Video Card
                Container(
                  decoration: BoxDecoration(
                    color: controller.selectedVideoType.value == 'Premium'
                        ? ColorUtils.darkBrown.withOpacity(0.05)
                        : Colors.white,
                    border: Border.all(
                      color: controller.selectedVideoType.value == 'Premium'
                          ? ColorUtils.darkBrown
                          : ColorUtils.grey.withOpacity(0.3),
                      width: controller.selectedVideoType.value == 'Premium' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => controller.setVideoType('Premium'),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Price Row with Radio Button
                                Row(
                                  children: [
                                    // Custom Radio Button



                                    // Title and Price Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title with Badge
                                          Row(
                                            children: [
                                              Text(
                                                "Premium".tr,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: ColorUtils.darkBrown,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),

                                            ],
                                          ),

                                          // SizedBox(height: 4.h),

                                          // Price
                                          Text(
                                            controller.siteSettings.value != null &&
                                                controller.siteSettings.value!.settings != null
                                                ? '${controller.siteSettings.value!.settings!.currencySymbol} ${controller.siteSettings.value!.settings!.premiumSponsoredVideoPrice ?? 0}'
                                                : 'SAR Loading...',
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              color: ColorUtils.darkBrown,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      width: 20.w,
                                      height: 20.h,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: controller.selectedVideoType.value == 'Premium'
                                              ? ColorUtils.darkBrown
                                              : ColorUtils.grey,
                                          width: 2,
                                        ),
                                        color: controller.selectedVideoType.value == 'Premium'
                                            ? ColorUtils.darkBrown
                                            : Colors.transparent,
                                      ),
                                      child: controller.selectedVideoType.value == 'Premium'
                                          ? Icon(
                                        Icons.check,
                                        size: 12.sp,
                                        color: Colors.white,
                                      )
                                          : null,
                                    ),
                                  ],
                                ),

                                // SizedBox(height: 10.h),

                                // Description
                                Text(
                                  textAlign: TextAlign.justify,
                                  "premium_description".tr,
                                  style: TextStyle(

                                    fontSize: 12.sp,
                                    color: ColorUtils.darkBrown.withOpacity(0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                      textDirection: Get.locale?.languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
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
                            textDirection: Get.locale?.languageCode == 'ar'
                                ? TextDirection.rtl
                                : TextDirection.ltr,
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
                      textDirection: Get.locale?.languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
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

                        return Column(
                          children: [
                            InkWell(
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
    final VideoAddController controller = Get.find();
    final CityController cityController = Get.put(CityController());

    Map<String, int> cityMap = {};
    List<String> cityName = cityController.cityList.map((city) {
      cityMap[city.name!] = city.id!;
      return city.name!;
    }).toList();

    final TextEditingController searchController = TextEditingController();
    RxList<String> filteredCityName = cityName.obs;

    // Initialize with current selected cities from controller
    RxList<String> selectedCities = <String>[].obs;
    selectedCities.addAll(controller.selectedCities);

    void filterCities(String query) {
      if (query.isEmpty) {
        filteredCityName.value = cityName;
      } else {
        filteredCityName.value = cityName
            .where((city) => city.toLowerCase().contains(query.toLowerCase()))
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
            child: cityController.isLoading.value
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
                            bool isSelected = selectedCities.contains(city);

                            return Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    controller.toggleCity(city, cityMap[city]!);
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
                                              fontWeight: isSelected
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
                                              controller.toggleCity(city, cityMap[city]!);
                                              if (value) {
                                                selectedCities.add(city);
                                              } else {
                                                selectedCities.remove(city);
                                              }
                                            }
                                          },
                                          activeColor: ColorUtils.primaryColor,
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
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Obx(
                      () => ElevatedButton(
                    onPressed: controller.selectedCities.isNotEmpty
                        ? () => Get.back()
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
