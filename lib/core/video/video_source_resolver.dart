import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
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
      legacyPath: video.video,
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

    return _withCdnFallbacks(candidates);
  }

  List<VideoSourceCandidate> _withCdnFallbacks(
    List<VideoSourceCandidate> candidates,
  ) {
    const cdnHost = 'cdn.cookster.org';
    const gcsHost = 'storage.googleapis.com/cookster-storage-v1';
    final seen = <String>{};
    final expanded = <VideoSourceCandidate>[];
    for (final candidate in candidates) {
      for (final url in <String>[
        candidate.url,
        if (candidate.url.contains(cdnHost))
          candidate.url.replaceFirst(cdnHost, gcsHost),
      ]) {
        if (seen.add(url)) {
          expanded.add(VideoSourceCandidate(url: url, type: candidate.type));
        }
      }
    }
    return expanded;
  }

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (MediaUrlResolver.isAbsolute(trimmed)) {
      return trimmed;
    }
    return '${Common.videoUrl}/$trimmed';
  }

  String? _normalizeLegacy(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (MediaUrlResolver.isAbsolute(trimmed)) {
      return trimmed;
    }
    return '${Common.videoUrl}/$trimmed';
  }
}

extension WallVideosPlayback on WallVideos {
  /// HLS master (`…/videos/{id}/hls/master.m3u8`) when [transcodeStatus] is ready.
  String? get resolvedHlsUrl {
    if (!isTranscodeReady) {
      return null;
    }
    final fromApi = MediaUrlResolver.firstAbsolute([
      hlsPlaylistUrl,
      hlsUrl,
    ]);
    if (fromApi != null) {
      return fromApi;
    }
    final legacy = video;
    if (legacy != null &&
        legacy.contains('.m3u8') &&
        MediaUrlResolver.isAbsolute(legacy)) {
      return legacy;
    }
    if (legacy != null && legacy.contains('.m3u8')) {
      return '${Common.videoUrl}/$legacy';
    }
    return null;
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
