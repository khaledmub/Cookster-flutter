import 'dart:async';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'nearBusinessController/nearBusinessController.dart'; // Adjust the import path

class AllowLocationScreen extends StatefulWidget {
  const AllowLocationScreen({super.key});

  @override
  State<AllowLocationScreen> createState() => _AllowLocationScreenState();
}

class _AllowLocationScreenState extends State<AllowLocationScreen>
    with WidgetsBindingObserver {
  final LocationController controller = Get.find<LocationController>();
  StreamSubscription<bool>? _locationServiceSubscription;
  DateTime? _lastCheckTime;
  static const _minCheckInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocationServiceListener();
    _checkLocationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLocationStatus();
    }
  }

  void _startLocationServiceListener() {
    _locationServiceSubscription = Geolocator.getServiceStatusStream()
        .map((status) => status == ServiceStatus.enabled)
        .listen((isEnabled) {
          if (isEnabled) {
            _checkLocationStatus();
          }
        });
  }

  Future<void> _checkLocationStatus() async {
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _minCheckInterval) {
      return;
    }
    _lastCheckTime = DateTime.now();

    // Check if location is allowed
    await controller.getLocationOnly();
    if (controller.isLocationAllowed.value) {
      // Immediately fetch full location and businesses
      await controller.getCurrentLocation();
      if (controller.isLocationAllowed.value) {
        Get.back(); // Navigate back only after fetching businesses
      }
    }
  }

  @override
  void dispose() {
    _locationServiceSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Location Icon
              Icon(
                Icons.location_on_outlined,
                size: 80,
                color: ColorUtils.primaryColor,
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'location_access_required'.tr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'location_description'.tr,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Allow Location Button
              const SizedBox(height: 16),
              // Open Settings Button
              AppButton(
                text: 'open_settings'.tr,
                onTap: () async {
                  await Geolocator.openLocationSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
