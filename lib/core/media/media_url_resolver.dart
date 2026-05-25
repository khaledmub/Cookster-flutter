import 'package:cookster/appUtils/apiEndPoints.dart';

/// Resolves API media fields without double-prefixing absolute CDN URLs.
class MediaUrlResolver {
  const MediaUrlResolver._();

  static bool isAbsolute(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Preferred playback URL: [videoUrl] then legacy [video].
  static String? playbackUrl({
    String? videoUrl,
    String? video,
    String? legacyBase,
  }) {
    return _firstResolved([videoUrl, video], legacyBase ?? Common.videoUrl);
  }

  /// Poster / grid cover: [thumbnailUrl], [imageUrl], then legacy [image].
  static String? thumbnailUrl({
    String? thumbnailUrl,
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    return _firstResolved(
      [thumbnailUrl, imageUrl, image],
      legacyBase ?? Common.videoUrl,
    );
  }

  /// Reel poster from API fields only (never synthesize `…/thumb.webp`).
  ///
  /// When [processingStatus] is `ready`, use [thumbnail_url] as returned (CDN
  /// `thumb.webp`). While pending, prefer grid [image]/[image_url] so a missing
  /// CDN poster file does not show a black frame.
  static String? reelPosterUrl({
    String? processingStatus,
    String? thumbnailUrl,
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    final base = legacyBase ?? Common.videoUrl;
    final posterReady = processingStatus == 'ready';

    if (posterReady) {
      final poster = _firstResolved([thumbnailUrl], base);
      if (poster != null) {
        return poster;
      }
    }

    final grid = firstAbsolute([imageUrl, image]);
    if (grid != null) {
      return grid;
    }

    if (!posterReady) {
      final legacyPoster = _firstResolved([thumbnailUrl], base);
      if (legacyPoster != null) {
        return legacyPoster;
      }
    }

    return _firstResolved([imageUrl, image], base);
  }

  /// Grid/cover URL used when the primary poster 404s (e.g. thumb not backfilled).
  static String? reelPosterFallback({
    String? imageUrl,
    String? image,
    String? legacyBase,
  }) {
    final grid = firstAbsolute([imageUrl, image]);
    if (grid != null) {
      return grid;
    }
    return _firstResolved([imageUrl, image], legacyBase ?? Common.videoUrl);
  }

  /// Optional tiny blur while the poster loads (absolute CDN URL from API).
  static String? reelBlurPlaceholder(String? thumbnailBlur) {
    if (thumbnailBlur == null || thumbnailBlur.trim().isEmpty) {
      return null;
    }
    final trimmed = thumbnailBlur.trim();
    if (isAbsolute(trimmed)) {
      return trimmed;
    }
    return null;
  }

  /// User avatar / cover: absolute CDN as-is, else prefix [Common.profileImage].
  static String? profileImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (isAbsolute(trimmed)) {
      // API sometimes returns CDN URLs without the /storage/ segment (404).
      if (trimmed.contains('/front_users/') &&
          !trimmed.contains('/storage/front_users/')) {
        return trimmed.replaceFirst(
          '/front_users/',
          '/storage/front_users/',
        );
      }
      return trimmed;
    }
    return _resolve(trimmed, Common.profileImage);
  }

  static String? _firstResolved(List<String?> candidates, String legacyBase) {
    for (final value in candidates) {
      final resolved = _resolve(value, legacyBase);
      if (resolved != null) return resolved;
    }
    return null;
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

  static String? _resolve(String? value, String legacyBase) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (isAbsolute(trimmed)) return trimmed;
    final base = legacyBase.endsWith('/')
        ? legacyBase.substring(0, legacyBase.length - 1)
        : legacyBase;
    final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$base/$path';
  }
}
