import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';

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
    final ready = video.isTranscodeReady;
    return resolveCandidates(
      hlsUrl: ready ? video.resolvedHlsUrl : null,
      mp4Url: video.resolvedPlaybackUrl,
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

  /// Reels: 720p MP4 first (sharp on phone screens, single fast-start request,
  /// disk-cacheable so a pre-cached reel paints instantly). 360p stays as the
  /// next fallback for slow networks / decode failures, then 1080p, then HLS,
  /// then full/legacy MP4 last.
  ///
  /// Every reel plays the same tier — speed comes from pre-caching the 720p
  /// bytes ([VideoPreloadManager]), not from downgrading quality.
  List<VideoSourceCandidate> prioritizeForNetwork(
    List<VideoSourceCandidate> candidates,
    NetworkClass network,
  ) {
    if (candidates.length <= 1) {
      return candidates;
    }
    final mp4Quality =
        candidates.where((c) => c.type == 'mp4_quality').toList(growable: false);
    final hls = candidates.where((c) => c.type == 'hls').toList(growable: false);
    final rest = candidates
        .where((c) => c.type != 'mp4_quality' && c.type != 'hls')
        .toList(growable: false);
    final orderedMp4 = _orderMp4ByTier(mp4Quality, const ['720', '360', '1080']);
    return [...orderedMp4, ...hls, ...rest];
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
