import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:cookster/appUtils/apiEndPoints.dart'; // Assuming Common.videoUrl is here
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';

class VideoReelController extends GetxController with WidgetsBindingObserver {
  RxList<VideoPlayerController?> videoControllers =
      <VideoPlayerController?>[].obs;
  RxInt currentIndex = (-1).obs;
  RxBool isVideoPlaying = true.obs;
  RxBool isMuted = false.obs;
  RxBool isNavigating = false.obs;

  final HomeController homeController = Get.find<HomeController>();

  // Cache to store initialized controllers with a max limit
  final Map<String, VideoPlayerController> _videoCache = {};
  static const int _maxCacheSize = 5; // Limit cache to 5 controllers

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    fetchVideos();
  }

  void fetchVideos() {
    homeController.fetchVideos().then((_) {
      if (homeController.videoFeed.value.videos != null) {
        videoControllers.value = List.generate(
          homeController.videoFeed.value.videos!.length,
          (_) => null,
        );
        if (videoControllers.isNotEmpty) {
          initializeControllerAtIndex(0);
        }
      }
    });
  }

  Future<void> initializeControllerAtIndex(int index) async {
    if (index < 0 ||
        index >= videoControllers.length ||
        videoControllers[index] != null) {
      return;
    }

    final v = homeController.videoFeed.value.videos![index];
    final videoUrl = v.videoUrl?.isNotEmpty == true ? v.videoUrl! : '${Common.videoUrl}/${v.video}';

    // Check if the controller is already in the cache
    if (_videoCache.containsKey(videoUrl)) {
      videoControllers[index] = _videoCache[videoUrl];
      videoControllers[index]!.setVolume(isMuted.value ? 0 : 1);
      if (index == currentIndex.value &&
          isVideoPlaying.value &&
          !isNavigating.value) {
        videoControllers[index]!.play();
      }
      update();
      return;
    }

    // Create a new controller if not in cache
    final controller = VideoPlayerController.network(
      videoUrl,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    videoControllers[index] = controller;
    _addToCache(videoUrl, controller); // Add to cache with size limit
    await controller.initialize();
    controller.setLooping(true);
    controller.setVolume(isMuted.value ? 0 : 1);
    if (index == currentIndex.value &&
        isVideoPlaying.value &&
        !isNavigating.value) {
      controller.play();
    }
    update(); // Notify UI
  }

  void _addToCache(String videoUrl, VideoPlayerController controller) {
    if (_videoCache.length >= _maxCacheSize) {
      // Remove the oldest entry (first in the map)
      final oldestKey = _videoCache.keys.first;
      _videoCache[oldestKey]?.dispose();
      _videoCache.remove(oldestKey);
    }
    _videoCache[videoUrl] = controller;
  }

  void pauseCurrentVideo() {
    if (currentIndex.value >= 0 &&
        currentIndex.value < videoControllers.length &&
        videoControllers[currentIndex.value] != null) {
      videoControllers[currentIndex.value]!.pause();
      isVideoPlaying.value = false;
    }
  }

  void resumeCurrentVideo() {
    if (!isNavigating.value &&
        currentIndex.value >= 0 &&
        currentIndex.value < videoControllers.length &&
        videoControllers[currentIndex.value] != null) {
      videoControllers[currentIndex.value]!.play();
      isVideoPlaying.value = true;
      videoControllers[currentIndex.value]!.setVolume(isMuted.value ? 0 : 1);
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (currentIndex.value >= 0 &&
        videoControllers[currentIndex.value] != null) {
      videoControllers[currentIndex.value]!.setVolume(isMuted.value ? 0 : 1);
    }
  }

  void handleNavigationStart() {
    isNavigating.value = true;
    pauseCurrentVideo();
  }

  void handleNavigationEnd() {
    isNavigating.value = false;
    if (isVideoPlaying.value) {
      resumeCurrentVideo();
    }
  }

  void handlePageChange(int index) {
    if (index == currentIndex.value) return;
    pauseCurrentVideo();
    currentIndex.value = index;
    initializeControllerAtIndex(index).then((_) {
      if (isVideoPlaying.value && !isNavigating.value) {
        resumeCurrentVideo();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pauseCurrentVideo();
    } else if (state == AppLifecycleState.resumed) {
      if (!isNavigating.value) {
        resumeCurrentVideo();
      }
    }
  }

  @override
  void onClose() {
    // Dispose all controllers and clear the cache
    for (var controller in videoControllers) {
      controller?.dispose();
    }
    _videoCache.forEach((_, controller) {
      controller.dispose();
    });
    _videoCache.clear(); // Clear the cache
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
