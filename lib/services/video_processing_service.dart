import 'dart:async';
import 'dart:convert';

import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server-side thumbnail cover + HLS transcode status after upload.
class VideoProcessingStatusResult {
  const VideoProcessingStatusResult({
    this.processingStatus,
    this.transcodeStatus,
    this.hlsUrl,
    this.hlsPlaylistUrl,
    this.video,
  });

  final String? processingStatus;
  final String? transcodeStatus;
  final String? hlsUrl;
  final String? hlsPlaylistUrl;
  final WallVideos? video;

  bool get thumbnailReady => processingStatus == 'ready';
  bool get transcodeReady => transcodeStatus == 'ready';
  bool get transcodeFailed => transcodeStatus == 'failed';

  factory VideoProcessingStatusResult.fromJson(Map<String, dynamic> data) {
    WallVideos? parsedVideo;
    final nested = data['video'];
    if (nested is Map<String, dynamic>) {
      parsedVideo = WallVideos.fromJson(nested);
    }
    return VideoProcessingStatusResult(
      processingStatus:
          (data['processing_status'] ?? parsedVideo?.processingStatus)
              ?.toString(),
      transcodeStatus:
          (data['transcode_status'] ?? parsedVideo?.transcodeStatus)?.toString(),
      hlsUrl: (data['hls_url'] ?? parsedVideo?.hlsUrl)?.toString(),
      hlsPlaylistUrl:
          (data['hls_playlist_url'] ?? parsedVideo?.hlsPlaylistUrl)?.toString(),
      video: parsedVideo,
    );
  }
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
      return VideoProcessingStatusResult.fromJson(data);
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

  static Future<void> _refreshProfilesAfterProcessing() async {
    ensureLandingProfileControllers();
    final prefs = await SharedPreferences.getInstance();
    final entity = prefs.getInt('entity') ?? 0;
    if (entity == 2) {
      await Get.find<ProfessionalProfileController>().getUserDetails();
    } else {
      await Get.find<ProfileController>().getUserDetails();
    }
  }

  static void scheduleBackgroundPoll(
    String videoId, {
    bool waitForTranscode = true,
  }) {
    unawaited(() async {
      final result = await pollUntilSettled(
        videoId,
        waitForTranscode: waitForTranscode,
      );
      if (result == null) {
        return;
      }
      if (result.transcodeReady || result.thumbnailReady) {
        await _refreshProfilesAfterProcessing();
      }
    }());
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
