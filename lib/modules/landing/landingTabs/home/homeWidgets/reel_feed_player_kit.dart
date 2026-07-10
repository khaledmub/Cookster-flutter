import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/reel_gapless_poster.dart';
import 'package:cookster/core/widgets/reel_image_display.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/material.dart';

/// A poster URL plus whether to decode at LQIP size for precache/warm.
class ReelPosterPrecacheTier {
  const ReelPosterPrecacheTier({required this.url, required this.lqip});

  final String url;
  final bool lqip;
}

/// Shared poster + [ReelVideoPlayer] used by the General home feed and profile
/// reel viewers — one configuration so playback behaves identically everywhere.
class ReelFeedPlayerKit {
  ReelFeedPlayerKit._();

  static String posterUrl(WallVideos video) {
    // Prefer the reel/frame poster (matches video framing). Grid cover JPGs are
    // often a different crop — with BoxFit.cover they look heavily zoomed until
    // the decoder unmasks (logs: video 406x721 vs cover JPG).
    return video.resolvedReelPosterUrl ??
        video.resolvedThumbnailUrl ??
        video.resolvedReelPosterFallbackUrl ??
        '';
  }

  /// Avoid passing cover JPG as a video source before transcode finishes.
  static String _playbackUrlForPlayer(WallVideos video) {
    if (video.isPhotoPost || !video.isTranscodeReady) {
      return '';
    }
    final url = video.resolvedPlaybackUrl?.trim() ?? '';
    if (url.isEmpty || isStaticImagePlaybackUrl(url)) {
      return '';
    }
    return url;
  }

