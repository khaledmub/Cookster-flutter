import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Default minimum bytes before attempting partial fast-start playback.
const int kReelsMinFastStartBytes = 262144;

/// Session-level cache for moov-position validation results.
/// Avoids repeated disk I/O for the same URL within a single app session.
final Map<String, bool> _moovCheckCache = <String, bool>{};

/// True when [url] is already on disk (non-blocking cache lookup).
Future<bool> isPlaybackUrlCached(
  String url, {
  BaseCacheManager? cacheManager,
}) async {
  if (url.isEmpty) {
    return false;
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('file://') || !lower.startsWith('http')) {
    return true;
  }
  try {
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final info = await cache.getFileFromCache(url);
    final file = info?.file;
    return file != null && await file.exists() && await file.length() > 0;
  } catch (_) {
    return false;
  }
}

/// True when a partial on-disk file may be playable (fast-start MP4 heuristic).
/// Results are cached per URL for the session to avoid repeated disk I/O.
Future<bool> isPlaybackUrlPartiallyCached(
  String url, {
  BaseCacheManager? cacheManager,
  int minBytes = kReelsMinFastStartBytes,
}) async {
  if (url.isEmpty || url.toLowerCase().contains('.m3u8')) {
    return false;
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('file://') || !lower.startsWith('http')) {
    return true;
  }
  try {
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final info = await cache.getFileFromCache(url);
    final file = info?.file;
    if (file == null || !await file.exists()) {
      return false;
    }
    final len = await file.length();
    if (len < minBytes) {
      return false;
    }
    // Return cached result if we've already probed this URL this session.
    final cached = _moovCheckCache[url];
    if (cached != null) {
      return cached;
    }
    final result = await looksLikeFastStartMp4(file);
    _moovCheckCache[url] = result;
    return result;
  } catch (_) {
    return false;
  }
}

/// Heuristic: `moov` appears before `mdat` in the first 256 KiB.
Future<bool> looksLikeFastStartMp4(File file) async {
  try {
    final len = await file.length();
    final readLen = len < 262144 ? len : 262144;
    if (readLen < 12) {
      return false;
    }
    final bytes = await file.openRead(0, readLen).fold<BytesBuilder>(
      BytesBuilder(),
      (b, data) {
        b.add(data);
        return b;
      },
    );
    final data = bytes.takeBytes();
    final moov = _indexOfAscii(data, 'moov');
    final mdat = _indexOfAscii(data, 'mdat');
    if (moov < 0) {
      return false;
    }
    return mdat < 0 || moov < mdat;
  } catch (_) {
    return false;
  }
}

int _indexOfAscii(Uint8List data, String needle) {
  final pattern = needle.codeUnits;
  for (var i = 0; i <= data.length - pattern.length; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      return i;
    }
  }
  return -1;
}

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
    final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
    final info = await cache.getFileFromCache(url);
    final file = info?.file;
    if (file != null && await file.exists() && await file.length() > 0) {
      return Uri.file(file.path).toString();
    }
  } catch (_) {}
  return url;
}

/// Prefer local file when fully cached or partially cached with fast-start layout.
Future<String> resolveBestPlaybackUrl(
  String url, {
  BaseCacheManager? cacheManager,
  int minFastStartBytes = kReelsMinFastStartBytes,
}) async {
  if (url.isEmpty) {
    return url;
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('file://') || !lower.startsWith('http')) {
    return url;
  }
  final cache = cacheManager ?? ReelsVideoCacheManager.instance.manager;
  try {
    final info = await cache.getFileFromCache(url);
    final file = info?.file;
    if (file != null && await file.exists()) {
      final len = await file.length();
      if (len > 0) {
        // Only play from disk when moov is ahead of mdat (partial prefetch safe).
        // Incomplete cache files stall mid-decode on Honor after the first frame.
        if (len >= minFastStartBytes &&
            await looksLikeFastStartMp4(file)) {
          return Uri.file(file.path).toString();
        }
      }
    }
  } catch (_) {}
  return url;
}

/// Warm disk cache in the background (preload lane only).
void prefetchPlaybackUrl(
  String url, {
  BaseCacheManager? cacheManager,
  int priority = 50,
  bool isTablet = false,
}) {
  if (url.isEmpty || !url.toLowerCase().startsWith('http')) {
    return;
  }
  if (url.toLowerCase().contains('.m3u8')) {
    return;
  }
  ReelsVideoCacheManager.instance.prefetch(
    url,
    priority: priority,
    isTablet: isTablet,
  );
}
