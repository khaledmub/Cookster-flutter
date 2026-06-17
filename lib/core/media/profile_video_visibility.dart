import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/playback_media.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/video_sources.dart';

/// Profile grid / reel listing — hide inactive, failed, or media-less videos.
class ProfileVideoVisibility {
  ProfileVideoVisibility._();

  /// Reel viewer: never drop rows client-side — grid seeds + API merge handle gaps.
  static bool isWallVideoListable(WallVideos video) => true;

  static bool shouldListOnProfileGrid({
    dynamic status,
    dynamic state,
    dynamic processingStatus,
    dynamic transcodeStatus,
    dynamic videoUrl,
    dynamic video,
    dynamic hlsUrl,
    dynamic hlsPlaylistUrl,
    dynamic thumbnailUrl,
    dynamic imageUrl,
    dynamic image,
    dynamic isImage,
    VideoSources? videoSources,
  }) {
    if (!_isActiveFlag(status) || !_isActiveFlag(state)) {
      return false;
    }
    final proc = processingStatus?.toString().trim().toLowerCase();
    final trans = transcodeStatus?.toString().trim().toLowerCase();
    if (proc == 'failed' || trans == 'failed') {
      return false;
    }
    return true;
  }

  static bool hasPlayableMedia({
    dynamic videoUrl,
    dynamic video,
    dynamic hlsUrl,
    dynamic hlsPlaylistUrl,
    dynamic transcodeStatus,
    dynamic thumbnailUrl,
    dynamic imageUrl,
    dynamic image,
    dynamic isImage,
    VideoSources? videoSources,
  }) {
    if (_hasDisplayableMedia(
      videoUrl: videoUrl,
      video: video,
      hlsUrl: hlsUrl,
      hlsPlaylistUrl: hlsPlaylistUrl,
      transcodeStatus: transcodeStatus,
      thumbnailUrl: thumbnailUrl,
      imageUrl: imageUrl,
      image: image,
      isImage: isImage,
      videoSources: videoSources,
    )) {
      return true;
    }
    return _hasRawMediaFields(
      videoUrl: videoUrl,
      video: video,
      hlsUrl: hlsUrl,
      hlsPlaylistUrl: hlsPlaylistUrl,
      thumbnailUrl: thumbnailUrl,
      imageUrl: imageUrl,
      image: image,
      videoSources: videoSources,
    );
  }

  static bool _isActiveFlag(dynamic value) {
    if (value == null) {
      return true;
    }
    if (value == false) {
      return false;
    }
    if (value is num && value == 0) {
      // status/state 0 is often draft/processing on profile — still show on grid.
      return true;
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == '0') {
      return true;
    }
    return normalized != 'false' &&
        normalized != 'inactive' &&
        normalized != 'deleted' &&
        normalized != 'disabled';
  }

  static bool _hasDisplayableMedia({
    required dynamic videoUrl,
    required dynamic video,
    required dynamic hlsUrl,
    required dynamic hlsPlaylistUrl,
    required dynamic transcodeStatus,
    required dynamic thumbnailUrl,
    required dynamic imageUrl,
    required dynamic image,
    required dynamic isImage,
    VideoSources? videoSources,
  }) {
    final playback = MediaUrlResolver.playbackUrl(
      videoUrl: videoUrl?.toString(),
      video: video?.toString(),
    );
    if (playback != null && playback.isNotEmpty) {
      return true;
    }

    final hls = PlaybackMedia.resolvedHls(
      transcodeStatus: transcodeStatus?.toString(),
      hlsPlaylistUrl: hlsPlaylistUrl?.toString(),
      hlsUrl: hlsUrl?.toString(),
    );
    if (hls != null && hls.isNotEmpty) {
      return true;
    }

    if (videoSources != null && videoSources.hasAny) {
      return true;
    }

    final poster = MediaUrlResolver.reelPosterUrl(
          processingStatus: null,
          transcodeStatus: transcodeStatus?.toString(),
          thumbnailUrl: thumbnailUrl?.toString(),
          imageUrl: imageUrl?.toString(),
          image: image?.toString(),
        ) ??
        MediaUrlResolver.thumbnailUrl(
          thumbnailUrl: thumbnailUrl?.toString(),
          imageUrl: imageUrl?.toString(),
          image: image?.toString(),
        );
    return poster != null && poster.isNotEmpty;
  }

  static bool _hasRawMediaFields({
    required dynamic videoUrl,
    required dynamic video,
    required dynamic hlsUrl,
    required dynamic hlsPlaylistUrl,
    required dynamic thumbnailUrl,
    required dynamic imageUrl,
    required dynamic image,
    VideoSources? videoSources,
  }) {
    for (final raw in [
      videoUrl,
      video,
      hlsUrl,
      hlsPlaylistUrl,
      thumbnailUrl,
      imageUrl,
      image,
    ]) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return true;
      }
    }
    return videoSources != null && videoSources.hasAny;
  }
}
