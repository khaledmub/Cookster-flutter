import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoSourceCandidate {
  const VideoSourceCandidate({
    required this.url,
    required this.type,
  });

  final String url;
  final String type;
}

class VideoSourceResolver {
  const VideoSourceResolver();

  /// When [transcode_status] is `ready`: HLS → 360 → 720 → 1080 → full MP4.
  /// When pending: [video_url] / legacy only (no HLS ladder guess).
  List<VideoSourceCandidate> resolveForWallVideo(WallVideos video) {
    if (video.isPhotoPost) {
      return const [];
    }
    final ready = video.isPlaybackReady;
    final playback = video.resolvedPlaybackUrl;
    final mp4Url = playback != null && isStaticImagePlaybackUrl(playback)
        ? null
        : playback;
    return resolveCandidates(
      hlsUrl: ready ? video.resolvedHlsUrl : null,
      mp4Url: mp4Url,
      legacyPath: null,
      qualityMp4Urls: ready ? video.qualityMp4Urls : const [],
    );
  }

  List<VideoSourceCandidate> resolveCandidates({
    String? hlsUrl,
    String? mp4Url,
    String? legacyPath,
    List<String> qualityMp4Urls = const [],
  }) {
    final candidates = <VideoSourceCandidate>[];

    final normalizedHls = _normalize(hlsUrl);
    if (normalizedHls != null && normalizedHls.toLowerCase().contains('.m3u8')) {
      candidates.add(VideoSourceCandidate(url: normalizedHls, type: 'hls'));
    }

    for (final url in qualityMp4Urls) {
      final normalized = _normalize(url);
      if (normalized == null) {
        continue;
      }
      if (candidates.any((c) => c.url == normalized)) {
        continue;
      }
      candidates.add(VideoSourceCandidate(url: normalized, type: 'mp4_quality'));
    }

    final normalizedMp4 = _normalize(mp4Url);
    if (normalizedMp4 != null &&
        !isStaticImagePlaybackUrl(normalizedMp4) &&
        !candidates.any((c) => c.url == normalizedMp4)) {
      candidates.add(VideoSourceCandidate(url: normalizedMp4, type: 'mp4'));
    }

    final normalizedLegacy = _normalizeLegacy(legacyPath);
    if (normalizedLegacy != null &&
        !candidates.any((c) => c.url == normalizedLegacy)) {
      candidates.add(VideoSourceCandidate(url: normalizedLegacy, type: 'legacy'));
    }

    return candidates;
  }

  /// Phone playback: 360 → 720 → 1080 when [fastStartUncached]; otherwise
  /// 1080 → 720 → 360. Cached tiers first via [prioritizeForPlayback] when
  /// the cached tier is the highest available.
  List<VideoSourceCandidate> prioritizeForNetwork(
    List<VideoSourceCandidate> candidates,
    NetworkClass network, {
    bool isTablet = false,
    bool fastStartUncached = true,
    bool hlsWifiFirst = false,
  }) {
    if (candidates.length <= 1) {
      return candidates;
    }
    final mp4Quality =
        candidates.where((c) => c.type == 'mp4_quality').toList(growable: false);
    final hls = candidates.where((c) => c.type == 'hls').toList(growable: false);
    final rest = candidates
        .where((c) => c.type != 'mp4_quality' && c.type != 'hls')
        .toList(growable: false);

    if (hlsWifiFirst &&
        network == NetworkClass.wifi &&
        hls.isNotEmpty) {
      final tiers = isTablet
          ? const ['1080', '720', '360']
          : (fastStartUncached
              ? const ['360', '720', '1080']
              : const ['1080', '720', '360']);
      final orderedMp4 = _orderMp4ByTier(mp4Quality, tiers);
      return [...hls, ...orderedMp4, ...rest];
    }

    final tiers = isTablet
        ? switch (network) {
            NetworkClass.wifi => const ['1080', '720', '360'],
            NetworkClass.mobile => fastStartUncached
                ? const ['360', '720', '1080']
                : const ['1080', '720', '360'],
            NetworkClass.offline => fastStartUncached
                ? const ['720', '360', '1080']
                : const ['1080', '720', '360'],
          }
        : fastStartUncached
            ? const ['360', '720', '1080']
            : const ['1080', '720', '360'];
    final orderedMp4 = _orderMp4ByTier(mp4Quality, tiers);
    return [...orderedMp4, ...hls, ...rest];
  }

