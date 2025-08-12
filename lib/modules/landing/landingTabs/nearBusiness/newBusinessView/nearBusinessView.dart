import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../allowLocationView.dart';
import '../nearBusinessController/nearBusinessController.dart';
import '../nearBusinessModel/nearBusinessModel.dart';

class NearestBusinessScreen extends StatelessWidget {
  const NearestBusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark, // White icons ke liye
        statusBarColor:
            Colors.transparent, // Optional: Status bar background color
      ),
    );
    final LocationController controller = Get.put(
      LocationController(),
      permanent: true,
    );

    return Scaffold(
      body: Obx(() {
        return !controller.isLocationAllowed.value
            ? AllowLocationScreen() // Show AllowLocationScreen if location not allowed
            : controller.isLoading.value
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PulseLogoLoader(logoPath: "assets/images/appLogo.png"),
                  ],
                ),
              ],
            )
            : Stack(
              children: [
                // Full-screen Google Map
                GoogleMapWithBusinessImages(controller: controller),

                InkWell(
                  onTap: () {
                    controller.getCurrentLocation();
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 50),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      shape: BoxShape.circle,
                      color: ColorUtils.primaryColor,
                    ),
                    child: Icon(Icons.refresh, color: Colors.white),
                  ),
                ),

                // SafeArea for status bar and controls
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),

                      // Bottom control panel
                      Obx(
                        () =>
                            controller.isLoading.value
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child:
                                      controller.isRadiusCardVisible.value
                                          ? _buildBottomControls(
                                            controller,
                                            context,
                                          )
                                          : const SizedBox.shrink(),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            );
      }),
      floatingActionButton: Obx(() {
        return controller.isLocationAllowed.value
            ? FloatingActionButton(
              onPressed: controller.toggleRadiusCardVisibility,
              backgroundColor: ColorUtils.primaryColor,
              shape: const CircleBorder(),
              child: Obx(
                () => AnimatedCrossFade(
                  firstChild: const Icon(Icons.tune, color: Colors.white),
                  secondChild: const Icon(Icons.close, color: Colors.white),
                  crossFadeState:
                      controller.isRadiusCardVisible.value
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ),
            )
            : SizedBox.shrink();
      }),
    );
  }

  Widget _buildBottomControls(
    LocationController controller,
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional: Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () {
                controller.isRadiusCardVisible.value =
                    false; // Close panel without fetching
              },
            ),
          ),
          // Radius control
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Radius'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Obx(
                  () => Text(
                    '${controller.radius.value.round()} km',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(
            () => SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.amber.shade600,
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayColor: Colors.amber.withOpacity(0.3),
                trackHeight: 4,
              ),
              child: Slider(
                value: controller.radius.value,
                min: 1,
                max: 50,
                onChanged: controller.updateRadius,
              ),
            ),
          ),
          // Find Businesses button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Fetch businesses and close the radius card
                await controller.fetchNearestBusinesses(closeRadiusCard: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primaryColor,
                // Ensure ColorUtils is defined
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Find Business'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleMapWithBusinessImages extends StatefulWidget {
  final LocationController controller;

  const GoogleMapWithBusinessImages({super.key, required this.controller});

  @override
  _GoogleMapWithBusinessImagesState createState() =>
      _GoogleMapWithBusinessImagesState();
}

