import 'dart:collection';

import 'package:shared_preferences/shared_preferences.dart';

/// Local record of videos this device/user has already watched.
///
/// Used to put unwatched reels first on General / Near Me / Following until the
/// backend ships `unseen_first=1` with server-side view history. Cap the set so
/// prefs stay bounded; oldest entries drop first when over capacity.
class WatchedVideosStore {
  WatchedVideosStore._();

  static final WatchedVideosStore instance = WatchedVideosStore._();

  static const _prefsKey = 'watched_video_ids_v1';
  static const _maxIds = 2500;

  final LinkedHashSet<String> _ids = LinkedHashSet<String>();
  bool _loaded = false;
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    _ids
      ..clear()
      ..addAll(raw.where((id) => id.trim().isNotEmpty));
    _loaded = true;
  }

  bool isWatched(String? videoId) {
    final id = videoId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return _ids.contains(id);
  }

  /// Ids in insertion order (oldest → newest).
  List<String> snapshotIds({int limit = 300}) {
    if (_ids.isEmpty) {
      return const [];
    }
    final list = _ids.toList();
    if (list.length <= limit) {
      return list;
    }
    return list.sublist(list.length - limit);
  }

  Future<void> markWatched(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) {
      return;
    }
    await ensureLoaded();
    if (_ids.contains(id)) {
      // Move to newest position.
      _ids.remove(id);
      _ids.add(id);
      await _persist();
      return;
    }
    _ids.add(id);
    while (_ids.length > _maxIds) {
      _ids.remove(_ids.first);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList());
  }
}
