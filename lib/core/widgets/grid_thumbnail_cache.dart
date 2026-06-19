import 'package:cached_network_image/cached_network_image.dart';
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

/// RAM-sized provider for scroll-ahead poster precache (disk + decoded cache).
ImageProvider reelPosterPrecacheProvider(String url, BuildContext context) {
  final (memW, memH) = fullScreenPosterMemCacheSize(context);
  return ResizeImage(
    CachedNetworkImageProvider(url),
    width: memW,
    height: memH,
  );
}

/// Synchronous lookup after [precacheImage] — avoids one black frame on scroll-back.
class ReelPosterImageCache {
  ReelPosterImageCache._();

  static const int _maxEntries = 64;
  static final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  static ImageProvider? get(String url) {
    final key = url.trim();
    if (key.isEmpty) {
      return null;
    }
    return _providers[key];
  }

  static void put(String url, ImageProvider provider) {
    final key = url.trim();
    if (key.isEmpty) {
      return;
    }
    if (_providers.length >= _maxEntries && !_providers.containsKey(key)) {
      _providers.remove(_providers.keys.first);
    }
    _providers[key] = provider;
  }
}
