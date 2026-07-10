import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/widgets/profile_user_title.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/reels_feed_client.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/reel_screen_playback_helpers.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/core/video/video_preload_target.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/reel_page_keep_alive.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart'
    show VideoDescriptionWidget;
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_overlay_column.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vertical reel viewer for own / visit profile — same player + preload path
/// as the General home feed (`ReelFeedPlayerKit` + `GET /api/reels?feed=user`).
class ProfileReelScreen extends StatefulWidget {
  const ProfileReelScreen({
    super.key,
    required this.userId,
    this.videoTypeId,
    this.anchorId,
    this.ownerDisplayName,
    this.ownerUserName,
    this.ownerImage,
    this.seedVideos,
    this.initialIndex = 0,
    this.initialPosterUrl,
  });

  final String userId;
  final String? videoTypeId;
  final String? anchorId;
  final String? ownerDisplayName;
  final String? ownerUserName;
  final String? ownerImage;
  /// Grid rows shown immediately — API may return empty while transcode catches up.
  final List<WallVideos>? seedVideos;
  final int initialIndex;
  /// Grid poster shown while the feed API loads (avoids black spinner screen).
  final String? initialPosterUrl;

  @override
  State<ProfileReelScreen> createState() => _ProfileReelScreenState();
}

class _ProfileReelScreenState extends State<ProfileReelScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  final GlobalKey<ReelVideoPlayerState> _reelPlayerKey =
      GlobalKey<ReelVideoPlayerState>();
  final ValueNotifier<int> _visibleIndexNotifier = ValueNotifier<int>(0);
  bool _maskActiveVideoWithPoster = true;
  bool _poolSessionReady = false;
  /// True when this screen pushed [pauseReelsForRouteOverlay] (own profile path).
  bool _ownsRouteOverlayPause = false;

  final List<WallVideos> _videos = [];
  FeedMeta? _meta;
  bool _isLoading = true;
  bool _isLoadingMore = false;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ensureVisitProfileDependencies();
    _homeController = Get.find<HomeController>();
    // Visit-profile shell already paused home; own-profile grid opens this
    // screen directly and must own the pause/resume pair.
    if (_homeController.routeOverlayPauseDepth == 0) {
      _homeController.pauseReelsForRouteOverlay();
      _ownsRouteOverlayPause = true;
    } else {
      _homeController.reinforceReelsPausedForOverlay();
    }

    var startIndex = 0;
    final seeds = widget.seedVideos;
    if (seeds != null && seeds.isNotEmpty) {
      _videos.addAll(seeds);
      startIndex = widget.initialIndex.clamp(0, _videos.length - 1);
      _visibleIndexNotifier.value = startIndex;
      _isLoading = false;
    }

    _pageController = PageController(initialPage: startIndex);
    _pageController.addListener(_onPageScrollOffset);
    // Profile shares the pool with home — never spawn off-screen MTK decoders
    // here (renderFps=0 zombies). Disk prefetch only; one visible decoder.
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

  int _resolveAnchorIndex(List<WallVideos> videos) {
    final anchor = widget.anchorId?.trim();
    if (anchor != null && anchor.isNotEmpty) {
      final idx = videos.indexWhere((v) => v.id == anchor);
      if (idx != -1) {
        return idx;
      }
    }
    return widget.initialIndex.clamp(0, videos.length - 1);
  }

  void _startPlaybackAt(int index, {int warmMaxWaitMs = 200}) {
    if (index < 0 || index >= _videos.length) {
      return;
    }
    _visibleIndexNotifier.value = index;
    unawaited(_preloadManager.bootstrapFromVisible(index));
    unawaited(_attachPlaybackForIndex(index, warmMaxWaitMs: warmMaxWaitMs));
  }

  /// API fetch overlaps pool teardown — serial await was adding hundreds of ms.
  ///
  /// Important: do **not** set [_poolSessionReady] before the first feed merge.
  /// Enabling the player while seeds are on screen, then clearing/replacing
  /// [_videos] in [_applyFeedResult], disposes the [ReelVideoPlayer] mid-reveal
  /// (logs: surface_revealed → dispose → render_confirm_failed).
  Future<void> _bootstrap() async {
    final feedFuture = ReelsFeedClient.fetchPage(
      reset: true,
      feed: 'user',
      userId: widget.userId,
      videoTypeId: widget.videoTypeId,
      anchorId: widget.anchorId,
    );
    final hadSeeds = _videos.isNotEmpty;
    await _loadAuth();
    if (!mounted) {
      return;
    }
    // [prepareForProfileReelRoute] already tore down the pool from the grid tap.
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

    if (hadSeeds) {
      final idx = _visibleIndexNotifier.value.clamp(0, _videos.length - 1);
      unawaited(
        _preloadManager.prefetchVisibleReel(idx, maxWaitMs: 360),
      );
      unawaited(_preloadManager.bootstrapFromVisible(idx));
    }

    await _applyFeedResult(await feedFuture);
    if (!mounted) {
      return;
    }
    if (!_poolSessionReady) {
      setState(() => _poolSessionReady = true);
    }
    final idx = _videos.isEmpty
        ? -1
        : _visibleIndexNotifier.value.clamp(0, _videos.length - 1);
    if (idx >= 0 && !_playbackLiveForId(_videos[idx].id)) {
      _startPlaybackAt(idx, warmMaxWaitMs: 360);
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
    try {
      await MediaKitPlayerPool.instance.awaitOperationsIdle();
      await MediaKitPlayerPool.instance.disposeAll();
    } finally {
      // Always release the pause pair (even if disposeAll throws) so Home is
      // not left with routeOverlayPauseDepth > 0 and a dead feed.
      if (_ownsRouteOverlayPause) {
        _homeController.resumeReelsAfterRouteOverlay();
        _ownsRouteOverlayPause = false;
      }
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

  Future<void> _applyFeedResult(ReelsFeedResult result) async {
    if (!mounted) {
      return;
    }
    if (result.feed == null) {
      if (_videos.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Failed to load videos';
        });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    final incoming = _filterVideosForActiveType(
      List<WallVideos>.from(result.feed!.videos ?? []),
    );
    _meta = result.feed!.meta;

    if (incoming.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final seeds = widget.seedVideos ?? const <WallVideos>[];
    final merged = _mergeApiWithSeedVideos(incoming, seeds);
    if (merged.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final visibleId = _videos.isNotEmpty
        ? _videos[_visibleIndexNotifier.value.clamp(0, _videos.length - 1)].id
        : widget.anchorId;
    var startIndex = _resolveAnchorIndex(merged);
    if (visibleId != null && visibleId.trim().isNotEmpty) {
      final keepIdx = merged.indexWhere((v) => v.id == visibleId);
      if (keepIdx != -1) {
        startIndex = keepIdx;
      }
    }

    setState(() {
      _videos
        ..clear()
        ..addAll(merged);
      _isLoading = false;
      _error = null;
      _visibleIndexNotifier.value = startIndex;
    });
    // Playback is started by [_bootstrap] after [_poolSessionReady] — starting
    // here while the player is still unmounted caused dispose mid-reveal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? startIndex) != startIndex) {
        _pageController.jumpToPage(startIndex);
      }
    });
  }

  List<WallVideos> _filterVideosForActiveType(List<WallVideos> videos) {
    final typeId = widget.videoTypeId?.trim();
    if (typeId == null || typeId.isEmpty) {
      return videos;
    }
    return videos
        .where((v) {
          final declared = v.videoType?.toString();
          return declared == null ||
              declared.isEmpty ||
              declared == typeId;
        })
        .toList();
  }

  /// API rows enrich grid seeds; seed-only rows stay when the reel API omits them.
  List<WallVideos> _mergeApiWithSeedVideos(
    List<WallVideos> api,
    List<WallVideos> seeds,
  ) {
    if (seeds.isEmpty) {
      return List<WallVideos>.from(api);
    }
    if (api.isEmpty) {
      return List<WallVideos>.from(seeds);
    }

    final seedById = <String, WallVideos>{
      for (final v in seeds)
        if ((v.id ?? '').trim().isNotEmpty) v.id!.trim(): v,
    };

    final merged = <WallVideos>[];
    final seen = <String>{};

    for (final apiRow in api) {
      final id = apiRow.id?.trim() ?? '';
      if (id.isEmpty) {
        merged.add(apiRow);
        continue;
      }
      if (!seen.add(id)) {
        continue;
      }
      final seed = seedById[id];
      merged.add(seed != null ? _enrichApiVideoFromSeed(apiRow, seed) : apiRow);
    }

    for (final seed in seeds) {
      final id = seed.id?.trim() ?? '';
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      merged.add(seed);
      seen.add(id);
    }

    return merged;
  }

  WallVideos _enrichApiVideoFromSeed(WallVideos api, WallVideos seed) {
    String? pick(String? primary, String? fallback) {
      final p = primary?.trim();
      if (p != null && p.isNotEmpty) {
        return p;
      }
      final f = fallback?.trim();
      if (f != null && f.isNotEmpty) {
        return f;
      }
      return primary;
    }

    api.videoUrl = pick(api.videoUrl, seed.videoUrl);
    api.video = pick(api.video, seed.video);
    api.hlsUrl = pick(api.hlsUrl, seed.hlsUrl);
    api.hlsPlaylistUrl = pick(api.hlsPlaylistUrl, seed.hlsPlaylistUrl);
    api.thumbnailUrl = pick(api.thumbnailUrl, seed.thumbnailUrl);
    api.imageUrl = pick(api.imageUrl, seed.imageUrl);
    api.image = pick(api.image, seed.image);
    api.transcodeStatus = pick(api.transcodeStatus, seed.transcodeStatus);
    api.processingStatus = pick(api.processingStatus, seed.processingStatus);
    if (api.videoSources == null && seed.videoSources != null) {
      api.videoSources = seed.videoSources;
    }
    return api;
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
    int warmMaxWaitMs = 200,
  }) async {
    if (index < 0 || index >= _videos.length) {
      return;
    }
    if (_videos[index].isPhotoPost) {
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
      warmMaxWaitMs: warmMaxWaitMs,
    );
  }

  Widget _buildInlineReelPlayer(WallVideos video, int index) {
    return ReelFeedPlayerKit.buildInlinePlayer(
      video: video,
      playerKey: _reelPlayerKey,
      showProgressBar: !video.isPhotoPost,
      onPlaybackReady: () {
        _onVisibleReelReady(index);
      },
      onFeedVideoPainted: _onFeedVideoPainted,
      onVideoCompleted: _onReelVideoCompleted,
    );
  }

  void _onReelVideoCompleted() {
    // Reels loop in place (PlaylistMode.single). The user swipes manually to
    // move to the next post — no auto-advance.
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
    if (_isLoadingMore || _videos.isEmpty) {
      return;
    }
    final meta = _meta;
    if (meta != null && !meta.hasMore) {
      return;
    }
    final cursor = meta?.nextCursor;
    if (cursor == null || cursor.isEmpty) {
      return;
    }

    _isLoadingMore = true;
    try {
      final result = await ReelsFeedClient.fetchPage(
        reset: false,
        nextCursor: cursor,
        feed: 'user',
        userId: widget.userId,
        videoTypeId: widget.videoTypeId,
      );
      if (!mounted || result.feed == null) {
        return;
      }
      var incoming = List<WallVideos>.from(result.feed!.videos ?? []);
      incoming = _filterVideosForActiveType(incoming);
      if (incoming.isEmpty) {
        if (_meta != null) {
          _meta!.hasMore = false;
        }
        setState(() {});
        return;
      }
      final existingIds = _videos
          .map((v) => v.id)
          .whereType<String>()
          .toSet();
      final unique = incoming
          .where((v) => v.id != null && !existingIds.contains(v.id))
          .toList();
      setState(() {
        _videos.addAll(unique);
        _meta = result.feed!.meta ?? _meta;
      });
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
    _reelPlayerKey.currentState?.cancelInFlightPlaybackForPageChange();
    _visibleIndexNotifier.value = index;
    _resetPosterMaskForPageChange(
      videoId: index < _videos.length ? _videos[index].id : null,
    );
    _scrollTowardIndex = null;
    final video = _videos[index];
    if (video.isPhotoPost) {
      MediaKitPlayerPool.instance.pauseAllImmediate();
      _scheduleViewTrack(video);
      return;
    }
    _scheduleViewTrack(video);
    unawaited(_attachPlaybackForIndex(index));

    if (_meta?.hasMore != false && index >= _videos.length - 3) {
      unawaited(_fetchMoreVideos());
    }
  }

  void _popProfileReel() {
    navigateBack();
  }


  Widget _buildTopRightVideoStats(WallVideos? video) {
    if (video == null) {
      return const SizedBox.shrink();
    }
    final videoId = video.id ?? '';
    Widget statsRow(ReelVideoStats stats) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            ReelVideoStats.formatCount(stats.viewCount),
            style: TextStyle(color: Colors.white, fontSize: 12.sp),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.favorite_border, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            ReelVideoStats.formatCount(stats.likeCount),
            style: TextStyle(color: Colors.white, fontSize: 12.sp),
          ),
        ],
      );
    }

    if (videoId.isEmpty) {
      return statsRow(ReelVideoStats.empty);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        return statsRow(ReelVideoStats.fromDoc(snapshot.data));
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<int>(
        valueListenable: _visibleIndexNotifier,
        builder: (context, visibleIndex, _) {
          final WallVideos? video = _videos.isNotEmpty
              ? _videos[visibleIndex.clamp(0, _videos.length - 1)]
              : null;
          final topInset = MediaQuery.paddingOf(context).top;
          return _buildTopBarContent(video, topInset);
        },
      ),
      ),
    );
  }

  Widget _buildTopBarContent(WallVideos? video, double topInset) {
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x00000000)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: topInset, left: 4, right: 12, bottom: 16),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _popProfileReel,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.ownerImage != null && widget.ownerImage!.isNotEmpty)
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: MediaUrlResolver.profileImageUrl(
                          widget.ownerImage,
                        ) ??
                        '',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    memCacheWidth: avatarMemCacheSize(36),
                    memCacheHeight: avatarMemCacheSize(36),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ProfileUserTitle(
                  displayName: widget.ownerDisplayName ?? video?.title,
                  userName:
                      widget.ownerUserName ?? video?.creatorHandle ?? video?.userName,
                  textAlign: TextAlign.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  nameStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.sp,
                  ),
                  handleStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              _buildTopRightVideoStats(video),
            ],
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

    if (_isLoading && _videos.isEmpty) {
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
                  placeholder: (_, __) => const ColoredBox(color: Colors.black),
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
          body: Stack(
            fit: StackFit.expand,
            children: [
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
                  return ReelPageKeepAlive(
                    key: ValueKey<String>('profile_${video.id ?? 'video'}'),
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
                            child: RepaintBoundary(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (isActiveVideo && _poolSessionReady)
                                    _buildInlineReelPlayer(video, index),
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
                              iconOnlyLikeAndSave: true,
                              hideViewAndLikeCounts: true,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  );
                },
              ),
              _buildTopBar(),
            ],
          ),
        ),
      ),
    );
  }
}
