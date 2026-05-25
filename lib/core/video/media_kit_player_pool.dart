import 'dart:async';
import 'dart:collection';

import 'package:cookster/services/settings/settings_service.dart';
import 'package:media_kit/media_kit.dart';

class PooledMediaKitPlayer {
  PooledMediaKitPlayer({required this.key, required this.player});

  final String key;
  final Player player;
}

/// MediaKit player pool for reels with priority for the visible slot.
///
/// - [acquire], [setActive], [unmuteAndPlay], [pause], [pauseAll], [release]
///   run on a **priority** lane and never wait behind [warmUp].
/// - [warmUp] opens media then primes the first frame in the background (never
///   blocks [acquire]); [isFrameReady] reflects primed slots.
/// - Hard cap of [_maxPoolSize] players; LRU eviction for idle (lease 0) entries.
/// - Warm slot cap: 2 on phone, 3 on tablet ([tabletBreakpoint] logical px).
class MediaKitPlayerPool {
  MediaKitPlayerPool._();

  static final MediaKitPlayerPool instance = MediaKitPlayerPool._();

  static const int maxPoolSizePhone = 4;
  static const int maxPoolSizeTablet = 6;
  static const double tabletBreakpoint = 600;

  /// LRU order: oldest at [LinkedHashMap.keys.first], MRU at last.
  final LinkedHashMap<String, Player> _players = LinkedHashMap<String, Player>();
  final Map<String, int> _leaseCount = <String, int>{};
  final Set<String> _warmInFlight = <String>{};
  final Set<String> _frameReadyKeys = <String>{};
  final Set<String> _bufferPrimedKeys = <String>{};

  String? _activeKey;
  double _screenWidth = 400;
  int _priorityDepth = 0;
  /// Latest reel that should receive audio; older [activateVisible] calls bail out.
  String? _audibleTargetKey;
  final Set<String> _userPausedKeys = <String>{};

  /// Chains only priority (visible / active) operations.
  Future<void> _priorityChain = Future<void>.value();

  /// Chains background warm-ups; never awaited by [acquire].
  Future<void> _warmChain = Future<void>.value();

  /// Call from UI (e.g. reels [MediaQuery.sizeOf].width) to tune warm limits.
  void setScreenWidth(double logicalWidth) {
    if (logicalWidth > 0) {
      _screenWidth = logicalWidth;
    }
  }

  bool get _isTablet => _screenWidth >= tabletBreakpoint;

  int get _maxPoolSize => _isTablet ? maxPoolSizeTablet : maxPoolSizePhone;

  int get _maxWarmSlots => _isTablet ? 3 : 2;

  bool isWarmed(String key) => _players.containsKey(key);

  bool isFrameReady(String key) => _frameReadyKeys.contains(key);

  /// True when this key is the active slot, playing, and not muted.
  bool isPausedByUser(String key) => _userPausedKeys.contains(key);

  void clearUserPaused(String key) => _userPausedKeys.remove(key);

  bool isActiveAudible(String key) {
    if (_activeKey != key) {
      return false;
    }
    final player = _players[key];
    if (player == null) {
      return false;
    }
    return player.state.playing && player.state.volume > 50;
  }

  /// Demux/decode buffered without a [Video] surface (width stays null until attach).
  bool isBufferPrimed(String key) => _bufferPrimedKeys.contains(key);

  void markFrameReadyFromSurface(String key) {
    _markFrameReady(key);
  }

  void _markFrameReady(String key) {
    _frameReadyKeys.add(key);
  }

  void _clearFrameReady(String key) {
    _frameReadyKeys.remove(key);
    _bufferPrimedKeys.remove(key);
  }

  bool _needsRewind(Player player) {
    return player.state.completed ||
        player.state.position.inMilliseconds > 250;
  }

