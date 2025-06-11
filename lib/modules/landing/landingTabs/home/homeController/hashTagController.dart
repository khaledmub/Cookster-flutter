import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/videoFeedModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';

class HashtagController extends GetxController {
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

  final int maxConcurrentVideos = 3;

  List<ChewieController?> get chewieControllers => _chewieControllers;



  @override
  void onClose() {
    _debounceTimer?.cancel();
    pauseAllVideos();
    disposeControllers();
    super.onClose();
  }


  var currentCity = "".obs;
  var currentCountry = "".obs;

  Future<void> fetchVideos({String? city, required String tag}) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      String selectedCity;

      if (city != null) {
        // Use provided city if available
        selectedCity = city;
      } else {
        // Check and request location permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            error.value = "Location permission denied";
            isLoading.value = false;
            update();
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          error.value = "Location permission permanently denied";
          isLoading.value = false;
          update();
          return;
        }

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Get city from coordinates
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        selectedCity = placemarks.isNotEmpty ? placemarks[0].locality ?? 'Unknown' : 'Unknown';
      }

      // Print the city
      print('Fetching videos for city: $selectedCity');


      currentCity.value = selectedCity.trim();

      // Proceed with video fetching using the selected city
      final response = await ApiClient.postRequest(EndPoints.getVideos, {
        'city': selectedCity,
        'tags' : tag
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
    } catch (e) {
      error.value = "Error: $e";
    } finally {
      isLoading.value = false;
      update();
    }
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

        _videoControllers[index] = VideoPlayerController.network(
          videoUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );

        await _videoControllers[index]!.initialize();

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

    if (activeControllers >= maxConcurrentVideos) {
      print(
        "Active controllers ($activeControllers) exceeds limit ($maxConcurrentVideos). Cleaning up...",
      );

      int keepStart = (currentIndex - 1).clamp(0, _videoControllers.length - 1);
      int keepEnd = (currentIndex + 1).clamp(0, _videoControllers.length - 1);

      for (int i = 0; i < _videoControllers.length; i++) {
        if (i < keepStart || i > keepEnd) {
          if (_videoControllers[i] != null) {
            print(
              "Cleaning up controller at index $i (outside range $keepStart-$keepEnd)",
            );
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

        _videoControllers[index] = VideoPlayerController.network(
          videoUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );

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
          recreateControllerAtIndex(index).then((_) {
            if (!isAppInBackground.value && !isNavigating.value) {
              playVideoAtIndex(index);
            }
            _viewedIndices.add(index);
            preloadNextVideos(index);
          });
        } else {
          if (!isAppInBackground.value && !isNavigating.value) {
            playVideoAtIndex(index);
          }
          _viewedIndices.add(index);
          preloadNextVideos(index);
        }
      }
    });
  }

  void preloadNextVideos(int currentIndex) async {
    print("Preloading started for next videos");

    const int preloadLimit = 1;
    int nextIndex = currentIndex + 1;

    while (nextIndex < videoFeed.value.videos!.length &&
        nextIndex <= currentIndex + preloadLimit) {
      if (!_viewedIndices.contains(nextIndex) &&
          (_chewieControllers[nextIndex] == null ||
              _videoControllers[nextIndex]?.value.isInitialized != true)) {
        print("Preloading video at index $nextIndex");
        await initializeControllerAtIndex(nextIndex);
      }
      nextIndex++;
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
      // Initialize only if not already initialized
      if (!controller.videoPlayerController.value.isInitialized) {
        await initializeControllerAtIndex(index);
      }

      // Seek to last position only if valid
      if (lastVideoPosition.value.inMilliseconds > 0) {
        await controller.videoPlayerController.seekTo(lastVideoPosition.value);
      }

      // Set volume only if it differs from current state
      final targetVolume = isMuted.value ? 0.0 : 1.0;
      if (controller.videoPlayerController.value.volume != targetVolume) {
        controller.setVolume(targetVolume);
      }

      // Play video only if conditions are met
      if (wasPlaying.value && !isAppInBackground.value && !isNavigating.value) {
        await controller.play();
        isVideoPlaying.value = true;
      }
    } catch (e) {
      // Handle errors (e.g., log or notify user)
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
}
