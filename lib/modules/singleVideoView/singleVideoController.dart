import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/colorUtils.dart';
import 'package:share_plus/share_plus.dart';

class SingleVideoController extends GetxController with WidgetsBindingObserver {
  // Video state properties
  final videoUrl = Rx<String?>(null);
  final videoId = Rx<String?>(null);
  final Rx<VideoPlayerController?> videoPlayerController =
      Rx<VideoPlayerController?>(null);
  final Rx<ChewieController?> chewieController = Rx<ChewieController?>(null);

  // Observable state variables
  final isPlaying = true.obs;
  final isInitializing = true.obs;
  final isMuted = false.obs;
  final showPlayPauseIcon = false.obs;
  final hasError = false.obs;
  final videoSize = Rx<Size?>(null);
  final videoAspectRatio = Rx<double?>(null);

  // Retry mechanism
  final retryCount = 0.obs;
  final maxRetries = 3;

  // @override
  // void onInit() {
  //   super.onInit();
  //   WidgetsBinding.instance.addObserver(this);
  // }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeControllers();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      pauseVideo();
    } else if (state == AppLifecycleState.resumed) {
      if (isPlaying.value && chewieController.value != null) {
        resumeVideo();
      }
    }
  }

  void setVideoData(String? url, String? id) {
    videoUrl.value = url;
    videoId.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializePlayer();
    });
  }

  Future<void> initializePlayer() async {
    if (videoUrl.value == null || videoUrl.value!.isEmpty) {
      isInitializing.value = false;
      hasError.value = true;
      return;
    }

    isInitializing.value = true;
    hasError.value = false;

    // Construct and encode video URL
    String fullVideoUrl;
    if (videoUrl.value!.startsWith('http')) {
      fullVideoUrl = videoUrl.value!;
    } else {
      fullVideoUrl = Uri.encodeFull('${Common.videoUrl}/${videoUrl.value}');
    }

    print('Initializing video: $fullVideoUrl');

    // Dispose existing controllers first
    disposeControllers();

    // Create new controller with header settings
    videoPlayerController.value = VideoPlayerController.network(
      fullVideoUrl,
      httpHeaders: {'User-Agent': 'Mozilla/5.0', 'Accept': '*/*'},
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    try {
      // Add listener to handle video events
      videoPlayerController.value!.addListener(videoPlayerListener);

      // Initialize with a timeout
      await videoPlayerController.value!.initialize().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video initialization timed out');
        },
      );

      // Verify if video is playable
      if (!videoPlayerController.value!.value.isInitialized) {
        throw Exception('Video controller initialized but video is not ready');
      }

      // Store video dimensions for debugging
      videoSize.value = videoPlayerController.value!.value.size;
      videoAspectRatio.value = videoPlayerController.value!.value.aspectRatio;

      print('Video initialized with dimensions: ${videoSize.value}');
      print('Video aspect ratio: ${videoAspectRatio.value}');

      // Use a fixed aspect ratio if the derived one is invalid
      double aspectRatio = videoPlayerController.value!.value.aspectRatio;
      if (aspectRatio.isNaN || aspectRatio <= 0 || aspectRatio.isInfinite) {
        aspectRatio = 16 / 9; // Default to 16:9 if we get an invalid value
        print('Invalid aspect ratio detected, using 16:9 instead');
      }

      chewieController.value = ChewieController(
        videoPlayerController: videoPlayerController.value!,
        autoPlay: true,
        looping: true,
        showControls: false,
        aspectRatio: aspectRatio,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
        useRootNavigator: false,
        // Android specific settings
        // androidUseRenderSurface: true,

        // Error handling
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 50),
                SizedBox(height: 10),
                Text(
                  'Video Error: $errorMessage',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 20),
                if (retryCount.value < maxRetries)
                  ElevatedButton(
                    onPressed: retryInitialization,
                    child: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primaryColor,
                    ),
                  ),
              ],
            ),
          );
        },
      );

      isInitializing.value = false;
      hasError.value = false;
      retryCount.value = 0;

      // Ensure video plays
      if (isPlaying.value) {
        videoPlayerController.value!.play();
      }
    } catch (error) {
      print('Error initializing video player: $error');
      isInitializing.value = false;
      hasError.value = true;

      // Auto-retry if not exceeded max retries
      if (retryCount.value < maxRetries) {
        retryInitialization();
      }
    }
  }

  void videoPlayerListener() {
    // Skip if controller is disposed
    if (videoPlayerController.value == null) return;

    try {
      // Print debugging info
      if (videoPlayerController.value!.value.isInitialized) {
        videoSize.value = videoPlayerController.value!.value.size;
        videoAspectRatio.value = videoPlayerController.value!.value.aspectRatio;

        isPlaying.value = videoPlayerController.value!.value.isPlaying;
      }

      // Check for video player errors
      if (videoPlayerController.value!.value.hasError) {
        print(
          'Video player error: ${videoPlayerController.value!.value.errorDescription}',
        );

        if (!hasError.value) {
          hasError.value = true;

          // Auto-retry if not exceeded max retries
          if (retryCount.value < maxRetries) {
            retryInitialization();
          }
        }
      }
    } catch (e) {
      print('Error in video player listener: $e');
    }
  }

  void retryInitialization() {
    retryCount.value++;
    print('Retrying video initialization (${retryCount.value}/${maxRetries})');

    // Add a small delay before retry
    Future.delayed(Duration(seconds: 1), () {
      initializePlayer();
    });
  }

  void pauseVideo() {
    if (videoPlayerController.value != null &&
        videoPlayerController.value!.value.isInitialized &&
        videoPlayerController.value!.value.isPlaying) {
      videoPlayerController.value!.pause();
      isPlaying.value = false;
    }
  }

  void resumeVideo() {
    if (videoPlayerController.value != null &&
        videoPlayerController.value!.value.isInitialized &&
        !videoPlayerController.value!.value.isPlaying) {
      videoPlayerController.value!.play();
      isPlaying.value = true;
    }
  }

  void togglePlayPause() {
    if (hasError.value ||
        videoPlayerController.value == null ||
        !videoPlayerController.value!.value.isInitialized) {
      retryInitialization();
      return;
    }

    isPlaying.value = !isPlaying.value;
    showPlayPauseIcon.value = true;

    if (isPlaying.value) {
      resumeVideo();
    } else {
      pauseVideo();
    }

    // Hide play/pause icon after 1 second
    Future.delayed(Duration(seconds: 1), () {
      showPlayPauseIcon.value = false;
    });
  }

  void toggleMute() {
    if (hasError.value ||
        videoPlayerController.value == null ||
        !videoPlayerController.value!.value.isInitialized)
      return;

    isMuted.value = !isMuted.value;
    videoPlayerController.value!.setVolume(isMuted.value ? 0.0 : 1.0);
  }

  void disposeControllers() {
    if (videoPlayerController.value != null) {
      videoPlayerController.value!.removeListener(videoPlayerListener);
      videoPlayerController.value!.dispose();
      videoPlayerController.value = null;
    }

    if (chewieController.value != null) {
      chewieController.value!.dispose();
      chewieController.value = null;
    }
  }

  Future<void> handleShare(String videoId) async {
    pauseVideo();

    try {
      final String webUrl = "https://cookster.org/web/visitSingleVideo?id=$videoId";
      final String shareMessage =
          'Check out this amazing video on Cookster!\n$webUrl';

      await Share.share(shareMessage, subject: 'Cookster Video');
    } catch (e) {
      print('Error sharing video: $e');
      Get.snackbar(
        'Error',
        'Could not share this video',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (isPlaying.value) {
        resumeVideo();
      }
    }
  }

  void showMoreOptions(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.sell, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'Want to Promote this video?',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.flag_outlined, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'Report Content',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(
                    '/report-content',
                    arguments: {'videoId': videoId},
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
