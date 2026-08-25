import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/location/location_permission_gate.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/feed_disk_warm_service.dart';
import 'package:cookster/core/video/reels_feed_pin_store.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import '../../../../../services/apiClient.dart';
import '../../../../../services/video_processing_service.dart';
import '../homeModel/videoFeedModel.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:geolocator/geolocator.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  var isFollowing = false.obs;
  var rating = 0.0.obs;
  RxInt visiblePageIndex = 0.obs;

  var videoFeed = VideoFeed().obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var error = "".obs;
  var currentPage = 1.obs;
  static const int feedPageSize = 15;
  static const int reelsPageSize = 10;

  var currentIndex = 0.obs;

  final RxBool isReelsTabVisible = true.obs;
  final RxBool isVideoPlaying = true.obs;
  final RxBool isMuted = false.obs;
  var isNavigating = false.obs;
  var isAppInBackground = false.obs;
  int _routeOverlayPauseDepth = 0;

  /// How many overlay routes currently hold the home feed paused.
  int get routeOverlayPauseDepth => _routeOverlayPauseDepth;
  /// Rx so Obx trees under Home rebuild when camera/upload starts — a plain
  /// int was invisible to GetX and left the feed remounting under the form.
  final mediaCaptureDepth = 0.obs;
  int _playbackMuteDepth = 0;
  int _bottomNavMuteDepth = 0;
  bool _feedResumePendingWhenHomeTab = false;

  /// After camera/upload the shared pool + Camera2 surfaces are still tearing
  /// down. Opening Home too early mounts players onto abandoned BufferQueues
  /// (1x1 VideoOutput) and the feed stays permanently dead. Force a delayed
  /// cold remount on the next Home focus instead of an immediate restore.
  bool _needsColdRestoreAfterCapture = false;
  bool _coldRestoreInFlight = false;
  DateTime? _lastHealInvisibleAt;

  /// True while camera / picker / editor / upload flow holds feed decoders released.
  bool get isInMediaCaptureFlow => mediaCaptureDepth.value > 0;

  /// Set when an overlay disposed the feed pool while the user is not on Home.
  bool get feedResumePendingWhenHomeTab => _feedResumePendingWhenHomeTab;

  /// Post-upload / post-camera: pool wipe + delayed remount still pending or running.
  bool get needsColdRestoreAfterCapture => _needsColdRestoreAfterCapture;

  bool get coldRestoreInFlight => _coldRestoreInFlight;

  var lastVideoPosition = Duration.zero.obs;
  var wasPlaying = false.obs;

  Timer? _debounceTimer;
  Timer? _fetchMoreDebounce;
  DateTime? _lastMemoryPressureCleanupAt;
  Worker? _homeTabResumeWorker;

  /// Rebuild reels [PageView] only when list length changes (not every [videoFeed.refresh]).
  final reelListLength = 0.obs;

  /// Bumped after a full feed reset (tab switch, GPS refresh, filter apply) so
  /// the reels UI reattaches the visible player — same lifecycle as General.
  final feedPlaybackEpoch = 0.obs;

  /// Bumped whenever the home [ReelVideoPlayer] may remount after being torn
  /// down (camera / upload / mute). Forces a fresh [GlobalKey] so Flutter does
  /// not reactivate a disposed StatefulElement (`Null check` on activate).
  final feedPlayerMountEpoch = 0.obs;

  void _bumpFeedPlayerMountEpoch() {
    feedPlayerMountEpoch.value++;
  }

  /// Home icon re-tap: next [_finishFeedTabPlayback] must land on index 0 and
  /// autoplay — ignore any previous pin / page index.
  bool _preferNewestAttach = false;

  /// In-flight reel-screen teardown (profile/collection dispose+resume).
  /// Grid taps await this before opening a new reel screen so the previous
  /// screen's late [resumeReelsAfterRouteOverlay] doesn't clobber the new one.
  /// Monotonic token identifying which reel screen currently owns the shared
  /// player pool. A reel screen claims it in initState; its dispose-time
  /// teardown only runs disposeAll if it is still the owner, so a rapid
  /// close→reopen can never have the old screen's teardown destroy the new
  /// screen's freshly created players (black screen / disposed-player crash).
  int _reelPoolSessionToken = 0;
  int claimReelPoolSession() => ++_reelPoolSessionToken;
  bool isReelPoolSessionCurrent(int token) => token == _reelPoolSessionToken;

  Future<void>? _pendingReelTeardown;
  Future<void> awaitPendingReelTeardown() async {
    // Claim pool ownership FIRST so any in-flight previous teardown skips
    // disposeAll — otherwise the old screen's late disposeAll runs after we
    // await it (token not yet claimed by the new screen) and wipes players
    // that the new screen is about to mount → dead/stuck screen on reopen.
    claimReelPoolSession();
    final f = _pendingReelTeardown;
    if (f != null) {
      // Defensive timeout: a hung pool teardown must never permanently block
      // reopening a collection/profile reel (the "tap does nothing" bug).
      await f.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );
    }
  }

  /// Register an in-flight reel-screen teardown future. Cleared by
  /// [clearReelTeardown] once it completes (only if still the current one).
  void registerReelTeardown(Future<void> future) {
    _pendingReelTeardown = future;
  }

  void clearReelTeardown(Future<void> future) {
    if (identical(_pendingReelTeardown, future)) {
      _pendingReelTeardown = null;
    }
  }

  bool consumePreferNewestAttach() {
    final v = _preferNewestAttach;
    _preferNewestAttach = false;
    return v;
  }

  bool get prefersNewestAttach => _preferNewestAttach;

  /// Last successful feed per tab — instant UI when switching عام / بالقرب / المتابعة.
  /// Keys include General sort + location filter so stale unfiltered rows are never reused.
  final Map<String, VideoFeed> _tabFeedCache = {};

  String _tabFeedCacheKey(String tab) {
    if (tab == 'General') {
      if (hasGeneralLocationFilter) {
        return 'General|${feedSortOrder.value}|'
            '${generalFilterCountryId.value}|${generalFilterCityId.value}';
      }
      return 'General|${feedSortOrder.value}|all';
    }
    return tab;
  }

  VideoFeed? _cachedFeedForTab(String tab) =>
      _tabFeedCache[_tabFeedCacheKey(tab)];

  void _storeFeedCacheForTab(String tab, VideoFeed feed) {
    _tabFeedCache[_tabFeedCacheKey(tab)] = feed;
  }

  void _clearFeedCacheForTab(String tab) {
    _tabFeedCache.remove(_tabFeedCacheKey(tab));
  }

  /// Last scroll position per tab so switching tabs doesn't rewind to reel 0.
  final Map<String, int> _tabScrollIndex = {};

  /// Last visible video id per tab — restores exact reel if feed order shifts.
  final Map<String, String> _tabVideoId = {};

  /// Blocks [_refreshTabCacheSilently] while a feed tab switch is in flight
  /// (cache reorder race — see tab-switch handler in [VideoReelScreen]).
  bool _feedTabSwitchLocked = false;

  bool get isFeedTabSwitchLocked => _feedTabSwitchLocked;

  void beginFeedTabSwitch() => _feedTabSwitchLocked = true;

  void endFeedTabSwitch() => _feedTabSwitchLocked = false;

  /// Set after a successful upload — forces a network reload instead of
  /// remounting the pre-upload [videoFeed] snapshot (HomeController is permanent).
  bool _feedStaleAfterUpload = false;
  String? _pendingUploadVideoId;
  String? _pendingUploadResponseBody;

  bool get feedStaleAfterUpload => _feedStaleAfterUpload;

  /// Drop cached tab rows + live feed so General / Near Me refetch after upload.
  void markFeedStaleAfterUpload({
    String? videoId,
    String? responseBody,
  }) {
    _feedStaleAfterUpload = true;
    if (videoId != null && videoId.isNotEmpty) {
      _pendingUploadVideoId = videoId;
    }
    if (responseBody != null && responseBody.isNotEmpty) {
      _pendingUploadResponseBody = responseBody;
    }
    _tabFeedCache.clear();
    videoFeed.value = VideoFeed(status: true, videos: []);
    reelListLength.value = 0;
  }

  Future<void> refreshFeedAfterUploadIfNeeded() async {
    final pendingId = _pendingUploadVideoId;
    if (!_feedStaleAfterUpload &&
        (pendingId == null || pendingId.isEmpty)) {
      return;
    }

    if (pendingId != null && pendingId.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[FeedRestore] awaiting upload processing id=$pendingId',
        );
      }
      try {
        await VideoProcessingService.pollUntilSettled(
          pendingId,
          waitForTranscode: false,
        ).timeout(const Duration(seconds: 20), onTimeout: () => null);
      } catch (_) {}
    }

    _feedStaleAfterUpload = false;
    setSelectedType('General');
    resetTabScrollRestore('General');
    await fetchVideos(forceNetwork: true, resetScrollPosition: true);
    await _surfacePendingUploadAtTop();
  }

  /// Ensures the just-uploaded row is first when the API/pin has not caught up.
  Future<void> _surfacePendingUploadAtTop() async {
    final videoId = _pendingUploadVideoId;
    if (videoId == null || videoId.isEmpty) {
      return;
    }

    var videos = List<WallVideos>.from(videoFeed.value.videos ?? []);
    if (videos.isEmpty) {
      final local = VideoProcessingService.wallVideoFromUploadResponse(
        _pendingUploadResponseBody,
      );
      if (local != null) {
        videos = [local];
      } else {
        return;
      }
    }

    final existingIdx = videos.indexWhere((v) => v.id == videoId);
    if (existingIdx < 0) {
      final local = VideoProcessingService.wallVideoFromUploadResponse(
        _pendingUploadResponseBody,
      );
      if (local != null) {
        videos.insert(0, local);
        if (kDebugMode) {
          debugPrint(
            '[FeedRestore] prepended upload id=$videoId (not in API page yet)',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '[FeedRestore] upload id=$videoId missing from feed and no local row',
          );
        }
        return;
      }
    } else if (existingIdx > 0) {
      final row = videos.removeAt(existingIdx);
      videos.insert(0, row);
      if (kDebugMode) {
        debugPrint(
          '[FeedRestore] moved upload id=$videoId to index 0 (was $existingIdx)',
        );
      }
    }

    videoFeed.value = VideoFeed(
      status: videoFeed.value.status,
      videos: videos,
      meta: videoFeed.value.meta,
    );
    reelListLength.value = videos.length;
    _storeFeedCacheForTab('General', videoFeed.value);
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
    feedPlaybackEpoch.value++;
    _pendingUploadVideoId = null;
    _pendingUploadResponseBody = null;
    update();
  }

  // New reactive variables for location checks
  var isLocationServiceEnabled = true.obs; // Default to true until checked
  var isLocationPermissionGranted = false.obs; // Default to false until checked

  @override
  void onInit() {
    super.onInit();
    checkLocationStatus();
    WidgetsBinding.instance.addObserver(this);
    _bindHomeTabResumeWorker();
    unawaited(_bootstrapHomeFeed());
  }

  void _bindHomeTabResumeWorker() {
    if (!Get.isRegistered<NavBarController>()) {
      return;
    }
    _homeTabResumeWorker?.dispose();
    _homeTabResumeWorker = ever(
      Get.find<NavBarController>().selectedIndex,
      (index) {
        if (index != 0 || !_feedResumePendingWhenHomeTab) {
          return;
        }
        _flushPendingFeedResume();
      },
    );
  }

  static const _prefGeneralLocationFilter = 'generalLocationFilterActive';
  static const _prefGeneralFilterCountry = 'generalFilterCountry';
  static const _prefGeneralFilterCity = 'generalFilterCity';
  static const _prefGeneralFilterCountryId = 'generalFilterCountryId';
  static const _prefGeneralFilterCityId = 'generalFilterCityId';
  /// Legacy pref from when manual filter was incorrectly tied to Near Me.
  static const _prefNearMeManualFilter = 'nearMeManualFilterActive';

  /// Restore last known coords so Near Me can load before GPS finishes.
  Future<void> _restoreLocationFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    var generalFilter =
        prefs.getBool(_prefGeneralLocationFilter) ??
        prefs.getBool(_prefNearMeManualFilter) ??
        false;
    generalLocationFilterActive.value = generalFilter;

    final lat = prefs.getDouble('latitude');
    final lng = prefs.getDouble('longitude');
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      latitude.value = lat.toString();
      longitude.value = lng.toString();
    }
    final city = prefs.getString('currentCity');
    final country = prefs.getString('currentCountry');
    if (city != null && city.isNotEmpty) {
      currentCity.value = city;
    }
    if (country != null && country.isNotEmpty) {
      currentCountry.value = country;
    }
    if (generalFilter) {
      generalFilterCountry.value =
          prefs.getString(_prefGeneralFilterCountry) ?? '';
      generalFilterCity.value = prefs.getString(_prefGeneralFilterCity) ?? '';
      generalFilterCountryId.value =
          prefs.getString(_prefGeneralFilterCountryId) ?? '';
      generalFilterCityId.value =
          prefs.getString(_prefGeneralFilterCityId) ?? '';
      // Legacy Near Me manual filter could set the flag without explicit ids.
      // Never guess from GPS currentCountryId — that produced wrong filters
      // (e.g. country 45 vs catalog 194 for Saudi Arabia).
      if (generalFilterCountryId.value.isEmpty) {
        generalLocationFilterActive.value = false;
        generalFilter = false;
        generalFilterCountry.value = '';
        generalFilterCity.value = '';
        generalFilterCityId.value = '';
        await prefs.setBool(_prefGeneralLocationFilter, false);
        await prefs.remove(_prefNearMeManualFilter);
      }
    } else {
      generalFilterCountry.value = '';
      generalFilterCity.value = '';
      generalFilterCountryId.value = '';
      generalFilterCityId.value = '';
    }
  }

  Future<void> _bootstrapHomeFeed() async {
    await _restoreLocationFromPrefs();
    await _resolveLocationIdsFromStoredNames();
    await ReelsFeedPinStore.instance.restoreFromPrefs();
    await fetchVideos();
    if (selectedType.value == 'Near Me') {
      unawaited(fetchLocationOnce(refreshNearMeFeed: true));
    }
  }

  /// True while the OS location-permission sheet may be showing (iOS fires
  /// [AppLifecycleState.inactive] — must not tear down the feed player for that).
  bool get isLocationPermissionPromptVisible =>
      _awaitingLocationPermissionPrompt;

  /// Covers permission prompt + GPS lookup for Near Me — iOS also sends [paused].
  bool get isInNearMeLocationPermissionFlow => _nearMeLocationFlowDepth > 0;

  void _beginNearMeLocationFlow() {
    _nearMeLocationFlowDepth++;
  }

  void _endNearMeLocationFlow() {
    if (_nearMeLocationFlowDepth > 0) {
      _nearMeLocationFlowDepth--;
    }
  }

  /// Only block the feed on the first Near Me cold start when we have no coords
  /// and nothing to show yet. Background GPS refresh must not tear down a feed
  /// that is already playing (same UX as General).
  bool get blocksUiForLocation =>
      selectedType.value == 'Near Me' &&
      isLocationFetching.value &&
      !hasLocationBeenFetched.value &&
      (videoFeed.value.videos?.isEmpty ?? true);

  String get _reelsFeedMode {
    switch (selectedType.value) {
      case 'Near Me':
        return 'near_me';
      case 'Following':
        return 'following';
      default:
        return 'general';
    }
  }

  String? _pendingPinForTab(String tab) {
    final feedMode =
        tab == 'General'
            ? 'general'
            : tab == 'Near Me'
            ? 'near_me'
            : 'following';
    String? requestCountry;
    String? requestCity;
    if (tab == 'General' && hasGeneralLocationFilter) {
      requestCountry = generalFilterCountryId.value;
      requestCity = generalFilterCityId.value;
    }
    return ReelsFeedPinStore.instance.pinVideoIdForFirstPage(
      feedMode: feedMode,
      requestCountry: requestCountry,
      requestCity: requestCity,
      requestSortBy: feedSortOrder.value,
    );
  }

  Future<void> fetchMoreVideos() async {
    _fetchMoreDebounce?.cancel();
    _fetchMoreDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fetchMoreVideosNow());
    });
  }

  Future<void> _fetchMoreVideosNow() async {
    if (isLoading.value ||
        isLoadingMore.value ||
        videoFeed.value.videos == null ||
        videoFeed.value.videos!.isEmpty) {
      return;
    }

    final meta = videoFeed.value.meta;
    if (meta != null && !meta.hasMore) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final parsed = await _fetchFeedPage(reset: false);
      if (parsed == null) {
        return;
      }

      final incoming = parsed.videos ?? [];
      if (incoming.isEmpty) {
        if (videoFeed.value.meta != null) {
          videoFeed.value.meta!.hasMore = false;
        }
        videoFeed.refresh();
        return;
      }

      final existingIds = videoFeed.value.videos!
          .map((v) => v.id)
          .whereType<String>()
          .toSet();
      final uniqueIncoming = incoming
          .where((v) => v.id != null && !existingIds.contains(v.id))
          .toList();

      // Cursor pages arrive in sort order — append only. Re-sorting the full
      // list reshuffles indices and swaps the reel at the user's scroll position.
      videoFeed.value.videos!.addAll(uniqueIncoming);
      videoFeed.value.meta = parsed.meta ?? videoFeed.value.meta;
      if (parsed.meta?.page != null) {
        currentPage.value = parsed.meta!.page!;
      }
      reelListLength.value = videoFeed.value.videos!.length;
      // Mirror the full paginated list into the tab cache so a sub-tab switch
      // and back can restore the exact reel by id (the cache used to stay
      // page-1 only, so paginated ids went missing and restore fell to index 0).
      _storeFeedCacheForTab(selectedType.value, videoFeed.value);
      // Warm the first reels of the freshly appended page so crossing the
      // pagination boundary doesn't stall waiting on a live CDN fetch.
      _prefetchNewPageHead(uniqueIncoming);
    } catch (e) {
      error.value = "Error loading more videos: $e";
    } finally {
      isLoadingMore.value = false;
      update();
    }
  }

  /// Disk-warm the first couple of reels of a newly appended page so the user
  /// hits cached bytes at the pagination boundary instead of a live CDN fetch.
  void _prefetchNewPageHead(List<WallVideos> videos) {
    if (videos.isEmpty) {
      return;
    }
    const resolver = VideoSourceResolver();
    for (final video in videos.take(2)) {
      // resolveForWallVideo returns [] for photo posts, so no isPhotoPost check.
      final candidates = resolver.resolveForWallVideo(video);
      if (candidates.isEmpty) {
        continue;
      }
      final preload =
          resolver.prioritizeForPreload(candidates, offsetFromVisible: 1);
      for (final candidate in preload) {
        prefetchPlaybackUrl(candidate.url, priority: 85);
      }
    }
  }

  Future<VideoFeed?> _fetchFeedPage({required bool reset}) async {
    return _fetchReelsPage(reset: reset);
  }

  Future<VideoFeed?> _fetchReelsPage({required bool reset}) async {
    final params = <String, String>{};
    if (!reset) {
      final cursor = videoFeed.value.meta?.nextCursor;
      if (cursor != null && cursor.isNotEmpty) {
        params['cursor'] = cursor;
      }
    } else {
      final feed = _reelsFeedMode;
      if (feed != 'general') {
        params['feed'] = feed;
      }
    }

    // Near Me uses device GPS; optional city/country ids help server city-scope.
    if (selectedType.value == 'Near Me') {
      if (latitude.value.isNotEmpty) {
        params['latitude'] = latitude.value;
      }
      if (longitude.value.isNotEmpty) {
        params['longitude'] = longitude.value;
      }
      if (nearMeFilterCountryId.value.isNotEmpty &&
          nearMeFilterCountryId.value != '-1') {
        params['country'] = nearMeFilterCountryId.value;
      }
      if (nearMeFilterCityId.value.isNotEmpty &&
          nearMeFilterCityId.value != '-1') {
        params['city'] = nearMeFilterCityId.value;
      }
    }

    // General tab location filter only (country/city picker in filter sheet).
    if (selectedType.value == 'General' && hasGeneralLocationFilter) {
      if (generalFilterCountryId.value.isNotEmpty) {
        params['country'] = generalFilterCountryId.value;
      }
      if (generalFilterCityId.value.isNotEmpty) {
        params['city'] = generalFilterCityId.value;
      }
    }
    
    // Attach the active sort order. Since sorting is uniform across pagination
    // cursors and the backend uses created_at + sort_by to paginate reliably,
    // this should always be sent.
    if (feedSortOrder.value.isNotEmpty) {
      params['sort_by'] = feedSortOrder.value;
    }

    var pinSent = false;
    if (reset) {
      final pinId = ReelsFeedPinStore.instance.pinVideoIdForFirstPage(
        feedMode: _reelsFeedMode,
        requestCountry: params['country'],
        requestCity: params['city'],
        requestSortBy: feedSortOrder.value,
      );
      if (pinId != null && pinId.isNotEmpty) {
        params['pin_video_id'] = pinId;
        pinSent = true;
      }
    }

    var endpoint = EndPoints.reels;
    if (params.isNotEmpty) {
      endpoint = '$endpoint?${Uri(queryParameters: params).query}';
    }

    final response = await ApiClient.getRequest(endpoint);
    if (response.statusCode == 401) {
      error.value = 'Authentication required';
      return null;
    }
    if (response.statusCode != 200) {
      error.value = 'Failed to load reels: ${response.statusCode}';
      return null;
    }
    final parsed = await compute(parseVideoFeed, response.body);
    _sortFeedByOrder(parsed);
    final echoedSort = parsed.meta?.sortBy?.trim();
    // Only write when the value actually changes — assigning the same string
    // can still fire Obx workers that blank the active player after attach.
    if ((echoedSort == 'newest' || echoedSort == 'oldest') &&
        echoedSort != feedSortOrder.value) {
      feedSortOrder.value = echoedSort!;
    }
    if (kDebugMode &&
        (selectedType.value == 'Near Me' || selectedType.value == 'General')) {
      final cityIds = <int, int>{};
      for (final video in parsed.videos ?? const []) {
        final id = video.cityId;
        if (id != null && id > 0) {
          cityIds[id] = (cityIds[id] ?? 0) + 1;
        }
      }
      debugPrint(
        '${selectedType.value} reels: count=${parsed.videos?.length ?? 0} '
        'geo_fallback=${parsed.meta?.geoFallback ?? false} '
        'geo_scope=${parsed.meta?.geoScope ?? ''} '
        'geo_city=${parsed.meta?.geoCityName ?? ''} '
        'geo_city_id=${parsed.meta?.geoCityId ?? ''} '
        'geo_group=${parsed.meta?.geoCityGroupNames ?? parsed.meta?.geoCityGroupIds ?? ''} '
        'page_city_ids=$cityIds '
        'geo_radius_km=${parsed.meta?.geoRadiusKm ?? ''} '
        'pinned=${parsed.meta?.pinnedVideoId ?? 'none'} '
        'pin_sent=$pinSent '
        'generalLocationFilter=$hasGeneralLocationFilter '
        'lat=${latitude.value} lng=${longitude.value} '
        'nearMeCityId=${nearMeFilterCityId.value} '
        'filterCountryId=${generalFilterCountryId.value} '
        'filterCityId=${generalFilterCityId.value}',
      );
    }
    if (reset && pinSent) {
      final pinned = parsed.meta?.pinnedVideoId?.trim();
      if (pinned != null && pinned.isNotEmpty) {
        await ReelsFeedPinStore.instance.clearPin();
      } else if (kDebugMode) {
        debugPrint(
          '[FeedPin] pin sent but server did not pin — keeping for retry',
        );
      }
    }
    return parsed;
  }


  Future<void> checkLocationStatus() async {
    isLocationServiceEnabled.value =
        !await Permission.location.serviceStatus.isDisabled;
    isLocationPermissionGranted.value =
        await Permission.location.status.isGranted;

    print(
      'Location Service Enabled: ${isLocationServiceEnabled.value}, Location Permission Granted: ${isLocationPermissionGranted.value}',
    );
  }

  @override
  void onClose() {
    _homeTabResumeWorker?.dispose();
    _debounceTimer?.cancel();
    _fetchMoreDebounce?.cancel();
    pauseAllVideos();
    // Permanent controller: onClose is rare (force-delete). Still guard the
    // shared pool wipe so a late release cannot race a remount.
    disposeControllers();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   isAppInBackground.value = state == AppLifecycleState.paused;
  //   if (isAppInBackground.value) {
  //     pauseCurrentVideo();
  //   } else if (state == AppLifecycleState.resumed) {
  //     restoreVideoState();
  //   }
  // }

  @override
  void didHaveMemoryPressure() {
    final now = DateTime.now();
    if (_lastMemoryPressureCleanupAt != null &&
        now.difference(_lastMemoryPressureCleanupAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    _lastMemoryPressureCleanupAt = now;
    final cache = PaintingBinding.instance.imageCache;
    final oldMax = cache.maximumSize;
    cache.maximumSize = 100;
    cache.clearLiveImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cache.maximumSize = oldMax;
    });
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    unawaited(
      MediaKitPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
    unawaited(
      VideoPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
  }

  var currentCity = "".obs;
  var latitude = "".obs;
  var longitude = "".obs;
  var currentCountry = "".obs;

  /// General-tab country/city filter (does not affect Near Me GPS feed).
  final generalLocationFilterActive = false.obs;
  var generalFilterCountry = "".obs;
  var generalFilterCity = "".obs;
  var generalFilterCountryId = "".obs;
  var generalFilterCityId = "".obs;

  /// Resolved from GPS for optional Near Me `city` / `country` query params.
  var nearMeFilterCountryId = "".obs;
  var nearMeFilterCityId = "".obs;

  /// Apple iOS Simulator default GPS (Union Square, San Francisco).
  static const double iosSimulatorDefaultLat = 37.785834;
  static const double iosSimulatorDefaultLng = -122.406417;

  bool get isLikelyIosSimulatorDefaultLocation {
    final lat = double.tryParse(latitude.value);
    final lng = double.tryParse(longitude.value);
    if (lat == null || lng == null) {
      return false;
    }
    return (lat - iosSimulatorDefaultLat).abs() < 0.002 &&
        (lng - iosSimulatorDefaultLng).abs() < 0.002;
  }

  bool get hasGeneralLocationFilter =>
      generalLocationFilterActive.value &&
      generalFilterCountryId.value.isNotEmpty;

  var feedSortOrder = "newest".obs;

  void _teardownFeedForReload(String tab) {
    // Same teardown as [refreshHomeFeed] — without it, filter apply + modal
    // dismiss races restore and leaves the pool claiming a visible reel with
    // no mounted Video surface (all videos appear dead).
    MediaKitPlayerPool.instance.pauseAllImmediate();
    MediaKitPlayerPool.instance.silenceAllSync();
    unawaited(MediaKitPlayerPool.instance.clearFeedVisibleReel());
    _routeOverlayPauseDepth = 0;
    _playbackMuteDepth = 0;
    _bottomNavMuteDepth = 0;
    mediaCaptureDepth.value = 0;
    _feedResumePendingWhenHomeTab = false;
    isNavigating.value = false;
    isVideoPlaying.value = true;
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    setReelsTabVisible(true);

    _preferNewestAttach = true;
    _tabFeedCache.clear();
    resetTabScrollRestore(tab);
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
    videoFeed.value = VideoFeed(status: true, videos: []);
    reelListLength.value = 0;
  }

  void setSortOrder(String order) {
    if (feedSortOrder.value == order) return;
    feedSortOrder.value = order;
    _teardownFeedForReload(selectedType.value);
    unawaited(fetchVideos(forceNetwork: true, resetScrollPosition: true));
  }

  Future<void> applyFeedLocationFilterAndRefresh({
    required String countryId,
    required String countryName,
    required String cityId,
    required String cityName,
  }) async {
    applyGeneralLocationFilter(
      countryId: countryId,
      countryName: countryName,
      cityId: cityId,
      cityName: cityName,
    );
    if (selectedType.value != 'General') {
      setSelectedType('General');
    }
    _teardownFeedForReload('General');
    await fetchVideos(forceNetwork: true, resetScrollPosition: true);
    await saveGeneralFilterData();
  }

  Future<void> clearFeedLocationFilterAndRefresh() async {
    await clearGeneralLocationFilter();
    if (selectedType.value != 'General') {
      setSelectedType('General');
    }
    _teardownFeedForReload('General');
    await fetchVideos(forceNetwork: true, resetScrollPosition: true);
  }

  /// Maps GPS/display city names to API catalog ids for upload + filter consistency.
  Future<void> _resolveLocationIdsFromStoredNames() async {
    if (!Get.isRegistered<VideoAddController>()) {
      return;
    }
    final country = currentCountry.value.trim();
    final city = currentCity.value.trim();
    if (country.isEmpty ||
        city.isEmpty ||
        country == 'Unknown' ||
        city == 'Unknown') {
      return;
    }
    try {
      final upload = Get.find<VideoAddController>();
      upload.selectedCountry.value = country;
      upload.selectedCity.value = city;
      final prefs = await SharedPreferences.getInstance();
      final state = prefs.getString('currentState');
      final ready = await upload.ensureLocationIdsReady(
        alternateCityName: state,
      );
      if (ready) {
        nearMeFilterCountryId.value =
            upload.selectedLocationId.value.toString();
        nearMeFilterCityId.value = upload.selectedCityId.value.toString();
        // Warm the city catalog so Near Me group banners can resolve sibling
        // names (Dhahran / Khobar / Dammam) from city_id on each reel.
        final countryId = upload.selectedLocationId.value;
        if (countryId > 0 && Get.isRegistered<CityController>()) {
          unawaited(Get.find<CityController>().fetchCities(countryId));
        }
        if (kDebugMode) {
          debugPrint(
            '[LocationIds] resolved countryId=${upload.selectedLocationId.value} '
            'cityId=${upload.selectedCityId.value} for $city, $country',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationIds] resolve failed: $e');
      }
    }
  }

  /// Drop saved tab position so a sort/filter reload always opens at reel 0.
  void resetTabScrollRestore(String tab) {
    _tabVideoId.remove(tab);
    saveTabScrollIndex(tab, 0);
  }

  void _sortFeedByOrder(VideoFeed feed) {
    final videos = feed.videos;
    if (videos == null || videos.length < 2) {
      return;
    }

    int rank(WallVideos video) {
      final created = video.createdAt;
      if (created != null && created.isNotEmpty) {
        final parsed = DateTime.tryParse(created);
        if (parsed != null) {
          return parsed.millisecondsSinceEpoch;
        }
      }
      final updated = video.updatedAt;
      if (updated != null && updated.isNotEmpty) {
        final parsed = DateTime.tryParse(updated);
        if (parsed != null) {
          return parsed.millisecondsSinceEpoch;
        }
      }
      return 0;
    }

    if (feedSortOrder.value == 'oldest') {
      videos.sort((a, b) => rank(a).compareTo(rank(b)));
    } else {
      videos.sort((a, b) => rank(b).compareTo(rank(a)));
    }
  }

  // Add flags to track if location has been fetched
  var hasLocationBeenFetched = false.obs;
  var isLocationFetching = false.obs;
  var _awaitingLocationPermissionPrompt = false;
  int _nearMeLocationFlowDepth = 0;
  bool _preferSoftFeedResumeAfterLocation = false;

  // Make sure you have these imports:
  // import 'package:geocoding/geocoding.dart';

  Future<void> fetchLocationOnce({
    bool refreshNearMeFeed = false,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      hasLocationBeenFetched.value = false;
    }
    final needsInitialLocation = !hasLocationBeenFetched.value &&
        latitude.value.isEmpty &&
        longitude.value.isEmpty;
    final protectPlaybackDuringFlow =
        refreshNearMeFeed && selectedType.value == 'Near Me';
    if (protectPlaybackDuringFlow) {
      _beginNearMeLocationFlow();
    }
    final prevLat = double.tryParse(latitude.value);
    final prevLng = double.tryParse(longitude.value);
    if (selectedType.value == 'Near Me' && needsInitialLocation) {
      isLocationFetching.value = true;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error.value = "Location service is disabled";
        return;
      }

      _awaitingLocationPermissionPrompt = true;
      final LocationPermission permission;
      try {
        permission = await LocationPermissionGate.ensurePermission();
      } finally {
        _awaitingLocationPermissionPrompt = false;
      }
      if (!LocationPermissionGate.isGranted(permission)) {
        error.value = "Location permission denied";
        return;
      }

      final position = await LocationPermissionGate.currentPosition(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      if (position == null ||
          (position.latitude == 0 && position.longitude == 0)) {
        error.value = "Unable to get location coordinates";
        return;
      }

      print('Location: ${position.latitude}, ${position.longitude}');

      await setLocaleIdentifier('en_US');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        currentCity.value = (placemark.locality ?? 'Unknown').trim();
        currentCountry.value = (placemark.country ?? 'Unknown').trim();
        String currentState =
            (placemark.administrativeArea ?? 'Unknown').trim();

        latitude.value = position.latitude.toString();
        longitude.value = position.longitude.toString();

        if (kDebugMode) {
          debugPrint(
            '[NearMe GPS] lat=${position.latitude} lng=${position.longitude} '
            'city=${currentCity.value} country=${currentCountry.value}',
          );
        }

        print('=== Location Details ===');
        print('Latitude: ${position.latitude}');
        print('Longitude: ${position.longitude}');
        print('City (Locality): ${placemark.locality ?? 'Unknown'}');
        print('Country: ${placemark.country ?? 'Unknown'}');
        print(
          'State/Province: ${placemark.administrativeArea ?? 'Unknown'}',
        );
        print('Postal Code: ${placemark.postalCode ?? 'Unknown'}');
        print(
          'Sub-Administrative Area: ${placemark.subAdministrativeArea ?? 'Unknown'}',
        );
        print('Sub-Locality: ${placemark.subLocality ?? 'Unknown'}');
        print('Street: ${placemark.street ?? 'Unknown'}');
        print('Name: ${placemark.name ?? 'Unknown'}');
        print('ISO Country Code: ${placemark.isoCountryCode ?? 'Unknown'}');
        print('Thoroughfare: ${placemark.thoroughfare ?? 'Unknown'}');
        print('Sub-Thoroughfare: ${placemark.subThoroughfare ?? 'Unknown'}');
        print('=== End Location Details ===');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentCity', currentCity.value);
        await prefs.setString('currentCountry', currentCountry.value);
        await prefs.setString('currentState', currentState);
        await prefs.setString('postalCode', placemark.postalCode ?? 'Unknown');
        await prefs.setDouble('latitude', position.latitude);
        await prefs.setDouble('longitude', position.longitude);

        await _resolveLocationIdsFromStoredNames();

        hasLocationBeenFetched.value = true;
        print(
          'Location fetched - City: ${currentCity.value}, Country: ${currentCountry.value}, '
          'State: $currentState, Latitude: ${position.latitude}, Longitude: ${position.longitude}',
        );
      } else {
        currentCity.value = 'Unknown';
        currentCountry.value = 'Unknown';
        print('No placemarks found');
      }
    } catch (e) {
      print('Error fetching location: $e');
      error.value = "Error fetching location: $e";
    } finally {
      isLocationFetching.value = false;
      if (!refreshNearMeFeed ||
          selectedType.value != 'Near Me' ||
          !hasLocationBeenFetched.value) {
        if (protectPlaybackDuringFlow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _endNearMeLocationFlow();
          });
        }
        return;
      }
      // Only skip while a fetch is in-flight if we already have a playable feed.
      if (isLoading.value && (videoFeed.value.videos?.isNotEmpty ?? false)) {
        if (protectPlaybackDuringFlow) {
          _preferSoftFeedResumeAfterLocation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _endNearMeLocationFlow();
            resumeAfterAppForegroundIfAllowed(soft: true);
          });
        }
        return;
      }
      final hasFeed = videoFeed.value.videos?.isNotEmpty ?? false;
      if (hasFeed) {
        _preferSoftFeedResumeAfterLocation = true;
        final newLat = double.tryParse(latitude.value);
        final newLng = double.tryParse(longitude.value);
        final moved = prevLat == null ||
            prevLng == null ||
            newLat == null ||
            newLng == null ||
            (newLat - prevLat).abs() > 0.02 ||
            (newLng - prevLng).abs() > 0.02;
        if (moved) {
          unawaited(fetchVideos(backgroundRefresh: true));
        }
        if (protectPlaybackDuringFlow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _endNearMeLocationFlow();
            resumeAfterAppForegroundIfAllowed(soft: true);
          });
        }
        return;
      }
      unawaited(fetchVideos(forceNetwork: true));
      if (protectPlaybackDuringFlow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _endNearMeLocationFlow();
        });
      }
    }
  }

  /// Near Me must not surface the server's general-feed geo fallback as local reels.
  VideoFeed _nearMeFeedWithoutGeneralFallback(VideoFeed parsed) {
    if (parsed.meta?.geoFallback != true) {
      return parsed;
    }
    if (kDebugMode) {
      debugPrint(
        '[NearMe] geo_fallback filtered — empty Near Me '
        '(server returned ${parsed.videos?.length ?? 0} general reels)',
      );
    }
    final meta = parsed.meta;
    return VideoFeed(
      status: parsed.status,
      videos: [],
      meta: meta == null
          ? null
          : FeedMeta(
              page: meta.page,
              perPage: meta.perPage,
              hasMore: false,
              nextCursor: meta.nextCursor,
              feedSeed: meta.feedSeed,
              premiumIndex: meta.premiumIndex,
              sponsoredIndex: meta.sponsoredIndex,
              patternIndex: meta.patternIndex,
              normalOffset: meta.normalOffset,
              sortBy: meta.sortBy,
              geoFallback: true,
              geoExpanded: meta.geoExpanded,
              geoScope: meta.geoScope,
              geoRadiusKm: meta.geoRadiusKm,
              geoCityId: meta.geoCityId,
              geoCityName: meta.geoCityName,
              geoCityGroupIds: meta.geoCityGroupIds,
              geoCityGroupNames: meta.geoCityGroupNames,
            ),
    );
  }

  VideoFeed _feedForTab(String tab, VideoFeed parsed) {
    if (tab == 'Near Me') {
      return _nearMeFeedWithoutGeneralFallback(parsed);
    }
    return parsed;
  }

  blockUser(String? currentUserId, String? userId) async {
    try {
      final response = await ApiClient.postRequest(EndPoints.blockUser, {
        "blocked_user": userId,
      });

      print("PRINTING THE RESPONSE BODY");
      print(response.body);
      print(response.statusCode);
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update Firestore to mark the user as blocked in the chat
        if (currentUserId != null && userId != null) {
          final chatId = _getChatId(currentUserId, userId);
          await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
            'blockedBy': FieldValue.arrayUnion([currentUserId]),
          }, SetOptions(merge: true));
          print('✅ Updated Firestore: User $userId blocked in chat $chatId');
        }

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
            content: Text(decoded['message'] ?? 'Operation failed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('🚨 Error blocking user: $e');

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
      videos: updatedVideos,
    );

    // Adjust current index if needed
    // _adjustCurrentIndexAfterRemoval(currentVideoId, updatedVideos);

    reelListLength.value = updatedVideos.length;
  }

  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Helper method to remove blocked user's videos from current list

  // Helper method to adjust current index after video removal
  // void _adjustCurrentIndexAfterRemoval(
  //   String? currentVideoId,
  //   List<WallVideos> updatedVideos,
  // ) {
  //   if (currentVideoId == null || updatedVideos.isEmpty) {
  //     currentIndex.value = 0;
  //     return;
  //   }
  //
  //   // Try to find the current video in the updated list
  //   int newIndex = updatedVideos.indexWhere(
  //     (video) => video.id == currentVideoId,
  //   );
  //
  //   if (newIndex != -1) {
  //     // Current video still exists, update index
  //     currentIndex.value = newIndex;
  //   } else {
  //     // Current video was removed, go to previous video or first video
  //     int newCurrentIndex = currentIndex.value;
  //     if (newCurrentIndex >= updatedVideos.length) {
  //       newCurrentIndex = updatedVideos.length - 1;
  //     }
  //     if (newCurrentIndex < 0) {
  //       newCurrentIndex = 0;
  //     }
  //     currentIndex.value = newCurrentIndex;
  //   }
  //
  //   // Initialize the new current video if it exists
  //   // if (updatedVideos.isNotEmpty && currentIndex.value < updatedVideos.length) {
  //   //   Future.delayed(Duration(milliseconds: 100), () {
  //   //     initializeControllerAtIndex(currentIndex.value).then((_) {
  //   //       if (!isAppInBackground.value && !isNavigating.value) {
  //   //         playVideoAtIndex(currentIndex.value);
  //   //       }
  //   //     });
  //   //   });
  //   // }
  // }

  Future<void> saveGeneralFilterData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _prefGeneralLocationFilter,
      generalLocationFilterActive.value,
    );
    if (generalLocationFilterActive.value) {
      await prefs.setString(
        _prefGeneralFilterCountry,
        generalFilterCountry.value,
      );
      await prefs.setString(_prefGeneralFilterCity, generalFilterCity.value);
      if (generalFilterCountryId.value.isNotEmpty) {
        await prefs.setString(
          _prefGeneralFilterCountryId,
          generalFilterCountryId.value,
        );
      }
      if (generalFilterCityId.value.isNotEmpty) {
        await prefs.setString(
          _prefGeneralFilterCityId,
          generalFilterCityId.value,
        );
      }
    }
  }

  Future<void> clearGeneralLocationFilter() async {
    generalLocationFilterActive.value = false;
    generalFilterCountry.value = '';
    generalFilterCity.value = '';
    generalFilterCountryId.value = '';
    generalFilterCityId.value = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGeneralLocationFilter, false);
    await prefs.remove(_prefGeneralFilterCountry);
    await prefs.remove(_prefGeneralFilterCity);
    await prefs.remove(_prefGeneralFilterCountryId);
    await prefs.remove(_prefGeneralFilterCityId);
  }

  void applyGeneralLocationFilter({
    required String countryId,
    required String countryName,
    required String cityId,
    required String cityName,
  }) {
    generalLocationFilterActive.value = true;
    generalFilterCountryId.value = countryId;
    generalFilterCountry.value = countryName;
    generalFilterCityId.value = cityId;
    generalFilterCity.value = cityName;
  }

  Future<void> fetchVideos({
    String? country,
    String? city,
    bool forceNetwork = false,
    bool fromTabSwitch = false,
    bool backgroundRefresh = false,
    bool resetScrollPosition = false,
  }) async {
    final tab = selectedType.value;
    final pendingPin = _pendingPinForTab(tab);
    final needsPinFetch = pendingPin != null;
    final effectiveForceNetwork = forceNetwork || needsPinFetch;
    if (resetScrollPosition) {
      resetTabScrollRestore(tab);
      visiblePageIndex.value = 0;
      currentIndex.value = 0;
      // Do not bump [feedPlaybackEpoch] here — the old list is still mounted and
      // an early attach would resurrect the previous reel (silenced, not autoplaying
      // the newest). The post-fetch epoch bump below drives the real attach.
    }
    final cached = _cachedFeedForTab(tab);
    final sanitizedCache =
        cached != null ? _feedForTab(tab, cached) : null;
    final hasCachedFeed = !effectiveForceNetwork &&
        !_feedStaleAfterUpload &&
        sanitizedCache != null &&
        (sanitizedCache.videos?.isNotEmpty ?? false);

    if (hasCachedFeed) {
      final cachedVideos = sanitizedCache!.videos!;
      final wasEmpty =
          videoFeed.value.videos == null || videoFeed.value.videos!.isEmpty;
      videoFeed.value = sanitizedCache;
      _sortFeedByOrder(videoFeed.value);
      reelListLength.value = cachedVideos.length;
      if (fromTabSwitch || resetScrollPosition) {
        final target = resetScrollPosition
            ? 0
            : resolveScrollIndexForTab(tab, cachedVideos);
        visiblePageIndex.value = target;
        currentIndex.value = target;
      } else if (wasEmpty) {
        // Cold start only — restore saved tab position from cache.
        final target = resolveScrollIndexForTab(tab, cachedVideos);
        visiblePageIndex.value = target;
        currentIndex.value = target;
      }
      update();

      // Tab switch with warm cache: show instantly, no network replace, and no
      // silent cache refresh while the switch lock is held (cache reorder race).
      if (fromTabSwitch && !_feedStaleAfterUpload && !needsPinFetch) {
        return;
      }
    }

    if (isLoading.value && !hasCachedFeed && !fromTabSwitch) {
      return;
    }

    if (!hasCachedFeed && !backgroundRefresh) {
      isLoading.value = true;
      // Drop the previous tab's list so Near Me / Following never flash
      // General reels while their own feed is loading.
      videoFeed.value = VideoFeed(status: true, videos: []);
      reelListLength.value = 0;
    }
    currentPage.value = 1;

    try {
      if (selectedType.value == "Near Me") {
        if (city != null && city.isNotEmpty) {
          currentCity.value = city;
        }
        if (country != null && country.isNotEmpty) {
          currentCountry.value = country;
        }
        if (!hasLocationBeenFetched.value &&
            latitude.value.isEmpty &&
            longitude.value.isEmpty) {
          if (!isLocationFetching.value) {
            unawaited(fetchLocationOnce(refreshNearMeFeed: true));
          }
          final keepVisibleFeed = backgroundRefresh ||
              fromTabSwitch ||
              (videoFeed.value.videos?.isNotEmpty ?? false);
          if (!keepVisibleFeed) {
            videoFeed.value = VideoFeed(status: true, videos: []);
            reelListLength.value = 0;
          } else {
            isLoading.value = false;
          }
          return;
        }
      }

      final parsed = await _fetchFeedPage(reset: true);
      if (parsed != null) {
        if (_feedStaleAfterUpload && tab == selectedType.value) {
          _feedStaleAfterUpload = false;
        }
        final feedForTab = _feedForTab(tab, parsed);
        if (backgroundRefresh && (feedForTab.videos?.isEmpty ?? true)) {
          return;
        }
        // Stale response from a previous tab — keep cache only, don't overwrite live feed.
        if (tab != selectedType.value) {
          if (feedForTab.videos?.isNotEmpty ?? false) {
            _storeFeedCacheForTab(tab, feedForTab);
          } else {
            _clearFeedCacheForTab(tab);
          }
          return;
        }
        final parsedVideos = feedForTab.videos;
        // Publish + attach immediately. Disk warm is fire-and-forget so the
        // first frame is HTTPS/stream TTFB — never a multi-second poster hold.
        videoFeed.value = feedForTab;
        reelListLength.value = feedForTab.videos?.length ?? 0;
        if (feedForTab.videos?.isNotEmpty ?? false) {
          _storeFeedCacheForTab(tab, feedForTab);
        } else {
          _clearFeedCacheForTab(tab);
        }
        currentPage.value = feedForTab.meta?.page ?? 1;
        if (parsedVideos != null && parsedVideos.isNotEmpty) {
          if (resetScrollPosition) {
            visiblePageIndex.value = 0;
            currentIndex.value = 0;
          } else if (fromTabSwitch) {
            final target = resolveScrollIndexForTab(tab, parsedVideos);
            visiblePageIndex.value = target;
            currentIndex.value = target;
          }
          // Else: keep the user's current scroll — do not snap back to a stale
          // saved video id when a background fetch completes mid-playback.
        }

        if (!backgroundRefresh &&
            parsedVideos != null &&
            parsedVideos.isNotEmpty) {
          // Background only — do not await. Swipe/next opens stay fast.
          unawaited(
            FeedDiskWarmService.instance.warmAndAwaitFirst(
              parsedVideos,
              awaitFirstMs: 0,
            ),
          );
          if (!kIsWeb && Platform.isIOS) {
            unawaited(MediaKitPlayerPool.instance.ensureFeedPingPongInitialized());
          }
        }

        // Skip epoch bump during tab switch — serialized attach runs from the
        // tab handler; a concurrent epoch was spawning duplicate decoders on MTK.
        if (tab == selectedType.value &&
            (feedForTab.videos?.isNotEmpty ?? false) &&
            !backgroundRefresh &&
            !fromTabSwitch &&
            !_feedTabSwitchLocked) {
          feedPlaybackEpoch.value++;
          // Post-upload: Landing often boots with an empty list while pending
          // resume is set. When rows finally arrive and Home is focused, hard
          // restore so the feed never stays silenced after the epoch-only bump.
          if (_feedResumePendingWhenHomeTab &&
              _isOnHomeTab() &&
              _routeOverlayPauseDepth == 0 &&
              !isInMediaCaptureFlow &&
              !isAppInBackground.value) {
            if (_needsColdRestoreAfterCapture) {
              unawaited(_coldRestoreHomeFeedAfterCapture());
            } else {
              restoreHomeFeedPlayback();
            }
          }
        }
      }
    } catch (e) {
      error.value = "Error: $e";
    } finally {
      isLoading.value = false;
      isAppInBackground.value = false;
      update();
    }
  }

  /// Refresh tab cache from network without touching live feed / playback.
  Future<void> _refreshTabCacheSilently(String tab) async {
    // Cache reorder race: never mutate tab cache mid-switch.
    if (_feedTabSwitchLocked) {
      return;
    }
    if (selectedType.value != tab) {
      return;
    }
    try {
      final parsed = await _fetchFeedPage(reset: true);
      if (selectedType.value != tab) {
        return;
      }
      if (parsed == null || (parsed.videos?.isEmpty ?? true)) {
        return;
      }
      _storeFeedCacheForTab(tab, _feedForTab(tab, parsed));
    } catch (_) {}
  }

  // Method to manually refresh location if needed
  Future<void> refreshLocation({bool refreshFeed = true}) async {
    hasLocationBeenFetched.value = false;
    latitude.value = '';
    longitude.value = '';
    await fetchLocationOnce(
      refreshNearMeFeed: refreshFeed,
      forceRefresh: true,
    );
  }

  // Method to reset location data
  void resetLocationData() {
    hasLocationBeenFetched.value = false;
    isLocationFetching.value = false;
    currentCity.value = "";
    currentCountry.value = "";
  }

  // Future<void> initializeControllerAtIndex(
  //   int index, {
  //   int retryCount = 3,
  // }) async {
  //   // Guard against invalid index
  //   if (index < 0 || index >= videoFeed.value.videos!.length) {
  //     print("Invalid index: $index");
  //     return;
  //   }
  //
  //   // Check if controller is already initialized and valid
  //   if (_videoControllers[index] != null &&
  //       _videoControllers[index]!.value.isInitialized) {
  //     print("Controller at index $index is already initialized");
  //     return;
  //   }
  //
  //   // Clean up any existing controller at this index
  //   await _disposeControllerAtIndex(index);
  //
  //   int attempts = 0;
  //
  //   while (attempts < retryCount) {
  //     try {
  //       final videoUrl =
  //           '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
  //       print(
  //         "Attempt $attempts: Initializing video at index $index with URL: $videoUrl",
  //       );
  //
  //       // Check for cached video
  //       final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
  //       if (fileInfo != null && fileInfo.file != null) {
  //         _videoControllers[index] = VideoPlayerController.file(
  //           fileInfo.file,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //       } else {
  //         _videoControllers[index] = VideoPlayerController.network(
  //           videoUrl,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //         await _videoCacheManager.downloadFile(videoUrl);
  //       }
  //
  //       // Initialize the controller
  //       await _videoControllers[index]!.initialize();
  //       print("Initialization successful for index $index");
  //
  //       // Log video details
  //       print("Video details for index $index:");
  //       print(
  //         "  Resolution: ${_videoControllers[index]!.value.size.width}x${_videoControllers[index]!.value.size.height}",
  //       );
  //       print("  Duration: ${_videoControllers[index]!.value.duration}");
  //       print("  Position: ${_videoControllers[index]!.value.position}");
  //
  //       // Initialize ChewieController
  //       _chewieControllers[index] = ChewieController(
  //         videoPlayerController: _videoControllers[index]!,
  //         autoInitialize: false,
  //         looping: true,
  //         autoPlay: false,
  //         showControls: false,
  //         showControlsOnInitialize: false,
  //         allowMuting: true,
  //       );
  //
  //       _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //       _chewieControllers.refresh();
  //       print("Video initialized at index $index on attempt $attempts");
  //       return; // Success, exit the function
  //     } catch (e) {
  //       attempts++;
  //       print(
  //         "Error initializing video at index $index on attempt $attempts: $e",
  //       );
  //       if (attempts >= retryCount) {
  //         print(
  //           "Max retries reached for index $index. Falling back to recreate.",
  //         );
  //         await _disposeControllerAtIndex(index);
  //         // await recreateControllerAtIndex(index);
  //         return;
  //       }
  //       // Wait before retrying
  //       await Future.delayed(Duration(milliseconds: 500));
  //     }
  //   }
  // }

  // Helper method to dispose of a controller at a specific index
  // Future<void> recreateControllerAtIndex(
  //   int index, {
  //   int retryCount = 3,
  // }) async {
  //   if (index < 0 || index >= videoFeed.value.videos!.length) return;
  //
  //   disposeControllerAtIndex(index);
  //
  //   int attempts = 0;
  //
  //   while (attempts < retryCount) {
  //     try {
  //       final videoUrl =
  //           '${Common.videoUrl}/${videoFeed.value.videos![index].video}';
  //       print(
  //         "Attempt $attempts: Recreating video at index $index with URL: $videoUrl",
  //       );
  //
  //       final fileInfo = await _videoCacheManager.getFileFromCache(videoUrl);
  //       if (fileInfo != null && fileInfo.file != null) {
  //         _videoControllers[index] = VideoPlayerController.file(
  //           fileInfo.file,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //       } else {
  //         _videoControllers[index] = VideoPlayerController.network(
  //           videoUrl,
  //           videoPlayerOptions: VideoPlayerOptions(
  //             mixWithOthers: false,
  //             allowBackgroundPlayback: false,
  //           ),
  //         );
  //         await _videoCacheManager.downloadFile(videoUrl);
  //       }
  //
  //       await _videoControllers[index]!.initialize();
  //
  //       _chewieControllers[index] = ChewieController(
  //         videoPlayerController: _videoControllers[index]!,
  //         autoInitialize: false,
  //         looping: true,
  //         autoPlay: false,
  //         allowMuting: true,
  //         showControls: false,
  //         materialProgressColors: ChewieProgressColors(
  //           playedColor: Colors.red,
  //           handleColor: Colors.redAccent,
  //           backgroundColor: Colors.grey,
  //           bufferedColor: Colors.white30,
  //         ),
  //       );
  //
  //       _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //       _chewieControllers.refresh();
  //       print(
  //         "Recreated and initialized video at index $index on attempt $attempts",
  //       );
  //       return;
  //     } catch (e) {
  //       attempts++;
  //       print(
  //         "Error recreating video at index $index on attempt $attempts: $e",
  //       );
  //       if (attempts >= retryCount) {
  //         print("Max retries reached for index $index. Giving up.");
  //         error.value =
  //             "Failed to load video at index $index after $retryCount attempts: $e";
  //         return;
  //       }
  //       await Future.delayed(Duration(milliseconds: 500));
  //     }
  //   }
  // }

  // void handlePageChange(int index) {
  //   if (index == currentIndex.value) return;
  //
  //   _debounceTimer?.cancel();
  //
  //   _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
  //     print("handlePageChange: Processing index $index");
  //     pauseAllVideos();
  //     currentIndex.value = index;
  //
  //     // if (index >= 0 && index < videoFeed.value.videos!.length) {
  //     //   if (_chewieControllers[index] == null ||
  //     //       !_videoControllers[index]!.value.isInitialized) {
  //     //     await initializeControllerAtIndex(index);
  //     //     if (!isAppInBackground.value && !isNavigating.value) {
  //     //       playVideoAtIndex(index);
  //     //     }
  //     //     _viewedIndices.add(index);
  //     //     preloadNextVideos(index);
  //     //   } else {
  //     //     if (!isAppInBackground.value && !isNavigating.value) {
  //     //       playVideoAtIndex(index);
  //     //     }
  //     //     _viewedIndices.add(index);
  //     //     preloadNextVideos(index);
  //     //   }
  //     //   _cleanupUnusedControllers(index);
  //     // }
  //   });
  // }

  // void preloadNextVideos(int currentIndex) async {
  //   print("Preloading started for nearby videos");
  //
  //   const int preloadLimit = 1; // Preload ±1 indices
  //   int startIndex = (currentIndex - preloadLimit).clamp(
  //     0,
  //     videoFeed.value.videos!.length - 1,
  //   );
  //   int endIndex = (currentIndex + preloadLimit).clamp(
  //     0,
  //     videoFeed.value.videos!.length - 1,
  //   );
  //
  //   for (int nextIndex = startIndex; nextIndex <= endIndex; nextIndex++) {
  //     if (!_viewedIndices.contains(nextIndex) &&
  //         (_chewieControllers[nextIndex] == null ||
  //             _videoControllers[nextIndex]?.value.isInitialized != true)) {
  //       print("Preloading video at index $nextIndex");
  //       await initializeControllerAtIndex(nextIndex);
  //       await Future.delayed(
  //         Duration(milliseconds: 100),
  //       ); // Small delay to ease load
  //     }
  //   }
  //
  //   print("Preloading completed");
  // }

  void setReelsTabVisible(bool visible) {
    if (isReelsTabVisible.value == visible) {
      return;
    }
    void apply() {
      if (isReelsTabVisible.value != visible) {
        isReelsTabVisible.value = visible;
      }
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      apply();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  bool _hasOverlayRoute() => Get.key.currentState?.canPop() ?? false;

  /// Single gate for audible playback and user-initiated resume.
  ///
  /// Does NOT use [isReelsTabVisible] — that flag stuck false after camera/
  /// upload and permanently BAIL'd schedulePlayer (reason=reelsInvisible)
  /// while the user was already scrolling the Home feed.
  bool get shouldAllowHomeReelsPlayback =>
      !isAppInBackground.value &&
      !isInMediaCaptureFlow &&
      _playbackMuteDepth == 0 &&
      _bottomNavMuteDepth == 0 &&
      _routeOverlayPauseDepth == 0 &&
      _isOnHomeTab();

  /// Keeps the feed decoder mounted only on the Home tab (or while intentionally
  /// muted for a tab switch warm-keep). Never gated on [isReelsTabVisible].
  ///
  /// Only [_coldRestoreInFlight] blocks mounts (active pool wipe). The sticky
  /// [_needsColdRestoreAfterCapture] flag must NOT gate mount — that left
  /// schedulePlayer BAIL forever when cold restore never started (post-upload).
  bool get canMountHomeReelPlayer =>
      !isAppInBackground.value &&
      mediaCaptureDepth.value == 0 &&
      !_coldRestoreInFlight &&
      _playbackMuteDepth == 0 &&
      _routeOverlayPauseDepth == 0 &&
      _isOnHomeTab();

  /// Debug: why [canMountHomeReelPlayer] is false (empty when mountable).
  String get canMountBlockReason {
    if (isAppInBackground.value) return 'bg';
    if (isInMediaCaptureFlow) return 'captureDepth=${mediaCaptureDepth.value}';
    if (_coldRestoreInFlight) return 'coldRestoreInFlight';
    if (_playbackMuteDepth > 0) return 'muteDepth=$_playbackMuteDepth';
    if (_routeOverlayPauseDepth > 0) {
      return 'overlayDepth=$_routeOverlayPauseDepth';
    }
    if (!_isOnHomeTab()) return 'notHomeTab';
    return '';
  }

  bool get canPlayHomeReels => shouldAllowHomeReelsPlayback;

  void _applyMutedPlaybackSync() {
    isNavigating.value = true;
    setReelsTabVisible(false);
    pauseAllVideosSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(pauseAllVideosAwait());
  }

  /// Pause + silence when leaving Home via bottom nav.
  /// Unmounts the feed [ReelVideoPlayer] so it cannot re-unmute under Profile.
  Future<void> enterBottomNavMute() async {
    _bottomNavMuteDepth++;
    isNavigating.value = true;
    isVideoPlaying.value = false;
    setReelsTabVisible(false);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    final tab = selectedType.value;
    final videos = videoFeed.value.videos;
    if (videos != null && videos.isNotEmpty) {
      final idx = visiblePageIndex.value.clamp(0, videos.length - 1);
      saveTabScrollIndex(tab, idx);
      saveTabVideoId(tab, videos[idx].id);
    }
    MediaKitPlayerPool.instance.silenceAllSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    await pauseAllVideosAwait();
  }

  /// Sync mute when leaving home feed context (routes, overlays).
  void enterMutedPlaybackContext([String reason = '']) {
    _playbackMuteDepth++;
    if (_playbackMuteDepth == 1) {
      _applyMutedPlaybackSync();
    }
    MediaKitPlayerPool.instance.onEnterMutedContext();
  }

  /// Attempt resume when returning to home feed context.
  void exitMutedPlaybackContext() {
    if (_playbackMuteDepth <= 0) {
      return;
    }
    _playbackMuteDepth--;
    if (_playbackMuteDepth > 0) {
      return;
    }
    // Player was unmounted while muteDepth > 0 — retire the GlobalKey.
    _bumpFeedPlayerMountEpoch();
    _tryRestoreHomeFeedPlayback();
  }

  void _tryRestoreHomeFeedPlayback() {
    if (isAppInBackground.value) {
      return;
    }
    if (_routeOverlayPauseDepth > 0 ||
        !_isOnHomeTab() ||
        isInMediaCaptureFlow) {
      _feedResumePendingWhenHomeTab = true;
      // Dispose/resume often runs while the route is still mid-pop
      // (`canPop` still true), or while profile-reel disposeAll is in flight.
      // One post-frame retry is not enough — keep probing briefly.
      _scheduleFeedResumeRetries();
      return;
    }
    restoreHomeFeedPlayback();
  }

  void _scheduleFeedResumeRetries() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_feedResumePendingWhenHomeTab) {
        _flushPendingFeedResume();
      }
    });
    // Overlay disposeAll can take well over 800ms on MTK — keep probing.
    for (final ms in const <int>[50, 150, 400, 800, 1500, 2500, 4000]) {
      Future<void>.delayed(Duration(milliseconds: ms), () {
        if (isClosed || !_feedResumePendingWhenHomeTab) {
          return;
        }
        _flushPendingFeedResume();
      });
    }
  }

  void _flushPendingFeedResume() {
    if (!_feedResumePendingWhenHomeTab) {
      return;
    }
    if (isAppInBackground.value || isInMediaCaptureFlow) {
      return;
    }
    // Real overlay pause still blocks; bare canPop does not.
    if (_routeOverlayPauseDepth > 0) {
      return;
    }
    // Overlay routes are gone — any leftover pause depth is orphaned from an
    // async profile-reel teardown that lost the race with tab navigation.
    if (!_isOnHomeTab()) {
      return;
    }
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      // Still waiting on bootstrap fetch — keep pending so later ticks / the
      // fetch completion handler can restore.
      return;
    }
    if (_needsColdRestoreAfterCapture) {
      unawaited(_coldRestoreHomeFeedAfterCapture());
      return;
    }
    restoreHomeFeedPlayback();
  }

  /// App resume from background — only restore when user is on home with no overlay.
  void resumeAfterAppForegroundIfAllowed({bool soft = false}) {
    if (isAppInBackground.value && !soft) {
      return;
    }
    if (!shouldAllowHomeReelsPlayback && _playbackMuteDepth == 0) {
      return;
    }
    if (!shouldAllowHomeReelsPlayback) {
      _feedResumePendingWhenHomeTab = true;
      return;
    }
    isVideoPlaying.value = true;
    if (soft || _preferSoftFeedResumeAfterLocation) {
      _preferSoftFeedResumeAfterLocation = false;
      unawaited(resumeVisibleVideo(visiblePageIndex.value));
      return;
    }
    feedPlaybackEpoch.value++;
    unawaited(resumeVisibleVideo(visiblePageIndex.value));
  }

  /// Called from [MyApp] on [AppLifecycleState.resumed].
  ///
  /// Must clear [isReelsTabVisible] *before* [isAppInBackground] when the user
  /// is not on Home — otherwise [canMountHomeReelPlayer] flips true (warm-keep
  /// via [_bottomNavMuteDepth]) and the feed player remounts with audio while
  /// Profile/Discover/etc. is showing.
  void onAppLifecycleResumed() {
    final inLocationFlow = isInNearMeLocationPermissionFlow;
    final allowHomePlayback = _isOnHomeTab() &&
        _bottomNavMuteDepth == 0 &&
        _playbackMuteDepth == 0 &&
        _routeOverlayPauseDepth == 0 &&
        !isInMediaCaptureFlow &&
        !_hasOverlayRoute();
    if (!allowHomePlayback) {
      setReelsTabVisible(false);
      isNavigating.value = true;
      isVideoPlaying.value = false;
      MediaKitPlayerPool.instance.silenceAllSync();
      MediaKitPlayerPool.instance.pauseAllImmediate();
      isAppInBackground.value = false;
      _feedResumePendingWhenHomeTab = _isOnHomeTab();
      return;
    }
    isAppInBackground.value = false;
    isNavigating.value = false;
    setReelsTabVisible(true);
    resumeAfterAppForegroundIfAllowed(
      soft: inLocationFlow || _preferSoftFeedResumeAfterLocation,
    );
  }

  /// Immediate silence before a route push (no depth change). Pair with
  /// [pauseReelsForRouteOverlay] on the pushed screen's [initState].
  void silenceHomeReelsForTransition() {
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    MediaKitPlayerPool.instance.silenceAllSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
  }

  /// Stops reel audio/video immediately when pushing another route (e.g. profile).
  void pauseReelsForRouteOverlay() {
    _routeOverlayPauseDepth++;
    enterMutedPlaybackContext('route_overlay');
  }

  /// Re-applies silence while an overlay stack is still open (no depth change).
  void reinforceReelsPausedForOverlay() {
    if (_routeOverlayPauseDepth <= 0 && _playbackMuteDepth <= 0) {
      return;
    }
    _applyMutedPlaybackSync();
  }

  /// Resumes the visible reel after closing an overlay route, only on the home tab.
  void resumeReelsAfterRouteOverlay() {
    if (_routeOverlayPauseDepth <= 0) {
      return;
    }
    _routeOverlayPauseDepth--;
    exitMutedPlaybackContext();
    if (_routeOverlayPauseDepth > 0) {
      return;
    }
    if (_playbackMuteDepth > 0) {
      // Still muted by another context — mark pending so route observer can flush.
      _feedResumePendingWhenHomeTab = true;
      return;
    }
    _tryRestoreHomeFeedPlayback();
  }

  /// Release this overlay's pause ref WITHOUT triggering a home feed restore.
  /// Used by reel-screen teardown when a newer reel screen already claimed the
  /// pool session: we must keep the depth balanced, but must NOT let
  /// _tryRestoreHomeFeedPlayback → restoreHomeFeedPlayback dispose the pool out
  /// from under the newly opened reel screen (the "3rd tap stuck" race).
  void releaseRouteOverlayPauseSilent() {
    if (_routeOverlayPauseDepth <= 0) {
      return;
    }
    _routeOverlayPauseDepth--;
    exitMutedPlaybackContext();
  }

  bool _isOnHomeTab() {
    if (!Get.isRegistered<NavBarController>()) {
      return true;
    }
    return Get.find<NavBarController>().selectedIndex.value == 0;
  }

  /// Drops off-screen pool entries when leaving the home tab (long-session hygiene).
  void trimPoolOnNavAway() {
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    unawaited(
      MediaKitPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
    unawaited(
      VideoPlayerPool.instance.releaseFarFrom(
        currentIndex.value,
        window: 0,
        keyResolver: (index) {
          if (index < 0 || index >= videos.length) {
            return null;
          }
          final video = videos[index];
          return video.id ?? video.videoUrl ?? video.video;
        },
      ),
    );
  }

  /// Called after bottom-nav lands on Home — fast resume when decoder stayed warm.
  void onReturnedToHomeTab() {
    // Do NOT reclaim capture depth via Navigator.canPop — it flickers false mid
    // transition while camera/editor/upload are still stacked over Home
    // (selectedIndex stays 0). That wipe remounted the feed under the form.
    //
    // After Get.offAll post-upload, capture depth should already be 0. If a
    // leaked depth remains with no overlay routes, reclaim it so Home can remount.
    if (isInMediaCaptureFlow && !(Get.key.currentState?.canPop() ?? false)) {
      debugPrint('[FeedRestore] onHome reclaim leaked captureDepth='
          '${mediaCaptureDepth.value}');
      mediaCaptureDepth.value = 0;
    }
    if (isInMediaCaptureFlow) {
      // Real capture route still up under Home index — stay silenced.
      reinforceMediaCaptureSilence();
      return;
    }

    _clearAllHomePlaybackGates();
    isNavigating.value = false;
    isVideoPlaying.value = true;

    if (_needsColdRestoreAfterCapture) {
      // Claim the mount lock synchronously so Obx/schedulePlayer cannot attach
      // before the async wipe starts (race that left needsCold stuck + dead pool).
      if (!_coldRestoreInFlight) {
        _coldRestoreInFlight = true;
      }
      setReelsTabVisible(false);
      MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
      unawaited(_coldRestoreHomeFeedAfterCapture(alreadyClaimed: true));
      return;
    }

    // Open the mount gate immediately so scroll cannot BAIL reelsInvisible
    // while a warm remount runs.
    setReelsTabVisible(true);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);

    if (_feedStaleAfterUpload) {
      unawaited(refreshFeedAfterUploadIfNeeded());
      return;
    }

    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      _feedResumePendingWhenHomeTab = true;
      unawaited(fetchVideos());
      _scheduleFeedResumeRetries();
      return;
    }
    final tab = selectedType.value;
    final idx = resolveScrollIndexForTab(tab, videos);
    visiblePageIndex.value = idx;
    currentIndex.value = idx;
    restoreHomeFeedPlayback();
  }

  /// Last-resort heal when the UI is on Home but mount stayed blocked
  /// after camera/upload (BAIL schedulePlayer).
  ///
  /// NEVER clears [isInMediaCaptureFlow] / overlay pause while the camera,
  /// editor, or upload form is still open — that remounted the feed under the
  /// form (~4s later via resume retries), disposed players mid-upload, and
  /// crashed with StatefulElement.activate.
  void healHomeFeedIfStuckInvisible() {
    if (isClosed || isAppInBackground.value) {
      return;
    }
    if (!_isOnHomeTab()) {
      return;
    }
    // Capture / editor / upload keep selectedIndex==0. Schedule BAIL runs
    // constantly under those routes — healing here was wiping the gate early.
    if (isInMediaCaptureFlow) {
      debugPrint('[FeedRestore] heal SKIP captureDepth=${mediaCaptureDepth.value}');
      return;
    }
    if (_coldRestoreInFlight) {
      debugPrint('[FeedRestore] heal SKIP coldRestoreInFlight');
      return;
    }
    // Sticky post-upload flag with no in-flight wipe — start restore now.
    if (_needsColdRestoreAfterCapture) {
      debugPrint('[FeedRestore] heal kick coldRestore');
      if (!_coldRestoreInFlight) {
        _coldRestoreInFlight = true;
      }
      unawaited(_coldRestoreHomeFeedAfterCapture(alreadyClaimed: true));
      return;
    }
    if (_routeOverlayPauseDepth > 0) {
      debugPrint('[FeedRestore] heal SKIP overlayDepth=$_routeOverlayPauseDepth');
      return;
    }
    if (_hasOverlayRoute()) {
      debugPrint('[FeedRestore] heal SKIP canPop overlay still open');
      return;
    }
    final now = DateTime.now();
    if (_lastHealInvisibleAt != null &&
        now.difference(_lastHealInvisibleAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastHealInvisibleAt = now;
    debugPrint('[FeedRestore] heal Home mount '
        'block=${canMountBlockReason} capture=${mediaCaptureDepth.value} '
        'mute=$_playbackMuteDepth overlay=$_routeOverlayPauseDepth '
        'visible=${isReelsTabVisible.value}');

    // Reclaim leaked mute gates only — never while capture/overlays were open
    // above. User is literally scrolling a clear Home feed.
    _routeOverlayPauseDepth = 0;
    _playbackMuteDepth = 0;
    _bottomNavMuteDepth = 0;
    isNavigating.value = false;
    setReelsTabVisible(true);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    isVideoPlaying.value = true;

    if (_coldRestoreInFlight) {
      feedPlaybackEpoch.value++;
      return;
    }
    if (_needsColdRestoreAfterCapture) {
      unawaited(_coldRestoreHomeFeedAfterCapture());
      return;
    }
    // Pool may already be alive — force attach via epoch bump.
    feedPlaybackEpoch.value++;
    unawaited(resumeVisibleVideo(visiblePageIndex.value));
  }

  /// Wait out camera/codec teardown, wipe the pool, then hard-remount Home.
  ///
  /// Mount is blocked only while [_coldRestoreInFlight] is true (active wipe).
  Future<void> _coldRestoreHomeFeedAfterCapture({
    bool alreadyClaimed = false,
  }) async {
    if (_coldRestoreInFlight && !alreadyClaimed) {
      return;
    }
    // Still on camera / upload form — do not remount or unmute under it.
    if (isInMediaCaptureFlow || isAppInBackground.value) {
      debugPrint('[FeedRestore] coldRestore SKIP capture/bg');
      if (alreadyClaimed) {
        _coldRestoreInFlight = false;
      }
      reinforceMediaCaptureSilence();
      return;
    }
    // Not focused on Home yet — keep the flag and wait for the tab worker /
    // onReturnedToHomeTab. Running disposeAll under Profile used to race the
    // later Home attach and leave the feed dead until another tab switch.
    if (!_isOnHomeTab()) {
      debugPrint('[FeedRestore] coldRestore DEFER not-focused (pre)');
      if (alreadyClaimed) {
        _coldRestoreInFlight = false;
      }
      _feedResumePendingWhenHomeTab = true;
      _needsColdRestoreAfterCapture = true;
      setReelsTabVisible(false);
      MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
      _scheduleFeedResumeRetries();
      return;
    }

    if (!alreadyClaimed) {
      _coldRestoreInFlight = true;
    }
    _needsColdRestoreAfterCapture = true;
    _feedResumePendingWhenHomeTab = true;
    isNavigating.value = false;
    debugPrint('[FeedRestore] coldRestore START onHome=${_isOnHomeTab()} '
        'overlay=${_hasOverlayRoute()} bg=${isAppInBackground.value}');
    setReelsTabVisible(false);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    MediaKitPlayerPool.instance.pauseAllImmediate();
    MediaKitPlayerPool.instance.silenceAllSync();

    var remounted = false;
    try {
      // Camera2 / ImageReader teardown often lands AFTER Flutter route pops
      // (see BufferQueue abandoned in logs). Give hardware time to settle.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (isClosed) {
        return;
      }
      if (isInMediaCaptureFlow || isAppInBackground.value || !_isOnHomeTab()) {
        debugPrint('[FeedRestore] coldRestore ABORT mid-wait '
            'capture=${isInMediaCaptureFlow} bg=${isAppInBackground.value} '
            'onHome=${_isOnHomeTab()}');
        _needsColdRestoreAfterCapture = true;
        _feedResumePendingWhenHomeTab = true;
        if (isInMediaCaptureFlow) {
          reinforceMediaCaptureSilence();
        } else {
          setReelsTabVisible(false);
          MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
          _scheduleFeedResumeRetries();
        }
        return;
      }
      try {
        await MediaKitPlayerPool.instance.disposeAllWithTimeout(
          timeout: const Duration(milliseconds: 2500),
        );
        await MediaKitPlayerPool.instance.awaitOperationsIdle(
          timeout: const Duration(milliseconds: 2000),
        );
        await MediaKitPlayerPool.instance.ensureFeedPingPongInitialized();
      } catch (_) {}
      debugPrint('[FeedRestore] coldRestore pool reinit done '
          'onHome=${_isOnHomeTab()}');

      if (isClosed) {
        return;
      }
      if (isInMediaCaptureFlow) {
        debugPrint('[FeedRestore] coldRestore ABORT still capturing');
        _needsColdRestoreAfterCapture = true;
        reinforceMediaCaptureSilence();
        return;
      }
      if (!_isOnHomeTab() || isAppInBackground.value) {
        debugPrint('[FeedRestore] coldRestore DEFER not-focused');
        _feedResumePendingWhenHomeTab = true;
        _needsColdRestoreAfterCapture = true;
        setReelsTabVisible(false);
        MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
        _scheduleFeedResumeRetries();
        return;
      }

      final videos = videoFeed.value.videos;
      final hasPendingUpload =
          _pendingUploadVideoId != null && _pendingUploadVideoId!.isNotEmpty;
      if (_feedStaleAfterUpload || hasPendingUpload) {
        debugPrint('[FeedRestore] coldRestore stale/upload — refresh feed');
        _feedResumePendingWhenHomeTab = true;
        unawaited(refreshFeedAfterUploadIfNeeded());
        _scheduleFeedResumeRetries();
        return;
      }
      if (videos == null || videos.isEmpty) {
        debugPrint('[FeedRestore] coldRestore empty — network fetch');
        _feedResumePendingWhenHomeTab = true;
        unawaited(
          fetchVideos(forceNetwork: true, resetScrollPosition: true),
        );
        _scheduleFeedResumeRetries();
        return;
      }

      final tab = selectedType.value;
      final idx = resolveScrollIndexForTab(tab, videos);
      visiblePageIndex.value = idx;
      currentIndex.value = idx;
      debugPrint('[FeedRestore] coldRestore FORCE remount '
          'idx=$idx videos=${videos.length} '
          'idx0IsImage=${videos.first.isImage}');
      _needsColdRestoreAfterCapture = false;
      _coldRestoreInFlight = false;
      _forceRemountHomeFeedAfterCapture();
      remounted = true;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!isClosed &&
          _isOnHomeTab() &&
          !isInMediaCaptureFlow &&
          !isAppInBackground.value) {
        feedPlaybackEpoch.value++;
        debugPrint('[FeedRestore] coldRestore nudge epoch='
            '${feedPlaybackEpoch.value}');
      }
    } finally {
      _coldRestoreInFlight = false;
      if (!remounted) {
        if (!isClosed &&
            _isOnHomeTab() &&
            !isInMediaCaptureFlow &&
            !isAppInBackground.value) {
          debugPrint('[FeedRestore] coldRestore finally failsafe open');
          _needsColdRestoreAfterCapture = false;
          _forceOpenHomePlaybackGates();
          feedPlaybackEpoch.value++;
          _scheduleFeedResumeRetries();
        }
      } else if (!isClosed &&
          _isOnHomeTab() &&
          !isInMediaCaptureFlow &&
          !isAppInBackground.value &&
          !isReelsTabVisible.value) {
        debugPrint('[FeedRestore] coldRestore remounted but invisible — reopen');
        _forceOpenHomePlaybackGates();
        feedPlaybackEpoch.value++;
      }
    }
  }

  /// Clears every mute/capture gate and remounts — used only after camera /
  /// upload teardown. Ignores flaky [Navigator.canPop].
  void _forceOpenHomePlaybackGates() {
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    _clearAllHomePlaybackGates();
    _needsColdRestoreAfterCapture = false;
    _coldRestoreInFlight = false;
    isNavigating.value = false;
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    setReelsTabVisible(true);
    isVideoPlaying.value = true;
  }

  void _forceRemountHomeFeedAfterCapture() {
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    final token = claimReelPoolSession();
    _forceOpenHomePlaybackGates();
    _feedResumePendingWhenHomeTab = false;
    // Invalidate any stale "already handled" epoch on the reels screen by
    // bumping twice across a microtask — first opens attach, second catches
    // keep-alive pages that rebuilt after canMount flipped true.
    feedPlaybackEpoch.value++;
    unawaited(_completeForcedHomeFeedRemount(token));
  }

  Future<void> _completeForcedHomeFeedRemount(int token) async {
    try {
      await MediaKitPlayerPool.instance.awaitOperationsIdle(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!isReelPoolSessionCurrent(token) || isClosed) {
        return;
      }
      await MediaKitPlayerPool.instance.ensureFeedPingPongInitialized();
    } catch (_) {}
    if (isClosed || !isReelPoolSessionCurrent(token)) {
      return;
    }
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    if (!_isOnHomeTab() || isAppInBackground.value) {
      _feedResumePendingWhenHomeTab = true;
      _needsColdRestoreAfterCapture = true;
      setReelsTabVisible(false);
      _scheduleFeedResumeRetries();
      return;
    }
    _forceOpenHomePlaybackGates();
    feedPlaybackEpoch.value++;
    debugPrint('[FeedRestore] FORCE remount FINAL '
        'canMount=$canMountHomeReelPlayer block=${canMountBlockReason} '
        'epoch=${feedPlaybackEpoch.value} idx=${visiblePageIndex.value}');
    await resumeVisibleVideo(visiblePageIndex.value);
  }

  /// Called from [ReelsPlaybackRouteObserver] after the navigator stack changes.
  void syncPlaybackWithRouteStack({required bool hasOverlay}) {
    if (isAppInBackground.value) {
      return;
    }
    if (hasOverlay) {
      // Capture/editor/upload screens are full routes (overlays); keep the feed
      // silenced while any of them is on top.
      if (isInMediaCaptureFlow) {
        reinforceMediaCaptureSilence();
        return;
      }
      // Only silence when an overlay was intentionally paired with
      // pauseReelsForRouteOverlay. A bare Navigator.canPop=true (snackbar,
      // GetX mid-transition glitch after upload) must NOT mute the feed —
      // that left schedulePlayer BAIL !canMount forever ("photos only").
      if (_routeOverlayPauseDepth > 0) {
        reinforceReelsPausedForOverlay();
      }
      return;
    }

    // No overlay routes remain.
    if (_isOnHomeTab()) {
      // Never treat an active capture/upload as an "orphaned" gate. Clearing
      // depth here remounted the feed under the camera and leaked audio.
      if (isInMediaCaptureFlow) {
        reinforceMediaCaptureSilence();
        return;
      }
      // Any pop back to the feed root — search, visit-profile, liked/saved,
      // upload — must hard-restore. Soft tryRestore left mute gates / a dead
      // pool after late disposeAll and the feed never recovered.
      if (_needsColdRestoreAfterCapture) {
        unawaited(_coldRestoreHomeFeedAfterCapture());
      } else {
        restoreHomeFeedPlayback();
      }
    } else if (!isReelsTabVisible.value) {
      // Upload lands on profile tab with feed still silenced — resume on Home.
      _feedResumePendingWhenHomeTab = true;
    }
  }

  /// Re-attaches the home feed after profile/collection/search overlays tore
  /// down (or paused) the shared player pool.
  ///
  /// Critical race: overlay `dispose()` starts async `disposeAll` then the
  /// route observer restores the feed — if teardown still "owns" the pool it
  /// will wipe the freshly remounted players and the feed stays dead until
  /// process kill. We claim pool ownership first so late teardown skips
  /// disposeAll, then re-bump [feedPlaybackEpoch] after teardown settles.
  void restoreHomeFeedPlayback() {
    if (isAppInBackground.value) {
      return;
    }
    // Camera / upload owns the audio path — never remount under it.
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    // Never flip isReelsTabVisible=true while Profile/Discover is showing —
    // that used to mount (then kill) home decoders under the wrong tab and
    // leave the pool dead when the user finally opened Home.
    if (!_isOnHomeTab()) {
      _feedResumePendingWhenHomeTab = true;
      setReelsTabVisible(false);
      _scheduleFeedResumeRetries();
      return;
    }
    // Real overlay pause still blocks remount; bare canPop does not.
    if (_routeOverlayPauseDepth > 0) {
      _feedResumePendingWhenHomeTab = true;
      _scheduleFeedResumeRetries();
      return;
    }
    if (_needsColdRestoreAfterCapture) {
      unawaited(_coldRestoreHomeFeedAfterCapture());
      return;
    }
    final token = claimReelPoolSession();
    _clearAllHomePlaybackGates();
    _feedResumePendingWhenHomeTab = false;
    isNavigating.value = false;
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    setReelsTabVisible(true);
    isVideoPlaying.value = true;
    feedPlaybackEpoch.value++;
    unawaited(_completeHomeFeedRestore(token));
  }

  /// Zero every mute / overlay / capture gate so [canMountHomeReelPlayer] and
  /// [canPlayHomeReels] can pass after returning to Home.
  void _clearAllHomePlaybackGates() {
    _routeOverlayPauseDepth = 0;
    _playbackMuteDepth = 0;
    _bottomNavMuteDepth = 0;
    mediaCaptureDepth.value = 0;
    _bumpFeedPlayerMountEpoch();
  }

  Future<void> _completeHomeFeedRestore(int token) async {
    // Let overlay teardown finish (it will skip disposeAll once we claimed).
    final pending = _pendingReelTeardown;
    if (pending != null) {
      await pending.timeout(
        const Duration(milliseconds: 3000),
        onTimeout: () {},
      );
    }
    if (isClosed || !isReelPoolSessionCurrent(token)) {
      return;
    }
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    if (isAppInBackground.value ||
        !_isOnHomeTab() ||
        _routeOverlayPauseDepth > 0) {
      _feedResumePendingWhenHomeTab = true;
      if (!_isOnHomeTab()) {
        setReelsTabVisible(false);
      }
      return;
    }
    try {
      await MediaKitPlayerPool.instance.awaitOperationsIdle(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!isReelPoolSessionCurrent(token)) {
        return;
      }
      await MediaKitPlayerPool.instance.ensureFeedPingPongInitialized();
    } catch (_) {}
    if (isClosed || !isReelPoolSessionCurrent(token)) {
      return;
    }
    if (isInMediaCaptureFlow) {
      reinforceMediaCaptureSilence();
      return;
    }
    if (!_isOnHomeTab() ||
        _routeOverlayPauseDepth > 0 ||
        isAppInBackground.value) {
      _feedResumePendingWhenHomeTab = true;
      if (!_isOnHomeTab()) {
        setReelsTabVisible(false);
      }
      return;
    }
    // Late teardown may have flipped unmute/visibility again — re-assert.
    _clearAllHomePlaybackGates();
    isNavigating.value = false;
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    setReelsTabVisible(true);
    isVideoPlaying.value = true;
    // Second epoch bump: forces ReelVideoPlayer remount after the pool is
    // stable (first bump may have raced teardown).
    feedPlaybackEpoch.value++;
    debugPrint('[FeedRestore] completeRestore FINAL assert '
        'canMount=$canMountHomeReelPlayer canPlay=$canPlayHomeReels '
        'block=${canMountBlockReason} '
        'epoch=${feedPlaybackEpoch.value} idx=${visiblePageIndex.value}');
    await resumeVisibleVideo(visiblePageIndex.value);
  }

  /// Drop stale tab rows (old is_image / poster URLs) then remount the feed.
  void restoreHomeFeedPlaybackFresh() {
    _tabFeedCache.clear();
    restoreHomeFeedPlayback();
    unawaited(fetchVideos(forceNetwork: true));
  }

  void pauseAllVideosSync() {
    MediaKitPlayerPool.instance.silenceAllSync();
    isVideoPlaying.value = false;
  }

  Future<void> pauseAllVideosAwait() async {
    pauseAllVideosSync();
    await MediaKitPlayerPool.instance.pauseAllAwait();
    await VideoPlayerPool.instance.pauseAll();
    isVideoPlaying.value = false;
  }

  void pauseAllVideos() {
    pauseAllVideosSync();
    unawaited(pauseAllVideosAwait());
  }

  /// Frees reel decoders before camera / upload / editor flows so local
  /// [VideoPlayerController] can initialize without OOM on low-end devices.
  Future<void> releaseAllVideoResources({bool mediaCapture = false}) async {
    if (mediaCapture) {
      mediaCaptureDepth.value++;
      isNavigating.value = true;
      _needsColdRestoreAfterCapture = true;
      // Cancel any in-flight remount that would reopen audio under camera.
      _feedResumePendingWhenHomeTab = false;
    }
    setReelsTabVisible(false);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    MediaKitPlayerPool.instance.pauseAllImmediate();
    MediaKitPlayerPool.instance.silenceAllSync();
    await MediaKitPlayerPool.instance.pauseAllAwait();
    await VideoPlayerPool.instance.pauseAll();
    await MediaKitPlayerPool.instance.disposeAllWithTimeout();
    await VideoPlayerPool.instance.clear();
    isVideoPlaying.value = false;
  }

  /// Entry to add-button picker / camera / editor — blocks feed resume until
  /// [endMediaCaptureFlow] runs after the overlay stack is fully closed.
  Future<void> beginMediaCaptureFlow() {
    return releaseAllVideoResources(mediaCapture: true);
  }

  /// Re-assert silence while editor / upload screens are still open.
  void reinforceMediaCaptureSilence() {
    isNavigating.value = true;
    setReelsTabVisible(false);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    pauseAllVideosSync();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    MediaKitPlayerPool.instance.silenceAllSync();
    unawaited(pauseAllVideosAwait());
  }

  Future<void> endMediaCaptureFlow() async {
    // Capture/editor/upload still stacked above Landing — never remount Home yet.
    if (Get.key.currentState?.canPop() ?? false) {
      debugPrint('[FeedRestore] endCapture SKIP — overlay routes still open');
      reinforceMediaCaptureSilence();
      return;
    }
    if (mediaCaptureDepth.value <= 0) {
      // Even with depth already cleared, never leave Home stuck invisible.
      if (_isOnHomeTab() &&
          (!isReelsTabVisible.value || _needsColdRestoreAfterCapture)) {
        unawaited(_coldRestoreHomeFeedAfterCapture());
      }
      return;
    }
    mediaCaptureDepth.value--;
    if (mediaCaptureDepth.value > 0) {
      return;
    }
    // Capture unmounted the feed player — bump before canMount flips true so
    // remount uses a fresh GlobalKey (avoids StatefulElement.activate crash).
    _bumpFeedPlayerMountEpoch();
    isNavigating.value = false;
    _needsColdRestoreAfterCapture = true;
    // Upload finish / nested editor can leave canPop=true briefly. Never rely
    // on that to decide whether Home remounts — if we're on Home, remount;
    // otherwise mark pending and probe until Home is focused.
    if (!_isOnHomeTab() || isAppInBackground.value) {
      _feedResumePendingWhenHomeTab = true;
      setReelsTabVisible(false);
      MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
      _scheduleFeedResumeRetries();
      return;
    }
    await _coldRestoreHomeFeedAfterCapture();
  }

  /// After [Get.offAll] to Landing (post-upload): drop every capture/overlay
  /// mute gate and defer feed attach until the user opens the Home tab.
  void clearMediaCaptureGatesAfterLandingReset() {
    mediaCaptureDepth.value = 0;
    _routeOverlayPauseDepth = 0;
    _playbackMuteDepth = 0;
    _bottomNavMuteDepth = 0;
    // Invalidate any in-flight remount/teardown from the pre-offAll session so
    // a late releaseAll / cold-restore completion cannot wipe the new pool.
    claimReelPoolSession();
    _coldRestoreInFlight = false;
    _bumpFeedPlayerMountEpoch();
    isNavigating.value = false;
    setReelsTabVisible(false);
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
    _feedResumePendingWhenHomeTab = true;
    // Force delayed cold remount — camera BufferQueues are still dying here.
    _needsColdRestoreAfterCapture = true;
    markFeedStaleAfterUpload();
    // Don't rely solely on the next Home-tab tap — probe until Home is focused
    // so a post-upload offAll + slow bootstrap fetch cannot leave the feed dead.
    _scheduleFeedResumeRetries();
    _bindHomeTabResumeWorker();
  }

  Future<void> restoreVideoResourcesAfterCapture() async {
    await endMediaCaptureFlow();
  }

  Future<void> resumeVisibleVideo(int pageIndex) async {
    if (isAppInBackground.value || isNavigating.value || isInMediaCaptureFlow) {
      return;
    }
    // After forced remount, canPop can still flicker true — do not refuse to
    // mark the visible index when the user is clearly on Home.
    if (!_isOnHomeTab()) {
      return;
    }
    isReelsTabVisible.value = true;
    final videos = videoFeed.value.videos;
    if (videos == null || videos.isEmpty) {
      return;
    }
    final actualIndex = pageIndex.clamp(0, videos.length - 1);
    currentIndex.value = actualIndex;
    visiblePageIndex.value = actualIndex;
    isVideoPlaying.value = true;
    // Playback is started by the visible [VideoPlayerWidget] once autoPlay is
    // true again; do not touch the pool here (avoids racing disposed outputs).
  }

  // Future<void> playVideoAtIndex(int index) async {
  //   if (index < 0 ||
  //       index >= videoFeed.value.videos!.length ||
  //       _chewieControllers[index] == null)
  //     return;
  //
  //   print("Playing video at index $index");
  //   await initializeControllerAtIndex(index);
  //   _chewieControllers.refresh();
  //   await Future.delayed(const Duration(milliseconds: 100));
  //   await _chewieControllers[index]!.play();
  //   _chewieControllers[index]!.setVolume(isMuted.value ? 0 : 1);
  //   isVideoPlaying.value = true;
  //   _viewedIndices.add(index);
  // }

  // void pauseCurrentVideo() {
  //   if (currentIndex.value >= 0 &&
  //       currentIndex.value < _chewieControllers.length &&
  //       _chewieControllers[currentIndex.value] != null) {
  //     print("Pausing current video at index ${currentIndex.value}");
  //     final controller = _chewieControllers[currentIndex.value]!;
  //     lastVideoPosition.value = controller.videoPlayerController.value.position;
  //     wasPlaying.value = controller.isPlaying;
  //     controller.pause();
  //     isVideoPlaying.value = false;
  //   }
  // }

  void resumeCurrentVideo() {
    if (isAppInBackground.value || isNavigating.value) {
      return;
    }
    isVideoPlaying.value = true;
  }

  // void togglePlayPause() {
  //   if (currentIndex.value < 0 ||
  //       currentIndex.value >= _chewieControllers.length)
  //     return;
  //
  //   final controller = _chewieControllers[currentIndex.value];
  //   if (controller != null) {
  //     controller.isPlaying ? pauseCurrentVideo() : resumeCurrentVideo();
  //   }
  // }

  void toggleMute() {
    isMuted.value = !isMuted.value;
  }

  // void handleNavigation() {
  //   isNavigating.value = true;
  //   pauseCurrentVideo();
  // }

  // Future<void> restoreVideoState() async {
  //   final index = currentIndex.value;
  //   if (index < 0 ||
  //       index >= _chewieControllers.length ||
  //       _chewieControllers[index] == null) {
  //     isNavigating.value = false;
  //     return;
  //   }
  //
  //   final controller = _chewieControllers[index]!;
  //   try {
  //     if (!controller.videoPlayerController.value.isInitialized) {
  //       await initializeControllerAtIndex(index);
  //     }
  //
  //     if (lastVideoPosition.value.inMilliseconds > 0) {
  //       await controller.videoPlayerController.seekTo(lastVideoPosition.value);
  //     }
  //
  //     final targetVolume = isMuted.value ? 0.0 : 1.0;
  //     if (controller.videoPlayerController.value.volume != targetVolume) {
  //       controller.setVolume(targetVolume);
  //     }
  //
  //     if (wasPlaying.value && !isAppInBackground.value && !isNavigating.value) {
  //       await controller.play();
  //       isVideoPlaying.value = true;
  //     }
  //   } catch (e) {
  //     print('Error restoring video state: $e');
  //   } finally {
  //     isNavigating.value = false;
  //   }
  // }

  void disposeControllerAtIndex(int index) {}

  int scrollIndexForTab(String tab) => _tabScrollIndex[tab] ?? 0;

  String? videoIdForTab(String tab) => _tabVideoId[tab];

  List<WallVideos>? cachedVideosForTab(String tab) {
    final cached = _cachedFeedForTab(tab);
    if (cached == null) {
      return null;
    }
    return _feedForTab(tab, cached).videos;
  }

  int cachedListLengthForTab(String tab) =>
      cachedVideosForTab(tab)?.length ?? 0;

  /// Persist the live feed into the per-tab cache before leaving a sub-tab.
  void snapshotActiveTabFeedCache() {
    final tab = selectedType.value;
    final feed = videoFeed.value;
    if (feed.videos?.isNotEmpty ?? false) {
      _storeFeedCacheForTab(tab, feed);
    }
  }

  /// Swap [videoFeed] to a cached sub-tab list before the UI marks it active.
  /// Returns false when the destination tab has no cached rows yet.
  bool applyCachedFeedForTab(String tab) {
    final cached = _cachedFeedForTab(tab);
    if (cached == null) {
      return false;
    }
    final feed = _feedForTab(tab, cached);
    final videos = feed.videos;
    if (videos == null || videos.isEmpty) {
      return false;
    }
    videoFeed.value = feed;
    _sortFeedByOrder(videoFeed.value);
    reelListLength.value = videos.length;
    final target = resolveScrollIndexForTab(tab, videos);
    visiblePageIndex.value = target;
    currentIndex.value = target;
    return true;
  }

  void saveTabScrollIndex(String tab, int index) {
    if (index < 0) {
      return;
    }
    _tabScrollIndex[tab] = index;
  }

  void saveTabVideoId(String tab, String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    _tabVideoId[tab] = videoId;
  }

  int resolveScrollIndexForTab(String tab, List<WallVideos> videos) {
    if (videos.isEmpty) {
      return 0;
    }
    final savedId = _tabVideoId[tab];
    if (savedId != null && savedId.isNotEmpty) {
      final byId = videos.indexWhere((video) => video.id == savedId);
      if (byId != -1) {
        return byId.clamp(0, videos.length - 1);
      }
      // Saved id missing from this snapshot (stale cache / reorder) — index 0
      // avoids jumping to a wrong reel via a stale scroll index (index race).
      return 0;
    }
    final savedIndex = scrollIndexForTab(tab);
    if (savedIndex < 0 || savedIndex >= videos.length) {
      return 0;
    }
    return savedIndex;
  }

  /// TikTok-style refresh: reload the current feed from the network and jump
  /// back to the first reel. Triggered by re-tapping the Home tab.
  ///
  /// Also owns the full resume (visibility / epoch / unmute) so the re-tap path
  /// does NOT first call [onReturnedToHomeTab] (which would restore the saved
  /// scroll index ~N and lose the race against this reset to 0).
  Future<void> refreshHomeFeed() async {
    if (isLoading.value) {
      return;
    }
    final tab = selectedType.value;
    // Manual refresh is the recovery path after a stuck post-upload feed —
    // clear sticky cold-restore first so schedulePlayer / silence cannot fight
    // this remount (that left video without audio on first-session refresh).
    claimReelPoolSession();
    _needsColdRestoreAfterCapture = false;
    _coldRestoreInFlight = false;
    // Stop the reel that was playing before the re-tap — otherwise its audio
    // keeps running under the refresh (the kept-alive player isn't disposed
    // when the list is swapped) and overlaps the new first reel.
    MediaKitPlayerPool.instance.pauseAllImmediate();
    MediaKitPlayerPool.instance.silenceAllSync();
    unawaited(MediaKitPlayerPool.instance.clearFeedVisibleReel());
    // Clear mute depths / navigating so canPlayHomeReels is true after refresh.
    _routeOverlayPauseDepth = 0;
    _playbackMuteDepth = 0;
    _bottomNavMuteDepth = 0;
    mediaCaptureDepth.value = 0;
    _feedResumePendingWhenHomeTab = false;
    isNavigating.value = false;
    isVideoPlaying.value = true;
    // Unmute AFTER silence so setFeedUnmuteEnabled bumps silenceGeneration and
    // invalidates the fire-and-forget silenceAllSlots from silenceAllSync.
    MediaKitPlayerPool.instance.setFeedUnmuteEnabled(true);
    setReelsTabVisible(true);
    saveTabScrollIndex(tab, 0);
    _tabVideoId.remove(tab);
    _clearFeedCacheForTab(tab);
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
    // Tell the reels view to ignore the previous pin/page and attach+autoplay #0.
    _preferNewestAttach = true;
    // Drop the old list immediately so any accidental attach cannot resurrect
    // the previous reel while the network refresh is in flight.
    videoFeed.value = VideoFeed(status: true, videos: []);
    reelListLength.value = 0;
    // Do NOT bump the playback epoch before the fetch: that would re-attach the
    // player to index 0 of the *old* (pre-refresh) list and resurrect the very
    // reel we just paused. The post-fetch epoch bump inside fetchVideos drives
    // the attach onto the freshly fetched first reel.
    await fetchVideos(forceNetwork: true, resetScrollPosition: true);
  }

  /// Pause feed playback when switching عام / بالقرب / المتابعة.
  /// Clears feed-visible priming so the destination tab cannot claim
  /// "instant resume" / drop the poster while the shared player remounts
  /// (IndexedStack) with an opacity-0 surface → black scaffold.
  Future<void> prepareForFeedTabSwitch() async {
    // The view's _persistLeavingTabPlayback already saved the leaving tab's
    // scroll index + video id from the per-tab PageView truth (visibleIndexNotifier).
    // Do NOT overwrite here with visiblePageIndex — it can diverge from the
    // PageView after _finishFeedTabPlayback, which saved the wrong reel and made
    // the next return land on a different video.
    MediaKitPlayerPool.instance.pauseAllImmediate();
    final leavingKey = MediaKitPlayerPool.instance.feedVisibleKey;
    if (leavingKey != null && leavingKey.isNotEmpty) {
      MediaKitPlayerPool.instance.invalidatePrimedFrame(leavingKey);
    }
    await MediaKitPlayerPool.instance.clearFeedVisibleReel();
    await VideoPlayerPool.instance.pauseAll();
  }

  void disposeControllers() {
    // Capture ownership before the async wipe. If a remount claims a newer
    // session (post-upload Landing reset / forced remount), skip releasing the
    // shared pool so we never dispose the new ping-pong slots.
    final token = _reelPoolSessionToken;
    unawaited(_releasePoolIfSessionCurrent(token));
    visiblePageIndex.value = 0;
    currentIndex.value = 0;
  }

  Future<void> _releasePoolIfSessionCurrent(int token) async {
    if (!isReelPoolSessionCurrent(token)) {
      return;
    }
    await MediaKitPlayerPool.instance.releaseAll();
    if (!isReelPoolSessionCurrent(token)) {
      return;
    }
    await VideoPlayerPool.instance.clear();
  }

  RxString selectedType = "Near Me".obs;

  void setSelectedType(String type) {
    if (type == "General" || type == "Near Me" || type == "Following") {
      selectedType.value = type;
    }
  }
}
