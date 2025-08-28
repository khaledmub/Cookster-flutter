import 'package:cookster/modules/onBoarding/onBoardingView/onBoardingView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../initLanguageSelection/initLanguageView.dart';
// Import LanguageController

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Future<void> _navigateToInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool initLanguage = prefs.getBool('initLanguage') ?? false;

    print("SplashView: initLanguage: $initLanguage");

    // Navigate based on initLanguage flag
    if (initLanguage) {
      Get.offAll(() => const OnBoarding());
    } else {
      Get.offAll(() => const InitLanguageView());
    }
  }

  @override
  void initState() {
    super.initState();

    // Animation controller for breathing effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);

    // Navigate to the initial screen after a 3-second delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToInitialScreen();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fade-in background
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(seconds: 2),
              child: Image.asset(
                "assets/images/splashBackground.png",
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Breathing effect on app icon
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(scale: _controller.value, child: child);
              },
              child: Image.asset(
                "assets/images/appIcon.png",
                width: 100.h,
                height: 100.h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
