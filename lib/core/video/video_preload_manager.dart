import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'device_constraints.dart';
import 'network_policy.dart';
import 'video_player_pool.dart';
import 'video_source_resolver.dart';
import '../../services/feature_flags/remote_config_service.dart';
import '../../services/settings/settings_service.dart';

typedef VideoSourceBuilder = List<VideoSourceCandidate> Function(int index);

class VideoPreloadManager {
  VideoPreloadManager({
    required VideoSourceBuilder sourceBuilder,
    VideoPlayerPool? pool,
    NetworkPolicy? networkPolicy,
    DeviceConstraints? deviceConstraints,
    BaseCacheManager? cacheManager,
  }) : _sourceBuilder = sourceBuilder,
       _pool = pool ?? VideoPlayerPool.instance,
       _networkPolicy = networkPolicy ?? NetworkPolicy(),
       _deviceConstraints = deviceConstraints ?? DeviceConstraints(),
       _cacheManager = cacheManager ?? DefaultCacheManager();

  final VideoSourceBuilder _sourceBuilder;
  final VideoPlayerPool _pool;
  final NetworkPolicy _networkPolicy;
  final DeviceConstraints _deviceConstraints;
  final BaseCacheManager _cacheManager;

  Future<void> onVisibleIndexChanged(int currentIndex) async {
    if (!RemoteConfigService.instance.preloadEnabled) {
      return;
    }
    if (_deviceConstraints.shouldThrottleFastSwipe()) {
      return;
    }
    if (await _deviceConstraints.isBatteryLow()) {
      return;
    }

    final preloadDepth = await _resolvePreloadDepth();
    if (preloadDepth <= 0) {
      return;
    }

    for (int step = 1; step <= preloadDepth; step++) {
      final index = currentIndex + step;
      final candidates = _sourceBuilder(index);
      if (candidates.isEmpty) {
        continue;
      }
      final chosen = candidates.first;
      unawaited(_cacheManager.downloadFile(chosen.url));
      unawaited(_pool.warmUp(key: 'video_$index', sourceUrl: chosen.url));
    }
  }

  Future<int> _resolvePreloadDepth() async {
    final isDataSaver = SettingsService.instance.dataSaverEnabled.value;
    if (isDataSaver) {
      return 0;
    }
    final networkClass = await _networkPolicy.currentNetworkClass();
    switch (networkClass) {
      case NetworkClass.wifi:
        return RemoteConfigService.instance.preloadLimitWifi.clamp(2, 3);
      case NetworkClass.mobile:
        return RemoteConfigService.instance.preloadLimitMobile.clamp(0, 1);
      case NetworkClass.offline:
        return 0;
    }
  }
}
