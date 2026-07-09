import 'dart:async';

import 'package:cookster/core/location/app_location_defaults.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../appUtils/appUtils.dart';
import '../../../../appUtils/colorUtils.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  }) : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? mapController;
  TextEditingController searchController = TextEditingController();
  LatLng? selectedLocation;
  LatLng? userLocation;
  String selectedAddress = "Search or select location";
  bool _isFetchingLocation = false;
  static const String apiKey = "AIzaSyDwKQgoyXFVb6hXQY67yLogwHMojkjHCgo";

  bool get _hasValidInitialCoords {
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  @override
  void initState() {
    super.initState();
    if (_hasValidInitialCoords) {
      selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      selectedAddress = widget.initialAddress ?? "Selected Location";
    } else {
      selectedLocation = AppLocationDefaults.mapCenter;
      selectedAddress = "finding_address".tr;
      unawaited(_getAddressFromLatLng(AppLocationDefaults.mapCenter));
    }
    unawaited(_getUserLocation(applyAsSelection: !_hasValidInitialCoords));
  }

  Future<void> _getUserLocation({bool applyAsSelection = false}) async {
    if (_isFetchingLocation) {
      return;
    }
    _isFetchingLocation = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar("location_error".tr, "please_enable_location_services".tr);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar("permission_denied".tr, "location_access_required".tr);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          "permission_denied".tr,
          "permissions_permanently_denied".tr,
        );
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }

      setState(() {
        userLocation = current;
        if (applyAsSelection || selectedLocation == null) {
          selectedLocation = current;
        }
      });

      if (applyAsSelection || selectedLocation == current) {
        await _getAddressFromLatLng(current);
      }

      final target = selectedLocation ?? current;
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14),
      );
    } catch (e) {
      Get.snackbar("error".tr, "failed_to_get_location".tr);
    } finally {
      _isFetchingLocation = false;
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (userLocation != null) {
      setState(() {
        selectedLocation = userLocation;
      });
      await _getAddressFromLatLng(userLocation!);
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLocation!, 14),
      );
      return;
    }
    await _getUserLocation(applyAsSelection: true);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      selectedLocation = position.target;
      selectedAddress = "finding_address".tr;
    });
  }

  Future<void> _onCameraIdle() async {
    if (selectedLocation != null) {
      await _getAddressFromLatLng(selectedLocation!);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        if (!mounted) {
          return;
        }
        setState(() {
          selectedAddress =
              "${place.name}, ${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      debugPrint("Error fetching address: $e");
    }
  }

  void confirmLocation() {
    final finalLocation = selectedLocation ?? userLocation;

    if (finalLocation != null) {
      Get.back(
        result: {
          'latitude': finalLocation.latitude,
          'longitude': finalLocation.longitude,
          'address': selectedAddress,
        },
      );
    } else {
      Get.snackbar("Error", "Please select a location");
    }
  }

  FocusNode searchFocusNode = FocusNode();

  @override
  void dispose() {
    mapController?.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("pick_a_location".tr)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: searchController,
              googleAPIKey: apiKey,
              focusNode: searchFocusNode,
              inputDecoration: InputDecoration(
                alignLabelWithHint: true,
                hintText: "search_location".tr,
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: ColorUtils.primaryColor,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              debounceTime: 800,
              isLatLngRequired: true,
              itemClick: (Prediction prediction) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  searchFocusNode.requestFocus();
                });
              },
              getPlaceDetailWithLatLng: (Prediction prediction) {
                final lat = double.tryParse(prediction.lat ?? '');
                final lng = double.tryParse(prediction.lng ?? '');
                if (lat != null && lng != null) {
                  setState(() {
                    selectedLocation = LatLng(lat, lng);
                    selectedAddress =
                        prediction.description ?? "Selected Location";
                  });

                  mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(selectedLocation!, 14),
                  );
                }

                Future.delayed(const Duration(milliseconds: 300), () {
                  searchFocusNode.requestFocus();
                });
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target:
                        selectedLocation ??
                        userLocation ??
                        AppLocationDefaults.mapCenter,
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    mapController = controller;
                    final target =
                        selectedLocation ??
                        userLocation ??
                        AppLocationDefaults.mapCenter;
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(target, 14),
                    );
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),
                const Center(
                  child: Icon(Icons.location_pin, size: 40, color: Colors.red),
                ),
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed:
                        _isFetchingLocation ? null : () => _goToCurrentLocation(),
                    backgroundColor: Colors.white,
                    child: _isFetchingLocation
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: AppButton(
              text: "confirm_location".tr,
              onTap: confirmLocation,
            ),
          ),
        ],
      ),
    );
  }
}
