import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/videoFeedModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:location/location.dart' as LocationPackage;

class HomeController extends GetxController with WidgetsBindingObserver {
  var isFollowing = false.obs;
  var rating = 0.0.obs;
  RxInt visiblePageIndex = 0.obs;

  var videoFeed = VideoFeed().obs;
  var isLoading = false.obs;
  var error = "".obs;
  var currentPage = 1.obs;

  final _chewieControllers = <ChewieController?>[].obs;
  List<VideoPlayerController?> _videoControllers = [];
  var currentIndex = 0.obs;
  final Set<int> _viewedIndices = {};

  final RxBool isVideoPlaying = true.obs;
  final RxBool isMuted = false.obs;
  var isNavigating = false.obs;
  var isAppInBackground = false.obs;

  var lastVideoPosition = Duration.zero.obs;
  var wasPlaying = false.obs;

  Timer? _debounceTimer;

  final int maxConcurrentVideos = 0; // Reduced for buffer management
  final int retentionRange = 5; // Retain controllers for ±3 indices

  // Custom cache manager for videos
  final CacheManager _videoCacheManager = CacheManager(
    Config(
      'videoCache',
      stalePeriod: const Duration(days: 7), // Cache videos for 7 days
      maxNrOfCacheObjects: 50, // Cache up to 50 videos
    ),
  );

  List<ChewieController?> get chewieControllers => _chewieControllers;

  // New reactive variables for location checks
  var isLocationServiceEnabled = true.obs; // Default to true until checked
  var isLocationPermissionGranted = false.obs; // Default to false until checked

  @override
  void onInit() {
    super.onInit();
    checkLocationStatus();
    WidgetsBinding.instance.addObserver(this);
    fetchLocationOnce().then((_) {
      fetchVideos();
    });
  }

  Future<void> fetchMoreVideos() async {
    if (isLoading.value ||
        videoFeed.value.videos == null ||
        videoFeed.value.videos!.isEmpty) {
      print(
        "Cannot fetch more videos: loading=${isLoading.value}, videos=${videoFeed.value.videos?.length}",
      );
      return;
    }

    // isLoading.value = true;
    try {
      // Create a copy of the existing videos to append
      List<WallVideos> currentVideos = List<WallVideos>.from(
        videoFeed.value.videos!,
      );
      // Append the current videos to the existing list
      videoFeed.value.videos!.addAll(currentVideos);

      print(
        "Appended ${currentVideos.length} videos. New total: ${videoFeed.value.videos!.length}",
      );

      // Update controllers to match the new video count
      await _updateControllersForNewVideos(currentVideos.length);

      // Refresh the video feed observable
      videoFeed.refresh();
    } catch (e) {
      print("Error in fetchMoreVideos: $e");
      error.value = "Error appending more videos: $e";
    } finally {
      // isLoading.value = false;
    }
  }

  Future<void> _updateControllersForNewVideos(int additionalVideoCount) async {
    // Extend video controllers list
    _videoControllers.addAll(
      List.generate(additionalVideoCount, (index) => null),
    );

    // Extend chewie controllers list
    _chewieControllers.addAll(
      List.generate(additionalVideoCount, (index) => null),
    );

    // Preload controllers for the newly appended videos
    int startIndex = _videoControllers.length - additionalVideoCount;
    // for (int i = startIndex; i < _videoControllers.length; i++) {
    //   if (!_viewedIndices.contains(i)) {
    //     await initializeControllerAtIndex(i);
    //   }
    // }

    // Refresh the chewie controllers observable
    _chewieControllers.refresh();
  }

