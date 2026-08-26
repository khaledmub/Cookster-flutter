import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/core/format/near_me_geo_format.dart';
import 'package:cookster/core/text/hashtag_text.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/reel_page_keep_alive.dart';
import 'package:cookster/core/widgets/reel_action_rail.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/core/widgets/feed_hub_menu.dart';
import 'package:cookster/core/widgets/tiktok_feed_chrome.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/reel_screen_playback_helpers.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/core/video/video_preload_target.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
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
import '../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../../../search/searchController/searchController.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import '../../../../video_likes_screen/video_likes_screen.dart';
import '../../../../../services/reels/reels_session_store.dart';
import '../../../../../services/settings/settings_service.dart';
import '../../add/videoAddController/videoAddController.dart';
import '../homeController/addCommentControllr.dart';
import '../homeController/homeController.dart';
import '../homeWidgets/contactNowDialog.dart';
import '../homeWidgets/reviewSheet.dart';
import '../homeWidgets/reel_feed_player_kit.dart';
import '../homeWidgets/reel_video_player.dart';
import 'hashtagReelScreen.dart';

class _FeedTabLayer {
  _FeedTabLayer({required int initialIndex})
      : visibleIndexNotifier = ValueNotifier<int>(initialIndex),
        pageController = PageController(initialPage: initialIndex);

  final PageController pageController;
  final ValueNotifier<int> visibleIndexNotifier;
  WallVideos? activePlayerVideo;
  int? scrollTowardActualIndex;
  int? demuxAheadFiredFor;
  double? lastScrollPage;
  DateTime? lastScrollSampleAt;

