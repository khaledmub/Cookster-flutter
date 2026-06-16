import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';

extension WallVideosMedia on WallVideos {
  String? get resolvedPlaybackUrl => MediaUrlResolver.playbackUrl(
        videoUrl: videoUrl,
        video: video,
      );

  String? get resolvedThumbnailUrl => MediaUrlResolver.thumbnailUrl(
        thumbnailUrl: thumbnailUrl,
        imageUrl: imageUrl,
        image: image,
      );

  /// Poster for reel playback (CDN thumb only when pipeline fully ready).
  String? get resolvedReelPosterUrl => MediaUrlResolver.reelPosterUrl(
        processingStatus: processingStatus,
        transcodeStatus: transcodeStatus,
        thumbnailUrl: thumbnailUrl,
        imageUrl: imageUrl,
        image: image,
      );

  /// Cover/grid fallback if [thumbnail_url] 404s on CDN.
  String? get resolvedReelPosterFallbackUrl =>
      MediaUrlResolver.reelPosterFallback(
        imageUrl: imageUrl,
        image: image,
      );

  /// Optional blurred placeholder from GET /api/reels.
  String? get resolvedBlurThumbnailUrl =>
      MediaUrlResolver.reelBlurPlaceholder(thumbnailBlur);

  /// Reels: nested `user.image`; feeds: `user_image` / `user_image_url`.
  String? get resolvedUserAvatarUrl =>
      MediaUrlResolver.profileImageUrl(userImage);

  int get displayFollowersCount => parseApiCount(followersCount);
}
