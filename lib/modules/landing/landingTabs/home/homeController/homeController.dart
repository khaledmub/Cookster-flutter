import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/videoFeedModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  var isFollowing = false.obs;
  var rating = 0.0.obs;

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
  final int retentionRange = 3; // Retain controllers for ±3 indices

  // Custom cache manager for videos
  final CacheManager _videoCacheManager = CacheManager(
    Config(
      'videoCache',
      stalePeriod: const Duration(days: 7), // Cache videos for 7 days
      maxNrOfCacheObjects: 50, // Cache up to 50 videos
    ),
  );

  List<ChewieController?> get chewieControllers => _chewieControllers;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (videoFeed.value.videos != null && videoFeed.value.videos!.isNotEmpty) {
      prepareControllersIfNeeded().then((_) {
        restoreVideoState();
      });
    } else {
      fetchVideos();
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    pauseAllVideos();
    disposeControllers();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isAppInBackground.value = state == AppLifecycleState.paused;
    if (isAppInBackground.value) {
      pauseCurrentVideo();
    } else if (state == AppLifecycleState.resumed) {
      restoreVideoState();
    }
  }

  @override
  void didHaveMemoryPressure() {
    print("Memory pressure detected, cleaning up excess controllers");
    _cleanupUnusedControllers(currentIndex.value);
  }

  var currentCity = "".obs;
  var currentCityId = "".obs;
  var currentCountry = "".obs;

  // Add flags to track if location has been fetched
  var hasLocationBeenFetched = false.obs;
  var isLocationFetching = false.obs;

  // Method to fetch location only once
  Future<void> _fetchLocationOnce() async {
    if (hasLocationBeenFetched.value || isLocationFetching.value) {
      print("Location already fetched or currently fetching, skipping...");
      return;
    }

    isLocationFetching.value = true;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          error.value = "Location permission denied";
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        error.value = "Location permission permanently denied";
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      currentCity.value =
      placemarks.isNotEmpty
          ? (placemarks[0].locality ?? 'Unknown').trim()
          : 'Unknown';
      currentCountry.value =
      placemarks.isNotEmpty
          ? (placemarks[0].country ?? 'Unknown').trim()
          : 'Unknown';

      hasLocationBeenFetched.value = true;
      print(
        'Location fetched - City: ${currentCity.value}, Country: ${currentCountry.value}',
      );
    } catch (e) {
      print('Error fetching location: $e');
      error.value = "Error fetching location: $e";
    } finally {
      isLocationFetching.value = false;
    }
  }

  blockUser(String? userId) async {
    try {
      final response = await ApiClient.postRequest(EndPoints.blockUser, {
        "blocked_user": userId,
      });

      print("PRINTING THE RESPONSE BODY");
      print(response.body);
      print(response.statusCode);
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
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
            content: Text(decoded['message'] ?? 'Operation successful'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print(e);

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

  // Helper method to remove blocked user's videos from current list
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
      // message: videoFeed.value.message,
      videos: updatedVideos,
    );

    // Dispose controllers for videos that were removed
    _disposeRemovedVideoControllers(updatedVideos.length);

    // Update controllers list to match new video count
    _updateControllersAfterRemoval(updatedVideos.length);

    // Adjust current index if needed
    _adjustCurrentIndexAfterRemoval(currentVideoId, updatedVideos);

    // Refresh the observable
    videoFeed.refresh();
  }

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
  void _adjustCurrentIndexAfterRemoval(
      String? currentVideoId,
      List<WallVideos> updatedVideos,
      ) {
    if (currentVideoId == null || updatedVideos.isEmpty) {
      currentIndex.value = 0;
      return;
    }

    // Try to find the current video in the updated list
    int newIndex = updatedVideos.indexWhere(
          (video) => video.id == currentVideoId,
    );

    if (newIndex != -1) {
      // Current video still exists, update index
      currentIndex.value = newIndex;
    } else {
      // Current video was removed, go to previous video or first video
      int newCurrentIndex = currentIndex.value;
      if (newCurrentIndex >= updatedVideos.length) {
        newCurrentIndex = updatedVideos.length - 1;
      }
      if (newCurrentIndex < 0) {
        newCurrentIndex = 0;
      }
      currentIndex.value = newCurrentIndex;
    }

    // Initialize the new current video if it exists
    if (updatedVideos.isNotEmpty && currentIndex.value < updatedVideos.length) {
      Future.delayed(Duration(milliseconds: 100), () {
        initializeControllerAtIndex(currentIndex.value).then((_) {
          if (!isAppInBackground.value && !isNavigating.value) {
            playVideoAtIndex(currentIndex.value);
          }
        });
      });
    }
  }

  Future<void> fetchVideos({String? country, String? city}) async {
    if (isLoading.value) return;
    isLoading.value = true;

    print("I am there to fetch videos");

    try {
      if (selectedType.value == "General") {
        print('Fetching videos for General');
        final response = await ApiClient.postRequest(EndPoints.getVideos, {});
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);
          await prepareControllers();
          if (_chewieControllers.isNotEmpty) {
            await initializeControllerAtIndex(0);
            if (!isMuted.value &&
                !isAppInBackground.value &&
                !isNavigating.value) {
              playVideoAtIndex(0);
            }
            _viewedIndices.add(0);
            preloadNextVideos(0);
          }
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      } else if (selectedType.value == "Following") {
        print('Fetching videos for Following');
        final response = await ApiClient.postRequest(EndPoints.getVideos, {
          "is_following": 1,
        });
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);
          await prepareControllers();
          if (_chewieControllers.isNotEmpty) {
            await initializeControllerAtIndex(0);
            if (!isMuted.value &&
                !isAppInBackground.value &&
                !isNavigating.value) {
              playVideoAtIndex(0);
            }
            _viewedIndices.add(0);
            preloadNextVideos(0);
          }
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      } else {
        String selectedCity;
        String selectedCountry;

        // Use provided parameters first, then use stored values, then fetch location
        if (city != null && country != null) {
          selectedCity = city;
          selectedCountry = country;
          print(
            'Using provided city: $selectedCity, country: $selectedCountry',
          );
        } else if (hasLocationBeenFetched.value &&
            currentCity.value.isNotEmpty &&
            currentCountry.value.isNotEmpty) {
          // Use already fetched location
          selectedCity = currentCity.value;
          selectedCountry = currentCountry.value;
          print(
            'Using cached location - City: $selectedCity, Country: $selectedCountry',
          );
        } else {
          // Enhanced location fetching with iOS-specific handling
          await _fetchLocationWithIOSSupport();

          if (error.value.isNotEmpty) {
            isLoading.value = false;
            update();
            return;
          }

          selectedCity = currentCity.value;
          selectedCountry = currentCountry.value;
          print(
            'Using newly fetched location - City: $selectedCity, Country: $selectedCountry',
          );
        }

        print('Fetching videos for city: $selectedCity');
        print('Fetching videos for country: $selectedCountry');

        final response = await ApiClient.postRequest(EndPoints.getVideos, {
          'city': selectedCity,
          'country': selectedCountry,
        });

        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          videoFeed.value = VideoFeed.fromJson(jsonData);
          await prepareControllers();
          if (_chewieControllers.isNotEmpty) {
            await initializeControllerAtIndex(0);
            if (!isMuted.value &&
                !isAppInBackground.value &&
                !isNavigating.value) {
              playVideoAtIndex(0);
            }
            _viewedIndices.add(0);
            preloadNextVideos(0);
          }
        } else {
          error.value = "Failed to load videos: ${response.statusCode}";
        }
      }
    } catch (e) {
      error.value = "Error: $e";
      print("Exception in fetchVideos: $e");
    } finally {
      isLoading.value = false;
      update();
    }
  }

