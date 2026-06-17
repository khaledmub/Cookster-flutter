import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
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

  static Widget buildPagePoster(WallVideos video) {
    if (video.isImage == 1) {
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: video.resolvedPlaybackUrl ?? '',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (context, url, error) => const SizedBox(),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final (memW, memH) = fullScreenPosterMemCacheSize(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black,
              child: CachedNetworkImage(
                imageUrl: video.resolvedReelPosterFallbackUrl ??
                    video.resolvedReelPosterUrl ??
                    '',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                memCacheWidth: memW,
                memCacheHeight: memH,
                errorWidget: (context, url, error) => const SizedBox(),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget buildInlinePlayer({
    required WallVideos video,
    required GlobalKey<ReelVideoPlayerState> playerKey,
    VoidCallback? onPlaybackReady,
    VoidCallback? onVideoCompleted,
    /// When false, caller must place the player inside a [Stack] (e.g. via
    /// [Positioned.fill]). Nested [Positioned] crashes at runtime.
    bool wrapPositioned = true,
  }) {
    final player = ReelVideoPlayer(
      // Shared [GlobalKey] from [VideoReelScreen] — one player state across tabs.
      key: playerKey,
      releaseOnDispose: false,
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
