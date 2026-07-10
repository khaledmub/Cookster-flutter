import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/video_sources.dart';

/// Shared HLS / MP4-ladder resolution gated by `transcode_status`.
///
/// Mirrors the reels-feed contract for secondary surfaces (search, saved,
/// liked, single video). Never synthesize HLS/ladder URLs client-side; only
/// expose API-provided URLs and only when `transcode_status == "ready"`.
class PlaybackMedia {
  const PlaybackMedia._();

  static bool isReady(String? transcodeStatus) => transcodeStatus == 'ready';

  /// Parses API booleans sent as `true`, `1`, `"1"`, `1.0`, etc.
  static bool? parseOptionalFlag(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value == 1;
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == '1' || normalized == 'true') {
      return true;
    }
    if (normalized == '0' || normalized == 'false') {
      return false;
    }
    final asNum = num.tryParse(normalized);
    if (asNum != null) {
      return asNum == 1;
    }
    return null;
  }

  /// Backend contract: photo posts are always playable; videos use
  /// `playback_ready` when present, else `transcode_status == ready`.
  static bool isPlaybackReady({
    required bool isPhotoPost,
    bool? playbackReady,
    String? transcodeStatus,
  }) {
    if (isPhotoPost) {
      return true;
    }
    if (playbackReady != null) {
      return playbackReady;
    }
    return isReady(transcodeStatus);
  }

  /// Master `.m3u8` (absolute CDN URL) only when transcode is ready.
  static String? resolvedHls({
    required String? transcodeStatus,
    String? hlsPlaylistUrl,
    String? hlsUrl,
  }) {
    if (!isReady(transcodeStatus)) {
      return null;
    }
    return MediaUrlResolver.playbackUrl(
      videoUrl: hlsPlaylistUrl,
      video: hlsUrl,
    );
  }

  /// MP4 ladder (360 → 720 → 1080) only when ready. Handles null `url_1080`.
  static List<String> ladder({
    required String? transcodeStatus,
    VideoSources? sources,
  }) {
    if (!isReady(transcodeStatus) || sources == null || !sources.hasAny) {
      return const [];
    }
    return [
      if (sources.url360 != null) sources.url360!,
      if (sources.url720 != null) sources.url720!,
      if (sources.url1080 != null) sources.url1080!,
    ];
  }

  static VideoSources? parseSources(dynamic json) {
    if (json == null) {
      return null;
    }
    return VideoSources.fromJson(json);
  }
}
