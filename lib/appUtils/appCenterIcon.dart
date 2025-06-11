import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppCenterIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6.h),
        height: 50.h,
        width: 50.h,
        child: Image.asset("assets/images/appIconC.png"),
      ),
    );
  }
}
