import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/goLive/join_screen.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/core/video/video_preload_target.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/commentScreen.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/profileModel.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/simpleUserProfileModel.dart';
import 'package:cookster/modules/landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import 'package:cookster/modules/search/searchView/searchView.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:get/get.dart';
import 'package:pro_image_editor/core/platform/io/io_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../auth/signUp/signUpController/cityController.dart';
import '../../../../chatScreen/userChatList.dart';
import '../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../../../search/searchController/searchController.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import '../../../../video_likes_screen/video_likes_screen.dart';
import '../../../../../services/reels/reels_session_store.dart';
import '../../../../../services/settings/settings_service.dart';
import '../../add/videoAddController/videoAddController.dart';
import '../homeController/addCommentControllr.dart';
import '../homeController/homeController.dart';
import '../homeWidgets/chatIconWithCounter.dart';
import '../homeWidgets/contactNowDialog.dart';
import '../homeWidgets/reviewSheet.dart';
import '../homeWidgets/reel_video_player.dart';
import 'hashtagReelScreen.dart';

class VideoReelScreen extends StatefulWidget {
  @override
  _VideoReelScreenState createState() => _VideoReelScreenState();
}

class _VideoReelScreenState extends State<VideoReelScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final HomeController controller = Get.find();
  final PromoteVideoController promoteVideoController = Get.find();
  final VideoCommentsController videoCommentsController = Get.put(
    VideoCommentsController(),
  );
  final ProfileController profileController = Get.find();
  final ProfessionalProfileController professionalProfileController =
      Get.find();

  final SaveController saveController = Get.find();

  @override
  bool get wantKeepAlive => true;

  bool _showIcon = false;
  bool isAuthenticated = false;
  final VideoSourceResolver _sourceResolver = const VideoSourceResolver();
  final ReelsSessionStore _sessionStore = ReelsSessionStore.instance;
  late final VideoPreloadManager _preloadManager;
  late final ReelsPlaybackCoordinator _playbackCoordinator;
  String? _pendingRestoreVideoId;
  bool _sessionRestored = false;
  int? _pendingRestoreIndex;

  Timer? _viewTrackDebounce;
  Timer? _positionSaveThrottle;
  final Set<String> _trackedVideoIds = {};
  final ValueNotifier<int> _visibleIndexNotifier = ValueNotifier<int>(0);
  WallVideos? _activePlayerVideo;
  Worker? _feedRestoreWorker;
  Worker? _reelsVisibilityWorker;
  bool _pendingFeedTabPlayback = false;
  int? _scrollTowardActualIndex;
  final Map<String, int> _commentCounts = {};
  late final PageController _pageController;
  final GlobalKey<ReelVideoPlayerState> _reelPlayerKey =
      GlobalKey<ReelVideoPlayerState>();

  void _schedulePlayerForPage(int pageIndex) {
    final videos = controller.videoFeed.value.videos;
    if (videos == null ||
        videos.isEmpty ||
        !controller.isReelsTabVisible.value) {
      if (_activePlayerVideo != null && mounted) {
        setState(() => _activePlayerVideo = null);
      }
      return;
    }
    final actualIndex = pageIndex % videos.length;
    final video = videos[actualIndex];
    if (video.id == null || video.id!.isEmpty) {
      return;
    }
    if (_activePlayerVideo?.id == video.id) {
      return;
    }
    setState(() {
      _activePlayerVideo = video;
    });
  }

  /// Switches عام / بالقرب / المتابعة and always rewinds to the first reel.
  void _switchFeedTab(String newTabType) {
    if (newTabType != 'General' &&
        newTabType != 'Near Me' &&
        newTabType != 'Following') {
      return;
    }
    if (newTabType == controller.selectedType.value &&
        (controller.videoFeed.value.videos?.isNotEmpty ?? false)) {
      _finishFeedTabPlayback();
      return;
    }
    _pendingFeedTabPlayback = true;
    controller.prepareForFeedTabSwitch();
    controller.setSelectedType(newTabType);
    _visibleIndexNotifier.value = 0;
    if (mounted) {
      setState(() => _activePlayerVideo = null);
    }
    unawaited(
      controller.fetchVideos(fromTabSwitch: true).whenComplete(() {
        if (mounted && _pendingFeedTabPlayback) {
          _finishFeedTabPlayback();
        }
      }),
    );
    _finishFeedTabPlayback();
  }

  void _finishFeedTabPlayback() {
    if (!mounted || !controller.isReelsTabVisible.value) {
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    _pendingFeedTabPlayback = false;
    _visibleIndexNotifier.value = 0;
    controller.visiblePageIndex.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? 0) != 0) {
        _pageController.jumpToPage(0);
      }
      _schedulePlayerForPage(0);
      MediaKitPlayerPool.instance.setScreenWidth(
        MediaQuery.sizeOf(context).width,
      );
      final firstId = videos[0].id;
      if (firstId != null && firstId.isNotEmpty) {
        unawaited(MediaKitPlayerPool.instance.prepareVisiblePlayback(firstId));
      }
      _playbackCoordinator.onPageSettled(0, context: context);
      unawaited(_preloadManager.warmIndexNow(0, maxWaitMs: 1500));
      unawaited(_reelPlayerKey.currentState?.syncAudibleIfNeeded());
    });
  }


  Future<void> _onReelDoubleTapLike(WallVideos video) async {
    var currentUserDetails =
        profileController.simpleUserDetails.value?.user;
    var currentUser =
        professionalProfileController.userDetails.value?.user;
    final String userId = currentUserDetails?.id ?? currentUser?.id ?? '';

    if (userId.isNotEmpty && isAuthenticated) {
      final String? likedVideoId = video.id;
      if (likedVideoId == null) {
        return;
      }
      HapticFeedback.lightImpact();
      await videoCommentsController.toggleVideoLike(
        likedVideoId,
        userId,
      );
    } else if (!isAuthenticated) {
      Get.toNamed(AppRoutes.signIn);
    }
  }

  Widget _buildInlineReelPlayer(WallVideos video) {
    return Positioned.fill(
      child: ReelVideoPlayer(
          key: _reelPlayerKey,
          releaseOnDispose: false,
          playerPoolKey: video.id,
          videoId: video.id,
          thumbnailUrl: video.resolvedReelPosterUrl ?? '',
          posterFallbackUrl: video.resolvedReelPosterFallbackUrl,
          blurThumbnailUrl: video.resolvedBlurThumbnailUrl,
          videoUrl: video.resolvedPlaybackUrl ?? '',
          hlsUrl: video.resolvedHlsUrl,
          qualityMp4Urls:
              video.isTranscodeReady ? video.qualityMp4Urls : const [],
          onVideoCompleted: _onReelVideoCompleted,
        ),
    );
  }

  Widget _buildPagePoster(WallVideos videoDetail, {required bool isActiveReel}) {
    if (isActiveReel) {
      return const SizedBox.shrink();
    }
    return _buildReelPoster(videoDetail);
  }

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  Future<void> _checkAuthentication() async {
    try {
      bool authStatus = await _isUserAuthenticated();
      var currentUserDetails = profileController.simpleUserDetails.value?.user;
      var currentUser = professionalProfileController.userDetails.value?.user;
      String? id = currentUser?.id ?? currentUserDetails?.id;
      setState(() {
        isAuthenticated = authStatus;
      });
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    }
  }

  String _language = 'en'; // Default to English
  String userIdFromStorage = ''; // Default to English
  late String _labelShare;
  late String _labelComment;
  late String _labelFollow;

  void _cacheStaticLabels() {
    _labelShare = 'share'.tr;
    _labelComment = 'comment'.tr;
    _labelFollow = 'follow'.tr;
  }

  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
      userIdFromStorage = prefs.getString('user_id') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visibleIndexNotifier.value = controller.visiblePageIndex.value;
    _pageController = PageController(
      initialPage: controller.visiblePageIndex.value,
    );
    _pageController.addListener(_onPageScrollOffset);
    _feedRestoreWorker = ever(controller.videoFeed, (_) {
      _applyPendingRestoreIfPossible();
      if (_pendingFeedTabPlayback) {
        _finishFeedTabPlayback();
      }
      _maybeBootstrapPreload();
    });
    _loadLanguage();
    _cacheStaticLabels();
    _checkAuthentication();
    SettingsService.instance.load();
    _preloadManager = VideoPreloadManager(
      sourceBuilder: (index) => _preloadTargetForIndex(index),
    );
    _playbackCoordinator = ReelsPlaybackCoordinator(
      preloadManager: _preloadManager,
      targetForIndex: _preloadTargetForIndex,
      thumbnailUrlForIndex: (index) {
        final videos = controller.videoFeed.value.videos;
        if (videos == null || index < 0 || index >= videos.length) {
          return null;
        }
        return videos[index].resolvedReelPosterUrl;
      },
    );
    _reelsVisibilityWorker = ever(controller.isReelsTabVisible, (visible) {
      if (!visible) {
        MediaKitPlayerPool.instance.pauseAllImmediate();
        final key = _activePlayerVideo?.id;
        if (key != null && key.isNotEmpty) {
          unawaited(MediaKitPlayerPool.instance.release(key));
        }
        if (mounted) {
          setState(() {
            _activePlayerVideo = null;
          });
        }
        return;
      }
      _schedulePlayerForPage(_visibleIndexNotifier.value);
    });
    _restoreSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      MediaKitPlayerPool.instance.setScreenWidth(
        MediaQuery.sizeOf(context).width,
      );
      if (controller.isReelsTabVisible.value) {
        final index = _visibleIndexNotifier.value;
        _schedulePlayerForPage(index);
        unawaited(_preloadManager.warmIndexNow(index, maxWaitMs: 1200));
        _maybeBootstrapPreload();
      }
    });
  }

  void _maybeBootstrapPreload() {
    final videos = controller.videoFeed.value.videos;
    if (videos == null ||
        videos.isEmpty ||
        !controller.isReelsTabVisible.value) {
      return;
    }
    _playbackCoordinator.bootstrapFromVisible(_visibleIndexNotifier.value);
  }

  void _onPageScrollOffset() {
    if (!_pageController.hasClients || !mounted) {
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final length = videos.length;
    final page = _pageController.page;
    if (page == null) {
      return;
    }
    final rounded = page.roundToDouble();
    if ((page - rounded).abs() < 0.02) {
      _scrollTowardActualIndex = null;
      return;
    }
    final towardRaw = page > rounded ? page.ceil() : page.floor();
    final toward = towardRaw % length;
    if (_scrollTowardActualIndex == toward) {
      return;
    }
    _scrollTowardActualIndex = toward;
    _playbackCoordinator.onPageScrollToward(
      fromActualIndex: _visibleIndexNotifier.value,
      towardActualIndex: toward,
      context: context,
    );
  }

  bool _shouldListenFirestoreStats(int actualIndex) {
    final length = controller.videoFeed.value.videos?.length ?? 0;
    if (length == 0) {
      return false;
    }
    final visibleActual = _visibleIndexNotifier.value % length;
    return (actualIndex - visibleActual).abs() <= 1;
  }

  void _prefetchCommentCount(String videoId) {
    if (_commentCounts.containsKey(videoId)) {
      return;
    }
    FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .count()
        .get()
        .then((snap) {
          if (mounted) {
            setState(() => _commentCounts[videoId] = snap.count ?? 0);
          }
        })
        .catchError((_) {});
  }

  Widget _buildReelPoster(WallVideos videoDetail) {
    if (videoDetail.isImage == 1) {
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: videoDetail.resolvedPlaybackUrl ?? '',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (context, url, error) => const SizedBox(),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final (memW, memH) = fullScreenPosterMemCacheSize(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black,
              child: CachedNetworkImage(
                imageUrl: videoDetail.resolvedReelPosterUrl ?? '',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                memCacheWidth: memW,
                memCacheHeight: memH,
                errorWidget: (context, url, error) => const SizedBox(),
              ),
            ),
          ],
        );
      },
    );
  }

  VideoPreloadTarget? _preloadTargetForIndex(int index) {
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return null;
    }
    final length = videos.length;
    final actualIndex = ((index % length) + length) % length;
    final video = videos[actualIndex];
    final key = (video.id != null && video.id!.isNotEmpty)
        ? video.id!
        : (video.videoUrl?.isNotEmpty == true
            ? video.videoUrl!
            : video.video ?? '');
    if (key.isEmpty) {
      return null;
    }
    return VideoPreloadTarget(
      key: key,
      candidates: _sourceResolver.resolveForWallVideo(video),
    );
  }

  void _schedulePageSideEffects(int actualIndex) {
    unawaited(_reelPlayerKey.currentState?.syncAudibleIfNeeded());
    final videos = controller.videoFeed.value.videos;
    if (videos != null &&
        controller.videoFeed.value.meta?.hasMore != false &&
        actualIndex >= videos.length - 3) {
      unawaited(controller.fetchMoreVideos());
    }

    final videoId = videos != null && actualIndex < videos.length
        ? videos[actualIndex].id
        : null;
    if (videoId == null) {
      return;
    }

    _positionSaveThrottle?.cancel();
    _positionSaveThrottle = Timer(const Duration(milliseconds: 800), () {
      unawaited(
        _sessionStore.savePosition(videoId: videoId, index: actualIndex),
      );
    });

    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () {
      if (_trackedVideoIds.contains(videoId)) {
        return;
      }
      _trackedVideoIds.add(videoId);
      unawaited(
        _trackVideoView(
          videoId,
          userIdFromStorage.isNotEmpty ? userIdFromStorage : null,
          isAuthenticated,
        ),
      );
    });

    _prefetchCommentCount(videoId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_onPageScrollOffset);
    _feedRestoreWorker?.dispose();
    _reelsVisibilityWorker?.dispose();
    _viewTrackDebounce?.cancel();
    _positionSaveThrottle?.cancel();
    _visibleIndexNotifier.dispose();
    _playbackCoordinator.dispose();
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Generate a new device ID (you could also use UUID package)
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique device ID for Android
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor; // Unique device ID for iOS
      } else {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString(); // Fallback
      }
      await prefs.setString('device_id', deviceId!);
    }
    return deviceId;
  }

  // Updated _trackVideoView function to handle both user and device views
  Future<void> _trackVideoView(
    String videoId,
    String? userId,
    bool isAuthenticated,
  ) async {
    try {
      await VideoViewTracker.trackUniqueView(
        videoId: videoId,
        userId: userId,
        isAuthenticated: isAuthenticated,
      );
    } catch (e) {
      debugPrint('Error tracking video view: $e');
    }
  }

  void _scrollToNext() {
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onReelVideoCompleted() {
    if (!mounted || !controller.isReelsTabVisible.value) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !controller.isReelsTabVisible.value) {
        return;
      }
      _scrollToNext();
    });
  }

  void _scrollToPrevious() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Add a variable to store the last viewed index

  Future<void> _restoreSession() async {
    _pendingRestoreVideoId = await _sessionStore.readVideoId();
    _pendingRestoreIndex = await _sessionStore.readIndex();
  }

  void _applyPendingRestoreIfPossible() {
    if (_sessionRestored) {
      return;
    }
    if (_pendingRestoreVideoId == null) {
      _sessionRestored = true;
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final index = videos.indexWhere((item) => item.id == _pendingRestoreVideoId);
    final targetIndex = index == -1
        ? (_pendingRestoreIndex ?? 0).clamp(0, videos.length - 1)
        : index;
    if (targetIndex < 0 || targetIndex >= videos.length) {
      _sessionRestored = true;
      return;
    }
    _sessionRestored = true;
    unawaited(_restoreToIndex(targetIndex));
  }

  Future<void> _restoreToIndex(int targetIndex) async {
    await _preloadManager.warmIndexNow(targetIndex);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      if (_pageController.page?.round() != targetIndex) {
        _pageController.jumpToPage(targetIndex);
      }
      _visibleIndexNotifier.value = targetIndex;
      controller.visiblePageIndex.value = targetIndex;
      _schedulePlayerForPage(targetIndex);
      _maybeBootstrapPreload();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;
    bool isRtl = _language == 'ar';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),

      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (DragEndDetails details) {
          // Get available tab types based on settings
          List<String> availableTabs = [];

          if ((promoteVideoController
                      .siteSettings
                      .value
                      ?.settings
                      ?.allowGeneralVideos ??
                  0) ==
              1) {
            availableTabs.add("General");
          }
          availableTabs.add("Near Me");
          if ((promoteVideoController
                      .siteSettings
                      .value
                      ?.settings
                      ?.allowGeneralVideos ??
                  0) ==
              1) {
            availableTabs.add("Following");
          }

          if (availableTabs.isEmpty) return;

          // Get current tab index
          int currentIndex = availableTabs.indexOf(
            controller.selectedType.value,
          );
          if (currentIndex == -1) currentIndex = 0;

          // Determine swipe direction and calculate new index
          if (details.primaryVelocity! > 0) {
            // Swiped right - go to previous tab
            currentIndex =
                (currentIndex - 1 + availableTabs.length) %
                availableTabs.length;
          } else if (details.primaryVelocity! < 0) {
            // Swiped left - go to next tab
            currentIndex = (currentIndex + 1) % availableTabs.length;
          }

          String newTabType = availableTabs[currentIndex];

          // Handle authentication check for Following tab
          if (newTabType == "Following" && !isAuthenticated) {
            Get.toNamed(AppRoutes.signIn);
            return;
          }

          if (newTabType != controller.selectedType.value) {
            _switchFeedTab(newTabType);
          }
        },
        child: Stack(
            children: [
              Obx(() {
                final showSkeleton = controller.isLoading.value &&
                    (controller.videoFeed.value.videos?.isEmpty ?? true);
                if (!showSkeleton && !controller.blocksUiForLocation) {
                  return const SizedBox.shrink();
                }
                return const _ReelsSkeletonLoader();
              }),
              Obx(() {
                if (controller.isLoading.value ||
                    controller.blocksUiForLocation) {
                  return const SizedBox.shrink();
                }
                if (controller.videoFeed.value.videos == null ||
                    controller.videoFeed.value.videos!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      height: double.infinity,
                      width: double.infinity,
                      color: Colors.black,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            textAlign: TextAlign.center,
                            "${'no_video_for'.tr} ${controller.currentCity.value} ${'try_to_change'.tr}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (controller.selectedType.value == "Near Me")
                                Expanded(
                                  child: AppButton(
                                    text: "Change Location",
                                    onTap: () {
                                      _showBottomSheet(context);
                                    },
                                  ),
                                ),
                              SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Get.to(
                                    () => SearchView(
                                      isGeneral:
                                          controller.selectedType.value ==
                                                  "General"
                                              ? 1
                                              : 0,
                                    ),
                                  )?.then((_) {
                                    controller.fetchVideos(
                                      city: controller.currentCity.value,
                                      country: controller.currentCountry.value,
                                    );
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: ColorUtils.primaryColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        Icons.search,
                                        color: Colors.black,
                                        size: 24.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  controller.fetchVideos();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: ColorUtils.primaryColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        Icons.refresh,
                                        color: Colors.black,
                                        size: 24.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              Obx(() {
                if (controller.isLoading.value ||
                    controller.blocksUiForLocation ||
                    controller.videoFeed.value.videos == null ||
                    controller.videoFeed.value.videos!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final reelsActive = controller.isReelsTabVisible.value;
                return FocusDetector(
                    onFocusGained: () {
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(
                          controller.visiblePageIndex.value,
                        );
                      }
                      _schedulePlayerForPage(
                        controller.visiblePageIndex.value,
                      );
                      unawaited(
                        _reelPlayerKey.currentState?.syncAudibleIfNeeded(),
                      );
                    },
                    child: PageView.custom(
                      scrollDirection: Axis.vertical,
                      controller: _pageController,
                      clipBehavior: Clip.hardEdge,
                      dragStartBehavior: DragStartBehavior.down,
                      // allowImplicitScrolling kept off: with heavy video
                      // widgets it spawns extra decoders for off-screen pages,
                      // which is the dominant cause of swipe lag.
                      allowImplicitScrolling: false,
                      pageSnapping: true,
                      physics: const ClampingScrollPhysics(),
                      padEnds: false,
                      onPageChanged: (index) {
                        final length =
                            controller.videoFeed.value.videos?.length ?? 0;
                        if (length == 0) {
                          return;
                        }
                        final actualIndex = index % length;
                        final v = controller.videoFeed.value.videos![
                            actualIndex];
                        final incomingKey = v.id ?? '';
                        controller.visiblePageIndex.value = actualIndex;
                        _visibleIndexNotifier.value = actualIndex;
                        _schedulePlayerForPage(actualIndex);
                        if (incomingKey.isNotEmpty) {
                          MediaKitPlayerPool.instance.pauseAllImmediate(
                            exceptKey: incomingKey,
                          );
                          unawaited(
                            MediaKitPlayerPool.instance
                                .prepareVisiblePlayback(incomingKey),
                          );
                        } else {
                          MediaKitPlayerPool.instance.pauseAllImmediate();
                        }
                        MediaKitPlayerPool.instance.setScreenWidth(
                          MediaQuery.sizeOf(context).width,
                        );
                        _playbackCoordinator.onPageSettled(
                          actualIndex,
                          context: context,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          _schedulePageSideEffects(actualIndex);
                        });
                      },
                      childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (controller.videoFeed.value.videos == null ||
                              controller.videoFeed.value.videos!.isEmpty) {
                            return Container(
                              width: MediaQuery.sizeOf(context).width,
                              height: MediaQuery.sizeOf(context).height,
                              color: Colors.black,
                              child: const Center(
                                child: Text(
                                  'No videos available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          }

                          int actualIndex =
                              index % controller.videoFeed.value.videos!.length;
                          var videoDetail =
                              controller.videoFeed.value.videos![actualIndex];

                          return KeyedSubtree(
                            key: ValueKey<String>(
                              '${videoDetail.id ?? 'video'}_$index',
                            ),
                            child: ValueListenableBuilder<int>(
                              valueListenable: _visibleIndexNotifier,
                              builder: (context, visibleIndex, _) {
                                final isActiveReel =
                                    actualIndex == visibleIndex &&
                                    videoDetail.isImage != 1;
                                return Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomLeft,
                              children: [
                              _buildPagePoster(
                                videoDetail,
                                isActiveReel: isActiveReel,
                              ),
                              if (isActiveReel)
                                _buildInlineReelPlayer(videoDetail),
                              if (isActiveReel)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () {
                                      _reelPlayerKey.currentState
                                          ?.togglePlayPause();
                                    },
                                    onDoubleTapDown: (_) {
                                      unawaited(
                                        _onReelDoubleTapLike(videoDetail),
                                      );
                                    },
                                  ),
                                ),
                              VideoDescriptionWidget(
                                title: videoDetail.title,
                                description: videoDetail.description,
                                tags: videoDetail.tags,
                                controller: controller,
                              ),
                              videoUserDetails(
                                profileController: profileController,
                                professionalProfileController:
                                    professionalProfileController,
                                videoDetail: videoDetail,
                                controller: controller,
                                userId: userId,
                                isAuthenticated: isAuthenticated,
                              ),
                              videoActions(
                                videoDetail,
                                currentUserDetails,
                                currentUser,
                                isAuthenticated,
                                context,
                                listenLive: _shouldListenFirestoreStats(
                                  actualIndex,
                                ),
                              ),
                              Positioned(
                                top: MediaQuery.paddingOf(context).top + 64,
                                left: isRtl ? 0 : null,
                                right: isRtl ? null : 0,
                                child: GestureDetector(
                                  onTap: () {
                                    Get.to(
                                      () => SearchView(
                                        isGeneral:
                                            controller.selectedType.value ==
                                                    "General"
                                                ? 1
                                                : 0,
                                      ),
                                    )!.then((_) {
                                      controller.prepareForFeedTabSwitch();
                                      controller.fetchVideos(
                                        city: controller.currentCity.value,
                                        country:
                                            controller.currentCountry.value,
                                      );
                                    });
                                  },
                                  child: Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.search,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ],
                            );
                              },
                            ),
                          );
                        },
                        childCount:
                            controller.videoFeed.value.videos != null
                                ? controller.videoFeed.value.videos!.length
                                : 1,
                      ),
                    ),
                  );
              }),

              SafeArea(
                child: Obx(
                  () => Container(
                    margin: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            isAuthenticated
                                ? Get.to(JoinScreen())
                                : Get.toNamed(AppRoutes.signIn);
                          },
                          child: SvgPicture.asset(
                            "assets/icons/live.svg",
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if ((promoteVideoController
                                          .siteSettings
                                          .value
                                          ?.settings
                                          ?.allowGeneralVideos ??
                                      0) ==
                                  1)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _switchFeedTab('General');
                                    },
                                    child: Text(
                                      "General".tr,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            controller.selectedType.value ==
                                                    "General"
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                        fontWeight:
                                            controller.selectedType.value ==
                                                    "General"
                                                ? FontWeight.w500
                                                : FontWeight.w300,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    _switchFeedTab('Near Me');
                                  },
                                  child: Text(
                                    "Near Me".tr,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          controller.selectedType.value ==
                                                  "Near Me"
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.5),
                                      fontWeight:
                                          controller.selectedType.value ==
                                                  "Near Me"
                                              ? FontWeight.w500
                                              : FontWeight.w300,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              if ((promoteVideoController
                                          .siteSettings
                                          .value
                                          ?.settings
                                          ?.allowGeneralVideos ??
                                      0) ==
                                  1)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!isAuthenticated) {
                                        Get.toNamed(AppRoutes.signIn);
                                        return;
                                      }
                                      _switchFeedTab('Following');
                                    },
                                    child: Text(
                                      "Following".tr,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            controller.selectedType.value ==
                                                    "Following"
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                        fontWeight:
                                            controller.selectedType.value ==
                                                    "Following"
                                                ? FontWeight.w500
                                                : FontWeight.w300,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChatIconWithCounter(
                          userId: userId ?? '',
                          isAuthenticated: isAuthenticated,
                          onTap: () {
                            isAuthenticated
                                ? Get.to(
                                  ChatListScreen(userId: userIdFromStorage),
                                )?.then((_) {
                                  // controller.restoreVideoState();
                                })
                                : Get.toNamed(AppRoutes.signIn);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // Optional: Swipe indicator at the bottom
            ],
          ),
      ),
    );
  }

  String? selectedCountry;
  String? selectedCity;

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (BuildContext context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                color: Colors.white,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter'.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    InkWell(
                      onTap: () {
                        showLocationDialog(context);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 10),
                          Obx(
                            () => Text(
                              controller.currentCountry.value == ""
                                  ? 'Select Country'.tr
                                  : controller.currentCountry.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    SizedBox(height: 15),
                    InkWell(
                      onTap: () {
                        debugPrint(controller.currentCityId.value);
                        // Pass the initialCity ID to showCityDialog
                        showCityDialog(
                          context,
                          initialCity: int.parse(
                            controller.currentCityId.value,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 10),
                          Obx(
                            () => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              // Set your desired maximum width
                              child: Text(
                                controller.currentCity.value == ""
                                    ? 'Select City'.tr
                                    : controller.currentCity.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow:
                                    TextOverflow
                                        .ellipsis, // Show ellipsis if text exceeds maxWidth
                              ),
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Obx(() {
                      return AppButton(
                        isLoading: controller.isLoading.value,
                        text: "Submit".tr,
                        onTap: () {
                          controller.isLoading.value
                              ? null
                              : Navigator.pop(context);
                          controller.currentCity.value == ""
                              ? null
                              : controller
                                  .fetchVideos(
                                    city: controller.currentCity.value,
                                    country: controller.currentCountry.value,
                                  )
                                  .then((value) {
                                    controller.saveLocationData();
                                  });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Video widgets with details
  Positioned videoActions(
    WallVideos videoDetail,
    SimpleUser? currentUserDetails,
    User? currentUser,
    dynamic isAuthenticated,
    BuildContext context, {
    required bool listenLive,
  }) {
    return Positioned(
      right: 10,
      bottom: Platform.isAndroid ? Get.height * 0.02 : Get.height * 0.02,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: _buildReelActionsColumn(
                  videoDetail: videoDetail,
                  currentUserDetails: currentUserDetails,
                  currentUser: currentUser,
                  isAuthenticated: isAuthenticated,
                  context: context,
                  listenLive: listenLive,
                ),
              ),
            ),
          ),
          SizedBox(height: 8),

          if (videoDetail.sponsorType == null)
            if (videoDetail.frontUserId != currentUserDetails?.id)
              _buildReviewButton(
                videoDetail: videoDetail,
                currentUserDetails: currentUserDetails,
                currentUser: currentUser,
                isAuthenticated: isAuthenticated,
                context: context,
                listenLive: listenLive,
              ),
        ],
      ),
    );
  }

  Widget _buildReelActionsColumn({
    required WallVideos videoDetail,
    required SimpleUser? currentUserDetails,
    required User? currentUser,
    required dynamic isAuthenticated,
    required BuildContext context,
    required bool listenLive,
  }) {
    final videoId = videoDetail.id ?? '';
    Widget buildColumn(ReelVideoStats stats) {
      final likes = stats.likes;
      final userId = currentUserDetails?.id ?? currentUser?.id ?? '';
      final isLiked = likes.contains(userId);
      final commentCount = stats.commentCount > 0
          ? stats.commentCount
          : (_commentCounts[videoId] ?? 0);
      final formattedLikeCount = ReelVideoStats.formatCount(stats.likeCount);
      final formattedCommentCount = ReelVideoStats.formatCount(commentCount);
      final formattedViewCount = ReelVideoStats.formatCount(stats.viewCount);

      return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Simplified Like Button
                              InkWell(
                                onTap: () async {
                                  final String videoId = videoDetail.id!;
                                  String userId =
                                      currentUserDetails?.id ??
                                      currentUser!.id!;
                                  HapticFeedback.lightImpact();

                                  // Optimistic UI update
                                  final optimisticLikes = List<dynamic>.from(
                                    likes,
                                  );
                                  if (isLiked) {
                                    optimisticLikes.remove(userId);
                                  } else {
                                    optimisticLikes.add(userId);
                                  }
                                  await videoCommentsController.toggleVideoLike(
                                    videoId.toString(),
                                    userId.toString(),
                                  );
                                },
                                child: SizedBox(
                                  height: 20.h,
                                  width: 20.h,
                                  child: SvgPicture.asset(
                                    "assets/icons/heart.svg",
                                    fit: BoxFit.fill,
                                    color: isLiked ? Colors.red : Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              InkWell(
                                onTap: () {
                                  Get.to(
                                    VideoLikesScreen(videoId: videoDetail.id!),
                                  );
                                },
                                child: Text(
                                  formattedLikeCount,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: SvgPicture.asset(
                                  "assets/icons/eye.svg",
                                  fit: BoxFit.fill,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                formattedViewCount,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                ),
                              ),
                              // Comment Button
                              if (videoDetail.allowComments == 1) ...[
                                SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    if (!isAuthenticated) {
                                      Get.toNamed(AppRoutes.signIn);
                                      return;
                                    }
                                    // controller.pauseCurrentVideo();
                                    String? userId =
                                        currentUserDetails?.id ??
                                        currentUser!.id;
                                    String? userImage =
                                        currentUserDetails?.image ??
                                        currentUser?.image ??
                                        "";
                                    showCommentsBottomSheetNew(
                                      context,
                                      videoDetail.id!,
                                      userId!,
                                      userImage!,
                                    );

                                    if (mounted) {
                                      // controller.restoreVideoState();
                                    }
                                  },
                                  child: SizedBox(
                                    height: 20.h,
                                    width: 20.h,
                                    child: SvgPicture.asset(
                                      "assets/icons/comment.svg",
                                      fit: BoxFit.fill,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  formattedCommentCount,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                ),
                                SizedBox(height: 8),
                              ],
                              // Static Buttons (Share, Save, More)
                              _buildStaticButtons(
                                videoDetail,
                                currentUserDetails?.id ?? currentUser?.id ?? '',
                                context,
                              ),

                              if (videoDetail.takeOrder == 1 &&
                                  (videoDetail.contactPhone?.isNotEmpty ==
                                          true ||
                                      videoDetail.contactEmail?.isNotEmpty ==
                                          true ||
                                      videoDetail.latitude?.isNotEmpty == true))
                                Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      width: 40,
                                      height: 1,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        if (!isAuthenticated) {
                                          Get.toNamed(AppRoutes.signIn);
                                          return;
                                        }
                                        final businessId =
                                            videoDetail.frontUserId.toString();
                                        final firestore =
                                            FirebaseFirestore.instance;
                                        final docRef = firestore
                                            .collection('countContactClick')
                                            .doc(videoDetail.id);

                                        firestore.runTransaction((
                                          transaction,
                                        ) async {
                                          final docSnapshot = await transaction
                                              .get(docRef);
                                          if (!docSnapshot.exists) {
                                            transaction.set(docRef, {
                                              'businessId':
                                                  videoDetail.frontUserId,
                                              'videoId': videoDetail.id,
                                              'totalClicks': 1,
                                              'userIds': [
                                                currentUserDetails!.id,
                                              ],
                                            });
                                          } else {
                                            final data = docSnapshot.data()!;
                                            final userIds = List<String>.from(
                                              data['userIds'] ?? [],
                                            );
                                            if (!userIds.contains(
                                              currentUserDetails!.id,
                                            )) {
                                              transaction.update(docRef, {
                                                'totalClicks':
                                                    FieldValue.increment(1),
                                                'userIds':
                                                    FieldValue.arrayUnion([
                                                      currentUserDetails.id,
                                                    ]),
                                              });
                                            }
                                          }
                                        });

                                        // controller.pauseCurrentVideo();
                                        showContactNowDialog(
                                          context,
                                          website: videoDetail.website ?? "",
                                          phoneNumber:
                                              videoDetail.contactPhone ?? "",
                                          latitude: videoDetail.latitude ?? "",
                                          longitude:
                                              videoDetail.longitude ?? "",
                                          email: videoDetail.contactEmail ?? "",
                                          videoId: videoDetail.id.toString(),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ColorUtils.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SvgPicture.asset(
                                          "assets/icons/contact.svg",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          );
    }

    if (!listenLive || videoId.isEmpty) {
      return buildColumn(ReelVideoStats.empty);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        return buildColumn(ReelVideoStats.fromDoc(snapshot.data));
      },
    );
  }

  Widget _buildReviewButton({
    required WallVideos videoDetail,
    required SimpleUser? currentUserDetails,
    required User? currentUser,
    required dynamic isAuthenticated,
    required BuildContext context,
    required bool listenLive,
  }) {
    final videoId = videoDetail.id ?? '';
    Widget ratingLabel(double rating) {
      final label = rating > 0 ? rating.toStringAsFixed(1) : '0.0';
      return Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
      );
    }

    Widget buttonChild(Widget ratingWidget) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(50),
            ),
            child: InkWell(
              onTap: () {
                if (!isAuthenticated) {
                  Get.toNamed(AppRoutes.signIn);
                  return;
                }
                final userId = currentUserDetails?.id ?? currentUser!.id;
                final userImage =
                    currentUserDetails?.image ?? currentUser?.image ?? '';
                showReviewsBottomSheet(
                  context,
                  videoDetail.id!,
                  userId!,
                  userImage,
                );
              },
              child: Column(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.amberAccent,
                    size: 40,
                  ),
                  ratingWidget,
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!listenLive || videoId.isEmpty) {
      return buttonChild(ratingLabel(0));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        final stats = ReelVideoStats.fromDoc(snapshot.data);
        return buttonChild(ratingLabel(stats.averageRating));
      },
    );
  }

  // Helper method for static buttons to avoid rebuilding
  Widget _buildStaticButtons(
    WallVideos videoDetail,
    String loggedInUserId,
    BuildContext context,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share Button
        Column(
          children: [
            InkWell(
              onTap: () => _handleShare(videoDetail),
              child: SizedBox(
                height: 20.h,
                width: 20.h,
                child: SvgPicture.asset(
                  "assets/icons/share.svg",
                  fit: BoxFit.fill,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 2),
            Text(
              "share".tr,
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
            SizedBox(height: 8),
          ],
        ),

        // Save Button
        videoDetail.sponsorType == null
            ? Obx(() {
              // Check if video is already saved
              bool isSaved = saveController.savedVideos.any(
                (video) => video.id.toString() == videoDetail.id,
              );

              return Column(
                children: [
                  InkWell(
                    onTap: () async {
                      if (isAuthenticated) {
                        if (isSaved) {
                          // 1. Immediately remove from local list
                          saveController.savedVideos.removeWhere(
                            (video) =>
                                video.id.toString() ==
                                videoDetail.id.toString(),
                          );

                          // 2. Then hit API
                          await saveController.saveVideo(videoDetail.id!);
                        } else {
                          // 1. Immediately add to local list
                          saveController.savedVideos.add(
                            SavedVideos(
                              id: videoDetail.id,
                              title: videoDetail.title,
                              // Add other fields if needed, or just id is fine for now
                            ),
                          );

                          // 2. Then hit API
                          await saveController.saveVideo(videoDetail.id!);
                        }
                      } else {
                        Get.toNamed(AppRoutes.signIn);
                      }
                    },
                    child: SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: SvgPicture.asset(
                        "assets/icons/bookmark.svg",
                        fit: BoxFit.fill,
                        color: isSaved ? ColorUtils.primaryColor : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Save".tr,
                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                  ),
                  SizedBox(height: 8),
                ],
              );
            })
            : SizedBox.shrink(),

        // SizedBox(height: 16),
        // More Button
        if (videoDetail.frontUserId != loggedInUserId)
          Column(
            children: [
              InkWell(
                onTap: () {
                  // controller.pauseCurrentVideo();
                  if (isAuthenticated) {
                    _showMoreOptions(
                      context,
                      videoDetail.id!,
                      videoDetail.frontUserId!,
                      loggedInUserId,
                    );

                    if (mounted) {
                      // controller.restoreVideoState();
                    }
                  } else {
                    Get.toNamed(AppRoutes.signIn);
                  }
                },
                child: SizedBox(
                  height: 20.h,
                  width: 20.h,
                  child: SvgPicture.asset(
                    "assets/icons/more.svg",
                    fit: BoxFit.fill,
                    color: Colors.white,
                  ),
                ),
              ),
              // SizedBox(height: 2),
              Text(
                "more".tr,
                style: TextStyle(color: Colors.white, fontSize: 10.sp),
              ),
            ],
          ),
      ],
    );
  }

  void _handleShare(WallVideos videoDetail) async {
    // _handleScreenExit();
    try {
      final String videoId = videoDetail.id!;
      final String appUrl = "cookster://open.cookster.app/video?id=$videoId";
      final String webUrl =
          "https://cookster.org/web/visitSingleVideo?id=$videoId";
      final String shareMessage =
          'Check out this amazing video on Cookster!\n$appUrl\n\nIf the app does not open, use this web link:\n$webUrl';
      await Share.share(shareMessage, subject: 'Cookster Video');
    } catch (e) {
      debugPrint('Error sharing video: $e');
      Get.snackbar(
        'Error',
        'Could not share this video',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      // controller.restoreVideoState();
    }
  }

  void _showMoreOptions(
    BuildContext context,
    String videoId,
    String frontUserId,
    String userId,
  ) {
    // final PromoteVideoController promoteVideoController = Get.find();

    var infoEmail = promoteVideoController.siteSettings.value?.settings?.email;
    // _handleScreenExit();
    // controller.pauseCurrentVideo();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
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

                ListTile(
                  leading: Icon(Icons.block, color: ColorUtils.grey),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.grey,
                  ),
                  title: Text(
                    'block_user'.tr,
                    style: TextStyle(color: Colors.black, fontSize: 14.sp),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // controller.pauseCurrentVideo();
                    controller.blockUser(userId, frontUserId);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.flag_outlined, color: ColorUtils.grey),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.grey,
                  ),
                  title: Text(
                    'report-content'.tr,
                    style: TextStyle(color: Colors.black, fontSize: 14.sp),
                  ),
                  onTap: () {
                    debugPrint("THis is the report video id:$videoId");
                    Navigator.pop(context);
                    // controller.pauseCurrentVideo();
                    Get.to(ReportContentView(videoId: videoId))?.then((_) {
                      // controller.restoreVideoState();
                    });
                  },
                ),
                // ListTile(
                //   leading: Icon(Icons.headphones, color: ColorUtils.grey),
                //   trailing: Text(
                //     infoEmail!,
                //     style: TextStyle(color: Colors.black, fontSize: 14.sp),
                //   ),
                //   title: Text(
                //     'contact_us'.tr,
                //     style: TextStyle(color: Colors.black, fontSize: 14.sp),
                //   ),
                //   onTap: () async {
                //     final Uri emailUri = Uri(
                //       scheme: 'mailto',
                //       path: infoEmail,
                //       queryParameters: {
                //         'subject': 'Contact Us',
                //         // Optional: Pre-fill subject
                //         // 'body': 'Your message here', // Optional: Pre-fill body
                //       },
                //     );
                //
                //     // Launch the mail app
                //     if (await canLaunchUrl(emailUri)) {
                //       await launchUrl(emailUri);
                //     } else {
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(content: Text('No email app found')),
                //       );
                //     }
                //     Navigator.pop(context);
                //   },
                // ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReelsSkeletonLoader extends StatelessWidget {
  const _ReelsSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
    );
  }
}

class videoUserDetails extends StatelessWidget {
  const videoUserDetails({
    super.key,
    required this.profileController,
    required this.professionalProfileController,
    required this.videoDetail,
    required this.controller,
    required this.userId,
    required this.isAuthenticated,
  });

  final ProfileController profileController;
  final ProfessionalProfileController professionalProfileController;
  final WallVideos videoDetail;
  final HomeController controller;
  final String? userId;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    final overlayTop = MediaQuery.paddingOf(context).top + 64;
    return Positioned(
      top: overlayTop,
      left: 10,
      right: 10,
      child: SizedBox(
        width: Get.width * 1,
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth:
                    Get.width * 0.72, // Maximum width for the entire container
              ),
              decoration: BoxDecoration(
                color: Colors.transparent, // Transparent to show blur
                borderRadius: BorderRadius.circular(50),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Obx(() {
                      var currentUserDetails =
                          profileController.simpleUserDetails.value?.user;
                      var currentUser =
                          professionalProfileController.userDetails.value?.user;
                      bool isProfileNull = currentUser == null;
                      bool isFollowing =
                          isProfileNull
                              ? profileController.isFollowing(
                                videoDetail.frontUserId!,
                              )
                              : professionalProfileController.isFollowing(
                                videoDetail.frontUserId!,
                              );

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        // Adjust width to content
                        children: [
                          InkWell(
                            onTap: () {
                              unawaited(
                                Get.to(
                                  () => VisitProfileView(
                                    userId: videoDetail.frontUserId!,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 16.r,
                                    backgroundImage:
                                        videoDetail.userImage != null &&
                                                videoDetail
                                                    .userImage!
                                                    .isNotEmpty
                                            ? CachedNetworkImageProvider(
                                              videoDetail
                                                      .resolvedUserAvatarUrl ??
                                                  '',
                                            )
                                            : null,
                                    child:
                                        videoDetail.userImage == null ||
                                                videoDetail.userImage!.isEmpty
                                            ? Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            )
                                            : null,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            Get.width *
                                            0.3, // Max width for username
                                      ),
                                      child: Text(
                                        videoDetail.userName ?? 'Unknown User',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow:
                                            TextOverflow
                                                .ellipsis, // Ellipsis for overflow
                                      ),
                                    ),
                                    videoDetail.sponsorType != null
                                        ? Text(
                                          "Sponsored",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                        : Text(
                                          "${videoDetail.displayFollowersCount} ${"Followers".tr}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),

                          if (userId != videoDetail.frontUserId &&
                              videoDetail.sponsorType == null)
                            InkWell(
                              onTap: () async {
                                // Prevent multiple taps
                                if (_isProcessingFollow) return;

                                if (isAuthenticated) {
                                  _isProcessingFollow =
                                      true; // Set processing flag

                                  bool wasFollowing = isFollowing;
                                  String targetUserId =
                                      videoDetail.frontUserId!;

                                  try {
                                    if (isProfileNull) {
                                      await profileController
                                          .toggleFollowStatus(targetUserId);
                                    } else {
                                      await professionalProfileController
                                          .toggleFollowStatus(targetUserId);
                                    }

                                    // Update follower count for all videos of this user
                                    updateFollowerCountForUser(
                                      targetUserId,
                                      !wasFollowing,
                                      controller,
                                    );

                                    // Trigger UI update based on your state management
                                    // For GetX: controller.update();
                                  } catch (e) {
                                    // Handle error - maybe revert the changes if API call fails
                                    debugPrint('Error toggling follow status: $e');
                                    // You might want to show a snackbar or toast here

                                    // Revert the follower count changes on error
                                    updateFollowerCountForUser(
                                      targetUserId,
                                      wasFollowing, // Revert to original state
                                      controller,
                                    );
                                  } finally {
                                    _isProcessingFollow =
                                        false; // Reset processing flag
                                  }
                                } else {
                                  Get.toNamed(AppRoutes.signIn);
                                }
                              },
                              child: Container(
                                height: 25,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white),
                                  color:
                                      isFollowing ? Colors.white : Colors.black,
                                ),
                                child: Center(
                                  child:
                                      _isProcessingFollow
                                          ? SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    isFollowing
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                            ),
                                          )
                                          : Text(
                                            isFollowing
                                                ? "Following".tr
                                                : "follow".tr,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  isFollowing
                                                      ? Colors.black
                                                      : Colors.white,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isProcessingFollow = false;

// Helper method to update follower count across all videos
void updateFollowerCountForUser(
  String frontUserId,
  bool isFollowing,
  dynamic controller,
) {
  int countChange = isFollowing ? 1 : -1;

  for (int i = 0; i < controller.videoFeed.value.videos!.length; i++) {
    if (controller.videoFeed.value.videos![i].frontUserId == frontUserId) {
      controller.videoFeed.value.videos![i].followersCount =
          (controller.videoFeed.value.videos![i].followersCount ?? 0) +
          countChange;

      // Ensure follower count doesn't go below 0
      if (controller.videoFeed.value.videos![i].followersCount! < 0) {
        controller.videoFeed.value.videos![i].followersCount = 0;
      }
    }
  }
}

void showLocationDialog(BuildContext context) {
  final HomeController homeController = Get.find();
  final VideoAddController controller = Get.find();
  final NavBarController profileController = Get.find();
  final UserSearchController searchUpdateController = Get.find();
  final CityController cityController = Get.put(CityController());

  Map<String, int> countryMap = {};
  List<String> countryName =
      profileController.videoUploadSettings.value!.countries!.map((country) {
        countryMap[country.name!] = country.id!;
        return country.name!;
      }).toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;
  RxString selectedCountryName =
      (controller.selectedCountry.value.isNotEmpty
              ? controller.selectedCountry.value
              : '')
          .obs;

  // Filter countries based on search input
  void filterCountries(String query) {
    if (query.isEmpty) {
      filteredCountryName.value = countryName;
    } else {
      filteredCountryName.value =
          countryName
              .where(
                (country) =>
                    country.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
    // Get.back();
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 360.w,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Header (Title + Close Button)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.black),
                    SizedBox(width: 8.w),
                    Text(
                      "select_country_dialog_label".tr,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'search_country_placeholder'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: (value) => filterCountries(value),
            ),
            SizedBox(height: 10.h),

            /// Scrollable Location List
            Container(
              height: 220.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCountryName.length,
                      (index) => Column(
                        children: [
                          InkWell(
                            onTap: () {
                              selectedCountryName.value =
                                  filteredCountryName[index];
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 260.w,
                                    ),
                                    child: Text(
                                      filteredCountryName[index],
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight:
                                            selectedCountryName.value ==
                                                    filteredCountryName[index]
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 20.w,
                                    height: 20.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ColorUtils.primaryColor,
                                        width: 2.r,
                                      ),
                                      color:
                                          selectedCountryName.value ==
                                                  filteredCountryName[index]
                                              ? ColorUtils.primaryColor
                                              : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < filteredCountryName.length - 1)
                            Divider(
                              height: 1.h,
                              thickness: 1.r,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 5.h),

            /// Submit Button
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCountryName.value.isNotEmpty
                        ? () async {
                          try {
                            homeController.isLoading.value = true;
                            Get.back(); // Close the country dialog

                            String country = selectedCountryName.value;
                            controller.selectLocation(
                              country,
                              countryMap[country]!,
                            );
                            searchUpdateController.currentCountry.value =
                                country;
                            await cityController.fetchCities(
                              countryMap[country]!,
                            );
                            homeController.currentCountry.value = country;
                            homeController.isLoading.value = false;

                            showCityDialog(context);
                          } catch (e) {
                            debugPrint('Error selecting country: $e');
                            Get.snackbar('Error', 'Failed to load cities');
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  "Submit".tr,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showCityDialog(BuildContext context, {int? initialCity}) {
  final VideoAddController controller = Get.find();
  final CityController cityController = Get.find<CityController>();
  final UserSearchController homeController = Get.find();
  final HomeController homeUpdateController = Get.find();

  // Assuming City model has id and name properties
  List<Map<String, dynamic>> cityList =
      cityController.cityList
          .map((city) => {'id': city.id, 'name': city.name})
          .toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<Map<String, dynamic>> filteredCityList = cityList.obs;
  Rx<Map<String, dynamic>> selectedCity = Rx<Map<String, dynamic>>(
    controller.selectedCity.value.isNotEmpty
        ? {
          'id':
              cityList.firstWhere(
                (city) => city['name'] == controller.selectedCity.value,
                orElse: () => {'id': -1, 'name': ''},
              )['id'],
          'name': controller.selectedCity.value,
        }
        : {'id': -1, 'name': ''},
  );

  // Pre-select city if initialCity is provided
  if (initialCity != null) {
    Map<String, dynamic> initialCityData = cityList.firstWhere(
      (city) => city['id'] == initialCity,
      orElse: () => {'id': -1, 'name': ''},
    );
    if (initialCityData['name'].isNotEmpty) {
      selectedCity.value = initialCityData;
    }
  }

  // Filter cities based on search input
  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityList.value = cityList;
    } else {
      filteredCityList.value =
          cityList
              .where(
                (city) =>
                    city['name'].toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Obx(
        () => Container(
          width: 350.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child:
              cityController.isLoading.value
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// **Header (Title + Close Button)**
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.black),
                              SizedBox(width: 8.w),
                              Text(
                                "Select City".tr,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => Get.back(),
                            child: Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      /// **Search Field**
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'search_city_placeholder'.tr,
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(
                              color: ColorUtils.primaryColor,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10.h,
                            horizontal: 12.w,
                          ),
                        ),
                        onChanged: (value) => filterCities(value),
                      ),
                      SizedBox(height: 10.h),

                      /// **Scrollable Location List**
                      Container(
                        height: 230.h,
                        child: SingleChildScrollView(
                          child: Obx(
                            () => Column(
                              children: List.generate(filteredCityList.length, (
                                index,
                              ) {
                                var city = filteredCityList[index];
                                bool isSelected =
                                    selectedCity.value['id'] == city['id'] &&
                                    selectedCity.value['name'] == city['name'];

                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        selectedCity.value = city;
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: 200.w,
                                              ),
                                              child: Text(
                                                city['name'],
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 20.w,
                                              height: 20.w,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      ColorUtils.primaryColor,
                                                  width: 2,
                                                ),
                                                color:
                                                    isSelected
                                                        ? ColorUtils
                                                            .primaryColor
                                                        : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (index < filteredCityList.length - 1)
                                      Divider(
                                        height: 1.h,
                                        thickness: 1.r,
                                        color: Colors.grey.shade300,
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5.h),

                      /// **Submit Button**
                      Obx(
                        () => ElevatedButton(
                          onPressed:
                              selectedCity.value['name'].isNotEmpty
                                  ? () {
                                    try {
                                      int selectedId = selectedCity.value['id'];
                                      String selectedName =
                                          selectedCity.value['name'];
                                      debugPrint(
                                        "Selected City: $selectedName (ID: $selectedId)",
                                      );

                                      homeUpdateController.currentCityId.value =
                                          selectedId.toString();
                                      homeController.currentCity.value =
                                          selectedName;
                                      homeController.currentCityId.value =
                                          selectedId.toString();
                                      homeUpdateController.currentCity.value =
                                          selectedName;
                                      controller.selectedCity.value =
                                          selectedName;
                                      Get.back(); // Close the city dialog
                                    } catch (e) {
                                      debugPrint('Error selecting city: $e');
                                      Get.snackbar(
                                        'Error',
                                        'Failed to select city',
                                      );
                                    }
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            minimumSize: Size(double.infinity, 44.h),
                          ),
                          child: Text(
                            "Submit".tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    ),
  );
}

class VideoDescriptionWidget extends StatefulWidget {
  final String? title;
  final String? description;
  final String? tags;
  final HomeController? controller;

  const VideoDescriptionWidget({
    this.title,
    this.description,
    this.tags,
    this.controller,
    super.key,
  });

  @override
  _VideoDescriptionWidgetState createState() => _VideoDescriptionWidgetState();
}

class _VideoDescriptionWidgetState extends State<VideoDescriptionWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _hasOverflow = false;
  bool _isTagExpanded = false;
  bool _hasTagOverflow = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light, // White icons ke liye
        statusBarColor:
            Colors.transparent, // Optional: Status bar background color
      ),
    );
    if (widget.description != null) {
      _textController.text = widget.description!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflowOnce();
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light, // White icons ke liye
            statusBarColor:
                Colors.transparent, // Optional: Status bar background color
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _checkOverflowOnce() {
    final descriptionStyle = TextStyle(color: Colors.white, fontSize: 14.sp);
    final tagStyle = TextStyle(color: ColorUtils.primaryColor, fontSize: 12.sp);

    const double maxDescriptionWidth = 250.0;
    const double maxTagWidth = 250.0;

    // Check description overflow
    final TextPainter descPainter = TextPainter(
      text: TextSpan(text: widget.description, style: descriptionStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxDescriptionWidth);

    // Check tag overflow
    final String tagLine =
        widget.tags?.split(',').map((t) => '#${t.trim()}').join(' ') ?? '';
    final TextPainter tagPainter = TextPainter(
      text: TextSpan(text: tagLine, style: tagStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTagWidth);

    if (mounted) {
      setState(() {
        _hasOverflow = descPainter.didExceedMaxLines;
        _hasTagOverflow = tagPainter.didExceedMaxLines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = TextStyle(color: Colors.white, fontSize: 14.sp);
    final tagStyle = TextStyle(color: ColorUtils.primaryColor, fontSize: 12.sp);

    return Positioned(
      bottom: Platform.isAndroid ? Get.height * 0.03 : Get.height * 0.03,
      left: 10,
      child: Container(
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            if (widget.title != null && widget.title!.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 150),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (widget.title != null && widget.title!.isNotEmpty)
              SizedBox(height: 4.h),

            // Description with expand/collapse
            if (widget.description != null && widget.description!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 250),
                      child: Text(
                        widget.description!,
                        style: descriptionStyle,
                        maxLines: _isExpanded ? null : 1,
                        overflow:
                            _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_hasOverflow)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isExpanded ? "show_less".tr : "show_more".tr,
                          style: TextStyle(
                            color: ColorUtils.primaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            if (widget.description != null && widget.description!.isNotEmpty)
              SizedBox(height: 4.h),

            // Tags with expand/collapse and tap functionality
            if (widget.tags != null && widget.tags!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 250),
                      child: RichText(
                        maxLines: _isTagExpanded ? null : 1,
                        overflow:
                            _isTagExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                        text: TextSpan(
                          children:
                              widget.tags!.split(',').map((tag) {
                                final trimmedTag = tag.trim();
                                return TextSpan(
                                  text: '#$trimmedTag ',
                                  style: tagStyle,
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          // widget.controller
                                          //     ?.pauseCurrentVideo();

                                          Get.to(
                                            () => HashtagReelScreen(
                                              tag: trimmedTag,
                                            ),
                                          );
                                        },
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_hasTagOverflow)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTagExpanded = !_isTagExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isTagExpanded ? "show_less".tr : "show_more".tr,
                          style: TextStyle(
                            color: ColorUtils.primaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              Text("#", style: tagStyle),
          ],
        ),
      ),
    );
  }
}