  /// Fast LQIP for image posts — CDN thumbnail tier when full file lives elsewhere.
  static String? imageLqipUrl(WallVideos video) {
    final lqip = video.resolvedPhotoLqipUrl?.trim();
    if (lqip != null && lqip.isNotEmpty) {
      return lqip;
    }
    final thumb = video.resolvedThumbnailUrl ??
        video.resolvedReelPosterUrl ??
        video.resolvedReelPosterFallbackUrl;
    final trimmed = thumb?.trim() ?? '';
    final full = video.resolvedPhotoDisplayUrl?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == full) {
      return null;
    }
    return trimmed;
  }

  /// Blur/LQIP underlay for image posts — separate CDN path or same URL for
  /// downscaled decode tier.
  static String? imagePostBlurUrl(WallVideos video) {
    final full = imagePostDisplayUrl(video) ?? '';
    if (full.isEmpty) {
      return null;
    }
    final lqip = imageLqipUrl(video);
    if (lqip != null && lqip.isNotEmpty && lqip != full) {
      return lqip;
    }
    // Same URL for thumb + full — skip blur tier (upscaling LQIP looks pixelated).
    return null;
  }

  static String imagePostCacheKey(WallVideos video) =>
      'image_post_${video.id ?? video.resolvedPhotoDisplayUrl ?? ''}';

  static String? imagePostDisplayUrl(WallVideos video) {
    final url = video.resolvedPhotoDisplayUrl?.trim() ?? '';
    return url.isEmpty ? null : url;
  }

  /// Ordered decode tiers to warm ahead of scroll.
  static List<ReelPosterPrecacheTier> precachePosterTiers(WallVideos video) {
    if (video.isPhotoPost) {
      final full = imagePostDisplayUrl(video) ?? '';
      if (full.isEmpty) {
        return const [];
      }
      final lqip = imageLqipUrl(video);
      if (lqip != null && lqip.isNotEmpty && lqip != full) {
        return [
          ReelPosterPrecacheTier(url: lqip, lqip: true),
          ReelPosterPrecacheTier(url: full, lqip: false),
        ];
      }
      return [
        ReelPosterPrecacheTier(url: full, lqip: false),
      ];
    }
    final primary = posterUrl(video);
    if (primary.isEmpty) {
      return const [];
    }
    final tiers = <ReelPosterPrecacheTier>[
      ReelPosterPrecacheTier(url: primary, lqip: false),
    ];
    final blur = videoPosterBlurUrl(video);
    if (blur != null && blur.isNotEmpty) {
      if (blur != primary) {
        tiers.insert(0, ReelPosterPrecacheTier(url: blur, lqip: true));
      } else {
        tiers.insert(0, ReelPosterPrecacheTier(url: primary, lqip: true));
      }
    }
    return tiers;
  }

  /// Ordered URL strings for legacy callers.
  static List<String> precachePosterUrls(WallVideos video) {
    return precachePosterTiers(video).map((t) => t.url).toList();
  }

  /// Primary URL to warm in RAM/disk ahead of scroll (LQIP for image posts).
  static String? precachePosterUrl(WallVideos video) {
    final tiers = precachePosterTiers(video);
    return tiers.isEmpty ? null : tiers.first.url;
  }

  /// True when [url] at [index] in [precachePosterTiers] is the LQIP tier.
  static bool isPrecacheLqipTier(WallVideos video, String url) {
    for (final tier in precachePosterTiers(video)) {
      if (tier.url == url.trim()) {
        return tier.lqip;
      }
    }
    return false;
  }

  /// Blur underlay for video page posters.
  static String? videoPosterBlurUrl(WallVideos video) {
    if (video.isTranscodeReady) {
      final blur = video.resolvedBlurThumbnailUrl?.trim() ?? '';
      if (blur.isNotEmpty) {
        return blur;
      }
    }
    // Do not use grid cover as LQIP under the reel poster — different crop
    // reads as a zoomed flash before the video unmasks.
    return null;
  }

  /// Full-screen poster for off-screen / image pages. Active video pages should
  /// omit this when the inline player is mounted (player owns the poster).
  static Widget buildPagePoster(WallVideos video) {
    if (video.isPhotoPost) {
      final url = imagePostDisplayUrl(video) ?? '';
      if (url.isEmpty) {
        return const ColoredBox(color: Colors.black);
      }
      return ReelGaplessPoster(
        imageUrl: url,
        blurUrl: imagePostBlurUrl(video),
        fallbackUrl: video.resolvedThumbnailUrl ??
            video.resolvedReelPosterFallbackUrl,
        cacheKey: imagePostCacheKey(video),
        fit: BoxFit.cover,
      );
    }
    // Same URL order as [posterUrl] / inline player — keeps poster→video framing
    // identical (no side-shrink on unmask).
    final primary = posterUrl(video);
    return ReelGaplessPoster(
      imageUrl: primary,
      blurUrl: videoPosterBlurUrl(video),
      fallbackUrl: video.resolvedReelPosterFallbackUrl,
      cacheKey: 'page_poster_${video.id ?? primary}',
      fit: BoxFit.cover,
    );
  }

  /// Lightweight thumb-only layer for off-screen image posts.
  static Widget buildImageThumbPoster(WallVideos video) {
    final url = imagePostBlurUrl(video) ??
        imagePostDisplayUrl(video) ??
        '';
    if (url.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return ReelGaplessPoster(
      imageUrl: url,
      cacheKey: 'image_thumb_${video.id ?? url}',
      fit: BoxFit.cover,
      memScale: 0.35,
      filterQuality: FilterQuality.low,
      useLqipTier: true,
    );
  }

  /// Visible-slot image holder — mount only on the active image page.
  static Widget buildVisibleImageDisplay({
    required WallVideos video,
    required GlobalKey<ReelImageDisplayState> displayKey,
    bool wrapPositioned = true,
  }) {
    final url = imagePostDisplayUrl(video) ?? '';
    final display = ReelImageDisplay(
      key: displayKey,
      imageUrl: url,
      blurUrl: imagePostBlurUrl(video),
      cacheKey: imagePostCacheKey(video),
      fit: BoxFit.cover,
      overlayMode: true,
    );
    if (wrapPositioned) {
      return Positioned.fill(child: display);
    }
    return display;
  }

  static Widget buildInlinePlayer({
    required WallVideos video,
    required GlobalKey<ReelVideoPlayerState> playerKey,
    VoidCallback? onPlaybackReady,
    VoidCallback? onFeedVideoPainted,
    VoidCallback? onFeedAwaitingPaint,
    VoidCallback? onVideoCompleted,
    bool releaseOnDispose = false,
    bool wrapPositioned = true,
    bool showProgressBar = false,
  }) {
    final player = ReelVideoPlayer(
      key: playerKey,
      releaseOnDispose: releaseOnDispose,
      showProgressBar: showProgressBar && !video.isPhotoPost,
      playerPoolKey: video.id,
      videoId: video.id,
      thumbnailUrl: posterUrl(video),
      posterFallbackUrl: video.resolvedReelPosterFallbackUrl,
      // Never put a differently-cropped grid cover under the reel poster —
      // that reads as a zoom/shrink flash when the frame unmasks.
      blurThumbnailUrl: videoPosterBlurUrl(video),
      transcodeReady: video.isTranscodeReady,
      videoUrl: _playbackUrlForPlayer(video),
      hlsUrl: video.resolvedHlsUrl,
      qualityMp4Urls:
          video.isTranscodeReady ? video.qualityMp4Urls : const [],
      onPlaybackReady: onPlaybackReady,
      onFeedVideoPainted: onFeedVideoPainted,
      onFeedAwaitingPaint: onFeedAwaitingPaint,
      onVideoCompleted: onVideoCompleted,
    );
    if (wrapPositioned) {
      return Positioned.fill(child: player);
    }
    return player;
  }
}
