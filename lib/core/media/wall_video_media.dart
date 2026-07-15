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
  bool get isPhotoPost => isReelGridPhotoPost(
        isImage: isImage,
        videoUrl: videoUrl,
        video: video,
        thumbnailUrl: thumbnailUrl,
        imageUrl: imageUrl,
        image: image,
        transcodeStatus: transcodeStatus,
        processingStatus: processingStatus,
      );

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
        playbackUrl: resolvedPlaybackUrl,
      );
}

/// Shared photo-post detection for feed items and profile grid tiles.
bool isReelGridPhotoPost({
  required dynamic isImage,
  dynamic videoUrl,
  dynamic video,
  dynamic thumbnailUrl,
  dynamic imageUrl,
  dynamic image,
  dynamic transcodeStatus,
  dynamic processingStatus,
}) {
  if (isReelPhotoPostFlag(isImage)) {
    return true;
  }
  final playback = MediaUrlResolver.playbackUrl(
        videoUrl: videoUrl?.toString(),
        video: video?.toString(),
      )
          ?.trim()
          .toLowerCase() ??
      '';
  final hasRealVideoPlayback = playback.contains('.m3u8') ||
      playback.contains('.mp4') ||
      playback.contains('/hls/');
  if (hasRealVideoPlayback) {
    return false;
  }
  if (playback.isNotEmpty && isStaticImagePlaybackUrl(playback)) {
    // Fresh video uploads put the cover JPG in video_url until transcode.
    // Trust an explicit is_image=0 / false / "0" from the API as video so the
    // profile grid doesn't show the Photo badge until pull-to-refresh.
    if (isImage != null && !isReelPhotoPostFlag(isImage)) {
      return false;
    }
    // No is_image flag: only treat as video when the pipeline says pending.
    if (_looksLikePendingVideoTranscode(
      transcodeStatus: transcodeStatus,
      processingStatus: processingStatus,
    )) {
      return false;
    }
    return true;
  }
  final cover = MediaUrlResolver.thumbnailUrl(
        thumbnailUrl: thumbnailUrl?.toString(),
        imageUrl: imageUrl?.toString(),
        image: image?.toString(),
      )
          ?.trim()
          .toLowerCase() ??
      '';
  final hasVideoFields =
      (videoUrl?.toString().trim().isNotEmpty == true) ||
      (video?.toString().trim().isNotEmpty == true);
  // Cover-only rows (fresh uploads ship JPG before mp4):
  // - pending/processing → video (never treat as photo)
  // - is_image=0 and not yet ready → video
  // - is_image=0 + transcode ready + no video URL → mis-tagged photo (legacy)
  // - otherwise → photo
  if (!hasVideoFields &&
      cover.isNotEmpty &&
      isStaticImagePlaybackUrl(cover)) {
    if (_looksLikePendingVideoTranscode(
      transcodeStatus: transcodeStatus,
      processingStatus: processingStatus,
    )) {
      return false;
    }
    if (isImage != null &&
        !isReelPhotoPostFlag(isImage) &&
        transcodeStatus?.toString() != 'ready') {
      return false;
    }
    return true;
  }
  if (transcodeStatus?.toString() == 'ready' && hasRealVideoPlayback) {
    return false;
  }
  return false;
}

/// True when a grid item is a VIDEO post whose server-side transcode has not
/// finished yet — used to show a "processing" overlay and block opening it
/// until it is actually watchable.
bool isReelGridProcessing({
  required dynamic isImage,
  dynamic videoUrl,
  dynamic video,
  dynamic thumbnailUrl,
  dynamic imageUrl,
  dynamic image,
  dynamic transcodeStatus,
  dynamic processingStatus,
  dynamic playbackReady,
}) {
  // Real photos are never "processing".
  if (isReelPhotoPostFlag(isImage)) {
    return false;
  }
  // Fresh uploads: cover JPG + pending/processing before any mp4 exists.
  // Do this before the photo heuristic so we never open them as photos.
  if (_looksLikePendingVideoTranscode(
    transcodeStatus: transcodeStatus,
    processingStatus: processingStatus,
  )) {
    return true;
  }
  final isPhoto = isReelGridPhotoPost(
    isImage: isImage,
    videoUrl: videoUrl,
    video: video,
    thumbnailUrl: thumbnailUrl,
    imageUrl: imageUrl,
    image: image,
    transcodeStatus: transcodeStatus,
    processingStatus: processingStatus,
  );
  if (isPhoto) {
    return false;
  }
  final ready = PlaybackMedia.isPlaybackReady(
    isPhotoPost: false,
    playbackReady: PlaybackMedia.parseOptionalFlag(playbackReady),
    transcodeStatus: transcodeStatus?.toString(),
    playbackUrl: MediaUrlResolver.playbackUrl(
      videoUrl: videoUrl?.toString(),
      video: video?.toString(),
    ),
  );
  return !ready;
}

bool _looksLikePendingVideoTranscode({
  dynamic transcodeStatus,
  dynamic processingStatus,
}) {
  final statuses = <String>[
    transcodeStatus?.toString().trim().toLowerCase() ?? '',
    processingStatus?.toString().trim().toLowerCase() ?? '',
  ];
  const pending = <String>{
    'pending',
    'processing',
    'queued',
    'running',
    'transcoding',
  };
  for (final status in statuses) {
    if (status.isNotEmpty && pending.contains(status)) {
      return true;
    }
  }
  return false;
}

/// Shared photo-post flag parsing for [WallVideos] and profile grid tiles.
bool isReelPhotoPostFlag(dynamic isImage) {
  if (isImage == null) {
    return false;
  }
  if (isImage is bool) {
    return isImage;
  }
  if (isImage is num) {
    return isImage == 1;
  }
  final normalized = isImage.toString().trim().toLowerCase();
  if (normalized == '1' || normalized == 'true') {
    return true;
  }
  // JSON sometimes yields "1.0" for numeric flags.
  final asNum = num.tryParse(normalized);
  return asNum != null && asNum == 1;
}

bool isStaticImagePlaybackUrl(String url) {
  return RegExp(
    r'\.(jpe?g|png|webp|gif|heif|heic|bmp)(\?|#|$)',
    caseSensitive: false,
  ).hasMatch(url);
}
