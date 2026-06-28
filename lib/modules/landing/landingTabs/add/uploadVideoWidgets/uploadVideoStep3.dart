import 'dart:async';

import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/add/uploadVideoWidgets/sponsorBox.dart';
import 'package:cookster/modules/landing/landingTabs/add/uploadVideoWidgets/location_picker_dialog.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/services/video_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UploadVideoStep3 extends StatefulWidget {
  const UploadVideoStep3({super.key});

  @override
  State<UploadVideoStep3> createState() => _UploadVideoStep3State();
}

class _UploadVideoStep3State extends State<UploadVideoStep3> {
  final VideoAddController controller = Get.find();

  @override
  void initState() {
    super.initState();
    unawaited(VideoSettingsService.instance.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.validateSelectedCountry();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          child: Container(
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
                _VisibilityOptions(controller: controller),
                const Divider(color: Color(0XFFD5D5D5), thickness: 0.2),
                _CommentsToggle(controller: controller),
                const Divider(color: Color(0XFFD5D5D5), thickness: 0.2),
                _UploadLocationSection(controller: controller),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GetBuilder<VideoAddController>(
          id: VideoAddController.idUploadSponsor,
          builder: (c) {
            if (c.entityDetails.value['is_sponsored'] != 1) {
              return const SizedBox.shrink();
            }
            return const SponsorBox();
          },
        ),
      ],
    );
  }
}

class _UploadLocationSection extends StatelessWidget {
  const _UploadLocationSection({required this.controller});

  final VideoAddController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VideoAddController>(
      id: VideoAddController.idUploadLocation,
      builder: (c) {
        return Column(
          children: [
            InkWell(
              onTap: () async {
                await showUploadCountryPicker(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: ColorUtils.greyTextFieldBorderColor,
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      'select_country_label'.tr,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        c.selectedCountry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: () async {
                await showUploadCityPicker(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: ColorUtils.greyTextFieldBorderColor,
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      'select_city_label'.tr,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        c.selectedCity.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Keep legacy name for callers that still reference uploadVideoStep3.
typedef uploadVideoStep3 = UploadVideoStep3;

class _VisibilityOptions extends StatelessWidget {
  const _VisibilityOptions({required this.controller});

  final VideoAddController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedVisibility.value;
      return Wrap(
        spacing: 0,
        runSpacing: 0,
        children: [
          _buildRadioOption(
            context,
            "public_option".tr,
            VisibilityOption.public,
            selected,
          ),
          _buildRadioOption(
            context,
            "only_followers_option".tr,
            VisibilityOption.onlyFollowers,
            selected,
          ),
          _buildRadioOption(
            context,
            "private_option".tr,
            VisibilityOption.private,
            selected,
          ),
        ],
      );
    });
  }

  Widget _buildRadioOption(
    BuildContext context,
    String title,
    VisibilityOption option,
    VisibilityOption selected,
  ) {
    return ListTileTheme(
      horizontalTitleGap: 1,
      child: GestureDetector(
        onTap: () => controller.setVisibility(option),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<VisibilityOption>(
              fillColor: WidgetStateColor.resolveWith(
                (states) => ColorUtils.primaryColor,
              ),
              value: option,
              groupValue: selected,
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
}

class _CommentsToggle extends StatelessWidget {
  const _CommentsToggle({required this.controller});

  final VideoAddController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  "assets/icons/comment.svg",
                  colorFilter: ColorFilter.mode(
                    ColorUtils.greyTextFieldBorderColor,
                    BlendMode.srcIn,
                  ),
                  height: 15.h,
                ),
                SizedBox(width: 16.w),
                Text(
                  "allow_comments_label".tr,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Switch(
              value: controller.allowComments.value,
              activeThumbColor: Colors.yellow.shade700,
              onChanged: (_) => controller.toggleComments(),
            ),
          ],
        ),
      ),
    );
  }
}
