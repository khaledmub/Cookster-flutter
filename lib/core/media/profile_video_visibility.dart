import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/playback_media.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/video_sources.dart';

/// Profile grid / reel listing — hide inactive, failed, or media-less videos.
class ProfileVideoVisibility {
  ProfileVideoVisibility._();

  static bool isWallVideoListable(WallVideos video) {
    return shouldListOnProfileGrid(
      status: video.status,
      state: video.state,
      processingStatus: video.processingStatus,
      transcodeStatus: video.transcodeStatus,
      videoUrl: video.videoUrl,
      video: video.video,
      hlsUrl: video.hlsUrl,
      hlsPlaylistUrl: video.hlsPlaylistUrl,
      thumbnailUrl: video.thumbnailUrl,
      imageUrl: video.imageUrl,
      image: video.image,
      isImage: video.isImage,
      videoSources: video.videoSources,
    );
  }

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
    // Only hide videos that are explicitly inactive/deleted or failed to
    // transcode. Everything else (including still-processing uploads with only
    // relative storage keys) shows on the owner's profile grid — the grid has a
    // poster/fallback so a not-yet-playable row is still a valid entry.
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

  /// Stricter check for reel playback lists — needs resolvable media, not just
  /// a grid entry. Used where a black/un-playable reel would be a dead end.
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
      return false;
    }
    final normalized = value.toString().trim().toLowerCase();
    return normalized != '0' &&
        normalized != 'false' &&
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
