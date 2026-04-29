import 'dart:collection';

import 'package:video_player/video_player.dart';

class PooledVideoController {
  PooledVideoController({
    required this.key,
    required this.controller,
  });

  final String key;
  final VideoPlayerController controller;
}

class VideoPlayerPool {
  VideoPlayerPool._();

  static final VideoPlayerPool instance = VideoPlayerPool._();
  static const int maxPlayers = 8;

  final LinkedHashMap<String, VideoPlayerController> _controllers =
      LinkedHashMap<String, VideoPlayerController>();
  final Map<String, int> _leaseCount = <String, int>{};
  String? _activeKey;

  int get activeControllerCount => _controllers.length;

  Future<PooledVideoController> acquire({
    required String key,
    required String sourceUrl,
    bool autoPlay = false,
  }) async {
    final existing = _controllers.remove(key);
    if (existing != null) {
      _controllers[key] = existing;
      if (!existing.value.isInitialized) {
        await existing.initialize();
      }
      if (autoPlay) {
        await setActive(key);
      }
      _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
      return PooledVideoController(key: key, controller: existing);
    }

    await _evictIfNeeded();
    final controller = VideoPlayerController.networkUrl(Uri.parse(sourceUrl));
    await controller.initialize();
    _controllers[key] = controller;

    if (autoPlay) {
      await setActive(key);
    }
    _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
    return PooledVideoController(key: key, controller: controller);
  }

  Future<void> warmUp({
    required String key,
    required String sourceUrl,
  }) async {
    await acquire(key: key, sourceUrl: sourceUrl, autoPlay: false);
  }

  Future<void> setActive(String key) async {
    _activeKey = key;
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      if (!controller.value.isInitialized) {
        continue;
      }
      if (entry.key == key) {
        await controller.setVolume(1.0);
        if (!controller.value.isPlaying) {
          await controller.play();
        }
      } else {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
        await controller.setVolume(0.0);
      }
    }
  }

  Future<void> pause(String key) async {
    final controller = _controllers[key];
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    }
  }

  Future<void> pauseAll() async {
    _activeKey = null;
    for (final controller in _controllers.values) {
      if (!controller.value.isInitialized) {
        continue;
      }
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      await controller.setVolume(0.0);
    }
  }

  Future<void> release(String key) async {
    final currentLease = _leaseCount[key] ?? 0;
    if (currentLease > 1) {
      _leaseCount[key] = currentLease - 1;
    } else {
      _leaseCount.remove(key);
    }

    final controller = _controllers[key];
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      await controller.setVolume(0.0);
    }
    if (_activeKey == key) {
      _activeKey = null;
    }
  }

  Future<void> clear() async {
    final items = _controllers.values.toList(growable: false);
    _controllers.clear();
    _leaseCount.clear();
    _activeKey = null;
    for (final controller in items) {
      await controller.dispose();
    }
  }

  Future<void> _evictIfNeeded() async {
    if (_controllers.length < maxPlayers) {
      return;
    }
    String? evictKey;
    for (final key in _controllers.keys) {
      final leases = _leaseCount[key] ?? 0;
      if (leases == 0 && key != _activeKey) {
        evictKey = key;
        break;
      }
    }
    if (evictKey == null) {
      // All controllers are currently leased; skip eviction for now.
      return;
    }
    final oldest = _controllers.remove(evictKey);
    if (oldest != null) {
      await oldest.dispose();
    }
  }
}
