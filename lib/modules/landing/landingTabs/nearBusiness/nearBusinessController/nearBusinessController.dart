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

  // Cache for location to avoid repeated API calls
  Position? _cachedPosition;
  DateTime? _lastLocationUpdate;
  static const int _locationCacheMinutes = 5; // Cache location for 5 minutes

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
      isLoading.value = true;

      // Check if we have a cached location that's still valid
      if (_cachedPosition != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes < _locationCacheMinutes) {

        latitude.value = _cachedPosition!.latitude;
        longitude.value = _cachedPosition!.longitude;

        // Fetch businesses with cached location
        await fetchNearestBusinesses();
        return;
      }

      // Quick permission and service check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('Error', 'Location services are disabled. Please enable them.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('Error', 'Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Error',
          'Location permissions are permanently denied. Please enable them in settings.',
        );
        return;
      }

      // Get location with optimized settings for speed
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // Faster but less accurate
        timeLimit: Duration(seconds: 10), // Timeout after 10 seconds
      );

      // Cache the position
      _cachedPosition = position;
      _lastLocationUpdate = DateTime.now();

      // Update latitude and longitude
      latitude.value = position.latitude;
      longitude.value = position.longitude;

      // Fetch nearest businesses
      await fetchNearestBusinesses();
    } catch (e) {
      // If getCurrentPosition fails, try getLastKnownPosition as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          latitude.value = lastPosition.latitude;
          longitude.value = lastPosition.longitude;

          // Cache the fallback position
          _cachedPosition = lastPosition;
          _lastLocationUpdate = DateTime.now();

          await fetchNearestBusinesses();
        } else {
          // Get.snackbar('Error', 'Failed to get location: $e');
        }
      } catch (fallbackError) {
        // Get.snackbar('Error', 'Failed to get location: $fallbackError');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchNearestBusinesses({
    double? customLatitude,
    double? customLongitude,
    double? customRadius,
  }) async {
    try {
      // Don't show loading if we're just updating radius
      if (customRadius == null) {
        isLoading.value = true;
      }

      final lat = customLatitude ?? latitude.value;
      final lng = customLongitude ?? longitude.value;
      final rad = customRadius ?? radius.value;

      // Validate coordinates
      if (lat == 0.0 || lng == 0.0) {
        // Get.snackbar('Error', 'Invalid location coordinates.');
        return;
      }

      // Add timeout to API call
      final response = await ApiClient.postRequest(
        EndPoints.nearedBusiness,
        {'latitude': lat, 'longitude': lng, 'radius': rad},
      ).timeout(
        Duration(seconds: 15), // 15 second timeout
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        nearestBusinesses.value = NearBusinessModel.fromJson(data);
        isRadiusCardVisible.value = false;
      } else {
        // Get.snackbar(
        //   'Error',
        //   'Failed to fetch nearest businesses: ${response.statusCode}',
        // );
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        // Get.snackbar('Error', 'Request timed out. Please check your internet connection.');
      } else {
        // Get.snackbar('Error', 'Failed to fetch nearest businesses: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  void updateRadius(double newRadius) {
    radius.value = newRadius;
    // Immediately fetch businesses with new radius without showing loading
    fetchNearestBusinesses(customRadius: newRadius);
  }

  // Method to force refresh location (bypass cache)
  Future<void> refreshLocation() async {
    _cachedPosition = null;
    _lastLocationUpdate = null;
    await getCurrentLocation();
  }

  // Method to get location without fetching businesses (for quick location updates)
  Future<void> getLocationOnly() async {
    try {
      if (_cachedPosition != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes < _locationCacheMinutes) {

        latitude.value = _cachedPosition!.latitude;
        longitude.value = _cachedPosition!.longitude;
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      );

      _cachedPosition = position;
      _lastLocationUpdate = DateTime.now();
      latitude.value = position.latitude;
      longitude.value = position.longitude;
    } catch (e) {
      // Try last known position
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        latitude.value = lastPosition.latitude;
        longitude.value = lastPosition.longitude;
        _cachedPosition = lastPosition;
        _lastLocationUpdate = DateTime.now();
      }
    }
  }
}