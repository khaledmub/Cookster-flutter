import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SocialButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback onTap;
  final double size;
  final Color backgroundColor;
  final Color borderColor;

  const SocialButton({
    super.key,
    required this.iconPath,
    required this.onTap,
    this.size = 50, // Default size
    this.backgroundColor = const Color(0xFFF9E79F), // Light yellow
    this.borderColor = const Color(0xFFD4AC0D), // Slightly darker yellow
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50.h,
        width: 80.h,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Image.asset(iconPath, height: 35.h, width: 35.h)),
      ),
    );
  }
}
