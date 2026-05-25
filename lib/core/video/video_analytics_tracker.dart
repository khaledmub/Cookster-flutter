import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player/video_player.dart';

class VideoAnalyticsTracker {
  VideoAnalyticsTracker({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  final Set<String> _milestones = <String>{};
  DateTime? _startedAt;
  String? _videoId;
  StreamSubscription<Duration>? _mediaKitPositionSub;
  Duration _mediaKitDuration = Duration.zero;

  void attach({
    required String videoId,
    required VideoPlayerController controller,
  }) {
    detach();
    _videoId = videoId;
    _startedAt = DateTime.now();
    _milestones.clear();
    _logOnce('video_start');
    controller.addListener(() => _onLegacyPosition(controller));
  }

  void attachMediaKit({
    required String videoId,
    required Player player,
  }) {
    detach();
    _videoId = videoId;
    _startedAt = DateTime.now();
    _milestones.clear();
    _logOnce('video_start');

    _mediaKitPositionSub = player.stream.position.listen((position) {
      final duration = player.state.duration;
      if (duration > Duration.zero) {
        _mediaKitDuration = duration;
      }
      _onProgress(position, _mediaKitDuration);
    });
  }

  void detach() {
    _mediaKitPositionSub?.cancel();
    _mediaKitPositionSub = null;
    _mediaKitDuration = Duration.zero;
  }

  void markSkippedIfNeeded() {
    if (_videoId == null || _startedAt == null) {
      return;
    }
    if (DateTime.now().difference(_startedAt!).inSeconds < 3) {
      _logOnce('video_skip');
    }
  }

  void _onLegacyPosition(VideoPlayerController controller) {
    final value = controller.value;
    if (!value.isInitialized || value.duration.inMilliseconds <= 0) {
      return;
    }
    _onProgress(value.position, value.duration);
  }

  void _onProgress(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) {
      return;
    }
    final progress = position.inMilliseconds / duration.inMilliseconds;
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