class _GoogleMapWithBusinessImagesState
    extends State<GoogleMapWithBusinessImages> {
  GoogleMapController? mapController;
  Map<MarkerId, Marker> markers = {};
  BitmapDescriptor? customIcon = BitmapDescriptor.defaultMarker;
  final _customInfoWindowController = CustomInfoWindowController();

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        "assets/images/locationMarker.png",
      );
      setState(() {
        customIcon = icon;
      });
    } catch (e) {
      print("Error loading custom marker: $e");
      setState(() {
        customIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      });
    }
  }

  @override
  void initState() {
    _loadCustomMarker();
    super.initState();
  }

  @override
  void dispose() {
    mapController?.dispose();
    _customInfoWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _updateMarkers();
      return Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              _customInfoWindowController.googleMapController = controller;
              mapController?.setMapStyle(_mapStyle);
              _autoAdjustZoom(); // Trigger zoom adjustment after map creation
            },
            onTap: (location) {
              _customInfoWindowController.hideInfoWindow!();
            },
            onCameraMove: (position) {
              _customInfoWindowController.onCameraMove!();
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.controller.latitude.value,
                widget.controller.longitude.value,
              ),
              zoom: 15.0, // Reduced initial zoom for a more reasonable default
            ),
            markers: Set<Marker>.of(markers.values),
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 120,
            width: 250,
            offset: 50,
          ),
        ],
      );
    });
  }

  void _updateMarkers() {
    markers.clear();

    final markerIcon =
        customIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

    if (widget.controller.nearestBusinesses.value.accounts != null) {
      for (var account in widget.controller.nearestBusinesses.value.accounts!) {
        final lat = double.tryParse(account.latitude ?? '0') ?? 0.0;
        final lng = double.tryParse(account.longitude ?? '0') ?? 0.0;
        final businessId = account.id ?? 'unknown';
        final markerId = MarkerId('business_$businessId');

        markers[markerId] = Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: markerIcon,
          onTap: () {
            _customInfoWindowController.addInfoWindow!(
              _buildCustomInfoWindow(account),
              LatLng(lat, lng),
            );
          },
        );
      }
    }

    if (markers.length > 1) _autoAdjustZoom();
  }

  Widget _buildCustomInfoWindow(Accounts account) {
    return GestureDetector(
      onTap: () {
        Get.to(VisitProfileView(userId: account.id!));
      },
      child: SizedBox(
        width: 250,
        height: 200,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image or fallback asset
              SizedBox(height: 4),
              // Name
              Row(
                children: [
                  ClipOval(
                    child:
                        account.image != null
                            ? CachedNetworkImage(
                              imageUrl:
                                  '${Common.imageBaseUrl}/${account.image!}',
                              height: 60,
                              width: 60,
                              // Fixed width for circular shape
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              errorWidget:
                                  (context, url, error) => Image.asset(
                                    'assets/images/yellowLogo.png',
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                  ),
                            )
                            : Image.asset(
                              'assets/images/yellowLogo.png',
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                            ),
                  ),
                  SizedBox(width: 8),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name ?? 'Unknown Business',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // SizedBox(height: 4),
                      // Distance
                      // Email
                      if (account.email != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                Get.width * 0.35, // Maximum width for the email
                          ),
                          child: Text(
                            '${account.contactEmail}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Phone
                      if (account.phone != null)
                        Text(
                          '${account.contactPhone}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _autoAdjustZoom() {
    if (mapController == null || markers.length <= 1) return;

    LatLngBounds bounds = _getBounds();
    // Increase padding to zoom out more
    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, Get.width * 0.25), // Dynamic padding
    );
  }

  LatLngBounds _getBounds() {
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var marker in markers.values) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }
    // Add a small buffer to bounds to prevent overly tight zoom
    const buffer = 0.0005; // Adjust buffer as needed (in degrees)
    return LatLngBounds(
      southwest: LatLng(minLat - buffer, minLng - buffer),
      northeast: LatLng(maxLat + buffer, maxLng + buffer),
    );
  }

  static const String _mapStyle = '''
[
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#e9e9e9"}, {"lightness": 17}]},
  {"featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 20}]},
  {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#ffffff"}, {"lightness": 17}]},
  {"featureType": "poi", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.place_of_worship", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.school", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.medical", "elementType": "labels.text", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';
}

class ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;

  const ContactCard({
    Key? key,
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // padding: EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: Colors.blueGrey[100],
            child:
                avatarUrl == null
                    ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    )
                    : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