  /// Disk preload: N+1/N+2 → 1080 (HD-first); deeper indices → 720; falls back to
  /// lower tiers when 1080 is absent (480p-only sources).
  List<VideoSourceCandidate> prioritizeForPreload(
    List<VideoSourceCandidate> candidates, {
    int offsetFromVisible = 1,
    bool dualTier = true,
  }) {
    if (candidates.isEmpty) {
      return candidates;
    }
    final mp4Quality =
        candidates.where((c) => c.type == 'mp4_quality').toList(growable: false);
    if (mp4Quality.isEmpty) {
      return candidates
          .where((c) => c.type != 'hls')
          .take(1)
          .toList(growable: false);
    }

    VideoSourceCandidate? pick360;
    VideoSourceCandidate? pick720;
    VideoSourceCandidate? pick1080;
    for (final candidate in mp4Quality) {
      final tier = mp4Tier(candidate.url);
      pick360 ??= tier == '360' ? candidate : null;
      pick720 ??= tier == '720' ? candidate : null;
      pick1080 ??= tier == '1080' ? candidate : null;
    }

    // Visible: 720 only. Dual 720+1080 occupied both download slots and
    // starved N+1 — first opens stayed on HTTPS ~3s.
    if (offsetFromVisible == 0) {
      final visible = <VideoSourceCandidate>[];
      final smallFirst = DeviceConstraints.instance.prefer360ColdOpen;
      if (smallFirst) {
        if (pick360 != null) {
          visible.add(pick360);
        }
        if (pick720 != null && pick720 != pick360) {
          visible.add(pick720);
        }
      } else {
        if (pick720 != null) {
          visible.add(pick720);
        }
        // Never enqueue visible 1080 here — with max 2 download slots it
        // races N+1's 720 and forces first opens onto cold HTTPS.
      }
      if (visible.isNotEmpty) {
        return visible;
      }
    }

    // N+1/N+2: warm 720 first (fast partial). On Honor/MTK skip dual-tier 1080
    // in the near window — concurrent 720+1080 across many indices starved
    // N+1 completion and forced visible HTTPS opens.
    if (offsetFromVisible <= 2) {
      final constrained =
          DeviceConstraints.instance.needsConstrainedSurfaceRecovery;
      if (pick720 != null) {
        final result = <VideoSourceCandidate>[pick720];
        if (!constrained &&
            dualTier &&
            pick1080 != null &&
            pick1080 != pick720) {
          result.add(pick1080);
        }
        if (pick360 != null && pick360 != pick720) {
          result.add(pick360);
        }
        return result;
      }
      if (pick1080 != null) {
        return [pick1080];
      }
    }

    if (dualTier && offsetFromVisible <= 2) {
      final result = <VideoSourceCandidate>[];
      if (pick720 != null) {
        result.add(pick720);
      }
      if (pick360 != null && pick360 != pick720) {
        result.add(pick360);
      }
      if (result.isNotEmpty) {
        return result;
      }
    }

    if (pick720 != null) {
      return [pick720];
    }
    if (pick360 != null) {
      return [pick360];
    }
    return [mp4Quality.first];
  }

  /// Fast-start playback: cached highest MP4 → cached/partial 360 → stream 360 → stream 720 → HLS.
  Future<List<VideoSourceCandidate>> prioritizeForPlaybackFastStart({
    required List<VideoSourceCandidate> candidates,
    required NetworkClass network,
    BaseCacheManager? cacheManager,
    bool isTablet = false,
    bool fastStartUncached = true,
    bool hlsWifiEnabled = false,
  }) async {
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final hasCachedMp4 = await _anyMp4Cached(candidates, cache);
    if (hasCachedMp4) {
      return prioritizeForPlayback(
        candidates: candidates,
        network: network,
        cacheManager: cache,
        isTablet: isTablet,
        fastStartUncached: fastStartUncached,
      );
    }
    return prioritizeForNetwork(
      candidates,
      network,
      isTablet: isTablet,
      fastStartUncached: fastStartUncached,
      hlsWifiFirst: hlsWifiEnabled,
    );
  }

  /// Prefer the best *ready* MP4 on disk (full or fast-start partial) so open
  /// does not wait on a higher uncached tier while a lower tier is already warm.
  Future<List<VideoSourceCandidate>> prioritizeForPlayback({
    required List<VideoSourceCandidate> candidates,
    required NetworkClass network,
    BaseCacheManager? cacheManager,
    bool isTablet = false,
    bool fastStartUncached = true,
  }) async {
    final ordered = prioritizeForNetwork(
      candidates,
      network,
      isTablet: isTablet,
      fastStartUncached: fastStartUncached,
    );
    if (ordered.length <= 1) {
      return ordered;
    }
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final probeResults = await parallelCacheProbe(ordered, cacheManager: cache);
    VideoSourceCandidate? bestReady;
    var bestTierRank = -1;
    for (final candidate in ordered) {
      if (candidate.type != 'mp4_quality' ||
          candidate.url.toLowerCase().contains('.m3u8')) {
        continue;
      }
      final ready = probeResults[candidate.url] ?? false;
      if (!ready) {
        continue;
      }
      final rank = _tierRank(mp4Tier(candidate.url));
      if (rank > bestTierRank) {
        bestTierRank = rank;
        bestReady = candidate;
      }
    }
    if (bestReady == null) {
      return ordered;
    }
    final result = List<VideoSourceCandidate>.from(ordered);
    result.remove(bestReady);
    result.insert(0, bestReady);
    return result;
  }

