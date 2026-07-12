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
  /// When transcode is ready, prefer the CDN frame poster ([thumbnailUrl]) so
  /// the pre-video image matches the decoded frame (avoids side-shrink when a
  /// differently-cropped grid JPG was shown first). Before transcode, use the
  /// grid cover — it is the only still available.
  static String? reelPosterUrl({
    String? processingStatus,
    String? transcodeStatus,
    String? thumbnailUrl,
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    final transcodeReady = transcodeStatus == 'ready';
    final thumb = _firstResolved([thumbnailUrl]);
    final grid = _firstResolved([imageUrl, image]);

    if (transcodeReady &&
        thumb != null &&
        !_isPendingCdnThumb(thumb, true)) {
      return thumb;
    }
    if (grid != null) {
      return grid;
    }
    if (thumb != null && !_isPendingCdnThumb(thumb, transcodeReady)) {
      return thumb;
    }
    return grid;
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

  /// CDN feed sometimes puts a low-res file under `/videos/thumbnail/…`
  /// or names the still `thumb.webp` (grid/LQIP, not full photo).
  static bool isCdnThumbnailPath(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.contains('/videos/thumbnail/') || lower.contains('thumb.webp');
  }

  /// `…/videos/thumbnail/123.jpg` → `…/videos/123.jpg`
  /// `…/videos/123/thumb.webp` → left unchanged (caller should prefer another field).
  static String upgradePhotoUrlToFullResolution(String url) {
    final lower = url.toLowerCase();
    const marker = '/videos/thumbnail/';
    final idx = lower.indexOf(marker);
    if (idx < 0) {
      return url;
    }
    return '${url.substring(0, idx)}/videos/${url.substring(idx + marker.length)}';
  }

  /// Best full-screen URL for photo posts (`is_image: 1`).
  ///
  /// Backend contract: [videoUrl] / [video] = full JPG; [thumbnailUrl] = LQIP
  /// only. Legacy rows may still put `/videos/thumbnail/…` or `thumb.webp` in
  /// [videoUrl] — skip / upgrade those so full-screen photos are not pixelated.
  static String? photoDisplayUrl({
    String? videoUrl,
    String? video,
    String? imageUrl,
    String? image,
    String? thumbnailUrl,
  }) {
    String? fallbackThumb;
    for (final raw in [videoUrl, video, imageUrl, image]) {
      final resolved = _resolveMediaPath(raw);
      if (resolved == null || resolved.isEmpty) {
        continue;
      }
      if (!_isStaticImagePath(resolved)) {
        continue;
      }
      if (isCdnThumbnailPath(resolved)) {
        final upgraded = upgradePhotoUrlToFullResolution(resolved);
        if (upgraded != resolved && !isCdnThumbnailPath(upgraded)) {
          return upgraded;
        }
        fallbackThumb ??= resolved;
        continue;
      }
      return resolved;
    }

    // Legacy rows with only thumbnail fields populated.
    final legacyThumb = _resolveMediaPath(thumbnailUrl);
    if (legacyThumb != null &&
        legacyThumb.isNotEmpty &&
        _isStaticImagePath(legacyThumb)) {
      final upgraded = upgradePhotoUrlToFullResolution(legacyThumb);
      if (upgraded != legacyThumb && !isCdnThumbnailPath(upgraded)) {
        return upgraded;
      }
      return fallbackThumb ?? legacyThumb;
    }
    return fallbackThumb;
  }

  /// Low-res placeholder while [photoDisplayUrl] loads — uses [thumbnailUrl].
  static String? photoLqipUrl({
    String? videoUrl,
    String? video,
    String? imageUrl,
    String? image,
    String? thumbnailUrl,
  }) {
    final full = photoDisplayUrl(
      videoUrl: videoUrl,
      video: video,
      imageUrl: imageUrl,
      image: image,
      thumbnailUrl: thumbnailUrl,
    );
    if (full == null || full.isEmpty) {
      return null;
    }
    final thumb = _resolveMediaPath(thumbnailUrl);
    if (thumb != null && thumb.isNotEmpty && thumb != full) {
      return thumb;
    }
    for (final raw in [videoUrl, video]) {
      final resolved = _resolveMediaPath(raw);
      if (resolved == null || resolved.isEmpty || resolved == full) {
        continue;
      }
      if (isCdnThumbnailPath(resolved) &&
          upgradePhotoUrlToFullResolution(resolved) == full) {
        return resolved;
      }
    }
    return null;
  }

  static bool _isStaticImagePath(String url) {
    return RegExp(
      r'\.(jpe?g|png|webp|gif|heif|heic|bmp)(\?|#|$)',
      caseSensitive: false,
    ).hasMatch(url.toLowerCase());
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
