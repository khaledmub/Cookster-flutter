import 'dart:async';
import 'dart:collection';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../services/feature_flags/remote_config_service.dart';

class _PrefetchRequest {
  _PrefetchRequest({
    required this.url,
    required this.priority,
    required this.isTablet,
  });

  final String url;
  int priority;
  final bool isTablet;
}

/// Dedicated LRU cache for reel MP4 bytes with priority prefetch.
///
/// At most [_maxConcurrent] downloads run at once so nearer high-priority
/// reels (visible / N+1) finish before far dual-tier fan-out starves them.
class ReelsVideoCacheManager {
  ReelsVideoCacheManager._();

  static final ReelsVideoCacheManager instance = ReelsVideoCacheManager._();

  static const String _cacheKey = 'reelsVideoCache';
  /// Keep bandwidth focused on the swipe window (visible + 1–2 ahead).
  static const int _maxConcurrent = 2;

  CacheManager? _manager;
  final Map<String, int> _priorities = <String, int>{};
  final Set<String> _inFlight = <String>{};
  final Map<String, Completer<void>> _completers = <String, Completer<void>>{};
  final Map<String, _PrefetchRequest> _pendingByUrl = <String, _PrefetchRequest>{};
  final Queue<String> _pendingOrder = Queue<String>();
  int _activeCount = 0;
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
    final existing = _pendingByUrl[url];
    if (existing != null) {
      existing.priority = priority;
      _requeuePendingHighestFirst();
      _pump();
      return;
    }
    _pendingByUrl[url] = _PrefetchRequest(
      url: url,
      priority: priority,
      isTablet: isTablet,
    );
    _completers.putIfAbsent(url, Completer<void>.new);
    _pendingOrder.add(url);
    _requeuePendingHighestFirst();
    _pump();
  }

  void _requeuePendingHighestFirst() {
    if (_pendingByUrl.isEmpty) {
      _pendingOrder.clear();
      return;
    }
    final sorted = _pendingByUrl.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    _pendingOrder
      ..clear()
      ..addAll(sorted.map((e) => e.url));
  }

  void _pump() {
    while (_activeCount < _maxConcurrent && _pendingOrder.isNotEmpty) {
      final url = _pendingOrder.removeFirst();
      final req = _pendingByUrl.remove(url);
      if (req == null) {
        continue;
      }
      if (_inFlight.contains(url)) {
        continue;
      }
      final priority = _priorities[url] ?? req.priority;
      // Dropped by cancelBelowPriority while waiting.
      if (!_priorities.containsKey(url)) {
        continue;
      }
      _inFlight.add(url);
      _completers.putIfAbsent(url, Completer<void>.new);
      _activeCount++;
      unawaited(_runPrefetch(url, priority: priority, isTablet: req.isTablet));
    }
  }

  /// Await queued or in-flight prefetch for [url].
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

  /// True when [url] is queued or downloading.
  bool isQueuedOrInFlight(String url) =>
      _inFlight.contains(url) || _pendingByUrl.containsKey(url);

  Future<void> _runPrefetch(
    String url, {
    required int priority,
    required bool isTablet,
  }) async {
    try {
      if ((_priorities[url] ?? 0) > priority) {
        return;
      }
      // Ensure manager matches tablet budget for this job.
      managerForTablet(isTablet: isTablet);
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
      _activeCount = (_activeCount - 1).clamp(0, _maxConcurrent);
      _pump();
    }
  }

  /// Drop low-priority targets when the user swipes — frees slots for nearer URLs.
  void cancelBelowPriority(int minPriority) {
    _priorities.removeWhere((_, p) => p < minPriority);
    final dropped = <String>[];
    for (final entry in _pendingByUrl.entries) {
      if (entry.value.priority < minPriority) {
        dropped.add(entry.key);
      }
    }
    for (final url in dropped) {
      _pendingByUrl.remove(url);
      final completer = _completers.remove(url);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
    _requeuePendingHighestFirst();
    _pump();
  }

  void clearPriority(String url) {
    _priorities.remove(url);
  }
}
