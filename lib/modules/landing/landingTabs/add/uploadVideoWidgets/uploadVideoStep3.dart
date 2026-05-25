import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/add/uploadVideoWidgets/sponsorBox.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UploadVideoStep3 extends StatefulWidget {
  const UploadVideoStep3({super.key});

  @override
  State<UploadVideoStep3> createState() => _UploadVideoStep3State();
}

class _UploadVideoStep3State extends State<UploadVideoStep3>
    with AutomaticKeepAliveClientMixin {
  final VideoAddController controller = Get.find();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.validateSelectedCountry();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            spacing: 1.h,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "publish_label".tr,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Obx(
                () => Wrap(
                  spacing: 0.w,
                  runSpacing: 0.h,
                  alignment: WrapAlignment.start,
                  children: [
                    _buildRadioOption(
                      "public_option".tr,
                      VisibilityOption.public,
                    ),
                    _buildRadioOption(
                      "only_followers_option".tr,
                      VisibilityOption.onlyFollowers,
                    ),
                    _buildRadioOption(
                      "private_option".tr,
                      VisibilityOption.private,
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0XFFD5D5D5), thickness: 0.2),
              Obx(
                () => _buildToggleOption(
                  icon: "assets/icons/comment.svg",
                  title: "allow_comments_label".tr,
                  value: controller.allowComments.value,
                  onChanged: (_) => controller.toggleComments(),
                ),
              ),
              const Divider(color: Color(0XFFD5D5D5), thickness: 0.2),
              _buildLocationSection(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (controller.entityDetails.value['is_sponsored'] == 1) const SponsorBox(),
      ],
    );
  }

  Widget _buildRadioOption(String title, VisibilityOption option) {
    return ListTileTheme(
      horizontalTitleGap: 1,
      child: GestureDetector(
        onTap: () => controller.setVisibility(option),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Radio<VisibilityOption>(
              fillColor: WidgetStateColor.resolveWith(
                (states) => ColorUtils.primaryColor,
              ),
              activeColor: Colors.yellow.shade700,
              value: option,
              groupValue: controller.selectedVisibility.value,
              onChanged: (value) {
                if (value != null) controller.setVisibility(value);
              },
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

  Widget _buildToggleOption({
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
                colorFilter: ColorFilter.mode(
                  ColorUtils.greyTextFieldBorderColor,
                  BlendMode.srcIn,
                ),
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
            activeThumbColor: Colors.yellow.shade700,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => showLocationDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.location_on, color: ColorUtils.greyTextFieldBorderColor),
                SizedBox(width: 16.w),
                Text(
                  'select_country_label'.tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final country = controller.selectedCountry.value;
                  final city = controller.selectedCity.value;
                  if (country.isEmpty && city.isEmpty) return const Text('');
                  if (city.isEmpty) return Text(country);
                  if (country.isEmpty) return Text(city);
                  return Text(country);
                }),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: () => showCityDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.location_on, color: ColorUtils.greyTextFieldBorderColor),
                SizedBox(width: 16.w),
                Text(
                  'select_city_label'.tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Obx(
                  () => ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      controller.selectedCity.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Keep legacy name for callers that still reference uploadVideoStep3.
typedef uploadVideoStep3 = UploadVideoStep3;
