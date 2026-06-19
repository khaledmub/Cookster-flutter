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

/// Smaller decode for image-post LQIP / thumbnail underlay.
ImageProvider reelPosterLqipPrecacheProvider(String url, BuildContext context) {
  final (memW, memH) = fullScreenPosterMemCacheSize(context);
  final scaledW = (memW * 0.35).round().clamp(64, memW);
  final scaledH = (memH * 0.35).round().clamp(64, memH);
  return ResizeImage(
    CachedNetworkImageProvider(url),
    width: scaledW,
    height: scaledH,
  );
}

/// Tiered RAM keys when the same CDN URL is decoded at multiple sizes.
class ReelPosterTierKeys {
  ReelPosterTierKeys._();

  static String lqip(String url) => '${url.trim()}#lqip';
  static String full(String url) => '${url.trim()}#full';
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

/// Dedicated RAM cache for image posts — separate LQIP and full decode tiers.
class ReelImagePostCache {
  ReelImagePostCache._();

  static const int _maxEntries = 128;
  static final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  static ImageProvider? get(String url) => _providers[url.trim()];

  static ImageProvider? getLqip(String url) => get(ReelPosterTierKeys.lqip(url));

  static ImageProvider? getFull(String url) => get(ReelPosterTierKeys.full(url));

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

  static void putLqip(String url, ImageProvider provider) {
    put(ReelPosterTierKeys.lqip(url), provider);
  }

  static void putFull(String url, ImageProvider provider) {
    put(ReelPosterTierKeys.full(url), provider);
  }
}
