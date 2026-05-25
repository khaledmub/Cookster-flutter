import 'package:flutter/material.dart';

/// Decode thumbnails at ~2x logical size to cap memory in grids.
int gridThumbnailMemCacheSize(double logicalSize) {
  final ratio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  return (logicalSize * ratio * 2).round().clamp(64, 800);
}

/// Avatar decode size from logical diameter (radius × 2).
int avatarMemCacheSize(double logicalDiameter) =>
    gridThumbnailMemCacheSize(logicalDiameter);

/// Full-screen reel poster decode size (width × height).
(int, int) fullScreenPosterMemCacheSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final ratio = MediaQuery.devicePixelRatioOf(context);
  final w = (size.width * ratio).round().clamp(360, 1080);
  final h = (size.height * ratio).round().clamp(640, 1920);
  return (w, h);
}
