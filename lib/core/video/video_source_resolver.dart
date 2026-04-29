import 'package:cookster/appUtils/apiEndPoints.dart';

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

  List<VideoSourceCandidate> resolveCandidates({
    String? hlsUrl,
    String? mp4Url,
    String? legacyPath,
  }) {
    final candidates = <VideoSourceCandidate>[];

    final normalizedHls = _normalize(hlsUrl);
    if (normalizedHls != null && normalizedHls.toLowerCase().contains('.m3u8')) {
      candidates.add(VideoSourceCandidate(url: normalizedHls, type: 'hls'));
    }

    final normalizedMp4 = _normalize(mp4Url);
    if (normalizedMp4 != null) {
      candidates.add(VideoSourceCandidate(url: normalizedMp4, type: 'mp4'));
    }

    final normalizedLegacy = _normalizeLegacy(legacyPath);
    if (normalizedLegacy != null) {
      candidates.add(VideoSourceCandidate(url: normalizedLegacy, type: 'legacy'));
    }

    return candidates;
  }

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.startsWith('http')) {
      return trimmed;
    }
    return '${Common.videoUrl}/$trimmed';
  }

  String? _normalizeLegacy(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    return '${Common.videoUrl}/$trimmed';
  }
}