// Enhanced location fetching method with iOS-specific handling
  Future<void> _fetchLocationWithIOSSupport() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error.value = "Location services are disabled. Please enable location services.";
        return;
      }

      // Check and request location permissions with iOS-specific handling
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          error.value = "Location permissions are denied. Please allow location access in settings.";
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        error.value = "Location permissions are permanently denied. Please enable location access in device settings.";
        return;
      }

      // Get current position with iOS-optimized settings
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15), // Timeout for iOS
      ).timeout(
        Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Location request timed out', Duration(seconds: 20));
        },
      );

      print('Location obtained: ${position.latitude}, ${position.longitude}');

      // Get location details using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Geocoding request timed out', Duration(seconds: 10));
        },
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Handle iOS-specific placemark data
        currentCity.value = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown City';

        currentCountry.value = place.country ?? 'Unknown Country';

        hasLocationBeenFetched.value = true;

        print('City: ${currentCity.value}');
        print('Country: ${currentCountry.value}');

        // Clear any previous errors
        error.value = '';
      } else {
        error.value = "Unable to determine location details";
      }

    } on TimeoutException catch (e) {
      error.value = "Location request timed out. Please check your internet connection.";
      print('Location timeout: $e');
    } on LocationServiceDisabledException catch (e) {
      error.value = "Location services are disabled. Please enable location services.";
      print('Location service disabled: $e');
    } on PermissionDeniedException catch (e) {
      error.value = "Location permission denied. Please allow location access.";
      print('Permission denied: $e');
    } catch (e) {
      error.value = "Failed to get location: $e";
      print('Location error: $e');

      // Fallback: Try to use last known position for iOS
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');

          List<Placemark> placemarks = await placemarkFromCoordinates(
            lastPosition.latitude,
            lastPosition.longitude,
          );

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            currentCity.value = place.locality ??
                place.subAdministrativeArea ??
                place.administrativeArea ??
                'Unknown City';
            currentCountry.value = place.country ?? 'Unknown Country';
            hasLocationBeenFetched.value = true;
            error.value = ''; // Clear error if fallback succeeds
            print('Fallback location - City: ${currentCity.value}, Country: ${currentCountry.value}');
          }
        }
      } catch (fallbackError) {
        print('Fallback location also failed: $fallbackError');
      }
    }
  }

  // Method to manually refresh location if needed
  Future<void> refreshLocation() async {
    hasLocationBeenFetched.value = false;
    currentCity.value = "";
    currentCountry.value = "";
    await _fetchLocationOnce();
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

  Future<void> initializeControllerAtIndex(
      int index, {
        int retryCount = 3,
      }) async {
    if (index < 0 || index >= videoFeed.value.videos!.length) return;

    if (_videoControllers[index] != null &&
        _videoControllers[index]!.value.isInitialized)
      return;

    _cleanupUnusedControllers(index);

    int attempts = 0;

    while (attempts < retryCount) {
      try {
        final videoUrl =
            '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
        print(
          "Attempt $attempts: Initializing video at index $index with URL: $videoUrl",
        );

        // Check for cached video
        final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
        if (fileInfo != null && fileInfo.file != null) {
          _videoControllers[index] = VideoPlayerController.file(
            fileInfo.file,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
        } else {
          _videoControllers[index] = VideoPlayerController.network(
            videoUrl,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
          await _videoCacheManager.downloadFile(videoUrl);
        }

        await _videoControllers[index]!.initialize();
        print("Initialization successful for index $index");

        print("Video details for index $index:");
        print(
          "  Resolution: ${_videoControllers[index]!.value.size.width}x${_videoControllers[index]!.value.size.height}",
        );
        print("  Duration: ${_videoControllers[index]!.value.duration}");
        print("  Position: ${_videoControllers[index]!.value.position}");

        _chewieControllers[index] = ChewieController(
          videoPlayerController: _videoControllers[index]!,
          autoInitialize: false,
          looping: true,
          autoPlay: false,
          allowMuting: true,
          showControls: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white30,
          ),
        );

        _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
        _chewieControllers.refresh();
        print("Video initialized at index $index on attempt $attempts");
        return;
      } catch (e) {
        attempts++;
        print(
          "Error initializing video at index $index on attempt $attempts: $e",
        );
        if (attempts >= retryCount) {
          print(
            "Max retries reached for index $index. Falling back to recreate.",
          );
          await recreateControllerAtIndex(index);
          return;
        }
        await Future.delayed(Duration(milliseconds: 500));
      }
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

  Future<void> recreateControllerAtIndex(
      int index, {
        int retryCount = 3,
      }) async {
    if (index < 0 || index >= videoFeed.value.videos!.length) return;

    disposeControllerAtIndex(index);

    int attempts = 0;

    while (attempts < retryCount) {
      try {
        final videoUrl =
            '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
        print(
          "Attempt $attempts: Recreating video at index $index with URL: $videoUrl",
        );

        final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
        if (fileInfo != null && fileInfo.file != null) {
          _videoControllers[index] = VideoPlayerController.file(
            fileInfo.file,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
        } else {
          _videoControllers[index] = VideoPlayerController.network(
            videoUrl,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
          await _videoCacheManager.downloadFile(videoUrl);
        }

        await _videoControllers[index]!.initialize();

        _chewieControllers[index] = ChewieController(
          videoPlayerController: _videoControllers[index]!,
          autoInitialize: false,
          looping: true,
          autoPlay: false,
          allowMuting: true,
          showControls: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white30,
          ),
        );

        _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
        _chewieControllers.refresh();
        print(
          "Recreated and initialized video at index $index on attempt $attempts",
        );
        return;
      } catch (e) {
        attempts++;
        print(
          "Error recreating video at index $index on attempt $attempts: $e",
        );
        if (attempts >= retryCount) {
          print("Max retries reached for index $index. Giving up.");
          error.value =
          "Failed to load video at index $index after $retryCount attempts: $e";
          return;
        }
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
  }

  void handlePageChange(int index) {
    if (index == currentIndex.value) return;

    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      print("handlePageChange: Processing index $index");
      pauseAllVideos();
      currentIndex.value = index;

      if (index >= 0 && index < videoFeed.value.videos!.length) {
        if (_chewieControllers[index] == null ||
            !_videoControllers[index]!.value.isInitialized) {
          await initializeControllerAtIndex(index);
          if (!isAppInBackground.value && !isNavigating.value) {
            playVideoAtIndex(index);
          }
          _viewedIndices.add(index);
          preloadNextVideos(index);
        } else {
          if (!isAppInBackground.value && !isNavigating.value) {
            playVideoAtIndex(index);
          }
          _viewedIndices.add(index);
          preloadNextVideos(index);
        }
        _cleanupUnusedControllers(index);
      }
    });
  }

  void preloadNextVideos(int currentIndex) async {
    print("Preloading started for nearby videos");

    const int preloadLimit = 1; // Preload ±1 indices
    int startIndex = (currentIndex - preloadLimit).clamp(
      0,
      videoFeed.value.videos!.length - 1,
    );
    int endIndex = (currentIndex + preloadLimit).clamp(
      0,
      videoFeed.value.videos!.length - 1,
    );

    for (int nextIndex = startIndex; nextIndex <= endIndex; nextIndex++) {
      if (!_viewedIndices.contains(nextIndex) &&
          (_chewieControllers[nextIndex] == null ||
              _videoControllers[nextIndex]?.value.isInitialized != true)) {
        print("Preloading video at index $nextIndex");
        await initializeControllerAtIndex(nextIndex);
        await Future.delayed(
          Duration(milliseconds: 100),
        ); // Small delay to ease load
      }
    }

    print("Preloading completed");
  }

  void pauseAllVideos() {
    print("Pausing all videos");
    for (var controller in _chewieControllers) {
      controller?.pause();
      controller?.setVolume(0);
    }
    isVideoPlaying.value = false;
  }

  Future<void> playVideoAtIndex(int index) async {
    if (index < 0 ||
        index >= videoFeed.value.videos!.length ||
        _chewieControllers[index] == null)
      return;

    print("Playing video at index $index");
    await initializeControllerAtIndex(index);
    _chewieControllers.refresh();
    await Future.delayed(const Duration(milliseconds: 100));
    await _chewieControllers[index]!.play();
    _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
    isVideoPlaying.value = true;
    _viewedIndices.add(index);
  }

  void pauseCurrentVideo() {
    if (currentIndex.value >= 0 &&
        currentIndex.value < _chewieControllers.length &&
        _chewieControllers[currentIndex.value] != null) {
      print("Pausing current video at index ${currentIndex.value}");
      final controller = _chewieControllers[currentIndex.value]!;
      lastVideoPosition.value = controller.videoPlayerController.value.position;
      wasPlaying.value = controller.isPlaying;
      controller.pause();
      isVideoPlaying.value = false;
    }
  }

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

  void togglePlayPause() {
    if (currentIndex.value < 0 ||
        currentIndex.value >= _chewieControllers.length)
      return;

    final controller = _chewieControllers[currentIndex.value];
    if (controller != null) {
      controller.isPlaying ? pauseCurrentVideo() : resumeCurrentVideo();
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (currentIndex.value >= 0 &&
        currentIndex.value < _chewieControllers.length &&
        _chewieControllers[currentIndex.value] != null) {
      _chewieControllers[currentIndex.value]!.setVolume(isMuted.value ? 0 : 1);
    }
  }

  void handleNavigation() {
    isNavigating.value = true;
    pauseCurrentVideo();
  }

  Future<void> restoreVideoState() async {
    final index = currentIndex.value;
    if (index < 0 ||
        index >= _chewieControllers.length ||
        _chewieControllers[index] == null) {
      isNavigating.value = false;
      return;
    }

    final controller = _chewieControllers[index]!;
    try {
      if (!controller.videoPlayerController.value.isInitialized) {
        await initializeControllerAtIndex(index);
      }

      if (lastVideoPosition.value.inMilliseconds > 0) {
        await controller.videoPlayerController.seekTo(lastVideoPosition.value);
      }

      final targetVolume = isMuted.value ? 0.0 : 1.0;
      if (controller.videoPlayerController.value.volume != targetVolume) {
        controller.setVolume(targetVolume);
      }

      if (wasPlaying.value && !isAppInBackground.value && !isNavigating.value) {
        await controller.play();
        isVideoPlaying.value = true;
      }
    } catch (e) {
      print('Error restoring video state: $e');
    } finally {
      isNavigating.value = false;
    }
  }

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