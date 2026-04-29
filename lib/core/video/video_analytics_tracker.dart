import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:video_player/video_player.dart';

class VideoAnalyticsTracker {
  VideoAnalyticsTracker({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  final Set<String> _milestones = <String>{};
  DateTime? _startedAt;
  String? _videoId;

  void attach({
    required String videoId,
    required VideoPlayerController controller,
  }) {
    _videoId = videoId;
    _startedAt = DateTime.now();
    _milestones.clear();
    _logOnce('video_start');
    controller.addListener(() => _onPosition(controller));
  }

  void markSkippedIfNeeded() {
    if (_videoId == null || _startedAt == null) {
      return;
    }
    if (DateTime.now().difference(_startedAt!).inSeconds < 3) {
      _logOnce('video_skip');
    }
  }

  void _onPosition(VideoPlayerController controller) {
    final value = controller.value;
    if (!value.isInitialized || value.duration.inMilliseconds <= 0) {
      return;
    }
    final progress =
        value.position.inMilliseconds / value.duration.inMilliseconds;
    if (progress >= 0.25) {
      _logOnce('video_25_percent');
    }
    if (progress >= 0.50) {
      _logOnce('video_50_percent');
    }
    if (progress >= 0.98) {
      _logOnce('video_complete');
    }
  }

  Future<void> _logOnce(String eventName) async {
    if (_videoId == null) {
      return;
    }
    final key = '${_videoId!}:$eventName';
    if (_milestones.contains(key)) {
      return;
    }
    _milestones.add(key);
    await _analytics.logEvent(
      name: eventName,
      parameters: <String, Object>{'video_id': _videoId!},
    );
  }
}
