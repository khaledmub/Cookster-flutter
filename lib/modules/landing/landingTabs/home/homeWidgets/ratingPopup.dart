import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../appUtils/colorUtils.dart';

void showRatingDialog(BuildContext context) {
  final HomeController controller = Get.find();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            spacing: 10.h,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Container(
                width: double.infinity,
                height: 80.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),

                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: AssetImage("assets/images/ratingHeader.png"),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          "Rate Post",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Rating Bar
              Obx(
                () => RatingBar.builder(
                  unratedColor: ColorUtils.primaryColor,
                  glow: false,
                  initialRating: controller.rating.value,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder:
                      (context, index) => Icon(
                        index < controller.rating.value
                            ? Icons
                                .star_rounded // Filled star
                            : Icons.star_border_rounded, // Outlined star
                        color: ColorUtils.primaryColor,
                      ),
                  onRatingUpdate: (rating) {
                    // controller.updateRating(rating);
                  },
                ),
              ),

              // Rating Count
              Obx(
                () => Text(
                  "${controller.rating.value.toInt()}/5 Rating",
                  style: TextStyle(fontSize: 16),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AppButton(
                  text: "Submit",
                  color: ColorUtils.primaryColor,
                  textStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                  ),

                  onTap: () {
                    Get.back();
                  },
                ),
              ),

              // Submit Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AppButton(
                  text: "Cancel",
                  color: Colors.white,
                  textStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                  ),

                  onTap: () {
                    Get.back();
                  },
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      );
    },
  );
}
