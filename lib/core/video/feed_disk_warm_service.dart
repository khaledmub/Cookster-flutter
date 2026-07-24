import 'dart:async';

import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/reels_feed_client.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:cookster/services/feature_flags/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Disk-only early warm for the home feed.
///
/// Never opens MediaKit — that stays feed-gated so HTTPS decode cannot steal
/// bandwidth from the exclusive head download.
class FeedDiskWarmService {
  FeedDiskWarmService._();

  static final FeedDiskWarmService instance = FeedDiskWarmService._();

  /// Early warm only seeds ONE file — more concurrent downloads starved the
  /// real Near Me head and `awaitFirst` always timed out (`ready=false`).
  static const int _earlyWarmMax = 1;
  static const int _aheadWarmMax = 3;
  static const int _exclusivePriority = 1000;

  int _generation = 0;
  bool _inFlight = false;
  String? _lastReason;

  /// Fire-and-forget. Safe to call multiple times — coalesces concurrent runs.
  void warmEarlyFeed({String reason = 'unknown'}) {
    unawaited(_warmEarlyFeed(reason: reason));
  }

  /// Cancel pending early-warm work (e.g. logout).
  void cancel() {
    _generation++;
    _inFlight = false;
    _lastReason = null;
    ReelsVideoCacheManager.instance.cancelBelowPriority(1 << 30);
    debugPrint('[FeedDiskWarm] cancelled');
  }

  /// Prefetch reel #0 exclusively until it is on disk, then quietly warm N+1/N+2.
  ///
  /// MediaKit MUST NOT open HTTPS during this wait — competing CDN streams were
  /// why `awaitFirst ready=false` after 2.8s while the player still stalled.
  Future<bool> warmAndAwaitFirst(
    List<WallVideos> videos, {
    int awaitFirstMs = 12000,
    int aheadCount = _aheadWarmMax,
  }) async {
    if (videos.isEmpty) {
      return false;
    }
    const resolver = VideoSourceResolver();
    final headUrl = _primaryPlaybackUrl(videos.first, resolver);
    if (headUrl == null) {
      // Photo (or no candidates) — seed the next videos without blocking.
      _enqueueAhead(videos.skip(1), max: aheadCount - 1, basePriority: 120);
      return true;
    }

    if (awaitFirstMs <= 0) {
      prefetchPlaybackUrl(headUrl, priority: 120);
      _enqueueAhead(videos.skip(1), max: aheadCount - 1, basePriority: 110);
      return false;
    }

    if (await isPlaybackUrlCached(headUrl)) {
      debugPrint('[FeedDiskWarm] head already cached — open can be instant');
      _enqueueAhead(videos.skip(1), max: aheadCount - 1, basePriority: 120);
      return true;
    }

    final started = DateTime.now().millisecondsSinceEpoch;
    final ready = await ReelsVideoCacheManager.instance.downloadExclusiveAndWait(
      headUrl,
      maxWaitMs: awaitFirstMs,
    );
    debugPrint(
      '[FeedDiskWarm] awaitFirst ready=$ready '
      'waitedMs=${DateTime.now().millisecondsSinceEpoch - started} '
      'budgetMs=$awaitFirstMs '
      'url=${headUrl.length > 56 ? '${headUrl.substring(0, 56)}…' : headUrl}',
    );

    // Only after the visible file landed — otherwise we dilute the exclusive
    // download again.
    if (ready) {
      _enqueueAhead(videos.skip(1), max: aheadCount - 1, basePriority: 110);
    }
    return ready;
  }

  /// Disk-prefetch the preferred tier for [index] and wait until it is cached.
  Future<bool> warmIndexExclusive(
    List<WallVideos> videos,
    int index, {
    int maxWaitMs = 8000,
  }) async {
    if (index < 0 || index >= videos.length) {
      return false;
    }
    const resolver = VideoSourceResolver();
    final url = _primaryPlaybackUrl(videos[index], resolver);
    if (url == null) {
      return true;
    }
    if (await isPlaybackUrlCached(url)) {
      return true;
    }
    return ReelsVideoCacheManager.instance.downloadExclusiveAndWait(
      url,
      maxWaitMs: maxWaitMs,
    );
  }

