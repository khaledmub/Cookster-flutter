import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../services/feature_flags/remote_config_service.dart';

/// Dedicated LRU cache for reel MP4 bytes with priority prefetch.
class ReelsVideoCacheManager {
  ReelsVideoCacheManager._();

  static final ReelsVideoCacheManager instance = ReelsVideoCacheManager._();

  static const String _cacheKey = 'reelsVideoCache';

  CacheManager? _manager;
  final Map<String, int> _priorities = <String, int>{};
  final Set<String> _inFlight = <String>{};
  /// Completers for in-flight downloads so consumers can await a shared download
  /// instead of polling. Eliminates the 700ms worst-case startup delay.
  final Map<String, Completer<void>> _completers = <String, Completer<void>>{};
  bool? _configuredForTablet;

  /// Maps remote-config MB budget to object count (~4 MB per cached MP4).
  static int maxObjectsForBudgetMb(int budgetMb) {
    return (budgetMb / 4).round().clamp(60, 300);
  }

  BaseCacheManager get manager {
    return managerForTablet(isTablet: _configuredForTablet ?? false);
  }

  BaseCacheManager managerForTablet({required bool isTablet}) {
    if (_manager != null && _configuredForTablet == isTablet) {
      return _manager!;
    }
    _configuredForTablet = isTablet;
    final budgetMb = isTablet
        ? RemoteConfigService.instance.reelsCacheMaxMbTablet
        : RemoteConfigService.instance.reelsCacheMaxMbPhone;
    _manager = CacheManager(
      Config(
        _cacheKey,
        stalePeriod: const Duration(days: 14),
        maxNrOfCacheObjects: maxObjectsForBudgetMb(budgetMb),
        repo: JsonCacheInfoRepository(databaseName: _cacheKey),
        fileService: HttpFileService(),
      ),
    );
    return _manager!;
  }

  /// Higher [priority] wins when multiple URLs compete (visible+1 = 100, +2 = 90…).
  void prefetch(
    String url, {
    required int priority,
    bool isTablet = false,
  }) {
    if (url.isEmpty || !url.toLowerCase().startsWith('http')) {
      return;
    }
    if (url.toLowerCase().contains('.m3u8')) {
      return;
    }
    final current = _priorities[url];
    if (current != null && current >= priority) {
      return;
    }
    _priorities[url] = priority;
    if (_inFlight.contains(url)) {
      return;
    }
    _inFlight.add(url);
    _completers[url] = Completer<void>();
    unawaited(_runPrefetch(url, priority: priority));
  }

  /// Await an in-flight prefetch for [url] instead of polling.
  /// Returns immediately if no download is in flight.
  Future<void> waitForUrl(String url, {int maxWaitMs = 700}) async {
    final completer = _completers[url];
    if (completer == null || completer.isCompleted) {
      return;
    }
    await completer.future.timeout(
      Duration(milliseconds: maxWaitMs),
      onTimeout: () {},
    );
  }

  /// True when [url] has an active download in progress.
  bool isInFlight(String url) => _inFlight.contains(url);

  Future<void> _runPrefetch(
    String url, {
    required int priority,
  }) async {
    try {
      // Bail if a higher-priority task superseded this one while we waited.
      if ((_priorities[url] ?? 0) > priority) {
        return;
      }
      await manager.downloadFile(url);
    } catch (_) {
    } finally {
      _inFlight.remove(url);
      if (_priorities[url] == priority) {
        _priorities.remove(url);
      }
      final completer = _completers.remove(url);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Drop low-priority in-flight targets when the user swipes away.
  void cancelBelowPriority(int minPriority) {
    _priorities.removeWhere((_, p) => p < minPriority);
  }

  void clearPriority(String url) {
    _priorities.remove(url);
  }
}
