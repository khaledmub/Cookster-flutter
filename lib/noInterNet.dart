import 'dart:io';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: ColorUtils.primaryColor),
            const SizedBox(height: 20),
            Text(
              "no_internet".tr,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              "no_internet_description".tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AppButton(
                text: _isRetrying ? "retrying_button".tr : "retry_button".tr,
                onTap: _isRetrying ? null : _handleRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      // Check connectivity
      List<ConnectivityResult> connectivityResult =
          await Connectivity().checkConnectivity();

      bool hasInternet = connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasInternet) {
        // Double check with a real network request to ensure actual internet access
        bool actualInternet = await _checkActualInternet();

        if (actualInternet) {
          // Get the saved route from arguments or default to splash
          final arguments = Get.arguments as Map<String, dynamic>?;
          String? savedRoute = arguments?['savedRoute'];

          if (savedRoute != null &&
              savedRoute != AppRoutes.noInternet &&
              savedRoute != AppRoutes.splash) {
            // Return to the saved route
            Get.offAllNamed(savedRoute);
          } else {
            // Go to splash for fresh start
            Get.offAllNamed(AppRoutes.splash);
          }
        } else {
          // False positive - still no real internet
          _showNoInternetSnackBar();
        }
      } else {
        // Still no connectivity
        _showNoInternetSnackBar();
      }
    } catch (e) {
      print("Error checking connectivity: $e");
      _showNoInternetSnackBar();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<bool> _checkActualInternet() async {
    try {
      // Try to make a simple HTTP request to verify actual internet access
      // You can replace this with your app's API endpoint or a reliable service
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://www.google.com'));
      request.headers.set('User-Agent', 'Cookster App');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      print("Actual internet check failed: $e");
      return false;
    }
  }

  void _showNoInternetSnackBar() {
    if (mounted) {
      Get.snackbar(
        "snackbar_title".tr,
        "snackbar_message".tr,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      );
    }
  }
}