  void dispose() {
    pageController.dispose();
    visibleIndexNotifier.dispose();
  }
}

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

  @override
  bool get wantKeepAlive => true;

  bool _showIcon = false;
  bool isAuthenticated = false;
  final GlobalKey _headerHubKey = GlobalKey();
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
  final Map<String, _FeedTabLayer> _tabLayers = {};
  final Map<String, VoidCallback> _pageScrollListeners = {};
  Worker? _feedRestoreWorker;
  Worker? _feedPlaybackEpochWorker;
  Worker? _reelsVisibilityWorker;
  bool _pendingFeedTabPlayback = false;
  bool _feedTabSwitchInFlight = false;
  bool _suppressFocusPlayback = false;
  Timer? _playbackAttachDebounce;
  int _lastHandledPlaybackEpoch = -1;
  /// Serializes async player schedule after awaits (photo clear / tab race).
  int _playerScheduleEpoch = 0;
  final Map<String, int> _commentCounts = {};

  /// Soft handle for the mounted feed player — never [GlobalKey]. Capture /
  /// upload unmounts the player; GlobalKey reactivation of a disposed State
  /// crashed with StatefulElement.activate null-check.
  ReelVideoPlayerState? _feedPlayerState;

  void _onFeedPlayerStateChanged(ReelVideoPlayerState? state) {
    // Ignore dispose(null): a recycled player initState may have already
    // registered; clearing here caused attach_give_up while playback still
    // started via ReelVideoPlayer's own switch path.
    if (state == null || !mounted) {
      return;
    }
    _feedPlayerState = state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _feedTabSwitchInFlight) {
        return;
      }
      final layer = _activeLayer;
      if (layer.activePlayerVideo == null) {
        _kickColdStartPlaybackIfReady();
        return;
      }
      _attachScheduledFeedPlayer(
        epoch: _playerScheduleEpoch,
        forceReattach: false,
      );
    });
  }

  /// Opens the visible feed reel once [ReelVideoPlayer] is mounted. Retries when
  /// the widget tree has not built the player yet (common on first iOS open).
  void _attachScheduledFeedPlayer({
    required int epoch,
    required bool forceReattach,
    int attempt = 0,
  }) {
    if (epoch != _playerScheduleEpoch ||
        !mounted ||
        !controller.canPlayHomeReels) {
      return;
    }
    final layer = _activeLayer;
    final video = layer.activePlayerVideo;
    if (video == null || video.isPhotoPost) {
      return;
    }
    final key = video.id;
    if (key == null || key.isEmpty) {
      return;
    }
    final playerState = _feedPlayerState;
    // Tab switch remounts the IndexedStack player — dispose leaves a stale
    // State handle briefly. Treat !mounted as "not ready" and retry.
    if (playerState == null || !playerState.mounted) {
      if (playerState != null && !playerState.mounted) {
        _feedPlayerState = null;
      }
      if (attempt >= 45) {
        if (kDebugMode) {
          debugPrint(
            '[FeedRestore] attach_give_up id=$key attempts=$attempt '
            '(player not mounted yet)',
          );
        }
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) {
            return;
          }
          _kickColdStartPlaybackIfReady();
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _attachScheduledFeedPlayer(
          epoch: epoch,
          forceReattach: forceReattach,
          attempt: attempt + 1,
        );
      });
      return;
    }
    final needsReattach = forceReattach;
    final poolMismatch = !MediaKitPlayerPool.instance.isFeedVisibleKey(key);
    if (!needsReattach && !poolMismatch) {
      if (MediaKitPlayerPool.instance.isFrameReady(key) &&
          !MediaKitPlayerPool.instance.isActiveAudible(key)) {
        _resumeFeedAudibleOnce();
      }
      return;
    }
    if (!MediaKitPlayerPool.instance.isFeedVisibleKey(key) &&
        !MediaKitPlayerPool.instance.isFrameReady(key) &&
        !MediaKitPlayerPool.instance.hadRecentPaint(key)) {
      MediaKitPlayerPool.instance.invalidatePrimedFrame(key);
    }
    if (!MediaKitPlayerPool.instance.isFeedVisibleKey(key)) {
      unawaited(playerState.ensureVisibleOpen());
    } else if (needsReattach) {
      unawaited(playerState.resumeAfterRouteOverlay());
    }
  }

  /// Page poster stays above the video surface until the first composited frame.
  bool _maskActiveVideoWithPoster = true;

  /// Reel the poster was actually dropped for. A page cell can flip its own
  /// `showPlayer` on before this screen re-arms [_maskActiveVideoWithPoster],
  /// and on unconstrained devices (tier S — every modern iPhone) the video
  /// surface is also held at opacity 0 until it paints. Both layers invisible
  /// means the black scaffold shows through for the whole open. Keying the
  /// unmask to a reel id makes a stale `false` harmless.
  String? _unmaskedReelId;

  /// Debug-only dedupe so [ReelsBlank] logs transitions, not every frame.
  String? _lastPosterLayerLog;

  void _armPosterMask() {
    if (!mounted || (_maskActiveVideoWithPoster && _unmaskedReelId == null)) {
      return;
    }
    setState(() {
      _maskActiveVideoWithPoster = true;
      _unmaskedReelId = null;
    });
  }

  void _dropPosterMask(String? reelId) {
    // Never clear the mask with an unknown id — that left
    // `_maskActiveVideoWithPoster=false` + `_unmaskedReelId=null`, so every
    // page kept painting the poster on top of a playing surface.
    if (!mounted || reelId == null || reelId.isEmpty) {
      return;
    }
    if (!_maskActiveVideoWithPoster && _unmaskedReelId == reelId) {
      return;
    }
    setState(() {
      _maskActiveVideoWithPoster = false;
      _unmaskedReelId = reelId;
    });
  }

  /// First Home open: keep the black spinner over the feed until the first
  /// reel is actually playable — never clear on a transient empty list (Near Me
  /// waits for location, then videos arrive ~seconds later).
  bool _holdColdStartSpinner = true;
  bool _firstPlayableReelReady = false;
  Timer? _coldStartSpinnerTimeout;
  bool _coldStartTimeoutArmed = false;

  Completer<void>? _tabSwitchFrameCompleter;
  String? _tabSwitchTargetVideoId;

  String get _activeTabType => controller.selectedType.value;

  _FeedTabLayer _layerFor(String tab) {
    return _tabLayers.putIfAbsent(tab, () {
      final cached = controller.cachedVideosForTab(tab);
      final initialIndex = cached != null && cached.isNotEmpty
          ? controller.resolveScrollIndexForTab(tab, cached)
          : controller.scrollIndexForTab(tab);
      return _FeedTabLayer(initialIndex: initialIndex);
    });
  }

  _FeedTabLayer get _activeLayer => _layerFor(_activeTabType);

  List<String> _availableFeedTabs() {
    final tabs = <String>[];
    if ((promoteVideoController
                .siteSettings
                .value
                ?.settings
                ?.allowGeneralVideos ??
            0) ==
        1) {
      tabs.add('General');
    }
    tabs.add('Near Me');
    if ((promoteVideoController
                .siteSettings
                .value
                ?.settings
                ?.allowGeneralVideos ??
            0) ==
        1) {
      tabs.add('Following');
    }
    return tabs;
  }

  int _feedIndexedStackIndex() {
    final tabs = _availableFeedTabs();
    final idx = tabs.indexOf(_activeTabType);
    return idx == -1 ? 0 : idx;
  }

  void _ensurePageScrollListener(String tab) {
    final layer = _layerFor(tab);
    _pageScrollListeners.putIfAbsent(tab, () {
      void listener() => _onPageScrollOffsetForTab(tab);
      layer.pageController.addListener(listener);
      return listener;
    });
  }

  void _removePageScrollListener(String tab) {
    final listener = _pageScrollListeners.remove(tab);
    final layer = _tabLayers[tab];
    if (listener != null && layer != null) {
      layer.pageController.removeListener(listener);
    }
  }

  void _syncActiveTabScrollListener(String previousTab, String newTab) {
    if (previousTab != newTab) {
      _removePageScrollListener(previousTab);
    }
    _ensurePageScrollListener(newTab);
  }

  List<WallVideos>? _videosForTab(String tab, {required bool isActiveTab}) {
    if (isActiveTab) {
      return controller.videoFeed.value.videos;
    }
    return controller.cachedVideosForTab(tab);
  }

  int _listLenForTab(String tab, {required bool isActiveTab}) {
    if (isActiveTab) {
      return controller.reelListLength.value;
    }
    return controller.cachedListLengthForTab(tab);
  }

  void _resumeVisibleReelAfterOverlay() {
    if (!mounted || !controller.canPlayHomeReels) {
      return;
    }
    if (controller.needsColdRestoreAfterCapture ||
        controller.coldRestoreInFlight) {
      return;
    }
    _lastHandledPlaybackEpoch = -1;
    final tab = _activeTabType;
    final videos = _videosForTab(tab, isActiveTab: true);
    if (videos == null || videos.isEmpty) {
      return;
    }
    final layer = _activeLayer;
    // onReturnedToHomeTab resolves the exact saved video id into
    // visiblePageIndex; sync the per-tab layer + PageView to it so we resume
    // the same reel the user was watching (not a stale layer notifier value).
    final index = controller.visiblePageIndex.value.clamp(0, videos.length - 1);
    layer.visibleIndexNotifier.value = index;
    if (layer.pageController.hasClients &&
        (layer.pageController.page?.round() ?? index) != index) {
      layer.pageController.jumpToPage(index);
    }
    final video = videos[index];
    layer.activePlayerVideo = video;
    final key = video.id;
    _armPosterMask();
    _preloadManager.prepareForSessionStart();
    _schedulePlayerForPage(tab, index, forceReattach: true);
    unawaited(
      MediaKitPlayerPool.instance.ensureFeedPingPongInitialized().then((_) async {
        if (!mounted || !controller.canPlayHomeReels) {
          return;
        }
        unawaited(_preloadManager.prefetchVisibleReel(index, maxWaitMs: 0));
        await ReelScreenPlaybackHelpers.attachVisibleIndex(
          preloadManager: _preloadManager,
          coordinator: _playbackCoordinator,
          context: context,
          index: index,
          resolveState: () => _feedPlayerState,
          forcePlayerReattach: true,
          warmMaxWaitMs: 0,
        );
        if (!mounted || !controller.canPlayHomeReels) {
          return;
        }
        _resumeFeedAudibleOnce();
        _scheduleFinishPlaybackIfReady();
      }),
    );
  }

  void _resumeFeedAudibleOnce() {
    if (!controller.canPlayHomeReels) {
      return;
    }
    final key = _activeLayer.activePlayerVideo?.id;
    if (key == null || key.isEmpty) {
      return;
    }
    // Never unmute while the page poster still covers the surface.
    if (_maskActiveVideoWithPoster || _unmaskedReelId != key) {
      return;
    }
    if (!MediaKitPlayerPool.instance.isFeedVisibleKey(key) ||
        !MediaKitPlayerPool.instance.isFrameReady(key)) {
      return;
    }
    unawaited(
      MediaKitPlayerPool.instance.ensureFeedAudibleWithRetry(key),
    );
  }

  Future<void> _warmVisibleBeforePlayback(
    int index, {
    int maxWaitMs = 700,
  }) async {
    if (!mounted) {
      return;
    }
    _playbackCoordinator.precacheVisiblePoster(context, index);
    await _preloadManager.prefetchVisibleReel(index, maxWaitMs: maxWaitMs);
  }

  void _schedulePlayerForPage(
    String tab,
    int pageIndex, {
    bool forceReattach = false,
  }) {
    unawaited(
      _schedulePlayerForPageAsync(
        tab,
        pageIndex,
        forceReattach: forceReattach,
      ),
    );
  }

  Future<void> _schedulePlayerForPageAsync(
    String tab,
    int pageIndex, {
    bool forceReattach = false,
  }) async {
    final epoch = ++_playerScheduleEpoch;
    final isActiveTab = tab == _activeTabType;
    final layer = _layerFor(tab);
    // Post-upload sticky flag: kick cold restore instead of attaching onto a
    // disposed pool (that left 1x1 VideoOutputs and a dead feed).
    if (controller.needsColdRestoreAfterCapture &&
        !controller.coldRestoreInFlight &&
        !controller.isInMediaCaptureFlow) {
      debugPrint('[FeedRestore] schedulePlayer kick coldRestore page=$pageIndex');
      controller.healHomeFeedIfStuckInvisible();
      return;
    }
    if (!controller.canMountHomeReelPlayer) {
      debugPrint('[FeedRestore] schedulePlayer BAIL !canMount page=$pageIndex '
          'reason=${controller.canMountBlockReason}');
      layer.activePlayerVideo = null;
      // Only heal leaked mute/visible gates when Home is clear. Never while
      // capture/upload/camera is open (reason=captureDepth) — that wiped the
      // gate and remounted the feed under the form.
      if (!controller.isInMediaCaptureFlow &&
          !controller.canMountBlockReason.startsWith('capture') &&
          !controller.canMountBlockReason.startsWith('overlay')) {
        controller.healHomeFeedIfStuckInvisible();
      }
      return;
    }
    // Post-upload silence must not stick once Home is actively scheduling.
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    controller.setReelsTabVisible(true);
    final videos = _videosForTab(tab, isActiveTab: isActiveTab);
    if (videos == null ||
        videos.isEmpty ||
        !isActiveTab) {
      return;
    }
    final actualIndex = pageIndex % videos.length;
    var video = videos[actualIndex];
    final leavingPhoto = layer.activePlayerVideo?.isPhotoPost == true;

    if (video.isPhotoPost) {
      MediaKitPlayerPool.instance.pauseAllImmediate();
      await MediaKitPlayerPool.instance.clearFeedVisibleReel();
      if (epoch != _playerScheduleEpoch ||
          !mounted ||
          tab != _activeTabType) {
        return;
      }
      // Page may have moved during clear — re-check.
      final still = _videosForTab(tab, isActiveTab: true);
      if (still == null || still.isEmpty) {
        return;
      }
      final idx = pageIndex % still.length;
      if (still[idx].id != video.id) {
        return;
      }
      layer.activePlayerVideo = video;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (video.id == null || video.id!.isEmpty) {
      return;
    }
    // Serialize photo→video so clearFeedVisibleReel can't bump the open token
    // after the new player already synced its generation.
    if (leavingPhoto) {
      await MediaKitPlayerPool.instance.clearFeedVisibleReel();
      if (epoch != _playerScheduleEpoch ||
          !mounted ||
          tab != _activeTabType) {
        return;
      }
      final still = _videosForTab(tab, isActiveTab: true);
      if (still == null || still.isEmpty) {
        return;
      }
      final idx = pageIndex % still.length;
      video = still[idx];
      if (video.isPhotoPost) {
        layer.activePlayerVideo = video;
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (video.id == null || video.id!.isEmpty) {
        return;
      }
    }
    final needsReattach = forceReattach || leavingPhoto;
    if (!needsReattach && layer.activePlayerVideo?.id == video.id) {
      final id = video.id;
      if (id != null &&
          id.isNotEmpty &&
          MediaKitPlayerPool.instance.isFeedVisibleKey(id)) {
        if (MediaKitPlayerPool.instance.isFrameReady(id) &&
            !MediaKitPlayerPool.instance.isActiveAudible(id)) {
          _resumeFeedAudibleOnce();
        }
        return;
      }
      // Same page id but pool drifted (fast-scroll drop) — fall through to reopen.
    }
    layer.activePlayerVideo = video;
    if (mounted) {
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (epoch != _playerScheduleEpoch ||
          !mounted ||
          !controller.canPlayHomeReels) {
        return;
      }
      _attachScheduledFeedPlayer(
        epoch: epoch,
        forceReattach: needsReattach,
      );
    });
  }

  void _persistLeavingTabPlayback(String tab) {
    final layer = _layerFor(tab);
    final videos = tab == controller.selectedType.value
        ? controller.videoFeed.value.videos
        : controller.cachedVideosForTab(tab);
    if (videos == null || videos.isEmpty) {
      return;
    }
    final idx = layer.visibleIndexNotifier.value % videos.length;
    controller.saveTabScrollIndex(tab, idx);
    controller.saveTabVideoId(tab, videos[idx].id);
  }

  Future<void> _waitForTabSwitchFrame() async {
    final timeout = DeviceConstraints.instance.isIosSimulator
        ? const Duration(seconds: 4)
        : const Duration(seconds: 2);
    final completer = Completer<void>();
    _tabSwitchFrameCompleter = completer;
    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint(
            '[ReelsVideoScreen] tab switch frame wait exceeded ${timeout.inSeconds}s '
            '(target=${_tabSwitchTargetVideoId ?? "none"})',
          );
        },
      );
    } finally {
      if (identical(_tabSwitchFrameCompleter, completer)) {
        _tabSwitchFrameCompleter = null;
      }
    }
  }

  void _completeTabSwitchFrameIfReady() {
    final completer = _tabSwitchFrameCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    final expectedId = _tabSwitchTargetVideoId;
    final actualId = _activeLayer.activePlayerVideo?.id;
    if (expectedId != null &&
        expectedId.isNotEmpty &&
        actualId != null &&
        actualId != expectedId) {
      return;
    }
    completer.complete();
  }

  /// Switches عام / بالقرب / المتابعة — same playback lifecycle on every tab.
  void _switchFeedTab(String newTabType) {
    unawaited(_switchFeedTabAsync(newTabType));
  }

  Future<void> _switchFeedTabAsync(String newTabType) async {
    if (newTabType != 'General' &&
        newTabType != 'Near Me' &&
        newTabType != 'Following') {
      return;
    }
    if (newTabType == controller.selectedType.value &&
        (controller.videoFeed.value.videos?.isNotEmpty ?? false)) {
      _finishFeedTabPlayback(newTabType);
      return;
    }
    _feedTabSwitchInFlight = true;
    _suppressFocusPlayback = true;
    controller.beginFeedTabSwitch();
    try {
      final previousTab = controller.selectedType.value;
      // Index race: persist leaving tab before any index reads change.
      _persistLeavingTabPlayback(previousTab);
      await controller.prepareForFeedTabSwitch();
      // Keep inactive IndexedStack layers and the shared [videoFeed] in sync.
      controller.snapshotActiveTabFeedCache();
      _preloadManager.resetForTabSwitch();
      final layer = _layerFor(newTabType);
      final cached = controller.cachedVideosForTab(newTabType);
      int? targetIndex;
      final hasCache = cached != null && cached.isNotEmpty;
      if (hasCache) {
        // Must precede [setSelectedType] — active PageView reads [videoFeed],
        // not the per-tab cache map. Without this, General/Near Me show the
        // previous tab's reels until a late fetchVideos completes.
        controller.applyCachedFeedForTab(newTabType);
        targetIndex = controller.visiblePageIndex.value;
        layer.visibleIndexNotifier.value = targetIndex;
        // Always keep poster up across IndexedStack remount — pool may still
        // report frame-ready for the same id from the previous tab visit.
        _resetPosterMaskForPageChange(
          videoId: cached[targetIndex].id,
          forceShowPoster: true,
        );
        if (layer.pageController.hasClients) {
          layer.pageController.jumpToPage(targetIndex);
        }
        _tabSwitchTargetVideoId = cached[targetIndex].id;
        _warmPosterWindowForVisible();
        if (mounted) {
          _playbackCoordinator.precacheVisiblePoster(context, targetIndex);
        }
      }
      // Apply scroll + visiblePageIndex before showing the tab — otherwise
      // FocusDetector jumps using the previous tab's index (wrong reel poster).
      // Clear shared feed before activating Following/Near Me with no cache so
      // the previous tab's videos never flash under the new tab label.
      if (!hasCache) {
        controller.videoFeed.value = VideoFeed(status: true, videos: []);
        controller.reelListLength.value = 0;
      }
      controller.setSelectedType(newTabType);
      if (newTabType == 'Near Me') {
        unawaited(
          controller.fetchLocationOnce(
            forceRefresh: true,
            refreshNearMeFeed: true,
          ),
        );
      }
      _syncActiveTabScrollListener(previousTab, newTabType);
      if (hasCache) {
        // Warm disk before attach so General doesn't open HTTPS (2–5s on sim).
        await _preloadManager.prefetchVisibleReel(
          targetIndex!,
          maxWaitMs: 1800,
        );
        if (!mounted || controller.selectedType.value != newTabType) {
          return;
        }
        _finishFeedTabPlayback(newTabType, fromTabSwitch: true);
        unawaited(controller.fetchVideos(fromTabSwitch: true));
        await _waitForTabSwitchFrame();
      } else {
        await controller.fetchVideos(fromTabSwitch: true);
        if (mounted &&
            (controller.videoFeed.value.videos?.isNotEmpty ?? false)) {
          final videos = controller.videoFeed.value.videos!;
          final resolved =
              controller.resolveScrollIndexForTab(newTabType, videos);
          _tabSwitchTargetVideoId = videos[resolved].id;
          _warmPosterWindowForVisible();
          if (mounted) {
            _playbackCoordinator.precacheVisiblePoster(context, resolved);
          }
          await _preloadManager.prefetchVisibleReel(
            resolved,
            maxWaitMs: 1800,
          );
          if (!mounted || controller.selectedType.value != newTabType) {
            return;
          }
          _finishFeedTabPlayback(newTabType, fromTabSwitch: true);
          await _waitForTabSwitchFrame();
        }
      }
    } finally {
      controller.endFeedTabSwitch();
      _tabSwitchTargetVideoId = null;
      _feedTabSwitchInFlight = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _suppressFocusPlayback = false;
          }
        });
      });
    }
  }

  void _onFeedTabHorizontalSwipe(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;
    if (vx.abs() < 500 || vx.abs() <= vy.abs() * 1.5) {
      return;
    }

    final availableTabs = <String>[];
    if ((promoteVideoController
                .siteSettings
                .value
                ?.settings
                ?.allowGeneralVideos ??
            0) ==
        1) {
      availableTabs.add('General');
    }
    availableTabs.add('Near Me');
    if ((promoteVideoController
                .siteSettings
                .value
                ?.settings
                ?.allowGeneralVideos ??
            0) ==
        1) {
      availableTabs.add('Following');
    }
    if (availableTabs.isEmpty) {
      return;
    }

    var currentIndex = availableTabs.indexOf(controller.selectedType.value);
    if (currentIndex == -1) {
      currentIndex = 0;
    }

    if (vx > 0) {
      currentIndex =
          (currentIndex - 1 + availableTabs.length) % availableTabs.length;
    } else {
      currentIndex = (currentIndex + 1) % availableTabs.length;
    }

    final newTabType = availableTabs[currentIndex];
    if (newTabType == 'Following' && !isAuthenticated) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (newTabType != controller.selectedType.value) {
      _switchFeedTab(newTabType);
    }
  }

  void _finishFeedTabPlayback(
    String? tabType, {
    bool fromTabSwitch = false,
  }) {
    final tab = tabType ?? _activeTabType;
    if (!mounted || !controller.isReelsTabVisible.value || tab != _activeTabType) {
      return;
    }
    final videos = _videosForTab(tab, isActiveTab: true);
    if (videos == null || videos.isEmpty) {
      return;
    }
    _pendingFeedTabPlayback = false;
    final layer = _layerFor(tab);
    final preferNewest = controller.consumePreferNewestAttach();
    // While the user is on a reel, trust the live PageView index — not the saved
    // tab scroll id (fetchVideos + epoch replay was jumping to another video).
    // Icon re-tap (preferNewest) always lands on index 0 and autoplays.
    var targetIndex = preferNewest
        ? 0
        : fromTabSwitch
            ? controller.resolveScrollIndexForTab(tab, videos)
            : layer.visibleIndexNotifier.value.clamp(0, videos.length - 1);
    // When the feed grows (fetch-more), keep the reel that is already playing
    // even if its index shifted in the list. Never pin after an icon re-tap —
    // that resurrected the previous reel (muted) instead of the newest.
    if (!fromTabSwitch && !preferNewest) {
      final pinnedId = layer.activePlayerVideo?.id;
      if (pinnedId != null && pinnedId.isNotEmpty) {
        final pinnedIndex = videos.indexWhere((v) => v.id == pinnedId);
        if (pinnedIndex >= 0) {
          targetIndex = pinnedIndex;
        }
      }
    }
    if (preferNewest) {
      layer.activePlayerVideo = null;
      layer.visibleIndexNotifier.value = 0;
      controller.visiblePageIndex.value = 0;
      controller.currentIndex.value = 0;
    }
    final targetVideo = videos[targetIndex];
    final targetId = targetVideo.id;
    debugPrint('[FeedRestore] finishPlayback tab=$tab idx=$targetIndex '
        'id=$targetId isPhoto=${targetVideo.isPhotoPost} '
        'canPlay=${controller.canPlayHomeReels} '
        'canMount=${controller.canMountHomeReelPlayer}');
    // Cover until paint — even if an earlier transient empty_feed cleared us.
    if (!_firstPlayableReelReady) {
      _ensureColdStartSpinnerUntilPlayable(reason: 'finish_playback');
    }
    final currentPage = layer.pageController.hasClients
        ? (layer.pageController.page?.round() ?? -1) % videos.length
        : -1;
    final alreadyOnTarget = !preferNewest &&
        layer.visibleIndexNotifier.value == targetIndex &&
        currentPage == targetIndex &&
        layer.activePlayerVideo?.id == targetId &&
        targetId != null &&
        targetId.isNotEmpty &&
        MediaKitPlayerPool.instance.isFeedVisibleKey(targetId);
    if (alreadyOnTarget) {
      if (targetVideo.isPhotoPost) {
        _completeTabSwitchFrameIfReady();
        _dismissColdStartSpinner(reason: 'photo_already_visible');
        return;
      }
      final audible = MediaKitPlayerPool.instance.isActiveAudible(targetId!);
      if (audible) {
        _completeTabSwitchFrameIfReady();
        return;
      }
      _schedulePlayerForPage(tab, targetIndex, forceReattach: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || tab != _activeTabType) {
          return;
        }
        _resumeFeedAudibleOnce();
        _completeTabSwitchFrameIfReady();
      });
      return;
    }
    layer.activePlayerVideo = targetVideo;
    if (!fromTabSwitch || preferNewest) {
      _preloadManager.prepareForSessionStart();
    }
    layer.visibleIndexNotifier.value = targetIndex;
    _resetPosterMaskForPageChange(
      videoId: targetId,
      forceShowPoster: fromTabSwitch || preferNewest,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab != _activeTabType) {
        return;
      }
      if (layer.pageController.hasClients &&
          (layer.pageController.page?.round() ?? 0) != targetIndex) {
        layer.pageController.jumpToPage(targetIndex);
      }
      unawaited(
        _preloadManager.prefetchVisibleReel(
          targetIndex,
          maxWaitMs: fromTabSwitch ? 1200 : 0,
        ),
      );
      // Tab switch remounts the shared player — same-key early return in
      // attach left General silent/black until a later kick. Always reattach.
      _schedulePlayerForPage(
        tab,
        targetIndex,
        forceReattach: preferNewest || fromTabSwitch,
      );
      MediaKitPlayerPool.instance.setScreenWidth(
        MediaQuery.sizeOf(context).width,
      );
      _playbackCoordinator.onPageSettled(targetIndex, context: context);
      _resumeFeedAudibleOnce();
      if (targetVideo.isPhotoPost && _holdColdStartSpinner) {
        // Photos have no videoPainted signal — drop spinner once the page is up
        // (poster is usually already warmed by image_warmed).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && tab == _activeTabType) {
            _dismissColdStartSpinner(reason: 'photo_ready');
          }
        });
      }
      if (preferNewest) {
        // Icon re-tap: silence cleared the previous player; nudge audible
        // again after the first frame so autoplay isn't stuck muted.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _resumeFeedAudibleOnce();
          }
        });
      }
    });
  }

  void _onVisibleReelReady() {
    if (!mounted || !controller.isReelsTabVisible.value) {
      return;
    }
    _lastHandledPlaybackEpoch = controller.feedPlaybackEpoch.value;
    _completeTabSwitchFrameIfReady();
    _preloadManager.decoderWarmEnabled = true;
    _maybeBootstrapPreload();
    final index = _activeLayer.visibleIndexNotifier.value;
    unawaited(_preloadManager.onVisibleIndexChanged(index));
  }

  void _maybeDismissColdStartForSettledEmptyFeed() {
    if (!mounted || _firstPlayableReelReady) {
      return;
    }
    if (controller.isLoading.value || controller.blocksUiForLocation) {
      return;
    }
    if (controller.selectedType.value == 'Near Me' &&
        controller.isLocationFetching.value) {
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos != null && videos.isNotEmpty) {
      return;
    }
    _dismissColdStartSpinner(reason: 'feed_settled_empty');
  }

  void _dismissColdStartSpinner({required String reason}) {
    _coldStartSpinnerTimeout?.cancel();
    _coldStartSpinnerTimeout = null;
    if (_firstPlayableReelReady && !_holdColdStartSpinner) {
      return;
    }
    if (!mounted) {
      _firstPlayableReelReady = true;
      _holdColdStartSpinner = false;
      return;
    }
    setState(() {
      _firstPlayableReelReady = true;
      _holdColdStartSpinner = false;
    });
    debugPrint('[FeedRestore] coldStartSpinner dismiss reason=$reason');
  }

  /// Re-cover the feed if spinner was cleared too early (transient empty list
  /// during login / location) while the first reel is still mounting.
  void _ensureColdStartSpinnerUntilPlayable({required String reason}) {
    if (_firstPlayableReelReady) {
      return;
    }
    _armColdStartSpinnerTimeout();
    if (_holdColdStartSpinner) {
      return;
    }
    if (!mounted) {
      _holdColdStartSpinner = true;
      return;
    }
    setState(() => _holdColdStartSpinner = true);
    debugPrint('[FeedRestore] coldStartSpinner rearm reason=$reason');
  }

  void _armColdStartSpinnerTimeout() {
    if (_coldStartTimeoutArmed || _firstPlayableReelReady) {
      return;
    }
    _coldStartTimeoutArmed = true;
    _coldStartSpinnerTimeout?.cancel();
    // Login → Near Me location → first paint can exceed 5s on cold devices.
    _coldStartSpinnerTimeout = Timer(const Duration(seconds: 12), () {
      _dismissColdStartSpinner(reason: 'timeout');
    });
  }

  void _onFeedVideoPainted(String? paintedId) {
    if (!mounted) {
      return;
    }
    final activeId = _activeLayer.activePlayerVideo?.id;
    final id = (paintedId != null && paintedId.isNotEmpty)
        ? paintedId
        : activeId;
    // A late paint from the previous reel must not unmask (or clear) the
    // poster for the page that is actually on screen.
    if (id == null ||
        id.isEmpty ||
        (activeId != null &&
            activeId.isNotEmpty &&
            id != activeId)) {
      debugPrint(
        '[FeedRestore] videoPainted IGNORED id=$id active=$activeId',
      );
      return;
    }
    debugPrint('[FeedRestore] videoPainted -> unmask id=$id');
    _dropPosterMask(id);
    _dismissColdStartSpinner(reason: 'video_painted');
    _lastHandledPlaybackEpoch = controller.feedPlaybackEpoch.value;
    _resumeFeedAudibleOnce();
  }

  void _onFeedAwaitingPaint(String? fromId) {
    if (!mounted) {
      return;
    }
    final activeId = _activeLayer.activePlayerVideo?.id;
    // Ignore recycle/await signals from a non-active player — remasking here
    // left the thumb covering a live reel while its progress bar kept moving.
    if (fromId != null &&
        fromId.isNotEmpty &&
        activeId != null &&
        activeId.isNotEmpty &&
        fromId != activeId) {
      debugPrint(
        '[FeedRestore] awaitingPaint IGNORED id=$fromId active=$activeId',
      );
      return;
    }
    // Already painted and still the live feed surface — remasking after a
    // same-key upgrade/recycle left a black gap under the thumb.
    final id = fromId ?? activeId;
    if (id != null &&
        id.isNotEmpty &&
        id == _unmaskedReelId &&
        !_maskActiveVideoWithPoster &&
        MediaKitPlayerPool.instance.isFeedVisibleKey(id) &&
        MediaKitPlayerPool.instance.isFrameReady(id)) {
      debugPrint(
        '[FeedRestore] awaitingPaint SKIP already-live id=$id',
      );
      return;
    }
    debugPrint(
      '[FeedRestore] awaitingPaint (poster mask ON) id=${fromId ?? activeId}',
    );
    _armPosterMask();
  }

  void _resetPosterMaskForPageChange({
    String? videoId,
    bool forceShowPoster = false,
  }) {
    if (!forceShowPoster &&
        ReelScreenPlaybackHelpers.shouldKeepPosterHidden(videoId)) {
      _dropPosterMask(videoId);
      ReelScreenPlaybackHelpers.resumeAudibleForReel(videoId);
      return;
    }
    _armPosterMask();
  }

  void _resumeAfterAppForeground() {
    if (!mounted) {
      return;
    }
    _lastHandledPlaybackEpoch = -1;
    // [HomeController.onAppLifecycleResumed] owns background/visibility gates.
    // Never force [isReelsTabVisible]=true here — that remounts feed audio on
    // Profile after app reopen.
    if (!controller.canPlayHomeReels) {
      MediaKitPlayerPool.instance.silenceAllSync();
      MediaKitPlayerPool.instance.pauseAllImmediate();
      return;
    }
    controller.isNavigating.value = false;
    controller.setReelsTabVisible(true);
    final videos = controller.videoFeed.value.videos;
    final layer = _activeLayer;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final index = layer.visibleIndexNotifier.value.clamp(0, videos.length - 1);
    _resetPosterMaskForPageChange(
      videoId: videos[index].id,
    );
    final video = videos[index];
    if (video.isPhotoPost) {
      return;
    }
    layer.activePlayerVideo = video;
    unawaited(_preloadManager.prefetchVisibleReel(index, maxWaitMs: 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.canPlayHomeReels) {
        MediaKitPlayerPool.instance.silenceAllSync();
        MediaKitPlayerPool.instance.pauseAllImmediate();
        return;
      }
      _schedulePlayerForPage(_activeTabType, index, forceReattach: true);
      unawaited(_feedPlayerState?.resumeAfterAppBackground());
      _resumeFeedAudibleOnce();
    });
  }

  void _silenceFeedOnAppBackground() {
    MediaKitPlayerPool.instance.silenceAllSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
  }

  /// Warm posters for the pages that are about to be visible. Scroll-driven
  /// warms never run when the feed list is replaced wholesale.
  void _warmPosterWindowForVisible() {
    if (!mounted) {
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final index =
        _activeLayer.visibleIndexNotifier.value.clamp(0, videos.length - 1);
    _playbackCoordinator.precacheWindow(context, index);
  }

  /// True when the visible Near Me reel is already attached and painted.
  bool _isVisibleReelHealthy(String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return false;
    }
    final pool = MediaKitPlayerPool.instance;
    // Never treat hadRecentPaint alone as healthy — that dropped the poster
    // while the remounted surface was still black (sound without picture).
    return pool.isFeedVisibleKey(videoId) &&
        pool.isFrameReady(videoId) &&
        pool.canInstantResume(videoId);
  }

  void _resumeFeedAfterLocationPermission() {
    if (!mounted || !controller.canPlayHomeReels) {
      return;
    }
    _warmPosterWindowForVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.canPlayHomeReels) {
        return;
      }
      final videos = controller.videoFeed.value.videos;
      if (videos == null || videos.isEmpty) {
        _resumeAfterAppForeground();
        return;
      }
      final index =
          _activeLayer.visibleIndexNotifier.value.clamp(0, videos.length - 1);
      final video = videos[index];
      _activeLayer.activePlayerVideo = video;
      if (video.isPhotoPost) {
        _dismissColdStartSpinner(reason: 'location_photo');
        return;
      }
      final videoId = video.id?.toString();
      if (videoId == null || videoId.isEmpty) {
        return;
      }

      // Allow Once often completes while a reel is already playing. Force
      // reattach / invalidateFeedOpenToken was stopping that video.
      if (_isVisibleReelHealthy(videoId)) {
        debugPrint(
          '[FeedRestore] location resume KEEP-LIVE id=$videoId',
        );
        if (_unmaskedReelId != videoId || _maskActiveVideoWithPoster) {
          _dropPosterMask(videoId);
        }
        unawaited(_feedPlayerState?.resumeAfterAppBackground());
        _resumeFeedAudibleOnce();
        return;
      }

      debugPrint(
        '[FeedRestore] location resume REATTACH id=$videoId',
      );
      _armPosterMask();
      _lastHandledPlaybackEpoch = -1;
      unawaited(_preloadManager.prefetchVisibleReel(index, maxWaitMs: 0));
      _schedulePlayerForPage(
        _activeTabType,
        index,
        forceReattach: true,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.canPlayHomeReels) {
          return;
        }
        unawaited(_feedPlayerState?.ensureVisibleOpen());
        unawaited(_feedPlayerState?.resumeAfterAppBackground());
        _resumeFeedAudibleOnce();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        controller.isInNearMeLocationPermissionFlow) {
      // iOS "Allow Location" sheet — not a real background transition.
      return;
    }
    if (state == AppLifecycleState.inactive &&
        controller.isLocationPermissionPromptVisible) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _silenceFeedOnAppBackground();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (controller.isInNearMeLocationPermissionFlow) {
          return;
        }
        _resumeAfterAppForeground();
      });
    }
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

  Widget _buildInlineReelPlayer(WallVideos video, {required String tab}) {
    return ReelFeedPlayerKit.buildInlinePlayer(
      video: video,
      onStateChanged: _onFeedPlayerStateChanged,
      // Photos must never show the scrubber — only real video posts.
      showProgressBar: !video.isPhotoPost,
      onPlaybackReady: () {
        _onVisibleReelReady();
      },
      onFeedVideoPainted: _onFeedVideoPainted,
      onFeedAwaitingPaint: _onFeedAwaitingPaint,
      onVideoCompleted: _onReelVideoCompleted,
    );
  }

  Widget _buildPagePoster(WallVideos videoDetail, {required bool isActiveReel}) {
    // Always paint a poster under the active reel — Oppo/MediaTek can show
    // black until the decoder paints. Ready items use sharp CDN thumb.webp
    // (~720 long-edge); pending uploads may still use grid cover.
    return ReelFeedPlayerKit.buildPagePoster(videoDetail);
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
    ensureReelOverlayDependencies();
    unawaited(DeviceConstraints.instance.ensureInitialized());
    WidgetsBinding.instance.addObserver(this);
    final initialTab = _activeTabType;
    final initialLayer = _layerFor(initialTab);
    initialLayer.visibleIndexNotifier.value = controller.visiblePageIndex.value;
    _ensurePageScrollListener(initialTab);
    _feedRestoreWorker = ever(controller.videoFeed, (_) {
      _applyPendingRestoreIfPossible();
      _maybeBootstrapPreload();
      _maybeDismissColdStartForSettledEmptyFeed();
      // During General↔Near Me switch, finishPlayback owns attach. Scheduling
      // here races applyCachedFeedForTab (wrong selectedType) and aborts opens.
      if (_feedTabSwitchInFlight || controller.isFeedTabSwitchLocked) {
        return;
      }
      final videos = controller.videoFeed.value.videos;
      if (videos != null && videos.isNotEmpty) {
        final idx = _activeLayer.visibleIndexNotifier.value.clamp(
          0,
          videos.length - 1,
        );
        unawaited(_preloadManager.prefetchVisibleReel(idx));
      }
      // While loading, still prefetch disk in background — but attach as soon
      // as isLoading clears (never wait on disk before first paint).
      if (videos != null &&
          videos.isNotEmpty &&
          !controller.isLoading.value &&
          controller.canPlayHomeReels &&
          _activeLayer.activePlayerVideo == null) {
        final idx = _activeLayer.visibleIndexNotifier.value.clamp(
          0,
          videos.length - 1,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _feedTabSwitchInFlight ||
              controller.isFeedTabSwitchLocked) {
            return;
          }
          unawaited(
            _preloadManager.prefetchVisibleReel(idx, maxWaitMs: 0),
          );
          _schedulePlayerForPage(
            _activeTabType,
            _activeLayer.visibleIndexNotifier.value,
          );
        });
      }
    });
    _feedPlaybackEpochWorker = ever(controller.feedPlaybackEpoch, (_) {
      _scheduleFinishPlaybackIfReady();
    });
    ever(controller.feedSortOrder, (_) {
      if (!mounted) {
        return;
      }
      // Index reset only — never null activePlayerVideo here. Meta sort echo
      // used to fire this after attach and leave the pool with no remount
      // (filter → all videos dead). Teardown/reattach is owned by setSortOrder.
      final tab = _activeTabType;
      final layer = _layerFor(tab);
      layer.visibleIndexNotifier.value = 0;
      if (layer.pageController.hasClients) {
        layer.pageController.jumpToPage(0);
      }
    });
    ever(controller.reelListLength, (len) {
      if (len is int && len > 0) {
        final layer = _activeLayer;
        final key = layer.activePlayerVideo?.id;
        // Pagination append must not reattach while the current reel is live.
        if (key != null &&
            key.isNotEmpty &&
            MediaKitPlayerPool.instance.isFeedVisibleKey(key) &&
            MediaKitPlayerPool.instance.isActiveAudible(key)) {
          return;
        }
        _scheduleFinishPlaybackIfReady();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _warmPosterWindowForVisible();
            _kickColdStartPlaybackIfReady();
          }
        });
      }
    });
    ever(controller.isLoading, (loading) {
      if (loading == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _warmPosterWindowForVisible();
            // Near Me list replace after location — only reattach if the
            // current reel is dead. Always forcing reattach stopped playback
            // right after "Allow Once".
            if (controller.selectedType.value == 'Near Me' &&
                controller.hasLocationBeenFetched.value) {
              final videos = controller.videoFeed.value.videos;
              if (videos != null && videos.isNotEmpty) {
                final index = _activeLayer.visibleIndexNotifier.value
                    .clamp(0, videos.length - 1);
                final id = videos[index].id;
                if (!_isVisibleReelHealthy(id)) {
                  debugPrint(
                    '[FeedRestore] Near Me load REATTACH dead id=$id',
                  );
                  _armPosterMask();
                  _schedulePlayerForPage(
                    _activeTabType,
                    index,
                    forceReattach: true,
                  );
                } else {
                  debugPrint(
                    '[FeedRestore] Near Me load KEEP-LIVE id=$id',
                  );
                  _resumeFeedAudibleOnce();
                }
              }
            }
          }
        });
        _kickColdStartPlaybackIfReady();
        _maybeDismissColdStartForSettledEmptyFeed();
      }
    });
    ever(controller.isLocationFetching, (fetching) {
      _maybeDismissColdStartForSettledEmptyFeed();
      if (fetching == false &&
          controller.hasLocationBeenFetched.value &&
          controller.selectedType.value == 'Near Me') {
        _resumeFeedAfterLocationPermission();
      }
    });
    _loadLanguage();
    _cacheStaticLabels();
    _checkAuthentication();
    SettingsService.instance.load();
    _preloadManager = VideoPreloadManager(
      sourceBuilder: (index) => _preloadTargetForIndex(index),
      decoderWarmEnabled: false,
    );
    _playbackCoordinator = ReelsPlaybackCoordinator(
      preloadManager: _preloadManager,
      targetForIndex: _preloadTargetForIndex,
      thumbnailUrlForIndex: (index) {
        final videos = controller.videoFeed.value.videos;
        if (videos == null || index < 0 || index >= videos.length) {
          return null;
        }
        return ReelFeedPlayerKit.precachePosterUrl(videos[index]);
      },
      videoForIndex: (index) {
        final videos = controller.videoFeed.value.videos;
        if (videos == null || index < 0 || index >= videos.length) {
          return null;
        }
        return videos[index];
      },
    );
    _reelsVisibilityWorker = ever(controller.isReelsTabVisible, (visible) {
      if (!visible) {
        MediaKitPlayerPool.instance.pauseAllImmediate();
        final key = _activeLayer.activePlayerVideo?.id;
        if (key != null && key.isNotEmpty) {
          unawaited(MediaKitPlayerPool.instance.surrenderLease(key));
          MediaKitPlayerPool.instance.invalidatePrimedFrame(key);
        }
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _armPosterMask());
        }
        return;
      }
      // Post-upload cold restore owns pool wipe + epoch remount — skip the
      // overlay resume path or attach races disposeAll and sticks dead.
      if (controller.needsColdRestoreAfterCapture ||
          controller.coldRestoreInFlight) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resumeVisibleReelAfterOverlay();
        });
      });
    });
    _restoreSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      MediaKitPlayerPool.instance.setScreenWidth(
        MediaQuery.sizeOf(context).width,
      );
      _kickColdStartPlaybackIfReady();
    });
  }

  /// Feed may finish loading before [ever] workers register on first app open.
  void _kickColdStartPlaybackIfReady() {
    if (!mounted) {
      return;
    }
    controller.isAppInBackground.value = false;
    controller.isNavigating.value = false;
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    if (!controller.isReelsTabVisible.value) {
      controller.setReelsTabVisible(true);
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty || controller.isLoading.value) {
      return;
    }
    if (!controller.canPlayHomeReels) {
      return;
    }
    unawaited(MediaKitPlayerPool.instance.ensureFeedPingPongInitialized());
    // Icon re-tap: the previous reel is still pool-live after silenceAll — do
    // not warm-resume it; force [_finishFeedTabPlayback] at index 0 + autoplay.
    if (controller.prefersNewestAttach) {
      _lastHandledPlaybackEpoch = -1;
      _scheduleFinishPlaybackIfReady();
      return;
    }
    final key = _activeLayer.activePlayerVideo?.id;
    final poolLive = key != null &&
        key.isNotEmpty &&
        MediaKitPlayerPool.instance.isFeedVisibleKey(key);
    if (poolLive && MediaKitPlayerPool.instance.isFrameReady(key!)) {
      _lastHandledPlaybackEpoch = controller.feedPlaybackEpoch.value;
      _resumeFeedAudibleOnce();
      return;
    }
    _lastHandledPlaybackEpoch = -1;
    _scheduleFinishPlaybackIfReady();
  }

  void _scheduleFinishPlaybackIfReady() {
    if (!mounted || !controller.canPlayHomeReels || _feedTabSwitchInFlight) {
      return;
    }
    if (controller.needsColdRestoreAfterCapture ||
        controller.coldRestoreInFlight) {
      return;
    }
    final videos = controller.videoFeed.value.videos;
    if (videos == null || videos.isEmpty || controller.isLoading.value) {
      return;
    }
    final epoch = controller.feedPlaybackEpoch.value;
    final poolKey = _activeLayer.activePlayerVideo?.id;
    final poolLive = poolKey != null &&
        poolKey.isNotEmpty &&
        MediaKitPlayerPool.instance.isFeedVisibleKey(poolKey);
    if (_lastHandledPlaybackEpoch == epoch &&
        _activeLayer.activePlayerVideo != null &&
        poolLive) {
      return;
    }
    if (!poolLive) {
      _lastHandledPlaybackEpoch = -1;
    }
    // First attach for a new epoch runs immediately; duplicate signals for the
    // same epoch are debounced (MTK was spawning 3 decoders on burst attach).
    _playbackAttachDebounce?.cancel();
    void attach() {
      if (!mounted || !controller.isReelsTabVisible.value) {
        return;
      }
      final latest = controller.videoFeed.value.videos;
      if (latest == null || latest.isEmpty || controller.isLoading.value) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _finishFeedTabPlayback(_activeTabType);
        }
      });
    }

    if (_lastHandledPlaybackEpoch != epoch) {
      attach();
    } else {
      _playbackAttachDebounce = Timer(const Duration(milliseconds: 100), attach);
    }
  }

  void _maybeBootstrapPreload() {
    final videos = controller.videoFeed.value.videos;
    if (videos == null ||
        videos.isEmpty ||
        !controller.isReelsTabVisible.value) {
      return;
    }
    final visible = _activeLayer.visibleIndexNotifier.value;
    _playbackCoordinator.bootstrapFromVisible(visible);
    // First-install / session-cold: prime disk+decoder for the visible reel
    // before the warm-gated open so index 0 can hit file://.
    if (MediaKitPlayerPool.instance.feedOpenCount == 0) {
      unawaited(_preloadManager.warmIndexNow(visible, maxWaitMs: 2200));
    }
  }

  void _onPageScrollOffsetForTab(String tab) {
    if (tab != _activeTabType) {
      return;
    }
    final layer = _layerFor(tab);
    if (!layer.pageController.hasClients || !mounted) {
      return;
    }
    final videos = _videosForTab(tab, isActiveTab: true);
    if (videos == null || videos.isEmpty) {
      return;
    }
    final length = videos.length;
    final page = layer.pageController.page;
    if (page == null) {
      return;
    }
    final rounded = page.roundToDouble();
    if ((page - rounded).abs() < 0.02) {
      layer.scrollTowardActualIndex = null;
      return;
    }
    final towardRaw = page > rounded ? page.ceil() : page.floor();
    final toward = towardRaw % length;
    final progress = (page - rounded).abs();

    final now = DateTime.now();
    var scrollVelocity = 0.0;
    if (layer.lastScrollPage != null && layer.lastScrollSampleAt != null) {
      final elapsedMs =
          now.difference(layer.lastScrollSampleAt!).inMilliseconds;
      if (elapsedMs > 0) {
        scrollVelocity =
            ((page - layer.lastScrollPage!).abs() / elapsedMs) * 1000;
      }
    }
    layer.lastScrollPage = page;
    layer.lastScrollSampleAt = now;

    final towardChanged = layer.scrollTowardActualIndex != toward;
    if (!towardChanged && progress < 0.12) {
      return;
    }

    if (towardChanged) {
      layer.scrollTowardActualIndex = toward;
      layer.demuxAheadFiredFor = null;
      _playbackCoordinator.onPageScrollToward(
        fromActualIndex: layer.visibleIndexNotifier.value,
        towardActualIndex: toward,
        context: context,
        scrollProgress: progress,
        scrollVelocity: scrollVelocity,
      );
      return;
    }

    // Same target — start demux once mid-gesture so settle is already buffered.
    if (progress >= 0.12 && layer.demuxAheadFiredFor != toward) {
      layer.demuxAheadFiredFor = toward;
      unawaited(
        _preloadManager.onScrollDemuxAhead(
          towardIndex: toward,
          fromIndex: layer.visibleIndexNotifier.value,
        ),
      );
    }
  }

  bool _shouldListenFirestoreStats(String tab, int actualIndex) {
    if (tab != _activeTabType) {
      return false;
    }
    final length = controller.videoFeed.value.videos?.length ?? 0;
    if (length == 0) {
      return false;
    }
    final visibleActual = _activeLayer.visibleIndexNotifier.value % length;
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
    if (video.isPhotoPost) {
      return null;
    }
    if (!video.isPlaybackReady) {
      return VideoPreloadTarget(key: key, candidates: const []);
    }
    return VideoPreloadTarget(
      key: key,
      candidates: _sourceResolver.resolveForWallVideo(video),
    );
  }

  void _schedulePageSideEffects(int actualIndex) {
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

    if (videos != null &&
        actualIndex < videos.length &&
        !videos[actualIndex].isPhotoPost) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) {
            return;
          }
          if (MediaKitPlayerPool.instance.isActiveAudible(videoId)) {
            return;
          }
          ReelScreenPlaybackHelpers.resumeAudibleForReel(videoId);
        }),
      );
    }

    // Defer non-critical Firestore reads until after the frame paints.
    Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _prefetchCommentCount(videoId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coldStartSpinnerTimeout?.cancel();
    for (final tab in _pageScrollListeners.keys.toList()) {
      _removePageScrollListener(tab);
    }
    _feedRestoreWorker?.dispose();
    _feedPlaybackEpochWorker?.dispose();
    _reelsVisibilityWorker?.dispose();
    _playbackAttachDebounce?.cancel();
    _viewTrackDebounce?.cancel();
    _positionSaveThrottle?.cancel();
    _playbackCoordinator.dispose();
    for (final layer in _tabLayers.values) {
      layer.dispose();
    }
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

  void _onReelVideoCompleted() {
    // Reels loop in place (PlaylistMode.single). The user swipes manually to
    // move to the next post — no auto-advance.
  }

  // Add a variable to store the last viewed index

  Future<void> _restoreSession() async {
    _pendingRestoreVideoId = await _sessionStore.readVideoId();
    _pendingRestoreIndex = await _sessionStore.readIndex();
  }

  void _applyPendingRestoreIfPossible() {
    if (_sessionRestored || _feedTabSwitchInFlight) {
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
    if (!mounted) {
      return;
    }
    final tab = _activeTabType;
    final layer = _layerFor(tab);
    final videos = controller.videoFeed.value.videos;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !layer.pageController.hasClients) {
        return;
      }
      if (layer.pageController.page?.round() != targetIndex) {
        layer.pageController.jumpToPage(targetIndex);
      }
      layer.visibleIndexNotifier.value = targetIndex;
      _resetPosterMaskForPageChange(
        videoId: videos != null && targetIndex < videos.length
            ? videos[targetIndex].id
            : null,
      );
      controller.visiblePageIndex.value = targetIndex;
      controller.saveTabScrollIndex(tab, targetIndex);
      if (videos != null && targetIndex < videos.length) {
        controller.saveTabVideoId(tab, videos[targetIndex].id);
      }
      _schedulePlayerForPage(tab, targetIndex);
    });
  }

  Widget _buildFeedTabLayer(String tab, bool isActiveTab) {
    final listLen = _listLenForTab(tab, isActiveTab: isActiveTab);
    if (listLen == 0) {
      return const SizedBox.shrink();
    }
    final videos = _videosForTab(tab, isActiveTab: isActiveTab);
    if (videos == null || videos.isEmpty) {
      return const SizedBox.shrink();
    }
    final layer = _layerFor(tab);
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    final String? userId = currentUser?.id ?? currentUserDetails?.id;
    final bool isRtl = _language == 'ar';

    return FocusDetector(
      onFocusGained: isActiveTab
          ? () {
              if (_suppressFocusPlayback || _feedTabSwitchInFlight) {
                return;
              }
              if (!controller.canPlayHomeReels) {
                return;
              }
              if (layer.pageController.hasClients) {
                layer.pageController.jumpToPage(
                  controller.visiblePageIndex.value,
                );
              }
              final focusKey = layer.activePlayerVideo?.id;
              final poolLive = focusKey != null &&
                  focusKey.isNotEmpty &&
                  MediaKitPlayerPool.instance.isFeedVisibleKey(focusKey);
              _schedulePlayerForPage(
                tab,
                controller.visiblePageIndex.value,
                forceReattach: !poolLive,
              );
            }
          : null,
      child: PageView.custom(
        scrollDirection: Axis.vertical,
        controller: layer.pageController,
        clipBehavior: Clip.hardEdge,
        dragStartBehavior: DragStartBehavior.down,
        allowImplicitScrolling: true,
        pageSnapping: true,
        physics: isActiveTab
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padEnds: false,
        onPageChanged: isActiveTab
            ? (index) {
                final length = videos.length;
                if (length == 0) {
                  return;
                }
                final actualIndex = index % length;
                MediaKitPlayerPool.instance.pauseAllImmediate();
                _feedPlayerState?.cancelInFlightPlaybackForPageChange();
                controller.visiblePageIndex.value = actualIndex;
                controller.saveTabScrollIndex(tab, actualIndex);
                controller.saveTabVideoId(tab, videos[actualIndex].id);
                layer.visibleIndexNotifier.value = actualIndex;
                DeviceConstraints.instance.recordSwipe();
                _resetPosterMaskForPageChange(
                  videoId: videos[actualIndex].id,
                );
                // Open immediately — never wait on disk before attach. Disk warm
                // runs in parallel for N+1 so the next swipe can hit file://.
                unawaited(
                  _preloadManager.prefetchVisibleReel(
                    actualIndex,
                    maxWaitMs: 0,
                  ),
                );
                // Keep warming the next reel(s) under the finger for fast flings.
                unawaited(
                  _preloadManager.onScrollToward(
                    fromIndex: actualIndex,
                    towardIndex: actualIndex + 1,
                    extraDepth: 1,
                  ),
                );
                _schedulePlayerForPage(tab, actualIndex);
                _preloadManager.onVisiblePageSettled();
                MediaKitPlayerPool.instance.setScreenWidth(
                  MediaQuery.sizeOf(context).width,
                );
                _playbackCoordinator.onPageSettled(
                  actualIndex,
                  context: context,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || tab != _activeTabType) {
                    return;
                  }
                  _schedulePageSideEffects(actualIndex);
                });
              }
            : null,
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) {
            final actualIndex = index % videos.length;
            final videoDetail = videos[actualIndex];

            return ReelPageKeepAlive(
              key: ValueKey<String>(
                '${tab}_${videoDetail.id ?? 'video'}',
              ),
              child: _HomeReelPageCell(
                actualIndex: actualIndex,
                isActiveTab: isActiveTab,
                visibleIndexNotifier: layer.visibleIndexNotifier,
                videoDetail: videoDetail,
                builder: (context, showPlayer, isActivePage) {
                  return _buildReelPageStack(
                    tab: tab,
                    actualIndex: actualIndex,
                    videoDetail: videoDetail,
                    isActiveTab: isActiveTab,
                    isActivePage: isActivePage,
                    showPlayer: showPlayer,
                    userId: userId,
                    isAuthenticated: isAuthenticated,
                  );
                },
              ),
            );
          },
          childCount: listLen,
        ),
      ),
    );
  }

  Widget _buildReelPageStack({
    required String tab,
    required int actualIndex,
    required WallVideos videoDetail,
    required bool isActiveTab,
    required bool isActivePage,
    required bool showPlayer,
    required String? userId,
    required bool isAuthenticated,
  }) {
    final reelId = videoDetail.id;
    final posterDropped = !_maskActiveVideoWithPoster &&
        reelId != null &&
        reelId.isNotEmpty &&
        _unmaskedReelId == reelId;
    final maskPoster = showPlayer && !posterDropped;
    if (!kReleaseMode && showPlayer) {
      final layer = maskPoster ? 'poster' : 'video';
      final stamp = '$reelId:$layer';
      if (_lastPosterLayerLog != stamp) {
        _lastPosterLayerLog = stamp;
        debugPrint('[ReelsBlank] active=$reelId showing=$layer');
      }
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomLeft,
      children: [
        ReelFeedPageMediaChrome(
          video: videoDetail,
          isActivePage: isActivePage,
          belowFeedTabs: isActiveTab,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showPlayer && !videoDetail.isPhotoPost)
                  _buildInlineReelPlayer(
                    videoDetail,
                    tab: tab,
                  ),
                IgnorePointer(
                  ignoring: showPlayer && !maskPoster,
                  child: Opacity(
                    opacity: maskPoster || !showPlayer ? 1.0 : 0.0,
                    child: _buildPagePoster(
                      videoDetail,
                      isActiveReel: showPlayer,
                    ),
                  ),
                ),
                if (isActivePage && videoDetail.isPhotoPost)
                  ReelFeedPlayerKit.buildVisibleImageDisplay(
                    video: videoDetail,
                  ),
              ],
            ),
          ),
        ),
        const TikTokFeedTopGradient(),
        const TikTokFeedBottomGradient(),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !(showPlayer || videoDetail.isPhotoPost),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (_) {
                unawaited(
                  _onReelDoubleTapLike(videoDetail),
                );
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                VideoDescriptionWidget(
                  title: videoDetail.title,
                  description: videoDetail.description,
                  tags: videoDetail.tags,
                  controller: controller,
                  tiktokStyle: true,
                  userName: videoDetail.userName,
                  creatorHandle: videoDetail.creatorHandle,
                  sponsorType: videoDetail.sponsorType,
                  isPhotoPost: videoDetail.isPhotoPost,
                  distanceKm: tab == 'Near Me' ? videoDetail.distanceKm : null,
                  distanceBasis:
                      tab == 'Near Me' ? videoDetail.distanceBasis : null,
                  cityName: tab == 'Near Me' ? videoDetail.cityName : null,
                  bottomBarClearance: 12,
                ),
                videoUserDetails(
                  profileController: profileController,
                  professionalProfileController: professionalProfileController,
                  videoDetail: videoDetail,
                  controller: controller,
                  userId: userId,
                  isAuthenticated: isAuthenticated,
                  hideLegacyChrome: true,
                ),
              ],
            ),
          ),
        ),
        ReelActionRail(
          video: videoDetail,
          isAuthenticated: isAuthenticated,
          layout: ReelActionRailLayout.home,
          listenLive: _shouldListenFirestoreStats(
            tab,
            actualIndex,
          ),
          fallbackCommentCount: _commentCounts[videoDetail.id ?? ''],
          onBeforeNavigation: controller.silenceHomeReelsForTransition,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;
    bool isRtl = _language == 'ar';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
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
                final feedEmpty =
                    controller.videoFeed.value.videos?.isEmpty ?? true;
                if ((controller.isLoading.value && feedEmpty) ||
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
                            "${'no_video_for'.tr} ${controller.currentCity.value.isNotEmpty ? controller.currentCity.value : 'Near Me'.tr} ${'try_to_change'.tr}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                            ),
                          ),
                          if (DeviceConstraints.instance.isIosSimulator &&
                              controller.isLikelyIosSimulatorDefaultLocation) ...[
                            SizedBox(height: 12.h),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                textAlign: TextAlign.center,
                                'near_me_simulator_location_notice'.tr,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (controller.selectedType.value == "General")
                                Expanded(
                                  child: AppButton(
                                    text: "Filter".tr,
                                    onTap: () {
                                      _showFilterBottomSheet(context);
                                    },
                                  ),
                                ),
                              if (controller.selectedType.value == "Near Me")
                                Expanded(
                                  child: AppButton(
                                    text: 'use_gps_near_me'.tr,
                                    onTap: () {
                                      unawaited(controller.refreshLocation());
                                    },
                                  ),
                                ),
                              SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  controller.silenceHomeReelsForTransition();
                                  Get.to(
                                    () => SearchView(
                                      isGeneral:
                                          controller.selectedType.value ==
                                                  "General"
                                              ? 1
                                              : 0,
                                    ),
                                    binding: SearchBinding(),
                                  );
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
                                  if (controller.selectedType.value ==
                                      'Near Me') {
                                    unawaited(controller.refreshLocation());
                                  } else {
                                    controller.fetchVideos();
                                  }
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
                // While camera / editor / upload is open, keep Home as a static
                // black sheet. IndexedStack keeps this tab alive under Get.to
                // routes — rebuilding PageView/players there caused first-install
                // StatefulElement.activate crashes on the upload form.
                if (controller.isInMediaCaptureFlow) {
                  return const ColoredBox(color: Colors.black);
                }
                final activeTab = controller.selectedType.value;
                final feedEmpty =
                    controller.videoFeed.value.videos?.isEmpty ?? true;
                if ((controller.isLoading.value && feedEmpty) ||
                    controller.blocksUiForLocation) {
                  return const SizedBox.shrink();
                }
                final tabs = _availableFeedTabs();
                if (tabs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IndexedStack(
                  index: _feedIndexedStackIndex(),
                  sizing: StackFit.expand,
                  children: tabs
                      .map(
                        (tab) => KeyedSubtree(
                          key: ValueKey<String>('home_feed_tab_$tab'),
                          child: _buildFeedTabLayer(
                            tab,
                            tab == activeTab,
                          ),
                        ),
                      )
                      .toList(),
                );
              }),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: TikTokFeedChrome.topGradientHeight,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: TikTokFeedChrome.topGradientColors,
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Obx(
                  () => Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: _onFeedTabHorizontalSwipe,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              if ((promoteVideoController
                                          .siteSettings
                                          .value
                                          ?.settings
                                          ?.allowGeneralVideos ??
                                      0) ==
                                  1)
                                TikTokFeedTabLabel(
                                  label: "General".tr,
                                  selected:
                                      controller.selectedType.value ==
                                      "General",
                                  onTap: () => _switchFeedTab('General'),
                                ),
                              TikTokFeedTabLabel(
                                label: "Near Me".tr,
                                selected:
                                    controller.selectedType.value == "Near Me",
                                onTap: () => _switchFeedTab('Near Me'),
                              ),
                              if ((promoteVideoController
                                          .siteSettings
                                          .value
                                          ?.settings
                                          ?.allowGeneralVideos ??
                                      0) ==
                                  1)
                                TikTokFeedTabLabel(
                                  label: "Following".tr,
                                  selected:
                                      controller.selectedType.value ==
                                      "Following",
                                  onTap: () {
                                    if (!isAuthenticated) {
                                      Get.toNamed(AppRoutes.signIn);
                                      return;
                                    }
                                    _switchFeedTab('Following');
                                  },
                                ),
                            ],
                          ),
                          ),
                        ),
                        TikTokFeedTopIconButton(
                          onTap: () {
                            controller.silenceHomeReelsForTransition();
                            Get.to(
                              () => SearchView(
                                isGeneral:
                                    controller.selectedType.value == "General"
                                        ? 1
                                        : 0,
                              ),
                              binding: SearchBinding(),
                            );
                          },
                          child: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 26.sp,
                          ),
                        ),
                        Obx(
                          () {
                            final tab = controller.selectedType.value;
                            final showBadge =
                                controller.hasGeneralLocationFilter &&
                                tab == 'General';
                            return FeedHubIconButton(
                              anchorKey: _headerHubKey,
                              isAuthenticated: isAuthenticated,
                              showFilterBadge: showBadge,
                              iconSize: 26.sp,
                              onFilter: () => _showFilterBottomSheet(context),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                        if (controller.selectedType.value == 'Near Me')
                          _buildNearMeLocationNotice(context),
                      ],
                    ),
                  ),
                ),
              ),

              // Cold open: cover chrome + feed until first reel is playable so
              // users never see black/mount/decode gap — spinner → playing.
              if (_holdColdStartSpinner)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _ReelsSkeletonLoader(),
                  ),
                ),
            ],
        ),
      ),
    ),
    );
  }

  String? selectedCountry;
  String? selectedCity;

  Widget _buildNearMeLocationNotice(BuildContext context) {
    if (DeviceConstraints.instance.isIosSimulator &&
        controller.isLikelyIosSimulatorDefaultLocation) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Material(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 14,
                  color: Colors.amber.shade200,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'near_me_simulator_location_notice'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 11.sp,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildNearMeGeoNotice(context);
  }

  String? _nearMeGeoNoticeMessage(FeedMeta meta) {
    if (meta.geoFallback) {
      return 'near_me_geo_fallback_notice'.tr;
    }
    if (meta.geoExpanded) {
      final radius = meta.geoRadiusKm;
      if (radius != null && radius > 0) {
        return 'near_me_geo_expanded_radius_notice'.trParams({
          'radius': radius.round().toString(),
        });
      }
      return 'near_me_geo_expanded_notice'.tr;
    }
    if (!isNearMeCityScope(meta.geoScope)) {
      return null;
    }

    // City groups (Dhahran/Khobar/Dammam) already come from the API; the old
    // banner only showed geo_city_name (e.g. "Dhahran") which looked broken.
    final catalog = <int, String>{};
    if (Get.isRegistered<CityController>()) {
      for (final city in Get.find<CityController>().cityList) {
        final id = city.id;
        final name = city.name?.trim();
        if (id != null && name != null && name.isNotEmpty) {
          catalog[id] = name;
        }
      }
    }
    final feed = controller.videoFeed.value;
    final groupNames = cityGroupDisplayNames(
      anchorCityName: meta.geoCityName,
      serverGroupNames: meta.geoCityGroupNames,
      videoCityNames: (feed.videos ?? const []).map((v) => v.cityName),
      videoCityIds: (feed.videos ?? const []).map((v) => v.cityId),
      catalogNamesById: catalog,
    );
    if (groupNames.length > 1) {
      return 'near_me_geo_city_group_notice'.trParams({
        'cities': formatCityGroupList(groupNames),
      });
    }
    final city = groupNames.isNotEmpty
        ? groupNames.first
        : meta.geoCityName?.trim();
    if (city != null && city.isNotEmpty) {
      return 'near_me_geo_city_notice'.trParams({'city': city});
    }
    return null;
  }

  Widget _buildNearMeGeoNotice(BuildContext context) {
    final meta = controller.videoFeed.value.meta;
    if (meta == null) {
      return const SizedBox.shrink();
    }
    final String? message = _nearMeGeoNoticeMessage(meta);
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Material(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.white.withOpacity(0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11.sp,
                  ),
                ),
              ),
              if (meta.geoFallback)
                GestureDetector(
                  onTap: () => unawaited(controller.refreshLocation()),
                  child: Text(
                    'Change Location'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext sheetContext) {
        return Obx(() {
          final tab = controller.selectedType.value;
          final showLocation = tab == 'General';
          final selectedSort = controller.feedSortOrder.value;
          final filterActive = controller.hasGeneralLocationFilter;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    'feed_filter_title'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'sort_videos_title'.tr,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _SortOptionTile(
                    title: 'sort_newest_to_oldest'.tr,
                    icon: Icons.arrow_downward_rounded,
                    selected: selectedSort == 'newest',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        controller.setSortOrder('newest');
                      });
                    },
                  ),
                  _SortOptionTile(
                    title: 'sort_oldest_to_newest'.tr,
                    icon: Icons.arrow_upward_rounded,
                    selected: selectedSort == 'oldest',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        controller.setSortOrder('oldest');
                      });
                    },
                  ),
                  if (showLocation) ...[
                    Divider(height: 24.h),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'location_label'.tr,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'feed_filter_general_hint'.tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _FeedFilterLocationRow(
                      icon: Icons.public_rounded,
                      label: 'select_country_label'.tr,
                      value: controller.generalFilterCountry.value.isEmpty
                          ? 'Select Country'.tr
                          : controller.generalFilterCountry.value,
                      onTap: () => showLocationDialog(sheetContext),
                    ),
                    SizedBox(height: 10.h),
                    _FeedFilterLocationRow(
                      icon: Icons.location_city_rounded,
                      label: 'select_city_label'.tr,
                      value: controller.generalFilterCity.value.isEmpty
                          ? 'Select City'.tr
                          : controller.generalFilterCity.value,
                      enabled:
                          controller.generalFilterCountryId.value.isNotEmpty,
                      onTap: () async {
                        if (controller.generalFilterCountryId.value.isEmpty) {
                          Get.snackbar(
                            'Filter'.tr,
                            'select_country_city_error'.tr,
                          );
                          return;
                        }
                        await showCityDialog(
                          sheetContext,
                          initialCity: int.tryParse(
                                controller.generalFilterCityId.value,
                              ) ??
                              0,
                        );
                      },
                    ),
                    if (filterActive) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: ColorUtils.primaryColor.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_alt_rounded,
                              size: 16.sp,
                              color: ColorUtils.primaryColor,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                controller.generalFilterCityId.value.isNotEmpty
                                    ? '${'feed_filter_active'.tr}: '
                                        '${controller.generalFilterCity.value}, '
                                        '${controller.generalFilterCountry.value}'
                                    : '${'feed_filter_active'.tr}: '
                                        '${controller.generalFilterCountry.value}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 16.h),
                    AppButton(
                      isLoading: controller.isLoading.value,
                      text: 'feed_filter_apply'.tr,
                      onTap: () async {
                        if (controller.isLoading.value) {
                          return;
                        }
                        if (controller.generalFilterCountryId.value.isEmpty) {
                          Get.snackbar(
                            'Filter'.tr,
                            'select_country_city_error'.tr,
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        await controller.applyFeedLocationFilterAndRefresh(
                          countryId: controller.generalFilterCountryId.value,
                          countryName: controller.generalFilterCountry.value,
                          cityId: controller.generalFilterCityId.value,
                          cityName: controller.generalFilterCity.value,
                        );
                      },
                    ),
                    SizedBox(height: 8.h),
                    if (filterActive)
                      TextButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () async {
                              Navigator.pop(sheetContext);
                              await controller.clearFeedLocationFilterAndRefresh();
                            },
                        child: Text('clear_location_filter'.tr),
                      ),
                  ],
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

class _FeedFilterLocationRow extends StatelessWidget {
  const _FeedFilterLocationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = !enabled;
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: muted ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20.sp,
                color: muted ? Colors.grey : ColorUtils.primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: muted ? Colors.grey : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: muted ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rebuilds only when this page becomes active/inactive or mount gates change —
/// avoids rebuilding every keep-alive page on each scroll (semantics crash).
class _HomeReelPageCell extends StatefulWidget {
  const _HomeReelPageCell({
    required this.actualIndex,
    required this.isActiveTab,
    required this.visibleIndexNotifier,
    required this.videoDetail,
    required this.builder,
  });

  final int actualIndex;
  final bool isActiveTab;
  final ValueNotifier<int> visibleIndexNotifier;
  final WallVideos videoDetail;
  final Widget Function(
    BuildContext context,
    bool showPlayer,
    bool isActivePage,
  ) builder;

  @override
  State<_HomeReelPageCell> createState() => _HomeReelPageCellState();
}

class _HomeReelPageCellState extends State<_HomeReelPageCell> {
  bool _isActivePage = false;
  Worker? _mountWorker;

  @override
  void initState() {
    super.initState();
    _isActivePage = _computeIsActivePage();
    if (widget.isActiveTab) {
      widget.visibleIndexNotifier.addListener(_onVisibleIndexChanged);
    }
    final home = Get.find<HomeController>();
    _mountWorker = everAll(
      [
        home.isAppInBackground,
        home.mediaCaptureDepth,
        home.feedPlaybackEpoch,
      ],
      (_) {
        if (mounted && _isActivePage) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    if (widget.isActiveTab) {
      widget.visibleIndexNotifier.removeListener(_onVisibleIndexChanged);
    }
    _mountWorker?.dispose();
    super.dispose();
  }

  void _onVisibleIndexChanged() {
    final next = _computeIsActivePage();
    if (next != _isActivePage) {
      setState(() => _isActivePage = next);
    }
  }

  bool _computeIsActivePage() {
    if (!widget.isActiveTab) {
      return false;
    }
    return widget.actualIndex == widget.visibleIndexNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the player mounted for the active video page even when
    // [canMountHomeReelPlayer] flickers (mute/overlay/cold-restore). Unmounting
    // paused the only decoder (dispose → live=0) and left a black surface.
    // Mute/pause is owned by HomeController + the pool, not by removing the widget.
    final showPlayer = _isActivePage &&
        !widget.videoDetail.isPhotoPost &&
        widget.videoDetail.isPlaybackReady;
    return ExcludeSemantics(
      excluding: !_isActivePage,
      child: widget.builder(
        context,
        showPlayer,
        _isActivePage,
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
      leading: Icon(
        icon,
        color: selected ? ColorUtils.primaryColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: ColorUtils.primaryColor, size: 22.sp)
          : null,
      onTap: onTap,
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
    this.hideLegacyChrome = false,
  });

  final ProfileController profileController;
  final ProfessionalProfileController professionalProfileController;
  final WallVideos videoDetail;
  final HomeController controller;
  final String? userId;
  final bool isAuthenticated;
  final bool hideLegacyChrome;

  Widget _avatarPlaceholder() {
    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: Icon(Icons.person, color: Colors.white, size: 18.r),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hideLegacyChrome) {
      return const SizedBox.shrink();
    }
    final overlayTop = MediaQuery.paddingOf(context).top + 50;
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
                              controller.silenceHomeReelsForTransition();
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
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 32.r,
                                      height: 32.r,
                                      child:
                                          (videoDetail
                                                      .resolvedUserAvatarUrl
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? CachedNetworkImage(
                                                imageUrl:
                                                    videoDetail
                                                        .resolvedUserAvatarUrl!,
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    (context, url) =>
                                                        _avatarPlaceholder(),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        _avatarPlaceholder(),
                                              )
                                              : _avatarPlaceholder(),
                                    ),
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
                                    if (PublicUserIdentity.subtitleHandle(
                                          videoDetail.creatorHandle,
                                        ) !=
                                        null)
                                      Text(
                                        PublicUserIdentity.formatAtHandle(
                                          videoDetail.creatorHandle,
                                        ),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10.sp,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
  final NavBarController profileController = Get.find();
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
  RxString selectedCountryName = homeController.generalFilterCountry.value.obs;

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
                            final countryId = countryMap[country]!;
                            await cityController.fetchCities(
                              countryId,
                            );
                            homeController.generalFilterCountry.value = country;
                            homeController.generalFilterCountryId.value =
                                countryId.toString();
                            homeController.generalFilterCity.value = '';
                            homeController.generalFilterCityId.value = '';
                            homeController.isLoading.value = false;

                            await showCityDialog(context);
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

Future<void> showCityDialog(BuildContext context, {int? initialCity}) async {
  final CityController cityController = Get.find<CityController>();
  final UserSearchController homeController = Get.find();
  final HomeController homeUpdateController = Get.find();

  // The city catalog is a shared singleton — make sure it holds the filter
  // country's cities, otherwise the picker offers cities of whichever country
  // was loaded last (that used to tag the feed filter with a foreign city id).
  final filterCountryId =
      int.tryParse(homeUpdateController.generalFilterCountryId.value) ?? 0;
  if (filterCountryId > 0 &&
      (cityController.loadedCountryId != filterCountryId ||
          cityController.cityList.isEmpty)) {
    await cityController.fetchCities(filterCountryId);
  }

  // Assuming City model has id and name properties
  List<Map<String, dynamic>> cityList =
      cityController.cityList
          .map((city) => {'id': city.id, 'name': city.name})
          .toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<Map<String, dynamic>> filteredCityList = cityList.obs;
  Rx<Map<String, dynamic>> selectedCity = Rx<Map<String, dynamic>>(
    const {'id': -1, 'name': ''},
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

                                      homeUpdateController
                                          .generalFilterCityId.value =
                                          selectedId.toString();
                                      homeUpdateController.generalFilterCity
                                          .value = selectedName;
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
  /// Extra space above the bottom edge (e.g. home tab bar). Profile reels use ~8.
  final double bottomBarClearance;
  final bool tiktokStyle;
  final String? userName;
  final String? creatorHandle;
  final dynamic sponsorType;
  final bool isPhotoPost;
  final double? distanceKm;
  final String? distanceBasis;
  final String? cityName;

  const VideoDescriptionWidget({
    this.title,
    this.description,
    this.tags,
    this.controller,
    this.bottomBarClearance = 68,
    this.tiktokStyle = false,
    this.userName,
    this.creatorHandle,
    this.sponsorType,
    this.isPhotoPost = false,
    this.distanceKm,
    this.distanceBasis,
    this.cityName,
    super.key,
  });

  @override
  _VideoDescriptionWidgetState createState() => _VideoDescriptionWidgetState();
}

class _VideoDescriptionWidgetState extends State<VideoDescriptionWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _hasOverflow = false;

  String get _title => widget.title?.trim() ?? '';
  String get _description => widget.description?.trim() ?? '';
  List<String> get _tagList => HashtagText.splitTags(widget.tags);

  bool get _hasBody => _description.isNotEmpty || _tagList.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowOnce());
  }

  @override
  void didUpdateWidget(covariant VideoDescriptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.description != widget.description ||
        oldWidget.tags != widget.tags ||
        oldWidget.userName != widget.userName ||
        oldWidget.isPhotoPost != widget.isPhotoPost ||
        oldWidget.distanceKm != widget.distanceKm ||
        oldWidget.distanceBasis != widget.distanceBasis ||
        oldWidget.cityName != widget.cityName) {
      _isExpanded = false;
      _hasOverflow = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowOnce());
    }
  }

  TextStyle get _descriptionStyle => widget.tiktokStyle
      ? TikTokFeedChrome.bodyCaption
      : TextStyle(color: Colors.white, fontSize: 14.sp);

  TextStyle get _tagStyle => widget.tiktokStyle
      ? TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          shadows: TikTokFeedChrome.labelShadow,
        )
      : TextStyle(color: ColorUtils.primaryColor, fontSize: 12.sp);

  List<InlineSpan> _bodySpans({required bool interactive}) {
    final spans = <InlineSpan>[];
    if (_description.isNotEmpty) {
      spans.add(TextSpan(text: _description, style: _descriptionStyle));
    }
    if (_tagList.isNotEmpty) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: ' ', style: _descriptionStyle));
      }
      for (var i = 0; i < _tagList.length; i++) {
        final tag = _tagList[i];
        final label = HashtagText.displayLabel(tag);
        if (interactive) {
          final searchKey = HashtagText.searchKey(tag);
          spans.add(
            TextSpan(
              text: label,
              style: _tagStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().silenceHomeReelsForTransition();
                  }
                  Get.to(() => HashtagReelScreen(tag: searchKey));
                },
            ),
          );
        } else {
          spans.add(TextSpan(text: label, style: _tagStyle));
        }
        if (i < _tagList.length - 1) {
          spans.add(TextSpan(text: ' ', style: _tagStyle));
        }
      }
    }
    return spans;
  }

  void _checkOverflowOnce() {
    if (!mounted || !_hasBody) {
      if (mounted && _hasOverflow) {
        setState(() => _hasOverflow = false);
      }
      return;
    }
    final textDirection = Directionality.of(context);
    final maxContentWidth = _contentMaxWidth(context) - 16; // padding
    final painter = TextPainter(
      text: TextSpan(children: _bodySpans(interactive: false)),
      maxLines: 1,
      textDirection: textDirection,
    )..layout(maxWidth: maxContentWidth.clamp(0, double.infinity));
    final overflow = painter.didExceedMaxLines;
    if (mounted && overflow != _hasOverflow) {
      setState(() => _hasOverflow = overflow);
    }
  }

  double _contentMaxWidth(BuildContext context) {
    // Leave room for the right-side action column (~90px + margins).
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth * 0.72).clamp(0.0, screenWidth - 100);
  }

  double _bottomOffset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + widget.bottomBarClearance;
  }

  Widget? _buildCreatorHeader({
    required TextDirection textDirection,
    required double maxNameWidth,
  }) {
    final name = widget.userName?.trim() ?? '';
    final locationBadge = resolveNearMeLocationBadge(
      distanceKm: widget.distanceKm,
      distanceBasis: widget.distanceBasis,
      cityName: widget.cityName,
    );
    final String? locationLabel = switch (locationBadge.kind) {
      NearMeLocationBadgeKind.distance =>
        'near_me_distance_away'.trParams({
          'distance': locationBadge.distanceFormatted!,
        }),
      NearMeLocationBadgeKind.inCity => 'near_me_in_city'.trParams({
        'city': locationBadge.city!,
      }),
      NearMeLocationBadgeKind.none => null,
    };
    if (name.isEmpty &&
        !widget.isPhotoPost &&
        (locationLabel == null || locationLabel.isEmpty)) {
      return null;
    }

    final nameStyle = widget.tiktokStyle
        ? TikTokFeedChrome.userName
        : TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (name.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxNameWidth.clamp(0, double.infinity),
                ),
                child: Text(
                  name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  textDirection: textDirection,
                ),
              ),
            if (widget.isPhotoPost) ...[
              if (name.isNotEmpty) SizedBox(width: 8.w),
              const ReelPhotoInlineBadge(),
            ],
            ],
          ),
        if (locationLabel != null && locationLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locationBadge.kind == NearMeLocationBadgeKind.distance
                      ? Icons.near_me_outlined
                      : Icons.location_city_outlined,
                  size: 12.sp,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                SizedBox(width: 4.w),
                Text(
                  locationLabel,
                  style: widget.tiktokStyle
                      ? TikTokFeedChrome.bodyCaption.copyWith(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.85),
                        )
                      : TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.sp,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  textDirection: textDirection,
                ),
              ],
            ),
          ),
        if (PublicUserIdentity.subtitleHandle(widget.creatorHandle) != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              PublicUserIdentity.formatAtHandle(widget.creatorHandle),
              style: widget.tiktokStyle
                  ? TikTokFeedChrome.bodyCaption.copyWith(
                      fontSize: 13.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    )
                  : TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.sp,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              textDirection: textDirection,
            ),
          ),
        if (widget.sponsorType != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Sponsored',
              style: widget.tiktokStyle
                  ? TikTokFeedChrome.bodyCaption.copyWith(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.85),
                    )
                  : TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.sp,
                    ),
              textAlign: TextAlign.left,
              textDirection: textDirection,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final contentMaxWidth = _contentMaxWidth(context);

    final creatorHeader = _buildCreatorHeader(
      textDirection: textDirection,
      maxNameWidth: contentMaxWidth - (widget.isPhotoPost ? 72 : 0),
    );

    if (_title.isEmpty &&
        !_hasBody &&
        creatorHeader == null) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: _bottomOffset(context),
        child: const SizedBox.shrink(),
      );
    }

    return Positioned(
      bottom: _bottomOffset(context),
      // Physical left/right — action rail stays on the right in every locale.
      left: 10,
      right: 72,
      child: Directionality(
        // Flex "start" and Row child order follow ambient direction; without
        // this wrapper Arabic RTL flips caption content to the right edge.
        textDirection: TextDirection.ltr,
        child: Container(
        padding: widget.tiktokStyle
            ? EdgeInsets.zero
            : const EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        decoration: widget.tiktokStyle
            ? null
            : BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (creatorHeader != null) ...[
              creatorHeader,
              if (_title.isNotEmpty || _hasBody) SizedBox(height: 6.h),
            ],
            if (_title.isNotEmpty)
              Text(
                _title,
                style: widget.tiktokStyle
                    ? TikTokFeedChrome.bodyCaption.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                maxLines: widget.tiktokStyle ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                textDirection: textDirection,
              ),
            if (_title.isNotEmpty && _hasBody) SizedBox(height: 4.h),
            if (_hasBody) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topLeft,
                child: RichText(
                  maxLines: _isExpanded ? null : 1,
                  overflow: _isExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  textDirection: textDirection,
                  text: TextSpan(children: _bodySpans(interactive: true)),
                ),
              ),
              // "عرض المزيد" فقط إذا النص أطول من سطر واحد.
              if (_hasOverflow)
                GestureDetector(
                  onTap: () {
                    setState(() => _isExpanded = !_isExpanded);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _isExpanded ? "show_less".tr : "show_more".tr,
                      style: TextStyle(
                        color: widget.tiktokStyle
                            ? Colors.white.withValues(alpha: 0.95)
                            : ColorUtils.primaryColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        shadows: widget.tiktokStyle
                            ? TikTokFeedChrome.labelShadow
                            : null,
                      ),
                      textAlign: TextAlign.left,
                      textDirection: textDirection,
                    ),
                  ),
                ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
