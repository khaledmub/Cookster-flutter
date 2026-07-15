import 'dart:async';

import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/core/video/feed_disk_warm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../initLanguageSelection/initLanguageView.dart';

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
    final token = prefs.getString('auth_token');
    // Already signed in: start disk-warming feed bytes during the logo.
    if (token != null && token.isNotEmpty) {
      FeedDiskWarmService.instance.warmEarlyFeed(reason: 'splash_signed_in');
    }

    if (initLanguage) {
      Get.offAllNamed(AppRoutes.onBoarding);
    } else {
      Get.offAll(
        () => const InitLanguageView(),
        binding: SelectLanguageBinding(),
      );
    }
  }

  Future<void> _scheduleNavigation() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 800)),
      _navigateToInitialScreen(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);
    unawaited(_scheduleNavigation());
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
