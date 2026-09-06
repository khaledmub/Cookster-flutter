import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/reel_screen_playback_helpers.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/core/video/video_preload_target.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/reel_page_keep_alive.dart';
import 'package:cookster/core/widgets/reel_action_rail.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart'
    show VideoDescriptionWidget;
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/hashTagController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HashtagReelScreen extends StatefulWidget {
  const HashtagReelScreen({super.key, required this.tag, this.city});

  final String tag;
  final String? city;

  @override
  State<HashtagReelScreen> createState() => _HashtagReelScreenState();
}

class _HashtagReelScreenState extends State<HashtagReelScreen>
    with WidgetsBindingObserver {
  final HashtagController controller = Get.put(HashtagController());
  final GlobalKey<ReelVideoPlayerState> _reelPlayerKey =
      GlobalKey<ReelVideoPlayerState>();

  late PageController _pageController;
  final ValueNotifier<int> _visibleIndexNotifier = ValueNotifier<int>(0);
  final Set<String> _trackedVideoIds = {};
  Timer? _viewTrackDebounce;
  bool _maskActiveVideoWithPoster = true;
  int? _scrollTowardIndex;

  late final VideoPreloadManager _preloadManager;
  late final ReelsPlaybackCoordinator _playbackCoordinator;
  final VideoSourceResolver _sourceResolver = const VideoSourceResolver();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAuthState());
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().pauseReelsForRouteOverlay();
    } else {
      MediaKitPlayerPool.instance.silenceAllSync();
    }
    _pageController = PageController();
    _pageController.addListener(_onPageScrollOffset);
    _preloadManager = VideoPreloadManager(
      sourceBuilder: _preloadTargetForIndex,
      decoderWarmEnabled: false,
    );
    _playbackCoordinator = ReelsPlaybackCoordinator(
      preloadManager: _preloadManager,
      targetForIndex: _preloadTargetForIndex,
      thumbnailUrlForIndex: _thumbnailUrlForIndex,
      videoForIndex: (index) {
        final videos = controller.videoFeed.value.videos;
        if (videos == null || index < 0 || index >= videos.length) {
          return null;
        }
        return videos[index];
      },
    );
    unawaited(_bootstrap());
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (!mounted) return;
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      prepareForFullscreenVideoPlayback(),
      controller.fetchVideos(tag: widget.tag, city: widget.city),
    ]);
    if (!mounted) {
      return;
    }
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    _preloadManager.prepareForSessionStart();
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    unawaited(_preloadManager.bootstrapFromVisible(0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_attachPlaybackForIndex(0));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewTrackDebounce?.cancel();
    _visibleIndexNotifier.dispose();
    _pageController.removeListener(_onPageScrollOffset);
    _pageController.dispose();
    _playbackCoordinator.dispose();
    unawaited(MediaKitPlayerPool.instance.pauseAllAwait());
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().resumeReelsAfterRouteOverlay();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resumeAfterAppForeground();
        }
      });
    }
  }

  Future<void> _resumeAfterAppForeground() async {
    final videos = controller.videoFeed.value.videos;
    if (!mounted || videos == null || videos.isEmpty) {
      return;
    }
    final index =
        _visibleIndexNotifier.value.clamp(0, videos.length - 1);
    final video = videos[index];
    if (!_maskActiveVideoWithPoster) {
      setState(() => _maskActiveVideoWithPoster = true);
    }
    final videoId = video.id;
    if (videoId != null && videoId.isNotEmpty) {
      MediaKitPlayerPool.instance.invalidatePrimedFrame(videoId);
      MediaKitPlayerPool.instance.clearRecentPaint(videoId);
    }
    if (video.isPhotoPost) {
      return;
    }
    await ReelScreenPlaybackHelpers.resumeAfterAppForeground(
      playerKey: _reelPlayerKey,
      videoId: video.id,
      attachVisible: () => _attachPlaybackForIndex(
        index,
        forceReattach: true,
      ),
    );
  }

  void _onVisibleReelReady(int index) {
    if (!mounted) {
      return;
    }
    _preloadManager.decoderWarmEnabled = true;
    _playbackCoordinator.bootstrapFromVisible(index);
    unawaited(_preloadManager.onVisibleIndexChanged(index));
  }

  void _resetPosterMaskForPageChange({String? videoId}) {
    if (ReelScreenPlaybackHelpers.shouldKeepPosterHidden(videoId)) {
      if (_maskActiveVideoWithPoster) {
        setState(() => _maskActiveVideoWithPoster = false);
      }
      ReelScreenPlaybackHelpers.resumeAudibleForReel(videoId);
      return;
    }
    if (!_maskActiveVideoWithPoster) {
      setState(() => _maskActiveVideoWithPoster = true);
    }
  }

  Future<void> _attachPlaybackForIndex(
    int index, {
    bool forceReattach = false,
  }) async {
    final videos = controller.videoFeed.value.videos;
    if (videos == null || index < 0 || index >= videos.length) {
      return;
    }
    if (videos[index].isPhotoPost) {
      MediaKitPlayerPool.instance.pauseAllImmediate();
      return;
    }
    await ReelScreenPlaybackHelpers.attachVisibleIndex(
      preloadManager: _preloadManager,
      coordinator: _playbackCoordinator,
      context: context,
      index: index,
      playerKey: _reelPlayerKey,
      forcePlayerReattach: forceReattach,
    );
  }

  VideoPreloadTarget? _preloadTargetForIndex(int index) {
    final videos = controller.videoFeed.value.videos;
    if (videos == null || index < 0 || index >= videos.length) {
      return null;
    }
    final video = videos[index];
    if (video.isPhotoPost) {
      return null;
    }
    final key = video.id ?? video.resolvedPlaybackUrl ?? '';
    if (key.isEmpty || !video.isPlaybackReady) {
      return VideoPreloadTarget(key: key, candidates: const []);
    }
    return VideoPreloadTarget(
      key: key,
      candidates: _sourceResolver.resolveForWallVideo(video),
    );
  }

  String? _thumbnailUrlForIndex(int index) {
    final videos = controller.videoFeed.value.videos;
    if (videos == null || index < 0 || index >= videos.length) {
      return null;
    }
    return ReelFeedPlayerKit.precachePosterUrl(videos[index]);
  }

  void _onPageScrollOffset() {
    final videos = controller.videoFeed.value.videos;
    if (!_pageController.hasClients ||
        !mounted ||
        videos == null ||
        videos.isEmpty) {
      return;
    }
    final page = _pageController.page;
    if (page == null) {
      return;
    }
    final rounded = page.roundToDouble();
    if ((page - rounded).abs() < 0.02) {
      _scrollTowardIndex = null;
      return;
    }
    final towardRaw = page > rounded ? page.ceil() : page.floor();
    final toward = towardRaw.clamp(0, videos.length - 1).toInt();
    final progress = (page - rounded).abs();
    if (_scrollTowardIndex == toward && progress < 0.45) {
      return;
    }
    _scrollTowardIndex = toward;
    _playbackCoordinator.onPageScrollToward(
      fromActualIndex: _visibleIndexNotifier.value,
      towardActualIndex: toward,
      context: context,
      scrollProgress: progress,
    );
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
    _visibleIndexNotifier.value = index;
    controller.currentIndex.value = index;
    final videos = controller.videoFeed.value.videos;
    final videoId = videos != null && index < videos.length
        ? videos[index].id
        : null;
    _resetPosterMaskForPageChange(videoId: videoId);
    _scrollTowardIndex = null;

    if (videos != null &&
        videos.isNotEmpty &&
        index >= videos.length - 3) {
      unawaited(controller.fetchMoreVideos());
    }

    if (videos != null && index < videos.length) {
      final video = videos[index];
      _scheduleViewTrack(video);
      if (video.isPhotoPost) {
        MediaKitPlayerPool.instance.pauseAllImmediate();
        return;
      }
      unawaited(_attachPlaybackForIndex(index));
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
              clipBehavior: Clip.hardEdge,
              dragStartBehavior: DragStartBehavior.down,
              allowImplicitScrolling: true,
              physics: const ClampingScrollPhysics(),
              itemCount: videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final video = videos[index];
                return ReelPageKeepAlive(
                  key: ValueKey<String>('hashtag_${video.id ?? 'video'}'),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _visibleIndexNotifier,
                    builder: (context, visibleIndex, _) {
                      final isActivePage = index == visibleIndex;
                      final isActiveVideo = isActivePage &&
                          !video.isPhotoPost &&
                          video.isPlaybackReady;
                      final maskPoster =
                          isActiveVideo && _maskActiveVideoWithPoster;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomLeft,
                        fit: StackFit.expand,
                        children: [
                          ReelFeedPageMediaChrome(
                            video: video,
                            isActivePage: isActivePage,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (isActiveVideo)
                                  ReelFeedPlayerKit.buildInlinePlayer(
                                    video: video,
                                    playerKey: _reelPlayerKey,
                                    wrapPositioned: false,
                                    showProgressBar: !video.isPhotoPost,
                                    onPlaybackReady: () {
                                      _onVisibleReelReady(index);
                                    },
                                    onFeedVideoPainted: (_) {
                                      if (!mounted ||
                                          !_maskActiveVideoWithPoster) {
                                        return;
                                      }
                                      setState(
                                        () => _maskActiveVideoWithPoster = false,
                                      );
                                    },
                                  ),
                                IgnorePointer(
                                  ignoring: isActiveVideo && !maskPoster,
                                  child: Opacity(
                                    opacity: maskPoster || !isActiveVideo
                                        ? 1.0
                                        : 0.0,
                                    child: ReelFeedPlayerKit.buildPagePoster(
                                      video,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActivePage) ...[
                            VideoDescriptionWidget(
                              title: video.title,
                              description: video.description,
                              tags: video.tags,
                              controller: Get.isRegistered<HomeController>()
                                  ? Get.find<HomeController>()
                                  : null,
                              tiktokStyle: true,
                              userName: video.userName,
                              creatorHandle: video.creatorHandle,
                              sponsorType: video.sponsorType,
                              isPhotoPost: video.isPhotoPost,
                              bottomBarClearance: 8,
                            ),
                            ReelActionRail(
                              video: video,
                              isAuthenticated: _isAuthenticated,
                              layout: ReelActionRailLayout.collection,
                              onBeforeNavigation: () {
                                if (Get.isRegistered<HomeController>()) {
                                  Get.find<HomeController>()
                                      .pauseReelsForRouteOverlay();
                                }
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
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
