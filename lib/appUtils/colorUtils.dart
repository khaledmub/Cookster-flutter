import 'package:flutter/material.dart';

class ColorUtils {
  // Solid Colors
  static const Color peach = Color(0xFFE7A080);
  static const Color primaryColor = Color(0xFFFFD700);
  static const Color secondaryColor = Color(0xFFFFFADC);
  static const Color grey = Color(0xFF707070);
  static const Color greyTextFieldBorderColor = Color(0xFFCFCFCF);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBrown = Color(0xFF3F2317);

  // Gradient
  static const LinearGradient goldGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
