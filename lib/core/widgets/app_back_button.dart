import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:flutter/material.dart';

/// Standard yellow circular back button used across auth and secondary screens.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.result,
    this.top = 20,
    this.left,
    this.right,
  });

  final VoidCallback? onPressed;
  final dynamic result;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Positioned(
      left: left ?? (isRtl ? null : 16),
      right: right ?? (isRtl ? 16 : null),
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? () => navigateBack(result),
        child: Container(
          height: 40,
          width: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE6BE00),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_back,
              color: ColorUtils.darkBrown,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