  Future<void> _warmEarlyFeed({required String reason}) async {
    if (_inFlight) {
      debugPrint(
        '[FeedDiskWarm] skip coalesce (already running, last=$_lastReason)',
      );
      return;
    }

    try {
      if (!RemoteConfigService.instance.preloadEnabled) {
        debugPrint('[FeedDiskWarm] skip preloadEnabled=false');
        return;
      }
    } catch (_) {}

    final token = await _resolveAuthToken();
    if (token == null || token.isEmpty) {
      debugPrint('[FeedDiskWarm] skip no auth token ($reason)');
      return;
    }

    _inFlight = true;
    _lastReason = reason;
    final gen = ++_generation;
    debugPrint('[FeedDiskWarm] start reason=$reason gen=$gen');

    try {
      ApiClient.setAuthToken(token);
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('latitude');
      final lng = prefs.getDouble('longitude');
      final cityId = prefs.getString('currentCityId');
      final countryId = prefs.getString('currentCountryId');
      final hasManualFilter =
          (cityId != null && cityId.isNotEmpty) ||
          (countryId != null && countryId.isNotEmpty);
      final hasCoords =
          lat != null && lng != null && lat != 0.0 && lng != 0.0;

      // Prefer Near Me (home default). Only seed ONE file so Landing's
      // exclusive head warm is not bandwidth-starved.
      var warmed = 0;
      if (hasManualFilter || hasCoords) {
        warmed += await _fetchAndEnqueue(
          gen: gen,
          feed: 'near_me',
          latitude: hasManualFilter ? null : lat?.toString(),
          longitude: hasManualFilter ? null : lng?.toString(),
          city: (cityId != null && cityId.isNotEmpty) ? cityId : null,
          country:
              (countryId != null && countryId.isNotEmpty) ? countryId : null,
          label: 'near_me',
          maxVideos: _earlyWarmMax,
          basePriority: 200,
        );
      } else {
        warmed += await _fetchAndEnqueue(
          gen: gen,
          feed: 'general',
          label: 'general',
          maxVideos: _earlyWarmMax,
          basePriority: 200,
        );
      }
      debugPrint(
        '[FeedDiskWarm] done reason=$reason enqueued≈$warmed gen=$gen '
        'nearMe=$hasCoords',
      );
    } catch (e, st) {
      debugPrint('[FeedDiskWarm] error: $e\n$st');
    } finally {
      if (gen == _generation) {
        _inFlight = false;
      }
    }
  }

  Future<int> _fetchAndEnqueue({
    required int gen,
    required String feed,
    required String label,
    required int maxVideos,
    required int basePriority,
    String? latitude,
    String? longitude,
    String? city,
    String? country,
  }) async {
    if (gen != _generation) {
      return 0;
    }
    final result = await ReelsFeedClient.fetchPage(
      reset: true,
      feed: feed,
      latitude: latitude,
      longitude: longitude,
      city: city,
      country: country,
    );
    if (gen != _generation) {
      return 0;
    }
    if (result.statusCode != 200 || result.feed?.videos == null) {
      debugPrint(
        '[FeedDiskWarm] $label failed status=${result.statusCode} '
        'err=${result.error}',
      );
      return 0;
    }
    final videos = result.feed!.videos!;
    final urls = _enqueueDiskPrefetch(
      videos,
      gen: gen,
      maxVideos: maxVideos,
      basePriority: basePriority,
    );
    debugPrint(
      '[FeedDiskWarm] $label enqueued ${urls.length} of ${videos.length}',
    );
    return urls.length;
  }

  String? _primaryPlaybackUrl(
    WallVideos video,
    VideoSourceResolver resolver,
  ) {
    final candidates = resolver.resolveForWallVideo(video);
    if (candidates.isEmpty) {
      return null;
    }
    final preload = resolver.prioritizeForPreload(
      candidates,
      offsetFromVisible: 0,
    );
    if (preload.isEmpty) {
      return null;
    }
    return preload.first.url;
  }

  void _enqueueAhead(
    Iterable<WallVideos> videos, {
    required int max,
    required int basePriority,
  }) {
    if (max <= 0) {
      return;
    }
    _enqueueDiskPrefetch(
      videos.toList(growable: false),
      gen: 0,
      maxVideos: max,
      basePriority: basePriority,
    );
  }

  List<String> _enqueueDiskPrefetch(
    List<WallVideos> videos, {
    required int gen,
    int maxVideos = _aheadWarmMax,
    int basePriority = 120,
  }) {
    if (gen != 0 && gen != _generation) {
      return const [];
    }
    const resolver = VideoSourceResolver();
    final urls = <String>[];
    var warmIndex = 0;
    for (final video in videos) {
      if (warmIndex >= maxVideos) {
        break;
      }
      if (gen != 0 && gen != _generation) {
        break;
      }
      final url = _primaryPlaybackUrl(video, resolver);
      if (url == null) {
        continue;
      }
      final priority = (basePriority - (warmIndex * 3))
          .clamp(10, _exclusivePriority - 1);
      prefetchPlaybackUrl(url, priority: priority);
      urls.add(url);
      warmIndex++;
    }
    return urls;
  }

  Future<String?> _resolveAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = prefs.getString('auth_token');
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        return fromPrefs;
      }
    } catch (_) {}
    return null;
  }
}
