import 'package:geolocator/geolocator.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
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
  final loadError = RxnString();

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

  /// Called when the Discover tab becomes visible so map data loads even if
  /// the first attempt failed while Home reels were holding decoders.
  Future<void> ensureDiscoverLoaded() async {
    if (isLoading.value) {
      return;
    }
    if (!isLocationAllowed.value ||
        latitude.value == 0.0 ||
        longitude.value == 0.0) {
      await getCurrentLocation();
      return;
    }
    final accounts = nearestBusinesses.value.accounts;
    if (accounts == null || accounts.isEmpty) {
      await fetchNearestBusinesses();
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading.value = true;
      loadError.value = null;

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
    } catch (e, stack) {
      debugPrint('getCurrentLocation failed: $e\n$stack');
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
          loadError.value = 'Unable to get your location. Please try again.';
        }
      } catch (fallbackError, fallbackStack) {
        debugPrint('getCurrentLocation fallback failed: $fallbackError\n$fallbackStack');
        isLocationAllowed.value = false;
        loadError.value = 'Unable to get your location. Please try again.';
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
        nearestBusinesses.value =
            await compute(parseNearBusinesses, response.body);
        loadError.value = null;
        if (closeRadiusCard) {
          isRadiusCardVisible.value =
              false; // Only close if explicitly requested
        }
      } else {
        loadError.value =
            'Could not load nearby businesses (${response.statusCode}).';
        debugPrint(
          'fetchNearestBusinesses: HTTP ${response.statusCode} ${response.body}',
        );
      }
    } catch (e, stack) {
      debugPrint('fetchNearestBusinesses failed: $e\n$stack');
      if (e.toString().contains('timeout')) {
        loadError.value =
            'Request timed out. Check your connection and try again.';
      } else {
        loadError.value = 'Could not load nearby businesses. Please try again.';
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