  Future<bool> _anyMp4Cached(
    List<VideoSourceCandidate> candidates,
    BaseCacheManager cache,
  ) async {
    final probeResults = await parallelCacheProbe(candidates, cacheManager: cache);
    return probeResults.values.any((ready) => ready);
  }

  /// Cached MP4 at [tier] for adaptive upgrade after first frame, if on disk.
  Future<VideoSourceCandidate?> cachedTierCandidate(
    List<VideoSourceCandidate> candidates, {
    required String tier,
    BaseCacheManager? cacheManager,
  }) async {
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    for (final candidate in candidates) {
      if (candidate.type != 'mp4_quality' ||
          mp4Tier(candidate.url) != tier) {
        continue;
      }
      if (await isPlaybackUrlCached(candidate.url, cacheManager: cache)) {
        return candidate;
      }
    }
    return null;
  }

  /// Cached 1080 MP4 candidate for adaptive upgrade after first frame, if any.
  Future<VideoSourceCandidate?> cached1080Candidate(
    List<VideoSourceCandidate> candidates, {
    BaseCacheManager? cacheManager,
  }) async {
    return cachedTierCandidate(
      candidates,
      tier: '1080',
      cacheManager: cacheManager,
    );
  }

  int _tierRank(String? tier) {
    return switch (tier) {
      '1080' => 3,
      '720' => 2,
      '360' => 1,
      _ => 0,
    };
  }

  List<VideoSourceCandidate> _orderMp4ByTier(
    List<VideoSourceCandidate> mp4,
    List<String> tiers,
  ) {
    if (mp4.length <= 1) {
      return mp4;
    }
    final ordered = <VideoSourceCandidate>[];
    final remaining = List<VideoSourceCandidate>.from(mp4);
    for (final tier in tiers) {
      for (final c in List<VideoSourceCandidate>.from(remaining)) {
        if (mp4Tier(c.url) == tier) {
          ordered.add(c);
          remaining.remove(c);
        }
      }
    }
    ordered.addAll(remaining);
    return ordered;
  }

  /// Quality tier ('360' | '720' | '1080') parsed from a ladder MP4 URL.
  String? mp4Tier(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/360.mp4') || lower.contains('_360')) {
      return '360';
    }
    if (lower.contains('/720.mp4') || lower.contains('_720')) {
      return '720';
    }
    if (lower.contains('/1080.mp4') || lower.contains('_1080')) {
      return '1080';
    }
    return null;
  }

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return MediaUrlResolver.playbackUrl(videoUrl: value);
  }

  String? _normalizeLegacy(String? value) => _normalize(value);

  /// Probes all [candidates] in parallel and returns a map of URL → cached status.
  /// Used by both `_wifiQualityConstrainedOrder` and `prioritizeForPlayback`
  /// to avoid redundant sequential disk I/O.
  Future<Map<String, bool>> parallelCacheProbe(
    List<VideoSourceCandidate> candidates, {
    BaseCacheManager? cacheManager,
  }) async {
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final urls = candidates
        .where((c) => c.type == 'mp4_quality')
        .map((c) => c.url)
        .toList(growable: false);
    if (urls.isEmpty) {
      return const {};
    }
    final results = await Future.wait(
      urls.map((url) async =>
          await isPlaybackUrlCached(url, cacheManager: cache) ||
          await isPlaybackUrlPartiallyCached(url, cacheManager: cache)),
    );
    final map = <String, bool>{};
    for (var i = 0; i < urls.length; i++) {
      map[urls[i]] = results[i];
    }
    return map;
  }
}

extension WallVideosPlayback on WallVideos {
  /// HLS master (`…/videos/{id}/hls/master.m3u8`) when [transcodeStatus] is ready.
  String? get resolvedHlsUrl {
    if (!isTranscodeReady) {
      return null;
    }
    return MediaUrlResolver.playbackUrl(
      videoUrl: hlsPlaylistUrl,
      video: hlsUrl,
    );
  }

  /// Ladder order for mid-range devices: 360 → 720 → 1080.
  List<String> get qualityMp4Urls {
    final sources = videoSources;
    if (sources == null || !sources.hasAny) {
      return const [];
    }
    return [
      if (sources.url360 != null) sources.url360!,
      if (sources.url720 != null) sources.url720!,
      if (sources.url1080 != null) sources.url1080!,
    ];
  }
}