  Future<void> _waitForPositionNearStart(Player player, String key) async {
    var waited = 0;
    while (waited < 500) {
      if (_players[key] != player) {
        return;
      }
      if (!_needsRewind(player)) {
        return;
      }
      try {
        await player.seek(Duration.zero);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  /// Pause, seek to 0, wait for demuxer, then play muted (visible reel entry point).
  Future<void> _rewindToStartLocked(String key, {bool playMuted = true}) async {
    if (key.isEmpty || !_players.containsKey(key)) {
      return;
    }
    final player = _players[key];
    if (player == null) {
      return;
    }
    _activeKey = key;
    _touchLru(key);
    _clearFrameReady(key);
    await _silenceOthersLocked(key);
    if (_players[key] != player) {
      return;
    }
    try {
      await player.pause();
      await player.seek(Duration.zero);
      await _waitForPositionNearStart(player, key);
      if (_players[key] != player) {
        return;
      }
      await player.setVolume(0);
      if (playMuted && !player.state.playing) {
        await player.play();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Priority lane (visible reel — never blocked by warmUp)
  // ---------------------------------------------------------------------------

  Future<T> _runPriority<T>(Future<T> Function() action) {
    _priorityDepth++;
    final completer = Completer<T>();
    final previous = _priorityChain;
    _priorityChain = previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      } finally {
        _priorityDepth--;
      }
    });
    return completer.future;
  }

  void _touchLru(String key) {
    final player = _players.remove(key);
    if (player != null) {
      _players[key] = player;
    }
  }

  int _warmCount() {
    var count = 0;
    for (final key in _players.keys) {
      if ((_leaseCount[key] ?? 0) == 0 && key != _activeKey) {
        count++;
      }
    }
    return count;
  }

  String? _lruEvictableKey({String? except}) {
    for (final key in _players.keys) {
      if (key == except || key == _activeKey) {
        continue;
      }
      if ((_leaseCount[key] ?? 0) == 0) {
        return key;
      }
    }
    return null;
  }

  Future<void> _disposeKey(String key) async {
    _leaseCount.remove(key);
    _warmInFlight.remove(key);
    _clearFrameReady(key);
    final player = _players.remove(key);
    if (_activeKey == key) {
      _activeKey = null;
    }
    _userPausedKeys.remove(key);
    if (player == null) {
      return;
    }
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _evictLruIfNeeded({String? protect}) async {
    while (_players.length >= _maxPoolSize) {
      final evict = _lruEvictableKey(except: protect);
      if (evict == null) {
        break;
      }
      await _disposeKey(evict);
    }
  }

  Future<void> _setActiveLocked(String key, {required bool muted}) async {
    _activeKey = key;
    _touchLru(key);
    final snapshot = Map<String, Player>.from(_players);
    for (final entry in snapshot.entries) {
      final player = _players[entry.key];
      if (player == null) {
        continue;
      }
      if (entry.key == key) {
        try {
          await player.setVolume(muted ? 0 : 100);
        } catch (_) {}
        if (_players[entry.key] != player) {
          continue;
        }
        if (!player.state.playing) {
          try {
            await player.play();
          } catch (_) {}
        }
      } else {
        try {
          if (player.state.playing) {
            await player.pause();
          }
          if (_players[entry.key] == player) {
            await player.setVolume(0);
          }
        } catch (_) {}
      }
    }
  }

  /// Synchronous mute/pause for tab switches — stops audio before async cleanup runs.
  void silenceAllSync({String? exceptKey}) {
    if (exceptKey == null || exceptKey.isEmpty) {
      _activeKey = null;
    } else {
      _activeKey = exceptKey;
    }
    for (final entry in _players.entries) {
      if (exceptKey != null &&
          exceptKey.isNotEmpty &&
          entry.key == exceptKey) {
        continue;
      }
      final player = entry.value;
      try {
        unawaited(player.setVolume(0));
        if (player.state.playing) {
          unawaited(player.pause());
        }
      } catch (_) {}
    }
  }

  /// Mutes off-screen slots on swipe. When [exceptKey] is set, that slot is left
  /// alone so it can rewind/play without an extra pause→flush→stop cycle.
  void pauseAllImmediate({String? exceptKey}) {
    silenceAllSync(exceptKey: exceptKey);
    if (exceptKey != null && exceptKey.isNotEmpty) {
      unawaited(_runPriority(() => _silenceOthersLocked(exceptKey)));
    } else {
      unawaited(_runPriority(_silenceAllLocked));
    }
  }

  /// Awaitable full pause (tab leave, route overlay, app background).
  Future<void> pauseAllAwait({String? exceptKey}) async {
    pauseAllImmediate(exceptKey: exceptKey);
    if (exceptKey != null && exceptKey.isNotEmpty) {
      await _runPriority(() => _silenceOthersLocked(exceptKey));
    } else {
      await _runPriority(_silenceAllLocked);
    }
  }

  Future<void> _silenceAllLocked() async {
    for (final entry in _players.entries) {
      final player = _players[entry.key];
      if (player == null) {
        continue;
      }
      try {
        if (player.state.playing) {
          await player.pause();
        }
        if (_players[entry.key] == player) {
          await player.setVolume(0);
        }
      } catch (_) {}
    }
  }

  /// Mutes/pauses every slot except [exceptKey] (used when unmuting the visible reel).
  Future<void> _silenceOthersLocked(String exceptKey) async {
    for (final entry in _players.entries) {
      if (entry.key == exceptKey) {
        continue;
      }
      final player = _players[entry.key];
      if (player == null) {
        continue;
      }
      try {
        if (player.state.playing) {
          await player.pause();
        }
        if (_players[entry.key] == player && _needsRewind(player)) {
          await player.seek(Duration.zero);
        }
        if (_players[entry.key] == player) {
          await player.setVolume(0);
        }
      } catch (_) {}
    }
  }

  Future<void> pauseByUser(String key) {
    return _runPriority(() async {
      _userPausedKeys.add(key);
      _activeKey = key;
      final player = _players[key];
      if (player == null) {
        return;
      }
      try {
        await player.pause();
        await player.setVolume(0);
      } catch (_) {}
    });
  }

  Future<void> _unmuteAndPlayLocked(String key) async {
    if (_userPausedKeys.contains(key)) {
      return;
    }
    final player = _players[key];
    if (player == null) {
      return;
    }
    _activeKey = key;
    _touchLru(key);
    for (final entry in _players.entries) {
      if (entry.key == key) {
        continue;
      }
      try {
        if (entry.value.state.playing) {
          await entry.value.pause();
        }
        if (_players[entry.key] == entry.value) {
          await entry.value.setVolume(0);
        }
      } catch (_) {}
    }
    if (_players[key] != player) {
      return;
    }
    if (_needsRewind(player)) {
      await player.pause();
      await player.seek(Duration.zero);
      await _waitForPositionNearStart(player, key);
      if (_players[key] != player) {
        return;
      }
    }
    await player.setVolume(100);
    if (!player.state.playing) {
      await player.play();
    }
  }

  String? _lastActivateKey;
  int _lastActivateMs = 0;

  /// Single entry to make [key] the only audible reel (fixes multi-track fights).
  Future<void> activateVisible(String key) {
    return _runPriority(() async {
      if (key.isEmpty ||
          !_players.containsKey(key) ||
          _userPausedKeys.contains(key)) {
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastActivateKey == key && now - _lastActivateMs < 150) {
        return;
      }
      _lastActivateKey = key;
      _lastActivateMs = now;

      _audibleTargetKey = key;
      await _silenceOthersLocked(key);
      if (_audibleTargetKey != key) {
        return;
      }

      _activeKey = key;
      await _unmuteAndPlayLocked(key);
    });
  }

  /// Pauses/mutes off-screen slots and restores audible playback for [key].
  Future<void> ensureAudible(String key) => activateVisible(key);

  Future<void> _waitForWarmKey(String key, {int maxMs = 2500}) async {
    var waited = 0;
    while (waited < maxMs) {
      if (_players.containsKey(key)) {
        return;
      }
      if (!_warmInFlight.contains(key)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  /// Pauses off-screen warm slots so the visible reel gets the decoder first.
  Future<void> _pauseBackgroundWarmExcept(String key) async {
    for (final entry in _players.entries) {
      if (entry.key == key || (_leaseCount[entry.key] ?? 0) > 0) {
        continue;
      }
      try {
        if (entry.value.state.playing) {
          await entry.value.pause();
        }
        await entry.value.setVolume(0);
      } catch (_) {}
    }
  }

  Future<PooledMediaKitPlayer> acquire({
    required String key,
    required String sourceUrl,
    bool autoPlay = false,
  }) {
    return _runPriority(() async {
      if (SettingsService.instance.dataSaverEnabled.value) {
        // Still allow one visible player in data saver.
      }

      await _pauseBackgroundWarmExcept(key);

      if (_warmInFlight.contains(key)) {
        await _waitForWarmKey(key);
      }

      final existing = _players[key];
      if (existing != null) {
        _touchLru(key);
        if ((_leaseCount[key] ?? 0) == 0) {
          _leaseCount[key] = 1;
        }
        _warmInFlight.remove(key);
        if (autoPlay || _activeKey == key) {
          await _rewindToStartLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: existing);
      }

      await _evictLruIfNeeded(protect: key);
      if (_players.length >= _maxPoolSize) {
        final recycled = await _recycleLruPlayer(key, sourceUrl);
        _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
        if (autoPlay || _activeKey == key) {
          await _rewindToStartLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: recycled);
      }

      _clearFrameReady(key);
      final player = Player();
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      _players[key] = player;
      _leaseCount[key] = 1;
      if (autoPlay || _activeKey == key) {
        await _rewindToStartLocked(key);
      }
      return PooledMediaKitPlayer(key: key, player: player);
    });
  }

  Future<PooledMediaKitPlayer> replaceSource({
    required String key,
    required String sourceUrl,
    bool autoPlay = false,
  }) {
    return _runPriority(() async {
      final existing = _players[key];
      if (existing != null) {
        _touchLru(key);
        _clearFrameReady(key);
        await existing.open(Media(sourceUrl), play: false);
        await existing.setVolume(0);
        _leaseCount[key] = (_leaseCount[key] ?? 0) + 1;
        if (autoPlay) {
          await _rewindToStartLocked(key);
        }
        return PooledMediaKitPlayer(key: key, player: existing);
      }

      return acquire(key: key, sourceUrl: sourceUrl, autoPlay: autoPlay);
    });
  }

  Future<Player> _recycleLruPlayer(String key, String sourceUrl) async {
    final lruKey = _lruEvictableKey(except: key);
    if (lruKey == null) {
      final player = Player();
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      _players[key] = player;
      return player;
    }
    final player = _players.remove(lruKey)!;
    _leaseCount.remove(lruKey);
    _warmInFlight.remove(lruKey);
    _clearFrameReady(lruKey);
    if (_activeKey == lruKey) {
      _activeKey = null;
    }
    try {
      await player.stop();
    } catch (_) {}
    _clearFrameReady(key);
    await player.open(Media(sourceUrl), play: false);
    await player.setVolume(0);
    _players[key] = player;
    return player;
  }

  Future<void> setActive(String key) {
    return _runPriority(() => _setActiveLocked(key, muted: true));
  }

  /// Rewinds to the start and plays muted while off-screen slots stay silent.
  Future<void> prepareVisiblePlayback(String key) {
    return _runPriority(() => _rewindToStartLocked(key));
  }

  Future<void> unmuteAndPlay(String key) {
    return _runPriority(() => _unmuteAndPlayLocked(key));
  }

  Future<void> pause(String key) {
    return _runPriority(() async {
      final player = _players[key];
      if (player == null) {
        return;
      }
      await player.pause();
    });
  }

  /// Instant mute/pause on swipe; priority lane only reconciles state afterward.
  Future<void> pauseAll() async {
    await pauseAllAwait();
  }

  Future<void> release(String key) {
    return _runPriority(() => _releaseLocked(key));
  }

  /// Drops one display lease without evicting the player (reels page hide).
  Future<void> surrenderLease(String key) {
    return _runPriority(() async {
      final currentLease = _leaseCount[key] ?? 0;
      if (currentLease <= 0) {
        return;
      }
      _leaseCount[key] = currentLease - 1;
    });
  }

  Future<void> _releaseLocked(String key) async {
    final currentLease = _leaseCount[key] ?? 0;
    if (currentLease > 1) {
      _leaseCount[key] = currentLease - 1;
      return;
    }
    await _disposeKey(key);
  }

  Future<void> releaseAll() {
    return _runPriority(() async {
      final keys = _players.keys.toList(growable: false);
      for (final key in keys) {
        _leaseCount[key] = 1;
        await _disposeKey(key);
      }
      _activeKey = null;
    });
  }

  Future<void> disposeAll() {
    return _runPriority(() async {
      final keys = _players.keys.toList(growable: false);
      for (final key in keys) {
        await _disposeKey(key);
      }
      _activeKey = null;
      _warmInFlight.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Background lane (preload — open only, yields to priority)
  // ---------------------------------------------------------------------------

  static const int _warmPriorityWaitMs = 2500;
  int _activeWarmTasks = 0;

  Future<void> _waitForPriorityLane({required int maxMs}) async {
    var waited = 0;
    while (_priorityDepth > 0 && waited < maxMs) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      waited += 16;
    }
  }

  void _enqueueWarm(Future<void> Function() work) {
    final next = _warmChain.then((_) async {
      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_priorityDepth > 0) {
        return;
      }
      await work();
    }, onError: (_) {});
    _warmChain = next;
    unawaited(next);
  }

  /// Opens media and buffers demux off-screen (parallel slots).
  /// Returns immediately; never blocks [acquire].
  Future<void> warmUp({required String key, required String sourceUrl}) {
    if (SettingsService.instance.dataSaverEnabled.value) {
      return Future<void>.value();
    }
    if (_players.containsKey(key) ||
        (_leaseCount[key] ?? 0) > 0 ||
        _warmInFlight.contains(key)) {
      return Future<void>.value();
    }
    if (_warmCount() >= _maxWarmSlots) {
      return Future<void>.value();
    }

    _warmInFlight.add(key);
    unawaited(_runWarmUpTask(key: key, sourceUrl: sourceUrl));
    return Future<void>.value();
  }

  Future<void> _runWarmUpTask({
    required String key,
    required String sourceUrl,
  }) async {
    try {
      while (_activeWarmTasks >= _maxWarmSlots) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      _activeWarmTasks++;

      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_players.containsKey(key) || (_leaseCount[key] ?? 0) > 0) {
        return;
      }
      if (_warmCount() >= _maxWarmSlots) {
        return;
      }
      await _evictLruIfNeeded(protect: key);
      if (_players.length >= _maxPoolSize) {
        return;
      }

      final player = Player();
      await player.open(Media(sourceUrl), play: false);
      await player.setVolume(0);
      if (_players.containsKey(key) || (_leaseCount[key] ?? 0) > 0) {
        await player.dispose();
        return;
      }
      _players[key] = player;
      _leaseCount[key] = 0;
      unawaited(_primeFirstFrameOffScreen(key, player));
    } catch (_) {
      await _disposeKey(key);
    } finally {
      _activeWarmTasks--;
      _warmInFlight.remove(key);
    }
  }

  Future<void> releaseFarFrom(
    int visibleIndex, {
    required int window,
    required String? Function(int index) keyResolver,
  }) {
    _enqueueWarm(() async {
      if (_priorityDepth > 0) {
        return;
      }
      final keepKeys = <String>{};
      for (var offset = -window; offset <= window; offset++) {
        final resolved = keyResolver(visibleIndex + offset);
        if (resolved != null && resolved.isNotEmpty) {
          keepKeys.add(resolved);
        }
      }
      final active = _activeKey;
      if (active != null) {
        keepKeys.add(active);
      }
      for (final primed in _frameReadyKeys) {
        keepKeys.add(primed);
      }
      for (final buffered in _bufferPrimedKeys) {
        keepKeys.add(buffered);
      }

      final toRelease = _players.keys
          .where(
            (k) =>
                !keepKeys.contains(k) &&
                (_leaseCount[k] ?? 0) == 0 &&
                !_warmInFlight.contains(k),
          )
          .toList(growable: false);

      for (final key in toRelease) {
        await _disposeKey(key);
      }

      while (_players.length > _maxPoolSize) {
        final evict = _lruEvictableKey();
        if (evict == null) {
          break;
        }
        await _disposeKey(evict);
      }
    });
    return Future<void>.value();
  }

  /// Buffers first frames during warm-up without starting audio (no [play]).
  Future<void> _primeFirstFrameOffScreen(String key, Player player) async {
    try {
      await _waitForPriorityLane(maxMs: _warmPriorityWaitMs);
      if (_players[key] != player || (_leaseCount[key] ?? 0) > 0) {
        return;
      }
      try {
        await player.setVolume(0);
        if (player.state.playing) {
          await player.pause();
        }
      } catch (_) {}

      var waited = 0;
      while (waited < 2500) {
        if (_players[key] != player || (_leaseCount[key] ?? 0) > 0) {
          return;
        }
        final w = player.state.width;
        final pos = player.state.position.inMilliseconds;
        if (w != null && w > 0 && pos > 32) {
          _bufferPrimedKeys.add(key);
          _markFrameReady(key);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 32));
        waited += 32;
      }
    } catch (_) {}
  }
}
