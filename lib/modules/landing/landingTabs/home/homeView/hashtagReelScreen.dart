import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/hashTagController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HashtagReelScreen extends StatefulWidget {
  const HashtagReelScreen({super.key, required this.tag, this.city});

  final String tag;
  final String? city;

  @override
  State<HashtagReelScreen> createState() => _HashtagReelScreenState();
}

class _HashtagReelScreenState extends State<HashtagReelScreen> {
  final HashtagController controller = Get.put(HashtagController());
  final GlobalKey<ReelVideoPlayerState> _reelPlayerKey =
      GlobalKey<ReelVideoPlayerState>();

  late PageController _pageController;
  final Set<String> _trackedVideoIds = {};
  Timer? _viewTrackDebounce;
  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().pauseReelsForRouteOverlay();
    } else {
      MediaKitPlayerPool.instance.silenceAllSync();
    }
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchVideos(tag: widget.tag, city: widget.city);
    });
  }

  @override
  void dispose() {
    _viewTrackDebounce?.cancel();
    _pageController.dispose();
    unawaited(MediaKitPlayerPool.instance.pauseAllAwait());
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().resumeReelsAfterRouteOverlay();
    }
    super.dispose();
  }

  void _scheduleViewTrack(WallVideos video) {
    final videoId = video.id;
    if (videoId == null || videoId.isEmpty || _trackedVideoIds.contains(videoId)) {
      return;
    }
    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      _trackedVideoIds.add(videoId);
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final ref = FirebaseFirestore.instance.collection('videos').doc(videoId);
        if (userId != null && userId.isNotEmpty) {
          await ref.set({
            'views': FieldValue.arrayUnion([userId]),
          }, SetOptions(merge: true));
        } else {
          final deviceId =
              prefs.getString('device_id') ?? DateTime.now().millisecondsSinceEpoch.toString();
          await prefs.setString('device_id', deviceId);
          await ref.set({
            'views': FieldValue.arrayUnion([deviceId]),
          }, SetOptions(merge: true));
        }
      } catch (_) {}
    });
  }

  void _onPageChanged(int index) {
    _visibleIndex = index;
    controller.currentIndex.value = index;

    final videos = controller.videoFeed.value.videos;
    if (videos != null &&
        videos.isNotEmpty &&
        index >= videos.length - 3) {
      unawaited(controller.fetchMoreVideos());
    }

    if (videos != null && index < videos.length) {
      _scheduleViewTrack(videos[index]);
      unawaited(
        MediaKitPlayerPool.instance.releaseFarFrom(
          index,
          window: 0,
          keyResolver: (i) {
            if (i < 0 || i >= videos.length) return null;
            final v = videos[i];
            return v.id ?? v.videoUrl ?? v.video;
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('#${widget.tag}'),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.videoFeed.value.videos == null) {
          return const Center(
            child: PulseLogoLoader(logoPath: 'assets/images/appLogo.png'),
          );
        }

        final videos = controller.videoFeed.value.videos;
        if (videos == null || videos.isEmpty) {
          return Center(
            child: Text(
              controller.error.value.isNotEmpty
                  ? controller.error.value
                  : 'No videos for this hashtag',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final video = videos[index];
                final showPlayer =
                    index == _visibleIndex && video.isImage != 1;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!showPlayer)
                      ReelFeedPlayerKit.buildPagePoster(video),
                    if (showPlayer)
                      ReelFeedPlayerKit.buildInlinePlayer(
                        video: video,
                        playerKey: _reelPlayerKey,
                        wrapPositioned: false,
                      ),
                  ],
                );
              },
            ),
            if (controller.isLoadingMore.value)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        );
      }),
    );
  }
}
