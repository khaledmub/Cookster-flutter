import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../appUtils/colorUtils.dart';

class CustomTabButtonSearch extends StatelessWidget {
  final String label;
  final int typeValue;
  final RxInt selectedType; // Reactive variable from controller
  final VoidCallback onTap;
  final double size;
  final Color selectedBackgroundColor;
  final Color unselectedBackgroundColor;
  final Color selectedBorderColor;
  final Color unselectedBorderColor;

  const CustomTabButtonSearch({
    super.key,
    required this.label,
    required this.typeValue,
    required this.selectedType,
    required this.onTap,
    this.size = 25,
    this.selectedBackgroundColor = ColorUtils.darkBrown, // Light yellow (selected)
    this.unselectedBackgroundColor = ColorUtils.secondaryColor, // Grey (unselected)
    this.selectedBorderColor = ColorUtils.primaryColor, // Darker yellow (selected)
    this.unselectedBorderColor = ColorUtils.secondaryColor, // Grey (unselected)
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => GestureDetector(
      onTap: onTap,
      child: Container(
        height: size.h,
        width: 100.h, // Adjusted width for text
        decoration: BoxDecoration(
          color: selectedType.value == typeValue
              ? selectedBackgroundColor
              : unselectedBackgroundColor,
          borderRadius: BorderRadius.circular(50.r),
          // border: Border.all(
          //   color: selectedType.value == typeValue
          //       ? selectedBorderColor
          //       : unselectedBorderColor,
          //   width: 1.5.w,
          // ),
        ),
        child: Center(
          child: Text(
            label.tr,
            style: TextStyle(
              color: selectedType.value == typeValue
                  ? Colors.white // Text color when selected
                  : Colors.black, // Text color when unselected
              fontWeight: selectedType.value == typeValue
                  ? FontWeight.w500
                  : FontWeight.normal,
              fontSize: 14.sp,
            ),
          ),
        ),
      ),
    ));
  }
}