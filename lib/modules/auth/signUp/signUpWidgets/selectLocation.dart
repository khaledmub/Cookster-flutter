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
  final double? initialLatitude; // Add initial latitude
  final double? initialLongitude; // Add initial longitude
  final String? initialAddress; // Add initial address

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
  static const String apiKey = "AIzaSyDwKQgoyXFVb6hXQY67yLogwHMojkjHCgo";

  @override
  void initState() {
    super.initState();
    // Set initial values from widget parameters if provided and valid
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      // Check if the coordinates are valid (not 0.0 or invalid range)
      if (widget.initialLatitude != 0.0 &&
          widget.initialLongitude != 0.0 &&
          widget.initialLatitude! >= -90 &&
          widget.initialLatitude! <= 90 &&
          widget.initialLongitude! >= -180 &&
          widget.initialLongitude! <= 180) {
        selectedLocation = LatLng(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
        selectedAddress = widget.initialAddress ?? "Selected Location";
      }
    }
    // Always get user location
    _getUserLocation();
  }

  /// Get user's current location
  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar("location_error".tr, "please_enable_location_services".tr);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        // If no valid initial location was provided, use user's current location
        if (selectedLocation == null ||
            (widget.initialLatitude == 0.0 && widget.initialLongitude == 0.0)) {
          selectedLocation = userLocation;
          _getAddressFromLatLng(userLocation!);
        }
      });

      // Move camera to appropriate location
      LatLng target = selectedLocation ?? userLocation!;
      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
      }
    } catch (e) {
      Get.snackbar("error".tr, "failed_to_get_location".tr);
    }
  }

  /// Update location when map camera moves
  void _onCameraMove(CameraPosition position) {
    setState(() {
      selectedLocation = position.target;
      selectedAddress = "finding_address".tr;
    });
  }

  /// Get address when camera stops moving
  Future<void> _onCameraIdle() async {
    await _getAddressFromLatLng(selectedLocation!);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          selectedAddress =
              "${place.name}, ${place.locality}, ${place.country}" ??
              "Unknown Address";
        });
      }
    } catch (e) {
      print("Error fetching address: $e");
    }
  }

  /// Confirm location selection
  void confirmLocation() {
    LatLng? finalLocation = selectedLocation ?? userLocation;

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
      appBar: AppBar(title:  Text("pick_a_location".tr)),
      body: Column(
        children: [
          // Search Bar (Google Places Autocomplete)
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
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              debounceTime: 800,
              isLatLngRequired: true,
              itemClick: (Prediction prediction) {
                Future.delayed(Duration(milliseconds: 300), () {
                  searchFocusNode.requestFocus();
                });
              },
              getPlaceDetailWithLatLng: (Prediction prediction) {
                double? lat = double.tryParse(prediction.lat!);
                double? lng = double.tryParse(prediction.lng!);
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

                Future.delayed(Duration(milliseconds: 300), () {
                  searchFocusNode.requestFocus();
                });
              },
            ),
          ),

          // Google Map with Static Center Marker
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target:
                        selectedLocation ??
                        userLocation ??
                        const LatLng(31.5204, 74.3587),
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    mapController = controller;
                    // Only animate if we have a valid location
                    if (selectedLocation != null || userLocation != null) {
                      LatLng target = selectedLocation ?? userLocation!;
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(target, 14),
                      );
                    }
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),
                // Static Center Marker
                Center(
                  child: Icon(Icons.location_pin, size: 40, color: Colors.red),
                ),
                // Address Display
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
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
                // Custom Locate Button
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      if (userLocation != null) {
                        mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(userLocation!, 14),
                        );
                        setState(() {
                          selectedLocation = userLocation;
                        });
                        _getAddressFromLatLng(userLocation!);
                      } else {
                        // Get.snackbar(
                        //   "location_error".tr,
                        //   "User location not found!",
                        // );
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: AppButton(text: "confirm_location".tr, onTap: confirmLocation),
          ),
        ],
      ),
    );
  }
}
