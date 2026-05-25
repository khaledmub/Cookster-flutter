import 'dart:async';
import 'dart:convert';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/services/apiClient.dart';

/// Server-side thumbnail cover + HLS transcode status after upload.
class VideoProcessingStatusResult {
  const VideoProcessingStatusResult({
    this.processingStatus,
    this.transcodeStatus,
    this.hlsUrl,
    this.hlsPlaylistUrl,
  });

  final String? processingStatus;
  final String? transcodeStatus;
  final String? hlsUrl;
  final String? hlsPlaylistUrl;

  bool get thumbnailReady => processingStatus == 'ready';
  bool get transcodeReady => transcodeStatus == 'ready';
  bool get transcodeFailed => transcodeStatus == 'failed';
}

/// Polls server-side thumbnail / HLS processing after upload.
class VideoProcessingService {
  static const Duration pollInterval = Duration(seconds: 2);
  static const Duration maxPollDuration = Duration(minutes: 5);

  static Future<VideoProcessingStatusResult?> fetchStatus(String videoId) async {
    final response = await ApiClient.getRequest(
      '${EndPoints.videoProcessingStatus}?video_id=$videoId',
    );
    if (response.statusCode != 200) return null;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != true) return null;
      return VideoProcessingStatusResult(
        processingStatus: data['processing_status'] as String?,
        transcodeStatus: data['transcode_status'] as String?,
        hlsUrl: data['hls_url'] as String?,
        hlsPlaylistUrl: data['hls_playlist_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Polls until cover [ready]/[failed] and/or HLS [transcode_status] settles.
  static Future<VideoProcessingStatusResult?> pollUntilSettled(
    String videoId, {
    bool waitForTranscode = false,
  }) async {
    final deadline = DateTime.now().add(maxPollDuration);
    while (DateTime.now().isBefore(deadline)) {
      final result = await fetchStatus(videoId);
      if (result == null) {
        await Future<void>.delayed(pollInterval);
        continue;
      }
      final coverDone =
          result.processingStatus == 'ready' ||
          result.processingStatus == 'failed';
      final transcodeDone =
          result.transcodeStatus == 'ready' ||
          result.transcodeStatus == 'failed';
      if (waitForTranscode) {
        if (coverDone && transcodeDone) {
          return result;
        }
      } else if (coverDone) {
        return result;
      }
      await Future<void>.delayed(pollInterval);
    }
    return null;
  }

  static void scheduleBackgroundPoll(
    String videoId, {
    bool waitForTranscode = true,
  }) {
    unawaited(pollUntilSettled(videoId, waitForTranscode: waitForTranscode));
  }

  static String? extractVideoIdFromUploadResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final direct = data['video_id'];
      if (direct is String && direct.isNotEmpty) return direct;
      if (direct != null) return direct.toString();
      final video = data['video'];
      if (video is Map<String, dynamic>) {
        final id = video['id'];
        if (id is String && id.isNotEmpty) return id;
        if (id != null) return id.toString();
      }
    } catch (_) {}
    return null;
  }
}
