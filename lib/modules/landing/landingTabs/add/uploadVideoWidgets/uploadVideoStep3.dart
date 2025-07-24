import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/add/uploadVideoWidgets/sponsorBox.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class uploadVideoStep3 extends StatelessWidget {
  final VideoAddController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.validateSelectedCountry();
    });
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            spacing: 1.h,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// **Title**
              Text(
                "publish_label".tr,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              /// **Radio Buttons for Visibility**
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

              Divider(color: Color(0XFFD5D5D5), thickness: 0.2),

              /// **Allow Comments Toggle**
              Obx(
                () => buildToggleOption(
                  icon: "assets/icons/comment.svg",
                  title: "allow_comments_label".tr,
                  value: controller.allowComments.value,
                  onChanged: (value) => controller.toggleComments(),
                ),
              ),
              Divider(color: Color(0XFFD5D5D5), thickness: 0.2),

              /// **Location Option**
              buildClickableOption(
                icon: Icons.location_on,
                title: "location_label".tr,
                onTap: () {
                  showLocationDialog(context);
                  print("Open location settings");
                  // Add navigation to location settings if needed
                },
                context: context,
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Text('${controller.entityDetails.value['is_sponsored']}'),
        if (controller.entityDetails.value['is_sponsored'] == 1) SponsorBox(),
      ],
    );
  }

  /// **Reusable Widget for Radio Option**
  Widget buildRadioOption(
    String title,
    VisibilityOption option,
    VideoAddController ctrl,
  ) {
    return ListTileTheme(
      horizontalTitleGap: 1,
      child: GestureDetector(
        onTap: () => ctrl.setVisibility(option),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // Align items properly
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

                  // controller.setLocation(value as String);
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

  /// **Reusable Widget for Toggle Option**
  Widget buildToggleOption({
    required String icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
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
      ),
    );
  }

  /// **Reusable Widget for Clickable Option**
  Widget buildClickableOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Function() onTap,
  }) {
    // final VideoAddController videoAddController = Get.find();
    return Column(
      children: [
        InkWell(
          onTap: onTap,
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
                Obx(() {
                  final country = controller.selectedCountry.value;
                  final city = controller.selectedCity.value;

                  if (country.isEmpty && city.isEmpty) {
                    return Text(""); // Return empty text if both are empty
                  } else if (city.isEmpty) {
                    return Text(country); // Show only country if city is empty
                  } else if (country.isEmpty ) {
                    return Text(city); // Show only city if country is empty
                  } else {
                    return Text(
                      "$country",
                    ); // Show both with separator if both are non-empty
                  }
                }),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),

        SizedBox(height: 8.h),
        InkWell(
          onTap: () {
            showCityDialog(context);
          },
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
                Obx(() {
                  // final country = controller.selectedCountry.value;
                  final city = controller.selectedCity.value;

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),

                    child: Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
