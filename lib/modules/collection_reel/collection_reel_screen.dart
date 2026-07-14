import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/reel_screen_playback_helpers.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/core/video/video_preload_target.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/reel_page_keep_alive.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart'
    show VideoDescriptionWidget;
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_overlay_column.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:cookster/modules/liked_videos_screen/liked_videos_controller/liked_videos_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CollectionReelKind { saved, liked }

/// Vertical reel viewer for saved / liked collections — same player + preload
/// path as the home feed and [ProfileReelScreen].
class CollectionReelScreen extends StatefulWidget {
  const CollectionReelScreen({
    super.key,
    required this.kind,
    this.anchorId,
    this.initialPosterUrl,
    this.title,
  });

  final CollectionReelKind kind;
  final String? anchorId;
  final String? initialPosterUrl;
  final String? title;

  @override
  State<CollectionReelScreen> createState() => _CollectionReelScreenState();
}

class _CollectionReelScreenState extends State<CollectionReelScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  final GlobalKey<ReelVideoPlayerState> _reelPlayerKey =
      GlobalKey<ReelVideoPlayerState>();
  bool _maskActiveVideoWithPoster = true;
  final ValueNotifier<int> _visibleIndexNotifier = ValueNotifier<int>(0);

  final List<WallVideos> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _poolSessionReady = false;
  String? _error;
  bool _isAuthenticated = false;
  final Set<String> _trackedVideoIds = {};
  Timer? _viewTrackDebounce;
  Timer? _fetchMoreDebounce;
  late final HomeController _homeController;
  late final VideoPreloadManager _preloadManager;
  late final ReelsPlaybackCoordinator _playbackCoordinator;
  final VideoSourceResolver _sourceResolver = const VideoSourceResolver();
  int? _scrollTowardIndex;

  SaveController? _saveController;
  LikedVideosController? _likedController;
  bool _ownsRouteOverlayPause = false;
  late final int _poolSessionToken;
  /// Bumped on every scheduled attach so a superseded page-change bails.
  int _attachGeneration = 0;
  /// Index before the latest [onPageChanged] — used to detect photo→video.
  int? _previousVisibleIndex;

  WallVideos? get _activeVideo {
    final i = _visibleIndexNotifier.value;
    if (i < 0 || i >= _videos.length) {
      return null;
    }
    return _videos[i];
  }

  /// Sticky player lives outside [PageView] so photo↔video never races
  /// GlobalKey mount/unmount inside keep-alive pages (the stuck-poster bug).
  bool get _shouldShowStickyPlayer {
    final v = _activeVideo;
    return _poolSessionReady &&
        v != null &&
        !v.isPhotoPost &&
        v.isPlaybackReady;
  }

  String get _screenTitle {
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      return widget.title!.trim();
    }
    return widget.kind == CollectionReelKind.saved
        ? 'Saved Reels'.tr
        : 'liked_videos'.tr;
  }

  bool get _hasMore {
    if (widget.kind == CollectionReelKind.saved) {
      return _saveController?.hasMore ?? false;
    }
    final liked = _likedController;
    if (liked == null) {
      return false;
    }
    // Some liked-list responses can temporarily report hasMore=false while
    // Firestore already says there are more ids (e.g. photo rows missing from
    // first page). Keep paginating until count catches up.
    return liked.hasMore || liked.totalLikes.value > _videos.length;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeController = Get.find<HomeController>();
    // Claim the shared pool — supersedes any previous reel screen's in-flight
    // teardown so it cannot disposeAll() over this screen's players.
    _poolSessionToken = _homeController.claimReelPoolSession();
    if (_homeController.routeOverlayPauseDepth == 0) {
      _homeController.pauseReelsForRouteOverlay();
      _ownsRouteOverlayPause = true;
    } else {
      _homeController.reinforceReelsPausedForOverlay();
    }
    // Grid prep disabled home unmute; re-enable for this collection session so
    // forceFeedAudibleAtPosterUnmask can actually unmute the visible reel.
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);

    if (widget.kind == CollectionReelKind.saved) {
      _saveController = Get.find<SaveController>();
    } else {
      _likedController = Get.find<LikedVideosController>();
    }

    final preloaded = _videosFromController();
    final initialPage = _resolveInitialPage(preloaded);
    _pageController = PageController(initialPage: initialPage);
    _visibleIndexNotifier.value = initialPage;
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
        if (index < 0 || index >= _videos.length) {
          return null;
        }
        return _videos[index];
      },
    );
    unawaited(_bootstrap());
  }

  int _indexForId(List<WallVideos> videos, String? id) {
    final needle = id?.trim() ?? '';
    if (needle.isEmpty || videos.isEmpty) {
      return 0;
    }
    final idx = videos.indexWhere((v) => v.id?.toString() == needle);
    return idx >= 0 ? idx : 0;
  }

  int _resolveInitialPage([List<WallVideos>? videos]) {
    return _indexForId(videos ?? _videos, widget.anchorId);
  }

  List<WallVideos> _videosFromController() {
    if (widget.kind == CollectionReelKind.saved) {
      return _saveController!.savedVideos
          .map(WallVideos.fromSavedVideo)
          .toList();
    }
    return _likedController!.likedVideos
        .map(WallVideos.fromLikedVideo)
        .toList();
  }

  void _syncVideosFromController({bool preserveVisible = true}) {
    final incoming = _videosFromController();
    final visibleId = preserveVisible &&
            _visibleIndexNotifier.value >= 0 &&
            _visibleIndexNotifier.value < _videos.length
        ? _videos[_visibleIndexNotifier.value].id?.toString()
        : widget.anchorId?.trim();

    setState(() {
      _videos
        ..clear()
        ..addAll(incoming);
      _error = _videos.isEmpty ? 'No videos' : null;
    });

    if (_videos.isEmpty) {
      return;
    }

    final targetIndex = visibleId != null && visibleId.isNotEmpty
        ? _indexForId(_videos, visibleId)
        : _visibleIndexNotifier.value.clamp(0, _videos.length - 1);
    _visibleIndexNotifier.value = targetIndex;
    if (_pageController.hasClients && targetIndex != _pageController.page?.round()) {
      _pageController.jumpToPage(targetIndex);
    }
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      prepareForFullscreenVideoPlayback(),
      _loadAuth(),
      _ensureControllerLoaded(),
    ]);
    if (!mounted) {
      return;
    }
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    await MediaKitPlayerPool.instance.ensureFeedPingPongInitialized();
    if (!mounted) {
      return;
    }
    _preloadManager.prepareForSessionStart();
    _syncVideosFromController(preserveVisible: false);
    // Liked list can be transiently empty during a Firestore-driven reset even
    // after _ensureControllerLoaded — re-sync a few times before giving up so we
    // never show a bogus "No videos" on a tap that should have opened.
    if (_videos.isEmpty && widget.kind == CollectionReelKind.liked) {
      final ctrl = _likedController;
      var tries = 0;
      while (mounted &&
          _videos.isEmpty &&
          tries < 12 &&
          (ctrl?.commaSeparatedIds.value.isNotEmpty ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted) {
          return;
        }
        _syncVideosFromController(preserveVisible: false);
        tries++;
      }
    }
    setState(() {
      _isLoading = false;
      _poolSessionReady = true;
    });

    if (_videos.isNotEmpty) {
      final start = _visibleIndexNotifier.value;
      unawaited(
        _preloadManager.prefetchVisibleReel(start, maxWaitMs: 1200),
      );
      unawaited(_preloadManager.bootstrapFromVisible(start));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_schedulePlaybackForPage(start));
      });
      unawaited(_preloadAllPages());
    }
  }

  /// Load remaining saved/liked pages so the reel can scroll the full list.
  Future<void> _preloadAllPages() async {
    while (mounted && _hasMore) {
      final before = _videos.length;
      if (widget.kind == CollectionReelKind.saved) {
        await _saveController!.fetchMoreSavedVideos();
      } else {
        await _likedController!.fetchMoreLikedVideos();
      }
      if (!mounted) {
        return;
      }
      _syncVideosFromController();
      // Stop if backend/meta says "more" but no rows actually arrived.
      if (_videos.length <= before) {
        break;
      }
    }
  }

  Future<void> _ensureControllerLoaded() async {
    if (widget.kind == CollectionReelKind.saved) {
      final ctrl = _saveController!;
      if (ctrl.savedVideos.isEmpty && !ctrl.isLoading.value) {
        await ctrl.getSavedVideos();
      }
      while (ctrl.isLoading.value) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    final ctrl = _likedController!;
    // The liked list is driven by a Firestore snapshot that assignAll()s /
    // clears likedVideos on every emit. On (re)open it can be mid-reset or
    // transiently empty — that made the reel open empty and feel like "the tap
    // did nothing" until a second tap. Wait for real data before continuing.
    var waited = 0;
    // 1) Let any in-flight reset finish.
    while (ctrl.isLoading.value && waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    // 2) If the Firestore stream hasn't delivered ids yet but there are likes,
    //    give it a brief window.
    while (ctrl.likedVideos.isEmpty &&
        ctrl.commaSeparatedIds.value.isEmpty &&
        ctrl.totalLikes.value > 0 &&
        waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    // 3) Force a fetch if we have ids but no rows.
    if (ctrl.likedVideos.isEmpty &&
        !ctrl.isLoading.value &&
        ctrl.commaSeparatedIds.value.isNotEmpty) {
      await ctrl.sendVideoIdsToApi(ctrl.commaSeparatedIds.value, reset: true);
    }
    while (ctrl.isLoading.value && waited < 6000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    // 4) Last resort: a reset returned empty transiently — try once more.
    if (ctrl.likedVideos.isEmpty && ctrl.commaSeparatedIds.value.isNotEmpty) {
      await ctrl.sendVideoIdsToApi(ctrl.commaSeparatedIds.value, reset: true);
      while (ctrl.isLoading.value && waited < 8000) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waited += 50;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewTrackDebounce?.cancel();
    _fetchMoreDebounce?.cancel();
    _visibleIndexNotifier.dispose();
    _pageController.removeListener(_onPageScrollOffset);
    _pageController.dispose();
    _playbackCoordinator.dispose();
    unawaited(_teardownPoolAndResumeHome());
    super.dispose();
  }

  Future<void> _teardownPoolAndResumeHome() async {
    final completer = Completer<void>();
    final future = completer.future;
    _homeController.registerReelTeardown(future);
    var stillOwnsSession = true;
    try {
      await MediaKitPlayerPool.instance.awaitOperationsIdle(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!_homeController.isReelPoolSessionCurrent(_poolSessionToken)) {
        stillOwnsSession = false;
        return;
      }
      MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
      await MediaKitPlayerPool.instance.disposeAllWithTimeout();
    } finally {
      // Only release the pause pair AND trigger home restore if WE still own
      // the session. A newer reel screen already claimed the pool; calling
      // resumeReelsAfterRouteOverlay here would restoreHomeFeedPlayback →
      // disposeAll and wipe the new screen's players (3rd-tap-stuck race).
      // We still drop our pause ref (silently) so the depth stays balanced.
      if (_ownsRouteOverlayPause) {
        if (stillOwnsSession) {
          _homeController.resumeReelsAfterRouteOverlay();
        } else {
          _homeController.releaseRouteOverlayPauseSilent();
        }
        _ownsRouteOverlayPause = false;
      }
      completer.complete();
      _homeController.clearReelTeardown(future);
    }
  }

  Future<void> _loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (mounted) {
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
      });
    }
  }

  void _onVisibleReelReady(int index) {
    if (!mounted || index < 0 || index >= _videos.length) {
      return;
    }
    _preloadManager.decoderWarmEnabled = true;
    _playbackCoordinator.bootstrapFromVisible(index);
    unawaited(_preloadManager.onVisibleIndexChanged(index));
  }

  void _onFeedVideoPainted() {
    if (!mounted || !_maskActiveVideoWithPoster) {
      return;
    }
    setState(() => _maskActiveVideoWithPoster = false);
  }

  void _onFeedAwaitingPaint() {
    if (!mounted || _maskActiveVideoWithPoster) {
      return;
    }
    setState(() => _maskActiveVideoWithPoster = true);
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
    if (!mounted || _videos.isEmpty) {
      return;
    }
    final index =
        _visibleIndexNotifier.value.clamp(0, _videos.length - 1);
    final video = _videos[index];
    if (video.isPhotoPost) {
      return;
    }
    _resetPosterMaskForPageChange(videoId: video.id);
    await ReelScreenPlaybackHelpers.resumeAfterAppForeground(
      playerKey: _reelPlayerKey,
      videoId: video.id,
      attachVisible: () => _attachPlaybackForIndex(index),
    );
  }

  Future<void> _attachPlaybackForIndex(
    int index, {
    bool forceReattach = false,
    int warmMaxWaitMs = 700,
  }) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }
    if (_videos[index].isPhotoPost) {
      MediaKitPlayerPool.instance.pauseAllImmediate();
      return;
    }
    final token = ++_attachGeneration;
    await ReelScreenPlaybackHelpers.attachVisibleIndex(
      preloadManager: _preloadManager,
      coordinator: _playbackCoordinator,
      context: context,
      index: index,
      playerKey: _reelPlayerKey,
      forcePlayerReattach: forceReattach,
      warmMaxWaitMs: warmMaxWaitMs,
    );
    if (!mounted || token != _attachGeneration) {
      return;
    }
  }

  /// Photo↔video schedule — sticky player is outside the PageView, so after
  /// clear we only need a post-frame [ensureVisibleOpen] (player already mounted).
  Future<void> _schedulePlaybackForPage(int index) async {
    final token = ++_attachGeneration;
    if (index < 0 || index >= _videos.length) {
      return;
    }
    var video = _videos[index];
    final prev = _previousVisibleIndex;
    final leavingPhoto = prev != null &&
        prev >= 0 &&
        prev < _videos.length &&
        _videos[prev].isPhotoPost;

    if (video.isPhotoPost) {
      MediaKitPlayerPool.instance.pauseAllImmediate();
      await MediaKitPlayerPool.instance.clearFeedVisibleReel();
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      if (!_maskActiveVideoWithPoster && mounted) {
        setState(() => _maskActiveVideoWithPoster = true);
      }
      return;
    }

    if (leavingPhoto) {
      await MediaKitPlayerPool.instance.clearFeedVisibleReel();
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      video = _videos[index];
      if (video.isPhotoPost) {
        if (!_maskActiveVideoWithPoster && mounted) {
          setState(() => _maskActiveVideoWithPoster = true);
        }
        return;
      }
    }

    if (mounted && !_maskActiveVideoWithPoster) {
      setState(() => _maskActiveVideoWithPoster = true);
    }

    // Sticky player mounts with the visibleIndex rebuild; open after paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scheduleStillCurrent(token, index)) {
          return;
        }
        unawaited(_openStickyPlayer(index: index, token: token));
      });
    });
  }

  bool _scheduleStillCurrent(int token, int index) {
    return mounted &&
        token == _attachGeneration &&
        index == _visibleIndexNotifier.value &&
        index >= 0 &&
        index < _videos.length;
  }

  bool _playbackLiveForId(String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return false;
    }
    final pool = MediaKitPlayerPool.instance;
    return pool.isFeedVisibleKey(videoId) &&
        (pool.isFrameReady(videoId) ||
            pool.isBufferPrimed(videoId) ||
            pool.hadRecentPaint(videoId));
  }

  Future<void> _openStickyPlayer({
    required int index,
    required int token,
  }) async {
    if (!_scheduleStillCurrent(token, index)) {
      return;
    }
    final video = _videos[index];
    if (video.isPhotoPost) {
      return;
    }
    final key = video.id;
    if (key == null || key.isEmpty) {
      return;
    }

    await ReelScreenPlaybackHelpers.warmVisibleIndex(
      preloadManager: _preloadManager,
      coordinator: _playbackCoordinator,
      context: context,
      index: index,
      maxWaitMs: 700,
    );
    if (!_scheduleStillCurrent(token, index) || !context.mounted) {
      return;
    }
    MediaKitPlayerPool.instance.setScreenWidth(
      MediaQuery.sizeOf(context).width,
    );
    _preloadManager.onVisiblePageSettled();
    _playbackCoordinator.onPageSettled(index, context: context);

    // Sticky player can take one more frame after photo→video; wait briefly.
    var state = _reelPlayerKey.currentState;
    for (var i = 0; i < 6 && state == null && mounted; i++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      state = _reelPlayerKey.currentState;
    }
    if (state == null) {
      if (!context.mounted) {
        return;
      }
      await ReelScreenPlaybackHelpers.attachVisibleIndex(
        preloadManager: _preloadManager,
        coordinator: _playbackCoordinator,
        context: context,
        index: index,
        playerKey: _reelPlayerKey,
        forcePlayerReattach: false,
        warmMaxWaitMs: 400,
      );
      return;
    }
    // Reopen race: a previous screen's late teardown may have disposed the
    // pool right after our first open. Retry ensureVisibleOpen (idempotent,
    // never recycles the decoder) until playback is live.
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      await state.ensureVisibleOpen();
      if (!_scheduleStillCurrent(token, index)) {
        return;
      }
      if (_playbackLiveForId(key)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  Widget _buildStickyReelPlayer(WallVideos video, int index) {
    return ReelFeedPlayerKit.buildInlinePlayer(
      video: video,
      playerKey: _reelPlayerKey,
      showProgressBar: !video.isPhotoPost,
      wrapPositioned: false,
      onPlaybackReady: () {
        _onVisibleReelReady(index);
      },
      onFeedVideoPainted: _onFeedVideoPainted,
      onFeedAwaitingPaint: _onFeedAwaitingPaint,
      onVideoCompleted: () {},
    );
  }

  VideoPreloadTarget? _preloadTargetForIndex(int index) {
    if (index < 0 || index >= _videos.length) {
      return null;
    }
    final video = _videos[index];
    if (video.isPhotoPost) {
      return null;
    }
    final key = video.id ?? video.resolvedPlaybackUrl ?? '';
    if (key.isEmpty) {
      return VideoPreloadTarget(key: key, candidates: const []);
    }
    final candidates = _sourceResolver.resolveForWallVideo(video);
    if (candidates.isEmpty) {
      return VideoPreloadTarget(key: key, candidates: const []);
    }
    return VideoPreloadTarget(
      key: key,
      candidates: candidates,
    );
  }

  String? _thumbnailUrlForIndex(int index) {
    if (index < 0 || index >= _videos.length) {
      return null;
    }
    final video = _videos[index];
    return ReelFeedPlayerKit.precachePosterUrl(video);
  }

  void _onPageScrollOffset() {
    if (!_pageController.hasClients || !mounted || _videos.isEmpty) {
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
    final toward = towardRaw.clamp(0, _videos.length - 1).toInt();
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

  Future<void> _fetchMoreVideos() async {
    _fetchMoreDebounce?.cancel();
    _fetchMoreDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fetchMoreVideosNow());
    });
  }

  Future<void> _fetchMoreVideosNow() async {
    if (_isLoadingMore || _videos.isEmpty || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    try {
      final before = _videos.length;
      if (widget.kind == CollectionReelKind.saved) {
        await _saveController!.fetchMoreSavedVideos();
      } else {
        await _likedController!.fetchMoreLikedVideos();
      }
      if (!mounted) {
        return;
      }
      _syncVideosFromController();
      if (_videos.length <= before) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _scheduleViewTrack(WallVideos video) {
    final videoId = video.id;
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    if (_trackedVideoIds.contains(videoId)) {
      return;
    }
    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) {
        return;
      }
      _trackedVideoIds.add(videoId);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      await VideoViewTracker.trackUniqueView(
        videoId: videoId,
        userId: userId,
        isAuthenticated: _isAuthenticated,
      );
    });
  }

  void _onPageChanged(int index) {
    MediaKitPlayerPool.instance.pauseAllImmediate();
    final playerState = _reelPlayerKey.currentState;
    if (playerState != null) {
      playerState.cancelInFlightPlaybackForPageChange();
    }
    _previousVisibleIndex = _visibleIndexNotifier.value;
    _visibleIndexNotifier.value = index;
    _resetPosterMaskForPageChange(
      videoId: index < _videos.length ? _videos[index].id : null,
    );
    _scrollTowardIndex = null;
    if (index < 0 || index >= _videos.length) {
      return;
    }
    final video = _videos[index];
    _scheduleViewTrack(video);
    // Home-feed style: serialize clear + attach on the async path so
    // clearFeedVisibleReel cannot bump the open token under a live attach.
    unawaited(_schedulePlaybackForPage(index));

    if (!video.isPhotoPost && _hasMore && index >= _videos.length - 3) {
      unawaited(_fetchMoreVideos());
    }
  }

  Widget _buildTopBar() {
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x00000000)],
          ),
        ),
        child: Padding(
          padding:
              EdgeInsets.only(top: topInset, left: 4, right: 12, bottom: 16),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: navigateBack,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _screenTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    if (_isLoading) {
      final poster = widget.initialPosterUrl?.trim() ?? '';
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (poster.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.black),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Colors.black),
                ),
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
              _buildTopBar(),
            ],
          ),
        ),
      );
    }

    if (_error != null || _videos.isEmpty) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error ?? 'No videos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              _buildTopBar(),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ValueListenableBuilder<int>(
            valueListenable: _visibleIndexNotifier,
            builder: (context, visibleIndex, _) {
              final active = _activeVideo;
              final showStickyPlayer = _shouldShowStickyPlayer;
              final maskPoster =
                  showStickyPlayer && _maskActiveVideoWithPoster;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Sticky player — outside PageView so photo→video never
                  // loses the GlobalKey mount inside keep-alive pages.
                  if (showStickyPlayer && active != null)
                    Positioned.fill(
                      child: _buildStickyReelPlayer(active, visibleIndex),
                    ),
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    clipBehavior: Clip.hardEdge,
                    dragStartBehavior: DragStartBehavior.down,
                    allowImplicitScrolling: true,
                    pageSnapping: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _videos.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      final isActivePage = index == visibleIndex;
                      final isActiveVideo = isActivePage &&
                          !video.isPhotoPost &&
                          video.isPlaybackReady;
                      // Pages never own the player — only posters + chrome.
                      final showPagePoster =
                          !isActiveVideo || maskPoster || video.isPhotoPost;
                      return ReelPageKeepAlive(
                        key: ValueKey<String>(
                          'collection_${video.id ?? 'video'}',
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomLeft,
                          fit: StackFit.expand,
                          children: [
                            ReelFeedPageMediaChrome(
                              video: video,
                              isActivePage: isActivePage,
                              child: RepaintBoundary(
                                child: IgnorePointer(
                                  ignoring: isActiveVideo && !maskPoster,
                                  child: Opacity(
                                    opacity: showPagePoster ? 1.0 : 0.0,
                                    child: ReelFeedPlayerKit.buildPagePoster(
                                      video,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isActivePage) ...[
                              VideoDescriptionWidget(
                                title: video.title,
                                description: video.description,
                                tags: video.tags,
                                controller: _homeController,
                                bottomBarClearance: 8,
                              ),
                              ReelOverlayColumn(
                                video: video,
                                isAuthenticated: _isAuthenticated,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  _buildTopBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