  Future<void> checkLocationStatus() async {
    isLocationServiceEnabled.value =
        !await Permission.location.serviceStatus.isDisabled;
    isLocationPermissionGranted.value =
        await Permission.location.status.isGranted;

    print(
      'Location Service Enabled: ${isLocationServiceEnabled.value}, Location Permission Granted: ${isLocationPermissionGranted.value}',
    );
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    pauseAllVideos();
    disposeControllers();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   isAppInBackground.value = state == AppLifecycleState.paused;
  //   if (isAppInBackground.value) {
  //     pauseCurrentVideo();
  //   } else if (state == AppLifecycleState.resumed) {
  //     restoreVideoState();
  //   }
  // }

  @override
  void didHaveMemoryPressure() {
    print("Memory pressure detected, cleaning up excess controllers");
    _cleanupUnusedControllers(currentIndex.value);
  }

  var currentCity = "".obs;
  var latitude = "".obs;
  var longitude = "".obs;
  var currentCityId = "".obs;
  var currentCountry = "".obs;

  // Add flags to track if location has been fetched
  var hasLocationBeenFetched = false.obs;
  var isLocationFetching = false.obs;

  // Make sure you have these imports:
  // import 'package:geocoding/geocoding.dart';

  Future<void> fetchLocationOnce() async {
    isLocationFetching.value = true;

    try {
      // Use the location package with alias to avoid conflicts
      LocationPackage.Location location = LocationPackage.Location();

      bool serviceEnabled;
      LocationPackage.PermissionStatus permissionGranted;
      LocationPackage.LocationData locationData;

      // Check if location service is enabled
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          error.value = "Location service is disabled";
          return;
        }
      }

      // Check and request permission
      permissionGranted = await location.hasPermission();
      if (permissionGranted == LocationPackage.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != LocationPackage.PermissionStatus.granted) {
          error.value = "Location permission denied";
          return;
        }
      }

      // Get current location
      locationData = await location.getLocation();

      // Check if coordinates are available
      if (locationData.latitude == null || locationData.longitude == null) {
        error.value = "Unable to get location coordinates";
        return;
      }

      // Print latitude and longitude
      print('Location: ${locationData.latitude}, ${locationData.longitude}');

      // Set locale to English before fetching placemarks
      await setLocaleIdentifier('en_US');

      // Get placemarks from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      // Extract and print all available placemark details
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        currentCity.value = (placemark.locality ?? 'Unknown').trim();
        currentCountry.value = (placemark.country ?? 'Unknown').trim();
        String currentState =
            (placemark.administrativeArea ?? 'Unknown').trim();

        latitude.value = locationData.latitude.toString();
        longitude.value = locationData.longitude.toString();

        // Print all placemark fields with state highlighted
        print('=== Location Details ===');
        print('Latitude: ${locationData.latitude}');
        print('Longitude: ${locationData.longitude}');
        print('City (Locality): ${placemark.locality ?? 'Unknown'}');
        print('Country: ${placemark.country ?? 'Unknown'}');
        print(
          'State/Province: ${placemark.administrativeArea ?? 'Unknown'}',
        ); // Highlighted state
        print('Postal Code: ${placemark.postalCode ?? 'Unknown'}');
        print(
          'Sub-Administrative Area: ${placemark.subAdministrativeArea ?? 'Unknown'}',
        );
        print('Sub-Locality: ${placemark.subLocality ?? 'Unknown'}');
        print('Street: ${placemark.street ?? 'Unknown'}');
        print('Name: ${placemark.name ?? 'Unknown'}');
        print('ISO Country Code: ${placemark.isoCountryCode ?? 'Unknown'}');
        print('Thoroughfare: ${placemark.thoroughfare ?? 'Unknown'}');
        print('Sub-Thoroughfare: ${placemark.subThoroughfare ?? 'Unknown'}');
        print('=== End Location Details ===');

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentCity', currentCity.value);
        await prefs.setString('currentCountry', currentCountry.value);
        await prefs.setString('currentState', currentState); // Save state
        await prefs.setString('postalCode', placemark.postalCode ?? 'Unknown');
        await prefs.setDouble('latitude', locationData.latitude!);
        await prefs.setDouble('longitude', locationData.longitude!);

