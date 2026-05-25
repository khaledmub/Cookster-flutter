/// Per-quality MP4 URLs from GET /api/reels when [transcode_status] is ready.
class VideoSources {
  const VideoSources({this.url360, this.url720, this.url1080});

  final String? url360;
  final String? url720;
  final String? url1080;

  factory VideoSources.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const VideoSources();
    }
    return VideoSources(
      url360: _readUrl(json['url_360']),
      url720: _readUrl(json['url_720']),
      url1080: _readUrl(json['url_1080']),
    );
  }

  static String? _readUrl(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  bool get hasAny =>
      url360 != null || url720 != null || url1080 != null;
}
