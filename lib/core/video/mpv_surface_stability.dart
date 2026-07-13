import 'dart:async';

import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

/// Last even size successfully painted on the shared feed surface.
/// Kept in sync with [AndroidSurfaceSizeGate] (native SetSurfaceSize gate).
class FeedSurfaceParityLock {
  static int? evenWidth;
  static int? evenHeight;

  static void recordPainted(int? width, int? height) {
    if (width == null || height == null || width <= 1 || height <= 1) {
      return;
    }
    evenWidth = width.isOdd ? width - 1 : width;
    evenHeight = height.isOdd ? height - 1 : height;
    AndroidSurfaceSizeGate.recordPainted(evenWidth, evenHeight);
  }
}

enum MpvStabilizeAction {
  none,
  rounded,
  lockedToPrevious,
}

/// Soft mpv `video-crop` defense-in-depth for Honor/MTK.
///
/// The **authoritative** parity fix is in the vendored media_kit_video
/// [AndroidSurfaceSizeGate], which clamps sizes before
/// `VideoOutputManager.SetSurfaceSize`. This helper only nudges mpv's crop
/// after decode dimensions are known; it cannot prevent ImageReader recreate
/// on its own.
///
/// Call **after** play/decode has started — with `play: false`, width/height
/// often stay null and the old unbounded wait blocked the open chain ~2s.
/// [maxWaitMs] caps the poll; [shouldAbort] lets a newer swipe bail early.
Future<MpvStabilizeAction> stabilizeMpvSurfaceDimensions(
  Player player, {
  int maxWaitMs = 400,
  bool Function()? shouldAbort,
}) async {
  if (!DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
    return MpvStabilizeAction.none;
  }
  final deadline = DateTime.now().add(Duration(milliseconds: maxWaitMs));
  while (true) {
    if (shouldAbort?.call() == true) {
      return MpvStabilizeAction.none;
    }
    final w = player.state.width;
    final h = player.state.height;
    if (w != null && h != null && w > 1 && h > 1) {
      return _applyEvenCrop(player, w, h);
    }
    if (!DateTime.now().isBefore(deadline)) {
      return MpvStabilizeAction.none;
    }
    await Future<void>.delayed(const Duration(milliseconds: 24));
  }
}

/// Apply even crop immediately when dims are already known (wait-loop / reopen).
Future<MpvStabilizeAction> ensureEvenMpvCropIfNeeded(Player player) async {
  if (!DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
    return MpvStabilizeAction.none;
  }
  final w = player.state.width;
  final h = player.state.height;
  if (w == null || h == null || w <= 1 || h <= 1) {
    return MpvStabilizeAction.none;
  }
  return _applyEvenCrop(player, w, h);
}

Future<MpvStabilizeAction> _applyEvenCrop(
  Player player,
  int w,
  int h,
) async {
  var targetW = w.isOdd ? w - 1 : w;
  var targetH = h.isOdd ? h - 1 : h;
  var action = MpvStabilizeAction.rounded;

  final lockW = FeedSurfaceParityLock.evenWidth;
  final lockH = FeedSurfaceParityLock.evenHeight;
  if (lockW != null &&
      lockH != null &&
      (w - lockW).abs() <= 1 &&
      (h - lockH).abs() <= 1) {
    targetW = lockW;
    targetH = lockH;
    action = MpvStabilizeAction.lockedToPrevious;
  }

  if (targetW == w && targetH == h) {
    return MpvStabilizeAction.none;
  }

  final crop = '${targetW}x$targetH+0+0';
  try {
    await _mpvSetProperty(player, 'video-crop', crop);
    ReelsPerf.log(
      'mpv_parity_crop action=${action.name} from ${w}x$h to ${targetW}x$targetH',
    );
    return action;
  } catch (_) {
    return MpvStabilizeAction.none;
  }
}
