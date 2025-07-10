import 'package:cookster/appUtils/appUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../appUtils/colorUtils.dart';
import '../addReviewController/addReviewController.dart';

class AddReviewView extends StatelessWidget {
  final String professionalId;

  const AddReviewView({super.key, required this.professionalId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AddReviewController(professionalId: professionalId),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(155.h),
        child: Container(
          padding: EdgeInsets.only(top: 40.h),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.back(),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  height: 40.h,
                  width: 40.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6BE00),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Obx(
                          () => Icon(
                        controller.language.value == 'ar'
                            ? Icons.arrow_back
                            : Icons.arrow_back,
                        color: ColorUtils.darkBrown,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  textAlign: TextAlign.center,
                  "add_review".tr,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 56.w), // Balances the back button's width and margin
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              "rate_your_experience".tr,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: ColorUtils.darkBrown,
              ),
            ),
            SizedBox(height: 15.h),
            Center(
              child: RatingBar.builder(
                glow: false,
                initialRating: controller.rating.value,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder:
                    (context, _) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD700),
                    ),
                onRatingUpdate: (rating) => controller.rating.value = rating,
                itemSize: 40.w,
              ),
            ),
            SizedBox(height: 10.h),
            Center(
              child: Obx(
                () => Text(
                  controller.rating.value == 0.0
                      ? "tap_to_rate".tr
                      : "${controller.rating.value.toStringAsFixed(1)} ${"stars".tr}",
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
              ),
            ),
            SizedBox(height: 30.h),
            Text(
              "write_your_review".tr,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: ColorUtils.darkBrown,
              ),
            ),
            SizedBox(height: 15.h),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color:
                      controller.reviewFocusNode.hasFocus
                          ? const Color(0xFFFFD700)
                          : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Obx(
                () => TextField(
                  controller: controller.reviewController,
                  focusNode: controller.reviewFocusNode,
                  maxLines: 8,
                  maxLength: controller.maxCharacters,
                  textDirection:
                      controller.language.value == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: "share_your_experience".tr,
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16.w),
                    counterText: "",
                  ),
                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 8.h,
                right: controller.language.value == 'ar' ? 0 : 12.w,
                left: controller.language.value == 'ar' ? 12.w : 0,
              ),
              child: Obx(
                () => Row(
                  mainAxisAlignment:
                      controller.language.value == 'ar'
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                  children: [
                    Text(
                      "${controller.characterCount.value}/${controller.maxCharacters}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color:
                            controller.characterCount.value >
                                    controller.maxCharacters
                                ? Colors.red
                                : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40.h),
            AppButton(
              text: "submit_review".tr,
              onTap: () => controller.submitReview(context),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
