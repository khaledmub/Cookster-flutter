import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Ensures iOS routes reel playback audio through AVAudioSession (simulator + device).
class IosPlaybackAudio {
  IosPlaybackAudio._();

  static bool _configured = false;

  static Future<void> configureIfNeeded() async {
    if (kIsWeb || !Platform.isIOS || _configured) {
      return;
    }
    try {
      final session = await AudioSession.instance.timeout(
        const Duration(seconds: 2),
      );
      await session
          .configure(
            const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playback,
              avAudioSessionMode: AVAudioSessionMode.moviePlayback,
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.defaultToSpeaker,
            ),
          )
          .timeout(const Duration(seconds: 2));
      _configured = true;
    } catch (e) {
      debugPrint('IosPlaybackAudio.configureIfNeeded failed: $e');
    }
  }

  /// Call immediately before unmuting a media_kit [Player] on iOS.
  static Future<void> ensureActiveForPlayback() async {
    if (kIsWeb || !Platform.isIOS) {
      return;
    }
    await configureIfNeeded();
    final session = await AudioSession.instance;
    await session.setActive(true);
  }
}
