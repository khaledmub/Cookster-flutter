import 'video_source_resolver.dart';

class VideoPreloadTarget {
  const VideoPreloadTarget({
    required this.key,
    required this.candidates,
  });

  final String key;
  final List<VideoSourceCandidate> candidates;
}
