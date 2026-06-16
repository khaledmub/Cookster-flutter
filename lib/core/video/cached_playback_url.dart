import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Use on-disk bytes only when already cached — never block playback on a full download.
Future<String> resolveCachedPlaybackUrl(
  String url, {
  BaseCacheManager? cacheManager,
}) async {
  if (url.isEmpty) {
    return url;
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('file://') || !lower.startsWith('http')) {
    return url;
  }
  try {
    final cache = cacheManager ?? DefaultCacheManager();
    final info = await cache.getFileFromCache(url);
    final file = info?.file;
    if (file != null && await file.exists() && await file.length() > 0) {
      return Uri.file(file.path).toString();
    }
  } catch (_) {}
  return url;
}

/// Warm disk cache in the background (preload lane only).
void prefetchPlaybackUrl(
  String url, {
  BaseCacheManager? cacheManager,
}) {
  if (url.isEmpty || !url.toLowerCase().startsWith('http')) {
    return;
  }
  if (url.toLowerCase().contains('.m3u8')) {
    return;
  }
  final cache = cacheManager ?? DefaultCacheManager();
  unawaited(
    cache.downloadFile(url).then((_) {}, onError: (Object _, StackTrace __) {}),
  );
}
