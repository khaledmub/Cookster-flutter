import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Builds a device-playable preview for high-resolution or problematic codecs
/// (e.g. 4K MOV). The original file is still used for upload when possible.
class UploadVideoPreviewService {
  UploadVideoPreviewService._();

  /// Longest edge above this is downscaled for local [VideoPlayer] preview.
  static const int maxPlayableLongEdge = 1920;

  static final Map<String, Future<File?>> _transcodeInFlight = {};

  static Future<({int width, int height})?> probeVideoSize(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final info = session.getMediaInformation();
      if (info == null) return null;
      for (final stream in info.getStreams()) {
        if (stream.getType() != 'video') continue;
        final w = stream.getWidth();
        final h = stream.getHeight();
        if (w != null && h != null && w > 0 && h > 0) {
          return (width: w, height: h);
        }
      }
    } catch (e) {
      debugPrint('UploadVideoPreviewService.probeVideoSize: $e');
    }
    return null;
  }

  static Future<bool> needsDevicePreviewTranscode(File file) async {
    final size = await probeVideoSize(file);
    if (size == null) {
      final ext = file.path.split('.').last.toLowerCase();
      return ext == 'mov' || ext == 'm4v';
    }
    final longEdge = size.width > size.height ? size.width : size.height;
    return longEdge > maxPlayableLongEdge;
  }

  /// Returns a downscaled H.264 MP4 suitable for [VideoPlayerController], or null.
  static Future<File?> transcodeForDevicePlayback(File source) async {
    final cacheKey =
        '${source.path}:${await source.lastModified().then((t) => t.millisecondsSinceEpoch)}';
    final inFlight = _transcodeInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _transcodeForDevicePlaybackImpl(source);
    _transcodeInFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _transcodeInFlight.remove(cacheKey);
    }
  }

  static Future<File?> _transcodeForDevicePlaybackImpl(File source) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/device_preview_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final escapedIn = source.path.replaceAll("'", r"'\''");
    final escapedOut = outPath.replaceAll("'", r"'\''");
    final command =
        "-y -i '$escapedIn' "
        "-vf scale='min($maxPlayableLongEdge,iw)':-2 "
        "-c:v libx264 -preset veryfast -crf 23 "
        "-c:a aac -b:a 128k -movflags +faststart "
        "'$escapedOut'";

    debugPrint('UploadVideoPreviewService: transcoding preview → $outPath');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      debugPrint('UploadVideoPreviewService: transcode failed');
      return null;
    }
    final out = File(outPath);
    if (!await out.exists() || await out.length() == 0) return null;
    return out;
  }

  /// File to pass to [VideoPlayerController.file]; transcodes when needed.
  static Future<File> resolvePlayableFile(File source) async {
    if (!await needsDevicePreviewTranscode(source)) {
      return source;
    }
    final transcoded = await transcodeForDevicePlayback(source);
    return transcoded ?? source;
  }
}
