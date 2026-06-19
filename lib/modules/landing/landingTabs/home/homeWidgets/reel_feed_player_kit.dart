import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/reel_gapless_poster.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/material.dart';

/// Shared poster + [ReelVideoPlayer] used by the General home feed and profile
/// reel viewers — one configuration so playback behaves identically everywhere.
class ReelFeedPlayerKit {
  ReelFeedPlayerKit._();

  static String posterUrl(WallVideos video) {
    return video.resolvedReelPosterFallbackUrl ??
        video.resolvedReelPosterUrl ??
        video.resolvedThumbnailUrl ??
        '';
  }

  /// URL to warm in RAM/disk ahead of scroll — images use full asset, videos poster.
  static String? precachePosterUrl(WallVideos video) {
    if (video.isImage == 1) {
      return video.resolvedPlaybackUrl;
    }
    final url = posterUrl(video);
    return url.isEmpty ? null : url;
  }

  /// Full-screen poster for off-screen / image pages. Active video pages should
  /// omit this when the inline player is mounted (player owns the poster).
  static Widget buildPagePoster(WallVideos video) {
    if (video.isImage == 1) {
      final url = video.resolvedPlaybackUrl ?? '';
      return ReelGaplessPoster(
        imageUrl: url,
        cacheKey: 'image_post_${video.id ?? url}',
        fit: BoxFit.cover,
      );
    }
    final primary = video.resolvedReelPosterFallbackUrl ??
        video.resolvedReelPosterUrl ??
        '';
    return ReelGaplessPoster(
      imageUrl: primary,
      blurUrl: video.isTranscodeReady ? video.resolvedBlurThumbnailUrl : null,
      fallbackUrl: video.resolvedReelPosterFallbackUrl,
      cacheKey: 'page_poster_${video.id ?? primary}',
      fit: BoxFit.cover,
    );
  }

  static Widget buildInlinePlayer({
    required WallVideos video,
    required GlobalKey<ReelVideoPlayerState> playerKey,
    VoidCallback? onPlaybackReady,
    VoidCallback? onVideoCompleted,
    bool releaseOnDispose = false,
    bool wrapPositioned = true,
  }) {
    final player = ReelVideoPlayer(
      key: playerKey,
      releaseOnDispose: releaseOnDispose,
      playerPoolKey: video.id,
      videoId: video.id,
      thumbnailUrl: posterUrl(video),
      posterFallbackUrl: video.resolvedReelPosterFallbackUrl,
      blurThumbnailUrl:
          video.isTranscodeReady ? video.resolvedBlurThumbnailUrl : null,
      transcodeReady: video.isTranscodeReady,
      videoUrl: video.resolvedPlaybackUrl ?? '',
      hlsUrl: video.resolvedHlsUrl,
      qualityMp4Urls:
          video.isTranscodeReady ? video.qualityMp4Urls : const [],
      onPlaybackReady: onPlaybackReady,
      onVideoCompleted: onVideoCompleted,
    );
    if (wrapPositioned) {
      return Positioned.fill(child: player);
    }
    return player;
  }
}
