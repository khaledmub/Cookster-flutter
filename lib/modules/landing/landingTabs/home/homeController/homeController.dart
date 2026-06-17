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
  int _routeOverlayPauseDepth = 0;

  var lastVideoPosition = Duration.zero.obs;
  var wasPlaying = false.obs;

  Timer? _debounceTimer;
  Timer? _fetchMoreDebounce;
  DateTime? _lastMemoryPressureCleanupAt;

  /// Rebuild reels [PageView] only when list length changes (not every [videoFeed.refresh]).
  final reelListLength = 0.obs;

  /// Bumped after a full feed reset (tab switch, GPS refresh, filter apply) so
  /// the reels UI reattaches the visible player — same lifecycle as General.
  final feedPlaybackEpoch = 0.obs;

  /// Last successful feed per tab — instant UI when switching عام / بالقرب / المتابعة.
  final Map<String, VideoFeed> _tabFeedCache = {};

  /// Last scroll position per tab so switching tabs doesn't rewind to reel 0.
  final Map<String, int> _tabScrollIndex = {};

  /// Last visible video id per tab — restores exact reel if feed order shifts.
  final Map<String, String> _tabVideoId = {};

  /// Blocks [_refreshTabCacheSilently] while a feed tab switch is in flight
  /// (cache reorder race — see tab-switch handler in [VideoReelScreen]).
  bool _feedTabSwitchLocked = false;

  bool get isFeedTabSwitchLocked => _feedTabSwitchLocked;

  void beginFeedTabSwitch() => _feedTabSwitchLocked = true;

  void endFeedTabSwitch() => _feedTabSwitchLocked = false;

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
    final cityId = prefs.getString('currentCityId');
    if (city != null && city.isNotEmpty) {
      currentCity.value = city;
    }
    if (country != null && country.isNotEmpty) {
      currentCountry.value = country;
    }
    if (cityId != null && cityId.isNotEmpty) {
      currentCityId.value = cityId;
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

  /// Only block the feed on the first Near Me cold start when we have no coords
  /// and nothing to show yet. Background GPS refresh must not tear down a feed
  /// that is already playing (same UX as General).
  bool get blocksUiForLocation =>
      selectedType.value == 'Near Me' &&
      isLocationFetching.value &&
      !hasLocationBeenFetched.value &&
      (videoFeed.value.videos?.isEmpty ?? true);

  String get _reelsFeedMode {
    switch (selectedType.value) {
      case 'Near Me':
        return 'near_me';
      case 'Following':
        return 'following';
      default:
        return 'general';
    }
  }

  Future<void> fetchMoreVideos() async {
    _fetchMoreDebounce?.cancel();
    _fetchMoreDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fetchMoreVideosNow());
    });
  }

  Future<void> _fetchMoreVideosNow() async {
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
      final parsed = await _fetchFeedPage(reset: false);
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
      reelListLength.value = videoFeed.value.videos!.length;
    } catch (e) {
      error.value = "Error loading more videos: $e";
    } finally {
      isLoadingMore.value = false;
      update();
    }
  }

  Future<VideoFeed?> _fetchFeedPage({required bool reset}) async {
    return _fetchReelsPage(reset: reset);
  }

  Future<VideoFeed?> _fetchReelsPage({required bool reset}) async {
    final params = <String, String>{};
    if (!reset) {
      final cursor = videoFeed.value.meta?.nextCursor;
      if (cursor != null && cursor.isNotEmpty) {
        params['cursor'] = cursor;
      }
    } else {
      final feed = _reelsFeedMode;
      if (feed != 'general') {
        params['feed'] = feed;
      }
      if (selectedType.value == 'Near Me') {
        if (latitude.value.isNotEmpty) {
          params['latitude'] = latitude.value;
        }
        if (longitude.value.isNotEmpty) {
          params['longitude'] = longitude.value;
        }
        if (currentCityId.value.isNotEmpty) {
          params['city'] = currentCityId.value;
        }
      }
    }

    var endpoint = EndPoints.reels;
    if (params.isNotEmpty) {
      endpoint = '$endpoint?${Uri(queryParameters: params).query}';
    }

    final response = await ApiClient.getRequest(endpoint);
    if (response.statusCode == 401) {
      error.value = 'Authentication required';
      return null;
    }
    if (response.statusCode != 200) {
      error.value = 'Failed to load reels: ${response.statusCode}';
      return null;
    }
    final parsed = await compute(parseVideoFeed, response.body);
    if (kDebugMode && selectedType.value == 'Near Me') {
      debugPrint(
        'Near Me reels: count=${parsed.videos?.length ?? 0} '
        'geo_fallback=${parsed.meta?.geoFallback ?? false}',
      );
    }
    return parsed;
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
    _fetchMoreDebounce?.cancel();
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
    final needsInitialLocation = !hasLocationBeenFetched.value &&
        latitude.value.isEmpty &&
        longitude.value.isEmpty;
    final prevLat = double.tryParse(latitude.value);
    final prevLng = double.tryParse(longitude.value);
    if (selectedType.value == 'Near Me' && needsInitialLocation) {
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
        // GPS moved — drop a manual city filter from a previous location.
        currentCityId.value = '';
        final prefsForCity = await SharedPreferences.getInstance();
        await prefsForCity.remove('currentCityId');

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
      if (!refreshNearMeFeed ||
          selectedType.value != 'Near Me' ||
          !hasLocationBeenFetched.value) {
        return;
      }
      // Only skip while a fetch is in-flight if we already have a playable feed.
      if (isLoading.value && (videoFeed.value.videos?.isNotEmpty ?? false)) {
        return;
      }
      final hasFeed = videoFeed.value.videos?.isNotEmpty ?? false;
      if (hasFeed) {
        final newLat = double.tryParse(latitude.value);
        final newLng = double.tryParse(longitude.value);
        final moved = prevLat == null ||
            prevLng == null ||
            newLat == null ||
            newLng == null ||
            (newLat - prevLat).abs() > 0.02 ||
            (newLng - prevLng).abs() > 0.02;
        if (!moved) {
          return;
        }
        unawaited(fetchVideos(backgroundRefresh: true));
        return;
      }
      unawaited(fetchVideos(forceNetwork: true));
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

    reelListLength.value = updatedVideos.length;
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
    if (currentCityId.value.isNotEmpty) {
      await prefs.setString('currentCityId', currentCityId.value);
    }
  }

  Future<void> fetchVideos({
    String? country,
    String? city,
    bool forceNetwork = false,
    bool fromTabSwitch = false,
    bool backgroundRefresh = false,
  }) async {
    final tab = selectedType.value;
    final cached = _tabFeedCache[tab];
    final hasCachedFeed =
        !forceNetwork && cached != null && (cached.videos?.isNotEmpty ?? false);

    if (hasCachedFeed) {
      final cachedVideos = cached!.videos!;
      final target = resolveScrollIndexForTab(tab, cachedVideos);
      videoFeed.value = cached;
      reelListLength.value = cachedVideos.length;
      visiblePageIndex.value = target;
      currentIndex.value = target;
      update();

      // Tab switch with warm cache: show instantly, no network replace, and no
      // silent cache refresh while the switch lock is held (cache reorder race).
      if (fromTabSwitch) {
        return;
      }
    }

    if (isLoading.value && !hasCachedFeed && !fromTabSwitch) {
      return;
    }

    if (!hasCachedFeed && !backgroundRefresh) {
      isLoading.value = true;
      // Drop the previous tab's list so Near Me / Following never flash
      // General reels while their own feed is loading.
      videoFeed.value = VideoFeed(status: true, videos: []);
      reelListLength.value = 0;
    }
    currentPage.value = 1;

    try {
      if (selectedType.value == "Near Me") {
        if (city != null && city.isNotEmpty) {
          currentCity.value = city;
        }
        if (country != null && country.isNotEmpty) {
          currentCountry.value = country;
        }
        if (!hasLocationBeenFetched.value &&
            latitude.value.isEmpty &&
            longitude.value.isEmpty &&
            currentCityId.value.isEmpty) {
          videoFeed.value = VideoFeed(status: true, videos: []);
          reelListLength.value = 0;
          unawaited(fetchLocationOnce(refreshNearMeFeed: true));
          return;
        }
      }

      final parsed = await _fetchFeedPage(reset: true);
      if (parsed != null) {
        if (backgroundRefresh && (parsed.videos?.isEmpty ?? true)) {
          return;
        }
        videoFeed.value = parsed;
        reelListLength.value = parsed.videos?.length ?? 0;
        if (parsed.videos?.isNotEmpty ?? false) {
          _tabFeedCache[tab] = parsed;
        } else {
          _tabFeedCache.remove(tab);
        }
        currentPage.value = parsed.meta?.page ?? 1;
        final parsedVideos = parsed.videos;
        if (parsedVideos != null && parsedVideos.isNotEmpty) {
          final target = resolveScrollIndexForTab(tab, parsedVideos);
          visiblePageIndex.value = target;
          currentIndex.value = target;
        }
        // Skip epoch bump during tab switch — serialized attach runs from the
        // tab handler; a concurrent epoch was spawning duplicate decoders on MTK.
        if (tab == selectedType.value &&
            (parsed.videos?.isNotEmpty ?? false) &&
            !backgroundRefresh &&
            !fromTabSwitch &&
            !_feedTabSwitchLocked) {
          feedPlaybackEpoch.value++;
        }
      }
    } catch (e) {
      error.value = "Error: $e";
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Refresh tab cache from network without touching live feed / playback.
  Future<void> _refreshTabCacheSilently(String tab) async {
    // Cache reorder race: never mutate tab cache mid-switch.
    if (_feedTabSwitchLocked) {
      return;
    }
    if (selectedType.value != tab) {
      return;
    }
    try {
      final parsed = await _fetchFeedPage(reset: true);
      if (selectedType.value != tab) {
        return;
      }
      if (parsed == null || (parsed.videos?.isEmpty ?? true)) {
        return;
      }
      _tabFeedCache[tab] = parsed;
    } catch (_) {}
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

  bool get canPlayHomeReels =>
      !isAppInBackground.value &&
      !isNavigating.value &&
      isReelsTabVisible.value;

  /// Immediate silence before a route push (no depth change). Pair with
  /// [pauseReelsForRouteOverlay] on the pushed screen's [initState].
  void silenceHomeReelsForTransition() {
    isNavigating.value = true;
    setReelsTabVisible(false);
    pauseAllVideosSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(pauseAllVideosAwait());
  }

  /// Stops reel audio/video immediately when pushing another route (e.g. profile).
  void pauseReelsForRouteOverlay() {
    _routeOverlayPauseDepth++;
    isNavigating.value = true;
    setReelsTabVisible(false);
    pauseAllVideosSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(pauseAllVideosAwait());
  }

  /// Re-applies silence while an overlay stack is still open (no depth change).
  void reinforceReelsPausedForOverlay() {
    if (_routeOverlayPauseDepth <= 0) {
      return;
    }
    isNavigating.value = true;
    setReelsTabVisible(false);
    pauseAllVideosSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(pauseAllVideosAwait());
  }

  /// Resumes the visible reel after closing an overlay route, only on the home tab.
  void resumeReelsAfterRouteOverlay() {
    if (_routeOverlayPauseDepth <= 0) {
      return;
    }
    _routeOverlayPauseDepth--;
    if (_routeOverlayPauseDepth > 0) {
      return;
    }
    isNavigating.value = false;
    if (isAppInBackground.value) {
      return;
    }
    if (Get.isRegistered<NavBarController>() &&
        Get.find<NavBarController>().selectedIndex.value != 0) {
      return;
    }
    setReelsTabVisible(true);
    feedPlaybackEpoch.value++;
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

  int scrollIndexForTab(String tab) => _tabScrollIndex[tab] ?? 0;

  String? videoIdForTab(String tab) => _tabVideoId[tab];

  List<WallVideos>? cachedVideosForTab(String tab) =>
      _tabFeedCache[tab]?.videos;

  int cachedListLengthForTab(String tab) =>
      _tabFeedCache[tab]?.videos?.length ?? 0;

  void saveTabScrollIndex(String tab, int index) {
    if (index < 0) {
      return;
    }
    _tabScrollIndex[tab] = index;
  }

  void saveTabVideoId(String tab, String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    _tabVideoId[tab] = videoId;
  }

  int resolveScrollIndexForTab(String tab, List<WallVideos> videos) {
    if (videos.isEmpty) {
      return 0;
    }
    final savedId = _tabVideoId[tab];
    if (savedId != null && savedId.isNotEmpty) {
      final byId = videos.indexWhere((video) => video.id == savedId);
      if (byId != -1) {
        return byId.clamp(0, videos.length - 1);
      }
      // Saved id missing from this snapshot (stale cache / reorder) — index 0
      // avoids jumping to a wrong reel via a stale scroll index (index race).
      return 0;
    }
    final savedIndex = scrollIndexForTab(tab);
    if (savedIndex < 0 || savedIndex >= videos.length) {
      return 0;
    }
    return savedIndex;
  }

  /// TikTok-style refresh: reload the current feed from the network and jump
  /// back to the first reel. Triggered by re-tapping the Home tab.
  Future<void> refreshHomeFeed() async {
    if (isLoading.value) {
      return;
    }
    final tab = selectedType.value;
    saveTabScrollIndex(tab, 0);
    _tabVideoId.remove(tab);
    _tabFeedCache.remove(tab);
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
    await fetchVideos(forceNetwork: true);
  }

  /// Pause feed playback when switching عام / بالقرب / المتابعة. Keeps the
  /// decoder pool warm so returning to a tab resumes without a full reload.
  Future<void> prepareForFeedTabSwitch() async {
    final tab = selectedType.value;
    final index = visiblePageIndex.value;
    saveTabScrollIndex(tab, index);
    final videos = videoFeed.value.videos;
    if (videos != null && index >= 0 && index < videos.length) {
      saveTabVideoId(tab, videos[index].id);
    }
    MediaKitPlayerPool.instance.pauseAllImmediate();
    await VideoPlayerPool.instance.pauseAll();
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
