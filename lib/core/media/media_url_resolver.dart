import 'package:cookster/appUtils/apiEndPoints.dart';

/// Resolves API media fields without double-prefixing absolute CDN URLs.
class MediaUrlResolver {
  const MediaUrlResolver._();

  static bool isAbsolute(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Preferred playback URL from API (absolute CDN, or legacy storage path).
  static String? playbackUrl({
    String? videoUrl,
    String? video,
    String? legacyBase,
  }) {
    return _firstResolved([videoUrl, video]);
  }

  /// Poster / grid cover from API fields.
  static String? thumbnailUrl({
    String? thumbnailUrl,
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    return _firstResolved([thumbnailUrl, imageUrl, image]);
  }

  /// Reel poster from API fields only (never synthesize `…/thumb.webp`).
  ///
  /// CDN `thumb.webp` only when **both** cover and transcode are ready — fresh
  /// uploads often have `processing_status=ready` before the file exists (404 →
  /// white flash). Until then use grid [image]/[image_url].
  static String? reelPosterUrl({
    String? processingStatus,
    String? transcodeStatus,
    String? thumbnailUrl,
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    final coverReady = processingStatus == 'ready';
    final transcodeReady = transcodeStatus == 'ready';
    final useCdnPoster = coverReady && transcodeReady;

    final grid = _firstResolved([imageUrl, image]);

    if (useCdnPoster) {
      final poster = _firstResolved([thumbnailUrl]);
      if (poster != null && !_isPendingCdnThumb(poster, transcodeReady)) {
        // Oppo/MediaTek often fail WEBP in Flutter's ImageDecoder ('unimplemented');
        // prefer grid JPG when the CDN poster is WEBP.
        if (_isWebp(poster) && grid != null) {
          return grid;
        }
        return poster;
      }
    }
    if (grid != null) {
      return grid;
    }

    final thumb = _firstResolved([thumbnailUrl]);
    if (thumb != null && !_isPendingCdnThumb(thumb, transcodeReady)) {
      if (_isWebp(thumb) && grid != null) {
        return grid;
      }
      return thumb;
    }

    return grid;
  }

  static bool _isWebp(String? url) {
    if (url == null) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.contains('.webp') || lower.contains('thumb.webp');
  }

  /// CDN `thumb.webp` before transcode finishes — often 404 or a white placeholder.
  static bool _isPendingCdnThumb(String? url, bool transcodeReady) {
    if (transcodeReady || url == null) {
      return false;
    }
    return url.contains('thumb.webp');
  }

  /// Grid/cover URL used when the primary poster 404s (e.g. thumb not backfilled).
  static String? reelPosterFallback({
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    return _firstResolved([imageUrl, image]);
  }

  /// Optional tiny blur while the poster loads (absolute CDN URL from API).
  static String? reelBlurPlaceholder(String? thumbnailBlur) {
    return _firstResolved([thumbnailBlur]);
  }

  /// User avatar / cover: absolute CDN URL, or legacy `front_users/{file}` path.
  static String? profileImageUrl(String? value) {
    return _resolveProfileAsset(value);
  }

  /// First absolute https URL in [candidates]; skips relative keys.
  static String? firstAbsolute(List<String?> candidates) {
    for (final value in candidates) {
      if (value == null || value.trim().isEmpty) continue;
      final trimmed = value.trim();
      if (isAbsolute(trimmed)) return trimmed;
    }
    return null;
  }

  static String? _firstResolved(List<String?> candidates) {
    for (final value in candidates) {
      final resolved = _resolveMediaPath(value);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  static String? _resolveProfileAsset(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (isAbsolute(trimmed)) {
      return trimmed;
    }
    if (!trimmed.contains('/')) {
      return '${Common.profileImage}/$trimmed';
    }
    return _legacyStorageUrl(trimmed);
  }

  static String? _resolveMediaPath(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (isAbsolute(trimmed)) {
      return trimmed;
    }
    final storage = _legacyStorageUrl(trimmed);
    if (storage != null) {
      return storage;
    }
    if (!trimmed.contains('/')) {
      return '${Common.videoUrl}/$trimmed';
    }
    return null;
  }

  /// Joins relative API paths (`front_users/x.jpg`, `videos/foo.mp4`) to storage base.
  static String? _legacyStorageUrl(String relative) {
    var path = relative.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('storage/')) {
      path = path.substring('storage/'.length);
    }
    if (path.isEmpty) {
      return null;
    }
    return '${Common.imageBaseUrl}$path';
  }
}