        hasLocationBeenFetched.value = true;
        print(
          'Location fetched - City: ${currentCity.value}, Country: ${currentCountry.value}, '
          'State: ${currentState}, Latitude: ${locationData.latitude}, Longitude: ${locationData.longitude}',
        );
      } else {
        currentCity.value = 'Unknown';
        currentCountry.value = 'Unknown';
        print('No placemarks found');
      }
    } catch (e) {
      print('Error fetching location: $e');
      error.value = "Error fetching location: $e";
    } finally {
      isLocationFetching.value = false;
    }
  }

  blockUser(String? currentUserId, String? userId) async {
    try {
      final response = await ApiClient.postRequest(EndPoints.blockUser, {
        "blocked_user": userId,
      });

      print("PRINTING THE RESPONSE BODY");
      print(response.body);
      print(response.statusCode);
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update Firestore to mark the user as blocked in the chat
        if (currentUserId != null && userId != null) {
          final chatId = _getChatId(currentUserId, userId);
          await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
            'blockedBy': FieldValue.arrayUnion([currentUserId]),
          }, SetOptions(merge: true));
          print('✅ Updated Firestore: User $userId blocked in chat $chatId');
        }

        // Show success message
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Operation successful'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );

        // Remove blocked user's videos from the current video list
        _removeBlockedUserVideos(userId);
        disposeControllers();
        // Refresh the video feed
        await fetchVideos();
      } else {
        print("Failed to block the User");

        // Show failure message
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Operation failed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('🚨 Error blocking user: $e');

      // Show error message for exceptions
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(16),
      );
    }
  }

  void _removeBlockedUserVideos(String? blockedUserId) {
    if (blockedUserId == null || videoFeed.value.videos == null) return;

    // Get current video index before removal
    int currentVideoIndex = currentIndex.value;

    // Store the current video ID to check if it gets removed
    String? currentVideoId;
    if (currentVideoIndex >= 0 &&
        currentVideoIndex < videoFeed.value.videos!.length) {
      currentVideoId = videoFeed.value.videos![currentVideoIndex].id;
    }

    // Remove videos from blocked user
    List<WallVideos> updatedVideos =
        videoFeed.value.videos!
            .where((video) => video.frontUserId != blockedUserId)
            .toList();

    // Update the video feed
    videoFeed.value = VideoFeed(
      status: videoFeed.value.status,
      videos: updatedVideos,
    );

    // Dispose controllers for videos that were removed
    _disposeRemovedVideoControllers(updatedVideos.length);

    // Update controllers list to match new video count
    _updateControllersAfterRemoval(updatedVideos.length);

    // Adjust current index if needed
    // _adjustCurrentIndexAfterRemoval(currentVideoId, updatedVideos);

    // Refresh the observable
    videoFeed.refresh();
  }

  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Helper method to remove blocked user's videos from current list

  // Helper method to dispose controllers for removed videos
  void _disposeRemovedVideoControllers(int newVideoCount) {
    // Dispose controllers beyond the new video count
    for (int i = newVideoCount; i < _chewieControllers.length; i++) {
      if (_chewieControllers[i] != null) {
        _chewieControllers[i]!.dispose();
      }
      if (_videoControllers[i] != null) {
        _videoControllers[i]!.dispose();
      }
    }
  }

  // Helper method to update controller lists after video removal
  void _updateControllersAfterRemoval(int newVideoCount) {
    // Trim the controllers lists to match new video count
    if (_chewieControllers.length > newVideoCount) {
      _chewieControllers.value =
          _chewieControllers.take(newVideoCount).toList();
    }

    if (_videoControllers.length > newVideoCount) {
      _videoControllers = _videoControllers.take(newVideoCount).toList();
    }

    // Refresh the observable
    _chewieControllers.refresh();
  }

  // Helper method to adjust current index after video removal
  // void _adjustCurrentIndexAfterRemoval(
  //   String? currentVideoId,
  //   List<WallVideos> updatedVideos,
  // ) {
  //   if (currentVideoId == null || updatedVideos.isEmpty) {
  //     currentIndex.value = 0;
  //     return;
  //   }
  //
  //   // Try to find the current video in the updated list
  //   int newIndex = updatedVideos.indexWhere(
  //     (video) => video.id == currentVideoId,
  //   );
  //
  //   if (newIndex != -1) {
  //     // Current video still exists, update index
  //     currentIndex.value = newIndex;
  //   } else {
  //     // Current video was removed, go to previous video or first video
  //     int newCurrentIndex = currentIndex.value;
  //     if (newCurrentIndex >= updatedVideos.length) {
  //       newCurrentIndex = updatedVideos.length - 1;
  //     }
  //     if (newCurrentIndex < 0) {
  //       newCurrentIndex = 0;
  //     }
  //     currentIndex.value = newCurrentIndex;
  //   }
  //
  //   // Initialize the new current video if it exists
  //   // if (updatedVideos.isNotEmpty && currentIndex.value < updatedVideos.length) {
  //   //   Future.delayed(Duration(milliseconds: 100), () {
  //   //     initializeControllerAtIndex(currentIndex.value).then((_) {
  //   //       if (!isAppInBackground.value && !isNavigating.value) {
  //   //         playVideoAtIndex(currentIndex.value);
  //   //       }
  //   //     });
  //   //   });
  //   // }
  // }

  Future<void> saveLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentCountry', currentCountry.value);
    await prefs.setString('currentCity', currentCity.value);
  }

  Future<void> fetchVideos({String? country, String? city}) async {
    if (isLoading.value) return;
    isLoading.value = true;

    print("I am there to fetch videos");

    print(selectedType.value);

    try {
      if (selectedType.value == "General") {
        print('Fetching videos for General');
        final response = await ApiClient.postRequest(EndPoints.getVideos, {});
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);

          print(
            "This is the length of videos: ${videoFeed.value.videos!.length}",
          );
          // await prepareControllers();
          // if (_chewieControllers.isNotEmpty) {
          //   await initializeControllerAtIndex(0);
          //   if (!isMuted.value &&
          //       !isAppInBackground.value &&
          //       !isNavigating.value) {
          //     playVideoAtIndex(0);
          //   }
          //   _viewedIndices.add(0);
          //   preloadNextVideos(0);
          // }
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      } else if (selectedType.value == "Following") {
        print('Fetching videos for Following');
        final response = await ApiClient.postRequest(EndPoints.getVideos, {
          "is_following": 1,
        });

        print("PRINTING RESPONSE OF VIDEOS");
        print(response.body);
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);
          // await prepareControllers();
          // if (_chewieControllers.isNotEmpty) {
          //   await initializeControllerAtIndex(0);
          //   if (!isMuted.value &&
          //       !isAppInBackground.value &&
          //       !isNavigating.value) {
          //     playVideoAtIndex(0);
          //   }
          //   _viewedIndices.add(0);
          //   preloadNextVideos(0);
          // }
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      }else if (selectedType.value == "Near Me") {
        print("Check there if you are");
        String selectedCity;
        String selectedCountry;

        // Use provided parameters first, then use stored values, then fetch location
        if (city != null && country != null) {
          selectedCity = city;
          selectedCountry = country;
        } else if (hasLocationBeenFetched.value &&
            currentCity.value.isNotEmpty &&
            currentCountry.value.isNotEmpty) {
          // Use already fetched location
          selectedCity = currentCity.value;
          selectedCountry = currentCountry.value;
        } else {
          if (error.value.isNotEmpty) {
            isLoading.value = false;
            update();
            return;
          }

          selectedCity = currentCityId.value;
          selectedCountry = currentCountry.value;
        }

        // Build the request payload based on currentCityId
        final Map<String, dynamic> requestPayload = {};

        // Always add latitude and longitude
        requestPayload['latitude'] = latitude.value; // Use .value to get the raw value
        requestPayload['longitude'] = longitude.value; // Use .value to get the raw value

        // Add city and country only if currentCityId is not null or empty
        if (currentCityId.value.isNotEmpty) {
          requestPayload['city'] = currentCityId.value; // Use .value for RxString
          requestPayload['country'] = selectedCountry;
        }

        // Print the request payload
        print('Request payload: $requestPayload');

        // Make the API request
        final response = await ApiClient.postRequest(
          EndPoints.getVideos,
          requestPayload,
        );

        print(response.body);

        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      }
    } catch (e) {
      error.value = "Error: $e";
    } finally {
      isLoading.value = false;
      update();
    }
  }

  // Method to manually refresh location if needed
  Future<void> refreshLocation() async {
    hasLocationBeenFetched.value = false;
    currentCity.value = "";
    currentCountry.value = "";
    await fetchLocationOnce();
  }

  // Method to reset location data
  void resetLocationData() {
    hasLocationBeenFetched.value = false;
    isLocationFetching.value = false;
    currentCity.value = "";
    currentCountry.value = "";
  }

  Future<void> prepareControllersIfNeeded() async {
    if (_chewieControllers.isNotEmpty) return;
    await prepareControllers();
  }

  Future<void> prepareControllers() async {
    if (videoFeed.value.videos == null || videoFeed.value.videos!.isEmpty)
      return;

    _videoControllers = List.generate(
      videoFeed.value.videos!.length,
      (index) => null,
    );
    _chewieControllers.value = List.generate(
      videoFeed.value.videos!.length,
      (index) => null,
    );
  }

  // Future<void> initializeControllerAtIndex(
  //   int index, {
  //   int retryCount = 3,
  // }) async {
  //   // Guard against invalid index
  //   if (index < 0 || index >= videoFeed.value.videos!.length) {
  //     print("Invalid index: $index");
  //     return;
  //   }
  //
  //   // Check if controller is already initialized and valid
  //   if (_videoControllers[index] != null &&
  //       _videoControllers[index]!.value.isInitialized) {
  //     print("Controller at index $index is already initialized");
  //     return;
  //   }
  //
  //   // Clean up any existing controller at this index
  //   await _disposeControllerAtIndex(index);
  //
  //   int attempts = 0;
  //
  //   while (attempts < retryCount) {
  //     try {
  //       final videoUrl =
  //           '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
  //       print(
  //         "Attempt $attempts: Initializing video at index $index with URL: $videoUrl",
  //       );
  //
  //       // Check for cached video
  //       final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
  //       if (fileInfo != null && fileInfo.file != null) {
  //         _videoControllers[index] = VideoPlayerController.file(
  //           fileInfo.file,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //       } else {
  //         _videoControllers[index] = VideoPlayerController.network(
  //           videoUrl,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //         await _videoCacheManager.downloadFile(videoUrl);
  //       }
  //
  //       // Initialize the controller
  //       await _videoControllers[index]!.initialize();
  //       print("Initialization successful for index $index");
  //
  //       // Log video details
  //       print("Video details for index $index:");
  //       print(
  //         "  Resolution: ${_videoControllers[index]!.value.size.width}x${_videoControllers[index]!.value.size.height}",
  //       );
  //       print("  Duration: ${_videoControllers[index]!.value.duration}");
  //       print("  Position: ${_videoControllers[index]!.value.position}");
  //
  //       // Initialize ChewieController
  //       _chewieControllers[index] = ChewieController(
  //         videoPlayerController: _videoControllers[index]!,
  //         autoInitialize: false,
  //         looping: true,
  //         autoPlay: false,
  //         showControls: false,
  //         showControlsOnInitialize: false,
  //         allowMuting: true,
  //       );
  //
  //       _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //       _chewieControllers.refresh();
  //       print("Video initialized at index $index on attempt $attempts");
  //       return; // Success, exit the function
  //     } catch (e) {
  //       attempts++;
  //       print(
  //         "Error initializing video at index $index on attempt $attempts: $e",
  //       );
  //       if (attempts >= retryCount) {
  //         print(
  //           "Max retries reached for index $index. Falling back to recreate.",
  //         );
  //         await _disposeControllerAtIndex(index);
  //         // await recreateControllerAtIndex(index);
  //         return;
  //       }
  //       // Wait before retrying
  //       await Future.delayed(Duration(milliseconds: 500));
  //     }
  //   }
  // }

  // Helper method to dispose of a controller at a specific index
  Future<void> _disposeControllerAtIndex(int index) async {
    try {
      if (_chewieControllers[index] != null) {
        _chewieControllers[index]?.dispose();
        _chewieControllers[index] = null;
      }
      if (_videoControllers[index] != null) {
        await _videoControllers[index]?.dispose();
        _videoControllers[index] = null;
      }
    } catch (e) {
      print("Error disposing controller at index $index: $e");
    }
  }

  void _cleanupUnusedControllers(int currentIndex) {
    int activeControllers = _countActiveControllers();

    if (activeControllers > maxConcurrentVideos) {
      print(
        "Active controllers ($activeControllers) exceeds limit ($maxConcurrentVideos). Cleaning up...",
      );

      int keepStart = (currentIndex - retentionRange).clamp(
        0,
        _videoControllers.length - 1,
      );
      int keepEnd = (currentIndex + retentionRange).clamp(
        0,
        _videoControllers.length - 1,
      );

      for (int i = 0; i < _videoControllers.length; i++) {
        if (i < keepStart || i > keepEnd) {
          if (_videoControllers[i] != null &&
              _videoControllers[i]!.value.isInitialized) {
            print(
              "Cleaning up controller at index $i (outside range $keepStart-$keepEnd)",
            );
            _chewieControllers[i]?.pause();
            disposeControllerAtIndex(i);
          }
        }
      }
    }
  }

  int _countActiveControllers() {
    int count = 0;
    for (var controller in _videoControllers) {
      if (controller != null && controller.value.isInitialized) {
        count++;
      }
    }
    return count;
  }

  // Future<void> recreateControllerAtIndex(
  //   int index, {
  //   int retryCount = 3,
  // }) async {
  //   if (index < 0 || index >= videoFeed.value.videos!.length) return;
  //
  //   disposeControllerAtIndex(index);
  //
  //   int attempts = 0;
  //
  //   while (attempts < retryCount) {
  //     try {
  //       final videoUrl =
  //           '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
  //       print(
  //         "Attempt $attempts: Recreating video at index $index with URL: $videoUrl",
  //       );
  //
  //       final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
  //       if (fileInfo != null && fileInfo.file != null) {
  //         _videoControllers[index] = VideoPlayerController.file(
  //           fileInfo.file,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //       } else {
  //         _videoControllers[index] = VideoPlayerController.network(
  //           videoUrl,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //         await _videoCacheManager.downloadFile(videoUrl);
  //       }
  //
  //       await _videoControllers[index]!.initialize();
  //
  //       _chewieControllers[index] = ChewieController(
  //         videoPlayerController: _videoControllers[index]!,
  //         autoInitialize: false,
  //         looping: true,
  //         autoPlay: false,
  //         allowMuting: true,
  //         showControls: false,
  //         materialProgressColors: ChewieProgressColors(
  //           playedColor: Colors.red,
  //           handleColor: Colors.redAccent,
  //           backgroundColor: Colors.grey,
  //           bufferedColor: Colors.white30,
  //         ),
  //       );
  //
  //       _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //       _chewieControllers.refresh();
  //       print(
  //         "Recreated and initialized video at index $index on attempt $attempts",
  //       );
  //       return;
  //     } catch (e) {
  //       attempts++;
  //       print(
  //         "Error recreating video at index $index on attempt $attempts: $e",
  //       );
  //       if (attempts >= retryCount) {
  //         print("Max retries reached for index $index. Giving up.");
  //         error.value =
  //             "Failed to load video at index $index after $retryCount attempts: $e";
  //         return;
  //       }
  //       await Future.delayed(Duration(milliseconds: 500));
  //     }
  //   }
  // }

  // void handlePageChange(int index) {
  //   if (index == currentIndex.value) return;
  //
  //   _debounceTimer?.cancel();
  //
  //   _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
  //     print("handlePageChange: Processing index $index");
  //     pauseAllVideos();
  //     currentIndex.value = index;
  //
  //     // if (index >= 0 && index < videoFeed.value.videos!.length) {
  //     //   if (_chewieControllers[index] == null ||
  //     //       !_videoControllers[index]!.value.isInitialized) {
  //     //     await initializeControllerAtIndex(index);
  //     //     if (!isAppInBackground.value && !isNavigating.value) {
  //     //       playVideoAtIndex(index);
  //     //     }
  //     //     _viewedIndices.add(index);
  //     //     preloadNextVideos(index);
  //     //   } else {
  //     //     if (!isAppInBackground.value && !isNavigating.value) {
  //     //       playVideoAtIndex(index);
  //     //     }
  //     //     _viewedIndices.add(index);
  //     //     preloadNextVideos(index);
  //     //   }
  //     //   _cleanupUnusedControllers(index);
  //     // }
  //   });
  // }

  // void preloadNextVideos(int currentIndex) async {
  //   print("Preloading started for nearby videos");
  //
  //   const int preloadLimit = 1; // Preload ±1 indices
  //   int startIndex = (currentIndex - preloadLimit).clamp(
  //     0,
  //     videoFeed.value.videos!.length - 1,
  //   );
  //   int endIndex = (currentIndex + preloadLimit).clamp(
  //     0,
  //     videoFeed.value.videos!.length - 1,
  //   );
  //
  //   for (int nextIndex = startIndex; nextIndex <= endIndex; nextIndex++) {
  //     if (!_viewedIndices.contains(nextIndex) &&
  //         (_chewieControllers[nextIndex] == null ||
  //             _videoControllers[nextIndex]?.value.isInitialized != true)) {
  //       print("Preloading video at index $nextIndex");
  //       await initializeControllerAtIndex(nextIndex);
  //       await Future.delayed(
  //         Duration(milliseconds: 100),
  //       ); // Small delay to ease load
  //     }
  //   }
  //
  //   print("Preloading completed");
  // }

  void pauseAllVideos() {
    print("Pausing all videos");
    for (var controller in _chewieControllers) {
      controller?.pause();
      controller?.setVolume(0);
    }
    isVideoPlaying.value = false;
  }

  // Future<void> playVideoAtIndex(int index) async {
  //   if (index < 0 ||
  //       index >= videoFeed.value.videos!.length ||
  //       _chewieControllers[index] == null)
  //     return;
  //
  //   print("Playing video at index $index");
  //   await initializeControllerAtIndex(index);
  //   _chewieControllers.refresh();
  //   await Future.delayed(const Duration(milliseconds: 100));
  //   await _chewieControllers[index]!.play();
  //   _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //   isVideoPlaying.value = true;
  //   _viewedIndices.add(index);
  // }

  // void pauseCurrentVideo() {
  //   if (currentIndex.value >= 0 &&
  //       currentIndex.value < _chewieControllers.length &&
  //       _chewieControllers[currentIndex.value] != null) {
  //     print("Pausing current video at index ${currentIndex.value}");
  //     final controller = _chewieControllers[currentIndex.value]!;
  //     lastVideoPosition.value = controller.videoPlayerController.value.position;
  //     wasPlaying.value = controller.isPlaying;
  //     controller.pause();
  //     isVideoPlaying.value = false;
  //   }
  // }

  void resumeCurrentVideo() {
    if (!isAppInBackground.value &&
        !isNavigating.value &&
        currentIndex.value >= 0 &&
        currentIndex.value < _chewieControllers.length &&
        _chewieControllers[currentIndex.value] != null) {
      print("Resuming video at index ${currentIndex.value}");
      _chewieControllers[currentIndex.value]!.play();
      isVideoPlaying.value = true;
    }
  }

  // void togglePlayPause() {
  //   if (currentIndex.value < 0 ||
  //       currentIndex.value >= _chewieControllers.length)
  //     return;
  //
  //   final controller = _chewieControllers[currentIndex.value];
  //   if (controller != null) {
  //     controller.isPlaying ? pauseCurrentVideo() : resumeCurrentVideo();
  //   }
  // }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (currentIndex.value >= 0 &&
        currentIndex.value < _chewieControllers.length &&
        _chewieControllers[currentIndex.value] != null) {
      _chewieControllers[currentIndex.value]!.setVolume(isMuted.value ? 0 : 1);
    }
  }

  // void handleNavigation() {
  //   isNavigating.value = true;
  //   pauseCurrentVideo();
  // }

  // Future<void> restoreVideoState() async {
  //   final index = currentIndex.value;
  //   if (index < 0 ||
  //       index >= _chewieControllers.length ||
  //       _chewieControllers[index] == null) {
  //     isNavigating.value = false;
  //     return;
  //   }
  //
  //   final controller = _chewieControllers[index]!;
  //   try {
  //     if (!controller.videoPlayerController.value.isInitialized) {
  //       await initializeControllerAtIndex(index);
  //     }
  //
  //     if (lastVideoPosition.value.inMilliseconds > 0) {
  //       await controller.videoPlayerController.seekTo(lastVideoPosition.value);
  //     }
  //
  //     final targetVolume = isMuted.value ? 0.0 : 1.0;
  //     if (controller.videoPlayerController.value.volume != targetVolume) {
  //       controller.setVolume(targetVolume);
  //     }
  //
  //     if (wasPlaying.value && !isAppInBackground.value && !isNavigating.value) {
  //       await controller.play();
  //       isVideoPlaying.value = true;
  //     }
  //   } catch (e) {
  //     print('Error restoring video state: $e');
  //   } finally {
  //     isNavigating.value = false;
  //   }
  // }

  void disposeControllerAtIndex(int index) {
    if (index >= 0 && index < _chewieControllers.length) {
      print("Disposing controller at index $index");
      _chewieControllers[index]?.dispose();
      _videoControllers[index]?.dispose();
      _chewieControllers[index] = null;
      _videoControllers[index] = null;
      _chewieControllers.refresh();
    }
  }

  void disposeControllers() {
    print("Disposing all controllers");
    for (int i = 0; i < _chewieControllers.length; i++) {
      _chewieControllers[i]?.dispose();
      _videoControllers[i]?.dispose();
    }
    _chewieControllers.clear();
    _videoControllers.clear();
    _viewedIndices.clear();
    currentIndex.value = 0;
  }

  RxString selectedType = "Near Me".obs;

  void setSelectedType(String type) {
    if (type == "General" || type == "Near Me" || type == "Following") {
      selectedType.value = type;
    }
  }
}
