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
