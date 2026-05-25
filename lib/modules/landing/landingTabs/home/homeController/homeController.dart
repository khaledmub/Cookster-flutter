import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/videoFeedModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:geolocator/geolocator.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  var isFollowing = false.obs;
  var rating = 0.0.obs;
  RxInt visiblePageIndex = 0.obs;

  var videoFeed = VideoFeed().obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var error = "".obs;
  var currentPage = 1.obs;
  static const int feedPageSize = 15;
  static const int reelsPageSize = 10;

  var currentIndex = 0.obs;

  final RxBool isReelsTabVisible = true.obs;
  final RxBool isVideoPlaying = true.obs;
  final RxBool isMuted = false.obs;
  var isNavigating = false.obs;
  var isAppInBackground = false.obs;

  var lastVideoPosition = Duration.zero.obs;
  var wasPlaying = false.obs;

  Timer? _debounceTimer;
  DateTime? _lastMemoryPressureCleanupAt;

  /// Last successful feed per tab — instant UI when switching عام / بالقرب / المتابعة.
  final Map<String, VideoFeed> _tabFeedCache = {};

  // New reactive variables for location checks
  var isLocationServiceEnabled = true.obs; // Default to true until checked
  var isLocationPermissionGranted = false.obs; // Default to false until checked

  @override
  void onInit() {
    super.onInit();
    checkLocationStatus();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrapHomeFeed());
  }

  /// Restore last known coords so Near Me can load before GPS finishes.
  Future<void> _restoreLocationFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('latitude');
    final lng = prefs.getDouble('longitude');
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      latitude.value = lat.toString();
      longitude.value = lng.toString();
      hasLocationBeenFetched.value = true;
    }
    final city = prefs.getString('currentCity');
    final country = prefs.getString('currentCountry');
    if (city != null && city.isNotEmpty) {
      currentCity.value = city;
    }
    if (country != null && country.isNotEmpty) {
      currentCountry.value = country;
    }
  }

  Future<void> _bootstrapHomeFeed() async {
    await _restoreLocationFromPrefs();
    await fetchVideos();
    unawaited(_fetchLocationInBackground());
  }

  Future<void> _fetchLocationInBackground() async {
    await fetchLocationOnce(refreshNearMeFeed: true);
  }

  bool get blocksUiForLocation =>
      selectedType.value == 'Near Me' && isLocationFetching.value;

  bool get _usesReelsApi => selectedType.value == 'General';

  Future<void> fetchMoreVideos() async {
    if (isLoading.value ||
        isLoadingMore.value ||
        videoFeed.value.videos == null ||
        videoFeed.value.videos!.isEmpty) {
      return;
    }

    final meta = videoFeed.value.meta;
    if (meta != null && !meta.hasMore) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final parsed = _usesReelsApi
          ? await _fetchReelsPage(reset: false)
          : await _fetchLegacyFeedPage(reset: false);
      if (parsed == null) {
        return;
      }

      final incoming = parsed.videos ?? [];
      if (incoming.isEmpty) {
        if (videoFeed.value.meta != null) {
          videoFeed.value.meta!.hasMore = false;
        }
        videoFeed.refresh();
        return;
      }

      final existingIds = videoFeed.value.videos!
          .map((v) => v.id)
          .whereType<String>()
          .toSet();
      final uniqueIncoming = incoming
          .where((v) => v.id != null && !existingIds.contains(v.id))
          .toList();

      videoFeed.value.videos!.addAll(uniqueIncoming);
      videoFeed.value.meta = parsed.meta ?? videoFeed.value.meta;
      if (parsed.meta?.page != null) {
        currentPage.value = parsed.meta!.page!;
      }
      videoFeed.refresh();
    } catch (e) {
      error.value = "Error loading more videos: $e";
    } finally {
      isLoadingMore.value = false;
      update();
    }
  }

  Map<String, dynamic> _buildFeedPayload({required bool reset}) {
    final base = <String, dynamic>{
      'paginate': 1,
      'per_page': feedPageSize,
    };

    if (selectedType.value == "Following") {
      base['is_following'] = 1;
    } else if (selectedType.value == "Near Me") {
      base['latitude'] = latitude.value;
      base['longitude'] = longitude.value;
      if (currentCityId.value.isNotEmpty) {
        base['city'] = currentCityId.value;
        base['country'] = currentCountry.value;
      }
    }

    if (reset) {
      base['page'] = 1;
      return base;
    }

    final meta = videoFeed.value.meta;
    if (meta != null) {
      base.addAll(meta.toRequestPayload());
    } else {
      base['page'] = currentPage.value + 1;
    }
    return base;
  }

  Future<VideoFeed?> _fetchFeedPage({required bool reset}) async {
    if (_usesReelsApi) {
      return _fetchReelsPage(reset: reset);
    }
    return _fetchLegacyFeedPage(reset: reset);
  }

  Future<VideoFeed?> _fetchReelsPage({required bool reset}) async {
    var endpoint = EndPoints.reels;
    if (!reset) {
      final cursor = videoFeed.value.meta?.nextCursor;
      if (cursor != null && cursor.isNotEmpty) {
        endpoint =
            '${EndPoints.reels}?cursor=${Uri.encodeQueryComponent(cursor)}';
      }
    }
    final response = await ApiClient.getRequest(endpoint);
    if (response.statusCode != 200) {
      error.value = "Failed to load reels: ${response.statusCode}";
      return null;
    }
    return compute(parseVideoFeed, response.body);
  }

  Future<VideoFeed?> _fetchLegacyFeedPage({required bool reset}) async {
    final payload = _buildFeedPayload(reset: reset);
    final response = await ApiClient.postRequest(EndPoints.getVideos, payload);
    if (response.statusCode != 200) {
      error.value = "Failed to load videos: ${response.statusCode}";
      return null;
    }
    return compute(parseVideoFeed, response.body);
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
    final now = DateTime.now();
    if (_lastMemoryPressureCleanupAt != null &&
        now.difference(_lastMemoryPressureCleanupAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    _lastMemoryPressureCleanupAt = now;
    final cache = PaintingBinding.instance.imageCache;
    final oldMax = cache.maximumSize;
    cache.maximumSize = 100;
    cache.clearLiveImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cache.maximumSize = oldMax;
    });
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    unawaited(
      MediaKitPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
    unawaited(
      VideoPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
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

  Future<void> fetchLocationOnce({bool refreshNearMeFeed = false}) async {
    if (selectedType.value == 'Near Me') {
      isLocationFetching.value = true;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error.value = "Location service is disabled";
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          error.value = "Location permission denied";
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        error.value = "Location permission denied";
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (position.latitude == 0 && position.longitude == 0) {
        error.value = "Unable to get location coordinates";
        return;
      }

      print('Location: ${position.latitude}, ${position.longitude}');

      await setLocaleIdentifier('en_US');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        currentCity.value = (placemark.locality ?? 'Unknown').trim();
        currentCountry.value = (placemark.country ?? 'Unknown').trim();
        String currentState =
            (placemark.administrativeArea ?? 'Unknown').trim();

        latitude.value = position.latitude.toString();
        longitude.value = position.longitude.toString();

        print('=== Location Details ===');
        print('Latitude: ${position.latitude}');
        print('Longitude: ${position.longitude}');
        print('City (Locality): ${placemark.locality ?? 'Unknown'}');
        print('Country: ${placemark.country ?? 'Unknown'}');
        print(
          'State/Province: ${placemark.administrativeArea ?? 'Unknown'}',
        );
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentCity', currentCity.value);
        await prefs.setString('currentCountry', currentCountry.value);
        await prefs.setString('currentState', currentState);
        await prefs.setString('postalCode', placemark.postalCode ?? 'Unknown');
        await prefs.setDouble('latitude', position.latitude);
        await prefs.setDouble('longitude', position.longitude);

        hasLocationBeenFetched.value = true;
        print(
          'Location fetched - City: ${currentCity.value}, Country: ${currentCountry.value}, '
          'State: $currentState, Latitude: ${position.latitude}, Longitude: ${position.longitude}',
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
      if (refreshNearMeFeed &&
          selectedType.value == 'Near Me' &&
          hasLocationBeenFetched.value) {
        unawaited(fetchVideos(forceNetwork: true));
      }
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

  Future<void> fetchVideos({
    String? country,
    String? city,
    bool forceNetwork = false,
    bool fromTabSwitch = false,
  }) async {
    final tab = selectedType.value;
    final cached = _tabFeedCache[tab];
    final hasCachedFeed =
        !forceNetwork && cached != null && (cached.videos?.isNotEmpty ?? false);

    if (hasCachedFeed) {
      videoFeed.value = cached!;
      visiblePageIndex.value = 0;
      currentIndex.value = 0;
      update();
    }

    if (isLoading.value && !hasCachedFeed && !fromTabSwitch) {
      return;
    }

    if (!hasCachedFeed) {
      isLoading.value = true;
    }
    currentPage.value = 1;

    try {
      if (selectedType.value == "Near Me") {
        if (city != null && country != null) {
          currentCityId.value = city;
          currentCountry.value = country;
        } else if (!hasLocationBeenFetched.value &&
            latitude.value.isEmpty &&
            longitude.value.isEmpty) {
          return;
        }
      }

      final parsed = await _fetchFeedPage(reset: true);
      if (parsed != null) {
        videoFeed.value = parsed;
        _tabFeedCache[tab] = parsed;
        currentPage.value = parsed.meta?.page ?? 1;
        visiblePageIndex.value = 0;
        currentIndex.value = 0;
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

  void setReelsTabVisible(bool visible) {
    isReelsTabVisible.value = visible;
  }

  /// Stops reel audio/video immediately when pushing another route (e.g. profile).
  void pauseReelsForRouteOverlay() {
    isNavigating.value = true;
    setReelsTabVisible(false);
    pauseAllVideosSync();
    unawaited(pauseAllVideosAwait());
  }

  /// Resumes the visible reel after closing an overlay route, only on the home tab.
  void resumeReelsAfterRouteOverlay() {
    isNavigating.value = false;
    if (isAppInBackground.value) {
      return;
    }
    if (Get.isRegistered<NavBarController>() &&
        Get.find<NavBarController>().selectedIndex.value != 0) {
      return;
    }
    setReelsTabVisible(true);
    unawaited(resumeVisibleVideo(visiblePageIndex.value));
  }

  void pauseAllVideosSync() {
    MediaKitPlayerPool.instance.silenceAllSync();
    isVideoPlaying.value = false;
  }

  Future<void> pauseAllVideosAwait() async {
    pauseAllVideosSync();
    await MediaKitPlayerPool.instance.pauseAllAwait();
    await VideoPlayerPool.instance.pauseAll();
    isVideoPlaying.value = false;
  }

  void pauseAllVideos() {
    pauseAllVideosSync();
    unawaited(pauseAllVideosAwait());
  }

  /// Frees reel decoders before camera / upload / editor flows so local
  /// [VideoPlayerController] can initialize without OOM on low-end devices.
  Future<void> releaseAllVideoResources() async {
    setReelsTabVisible(false);
    pauseAllVideos();
    await MediaKitPlayerPool.instance.disposeAll();
    await VideoPlayerPool.instance.clear();
    isVideoPlaying.value = false;
  }

  Future<void> restoreVideoResourcesAfterCapture() async {
    if (isAppInBackground.value) {
      return;
    }
    setReelsTabVisible(true);
    await resumeVisibleVideo(visiblePageIndex.value);
  }

  Future<void> resumeVisibleVideo(int pageIndex) async {
    if (isAppInBackground.value || isNavigating.value) {
      return;
    }
    isReelsTabVisible.value = true;
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final actualIndex = pageIndex.clamp(0, videos.length - 1);
    currentIndex.value = actualIndex;
    visiblePageIndex.value = actualIndex;
    isVideoPlaying.value = true;
    // Playback is started by the visible [VideoPlayerWidget] once autoPlay is
    // true again; do not touch the pool here (avoids racing disposed outputs).
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
    if (isAppInBackground.value || isNavigating.value) {
      return;
    }
    isVideoPlaying.value = true;
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

  void disposeControllerAtIndex(int index) {}

  /// Light reset when switching عام / بالقرب / المتابعة (keep pool warm).
  void prepareForFeedTabSwitch() {
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(VideoPlayerPool.instance.pauseAll());
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
  }

  void disposeControllers() {
    unawaited(MediaKitPlayerPool.instance.releaseAll());
    unawaited(VideoPlayerPool.instance.clear());
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
  }

  RxString selectedType = "Near Me".obs;

  void setSelectedType(String type) {
    if (type == "General" || type == "Near Me" || type == "Following") {
      selectedType.value = type;
    }
  }
}
