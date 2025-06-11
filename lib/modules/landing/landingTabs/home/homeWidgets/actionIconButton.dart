import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Define ActionIconButton widget
class ActionIconButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback? onTap;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? labelStyle;

  const ActionIconButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconSize = 24.0,
    this.iconColor,
    this.labelStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            width: iconSize.h,
            height: iconSize.h,
            child: Center(
              child: icon is SvgPicture
                  ? SvgPicture.asset(
                icon.assetName,
                height: iconSize.h,
                width: iconSize.h,
                color: iconColor ?? icon.color,
                fit: BoxFit.contain,
              )
                  : Icon(
                icon.icon,
                size: iconSize.h,
                color: iconColor ?? icon.color,
              ),
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: labelStyle ??
              TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
              ),
        ),
      ],
    );
  }
}