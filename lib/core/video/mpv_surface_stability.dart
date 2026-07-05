import 'dart:async';

import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:media_kit/media_kit.dart';

Future<void> _mpvSetProperty(
  Player player,
  String key,
  String value,
) async {
  final platform = player.platform;
  if (platform == null) {
    return;
  }
  await (platform as dynamic).setProperty(
    key,
    value,
    waitForInitialization: false,
  );
}

/// Stabilize mpv-reported video dimensions on Honor/MTK before the Android
/// [VideoController] attaches a surface.
///
/// media_kit calls `player.seek(Duration.zero)` on every surface resize
/// ([AndroidVideoController.widListener]). Odd container heights (e.g. 721 for
/// a 720p ladder file) make the codec crop toggle 721↔720, which retriggers
/// that seek loop and leaves the user on a frozen first frame (looks like a
/// photo even though audio/position advance).
Future<void> stabilizeMpvSurfaceDimensions(Player player) async {
  if (!DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
    return;
  }
  for (var i = 0; i < 100; i++) {
    final w = player.state.width;
    final h = player.state.height;
    if (w != null && h != null && w > 1 && h > 1) {
      final evenW = w.isOdd ? w - 1 : w;
      final evenH = h.isOdd ? h - 1 : h;
      if (evenW != w || evenH != h) {
        final crop = '${evenW}x$evenH+0+0';
        try {
          await _mpvSetProperty(player, 'video-crop', crop);
          ReelsPerf.log('mpv_crop_applied $crop from ${w}x$h');
        } catch (_) {}
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 24));
  }
}
