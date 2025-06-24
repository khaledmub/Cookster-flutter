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
  var isLocationAllowed = false.obs;

  // Cache for location to avoid repeated API calls
  Position? _cachedPosition;
  DateTime? _lastLocationUpdate;
  static const int _locationCacheMinutes = 5;

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

      if (_cachedPosition != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes <
              _locationCacheMinutes) {
        latitude.value = _cachedPosition!.latitude;
        longitude.value = _cachedPosition!.longitude;
        isLocationAllowed.value = true;
        await fetchNearestBusinesses();
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        isLocationAllowed.value = false;
        // Get.snackbar(
        //   'Error',
        //   'Location services are disabled. Please enable them.',
        // );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          isLocationAllowed.value = false;
          // Get.snackbar('Error', 'Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        isLocationAllowed.value = false;
        // Get.snackbar(
        //   'Error',
        //   'Location permissions are permanently denied. Please enable them in settings.',
        // );
        return;
      }

      isLocationAllowed.value = true;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      );

      _cachedPosition = position;
      _lastLocationUpdate = DateTime.now();
      latitude.value = position.latitude;
      longitude.value = position.longitude;

      await fetchNearestBusinesses();
    } catch (e) {
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          latitude.value = lastPosition.latitude;
          longitude.value = lastPosition.longitude;
          _cachedPosition = lastPosition;
          _lastLocationUpdate = DateTime.now();
          isLocationAllowed.value = true;
          await fetchNearestBusinesses();
        } else {
          isLocationAllowed.value = false;
        }
      } catch (fallbackError) {
        isLocationAllowed.value = false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchNearestBusinesses({
    double? customLatitude,
    double? customLongitude,
    double? customRadius,
    bool closeRadiusCard = false, // New parameter to control card visibility
  }) async {
    try {
      if (customRadius == null) {
        isLoading.value = true;
      }

      final lat = customLatitude ?? latitude.value;
      final lng = customLongitude ?? longitude.value;
      final rad = customRadius ?? radius.value;

      if (lat == 0.0 || lng == 0.0) {
        return;
      }

      final response = await ApiClient.postRequest(EndPoints.nearedBusiness, {
        'latitude': lat,
        'longitude': lng,
        'radius': rad,
      }).timeout(
        Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        nearestBusinesses.value = NearBusinessModel.fromJson(data);
        if (closeRadiusCard) {
          isRadiusCardVisible.value =
              false; // Only close if explicitly requested
        }
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        // Get.snackbar(
        //   'Error',
        //   'Request timed out. Please check your internet connection.',
        // );
      }
    } finally {
      isLoading.value = false;
    }
  }

  void updateRadius(double newRadius) {
    radius.value = newRadius;
    // Fetch businesses without closing the radius card
    // fetchNearestBusinesses(customRadius: newRadius, closeRadiusCard: false);
  }

  Future<void> refreshLocation() async {
    _cachedPosition = null;
    _lastLocationUpdate = null;
    await getCurrentLocation();
  }

  Future<void> getLocationOnly() async {
    try {
      if (_cachedPosition != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes <
              _locationCacheMinutes) {
        latitude.value = _cachedPosition!.latitude;
        longitude.value = _cachedPosition!.longitude;
        isLocationAllowed.value = true;
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
      isLocationAllowed.value = true;
    } catch (e) {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        latitude.value = lastPosition.latitude;
        longitude.value = lastPosition.longitude;
        _cachedPosition = lastPosition;
        _lastLocationUpdate = DateTime.now();
        isLocationAllowed.value = true;
      } else {
        isLocationAllowed.value = false;
      }
    }
  }
}
