import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/playback_media.dart';
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

  /// Backend sends `is_image: 1` for photos and `0` for videos. When the flag
  /// disagrees with an obvious static-image URL, trust the URL (mis-tagged rows).
  bool get isPhotoPost {
    if (isReelPhotoPostFlag(isImage)) {
      return true;
    }
    if (_looksLikeStaticImagePost) {
      return true;
    }
    if (isImage != null) {
      return false;
    }
    return _looksLikeStaticImagePost;
  }

  bool get _looksLikeStaticImagePost {
    final playback = resolvedPlaybackUrl?.trim().toLowerCase() ?? '';
    if (playback.contains('.m3u8') ||
        playback.contains('.mp4') ||
        playback.contains('/hls/')) {
      return false;
    }
    if (playback.isNotEmpty && isStaticImagePlaybackUrl(playback)) {
      // Fresh video uploads: backend puts cover JPG in video_url until transcode.
      if (isImage != null && !isReelPhotoPostFlag(isImage)) {
        return false;
      }
      return true;
    }
    if (isTranscodeReady) {
      return false;
    }
    final hasVideoFields =
        (videoUrl?.trim().isNotEmpty == true) ||
        (video?.trim().isNotEmpty == true);
    final cover = resolvedThumbnailUrl?.trim().toLowerCase() ?? '';
    return !hasVideoFields &&
        cover.isNotEmpty &&
        isStaticImagePlaybackUrl(cover);
  }

  /// Full-screen photo URL — uses API [video_url] first; thumbnail upgrade is legacy fallback.
  String? get resolvedPhotoDisplayUrl => MediaUrlResolver.photoDisplayUrl(
        videoUrl: videoUrl,
        video: video,
        imageUrl: imageUrl,
        image: image,
        thumbnailUrl: thumbnailUrl,
      );

  /// Low-res CDN thumbnail for progressive photo load (optional).
  String? get resolvedPhotoLqipUrl => MediaUrlResolver.photoLqipUrl(
        videoUrl: videoUrl,
        video: video,
        imageUrl: imageUrl,
        image: image,
        thumbnailUrl: thumbnailUrl,
      );

  /// True when the item can be shown/played in feed (photo or `playback_ready`).
  bool get isPlaybackReady => PlaybackMedia.isPlaybackReady(
        isPhotoPost: isPhotoPost,
        playbackReady: playbackReady,
        transcodeStatus: transcodeStatus,
      );
}

/// Shared photo-post flag parsing for [WallVideos] and profile grid tiles.
bool isReelPhotoPostFlag(dynamic isImage) {
  if (isImage == null) {
    return false;
  }
  if (isImage is int) {
    return isImage == 1;
  }
  if (isImage is bool) {
    return isImage;
  }
  final normalized = isImage.toString().trim().toLowerCase();
  return normalized == '1' || normalized == 'true';
}

bool isStaticImagePlaybackUrl(String url) {
  return RegExp(
    r'\.(jpe?g|png|webp|gif|heif|heic|bmp)(\?|#|$)',
    caseSensitive: false,
  ).hasMatch(url);
}
