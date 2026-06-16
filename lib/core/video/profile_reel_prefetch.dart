import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/video_sources.dart';

import 'cached_playback_url.dart';
import 'network_policy.dart';
import 'video_source_resolver.dart';

/// Disk-warm the tapped grid tile before [ProfileReelScreen] opens.
void prefetchProfileReelEntry({
  String? mp4Url,
  String? hlsUrl,
  List<String> qualityMp4Urls = const [],
}) {
  const resolver = VideoSourceResolver();
  final candidates = resolver.resolveCandidates(
    hlsUrl: hlsUrl,
    mp4Url: mp4Url,
    qualityMp4Urls: qualityMp4Urls,
  );
  if (candidates.isEmpty) {
    return;
  }
  final ordered = resolver.prioritizeForNetwork(
    candidates,
    NetworkClass.wifi,
  );
  final url = ordered.first.url;
  if (!url.toLowerCase().contains('.m3u8')) {
    prefetchPlaybackUrl(url);
  }
}

List<String> _qualityLadder(VideoSources? sources) {
  if (sources == null || !sources.hasAny) {
    return const [];
  }
  return [
    if (sources.url360 != null) sources.url360!,
    if (sources.url720 != null) sources.url720!,
    if (sources.url1080 != null) sources.url1080!,
  ];
}

/// Poster shown on [ProfileReelScreen] while the feed API loads.
String? profileReelPosterFromGrid({
  dynamic processingStatus,
  dynamic transcodeStatus,
  dynamic thumbnailUrl,
  dynamic imageUrl,
  dynamic image,
}) {
  return MediaUrlResolver.reelPosterUrl(
    processingStatus: processingStatus?.toString(),
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
}

/// Call on grid tap — overlaps disk fetch with route transition.
void warmProfileReelTap({
  dynamic videoUrl,
  dynamic video,
  dynamic hlsUrl,
  dynamic hlsPlaylistUrl,
  dynamic transcodeStatus,
  VideoSources? videoSources,
}) {
  final ready = transcodeStatus?.toString() == 'ready';
  prefetchProfileReelEntry(
    mp4Url: MediaUrlResolver.playbackUrl(
      videoUrl: videoUrl?.toString(),
      video: video?.toString(),
    ),
    hlsUrl: ready
        ? MediaUrlResolver.playbackUrl(
            videoUrl: hlsPlaylistUrl?.toString(),
            video: hlsUrl?.toString(),
          )
        : null,
    qualityMp4Urls: ready ? _qualityLadder(videoSources) : const [],
  );
}
