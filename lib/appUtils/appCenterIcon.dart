import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Decorative header logo — must not intercept touches over back/filter buttons.
class AppCenterIcon extends StatelessWidget {
  const AppCenterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6.h),
          height: 50.h,
          width: 50.h,
          child: Image.asset('assets/images/appIconC.png'),
        ),
      ),
    );
  }
}
