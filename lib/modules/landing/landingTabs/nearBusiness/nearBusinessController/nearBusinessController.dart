import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../../services/apiClient.dart';
import '../nearBusinessModel/nearBusinessModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';

class LocationController extends GetxController {
  var latitude = 0.0.obs;
  var longitude = 0.0.obs;
  var radius = 10.0.obs; // Default radius of 10 km
  var isLoading = false.obs;
  var nearestBusinesses = NearBusinessModel().obs;
  var isRadiusCardVisible = false.obs;

  void toggleRadiusCardVisibility() {
    isRadiusCardVisible.value = !isRadiusCardVisible.value;
  }

  @override
  void onInit() {
    super.onInit();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading(true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('Error', 'Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('Error', 'Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar('Error', 'Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Optimized for performance
      );

      latitude.value = position.latitude;
      longitude.value = position.longitude;

      // Optionally, fetch businesses on initial location fetch
      await fetchNearestBusinesses();
    } catch (e) {
      Get.snackbar('Error', 'Failed to get location: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchNearestBusinesses({
    double? customLatitude,
    double? customLongitude,
    double? customRadius,
  }) async {
    try {
      isLoading(true);

      final lat = customLatitude ?? latitude.value;
      final lng = customLongitude ?? longitude.value;
      final rad = customRadius ?? radius.value;

      final response = await ApiClient.postRequest(
        '${EndPoints.nearedBusiness}',
        {'latitude': lat, 'longitude': lng, 'radius': rad},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        nearestBusinesses.value = NearBusinessModel.fromJson(data);
        // Hide the radius card on successful submission
        isRadiusCardVisible.value = false;
      } else {
        Get.snackbar(
          'Error',
          'Failed to fetch nearest businesses: ${response.statusCode}',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch nearest businesses: $e');
    } finally {
      isLoading(false);
    }
  }

  void updateRadius(double newRadius) {
    radius.value = newRadius; // Only update the radius value
  }
}