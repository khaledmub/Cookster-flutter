import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/feed_ping_pong_logic.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Result of presenting a reel on the feed ping-pong path.
class FeedPresentResult {
  const FeedPresentResult({
    required this.key,
    required this.player,
    required this.activeSlotIndex,
    required this.flipped,
    required this.openedMedia,
  });

  final String key;
  final Player player;
  final int activeSlotIndex;
  final bool flipped;

  /// True when [Player.open] ran — false on flip-back to an already-decoded slot.
  final bool openedMedia;
}

/// One permanent decode slot (player + surface) in the feed ping-pong pair.
class FeedDecodeSlot {
  FeedDecodeSlot({required this.index});

  final int index;
  Player? player;
  VideoController? videoController;
  String? boundKey;
  String? boundUrl;
  int openCount = 0;
  int generation = 0;
  bool isPrimed = false;

  void resetBinding() {
    boundKey = null;
    boundUrl = null;
    isPrimed = false;
  }
}

/// Dual-slot feed decoder: prefetch on hidden, flip on swipe, recycle hidden only.
class FeedPingPongController {
  FeedPingPongController({
    this.onSlotsChanged,
    this.singleSlotMode = true,
  });

  final VoidCallback? onSlotsChanged;

  /// MTK/Oppo cannot sustain two live [Video] surfaces — one decoder, one
  /// surface, swap media with [Player.open] on the same slot.
  final bool singleSlotMode;

  /// MTK/Oppo: disposing a hidden [Player] tears down ImageReader and spikes
  /// flush index — reuse the same two players for the whole feed session.
  static const bool hiddenSlotRecycleEnabled = false;
  static const int hiddenRecycleAfterOpens = 3;
  static const Duration recycleDefer = Duration(milliseconds: 300);

  final FeedDecodeSlot slot0 = FeedDecodeSlot(index: 0);
  final FeedDecodeSlot slot1 = FeedDecodeSlot(index: 1);

  int _activeIndex = 0;
  int _openToken = 0;
  int _prefetchToken = 0;
  int _recycleDeferToken = 0;
  Future<void> _slotOpenChain = Future<void>.value();

  int get activeSlotIndex => _activeIndex;

  FeedDecodeSlot get _active => _activeIndex == 0 ? slot0 : slot1;

  FeedDecodeSlot get _hidden => _activeIndex == 0 ? slot1 : slot0;

  FeedDecodeSlot slotAt(int index) => index == 0 ? slot0 : slot1;

  Player? get activePlayer => _active.player;

  String? get visibleKey => _active.boundKey;

  bool isStaleOpen(int token) => token < _openToken;

  bool isStalePrefetch(int token) => token < _prefetchToken;

  Future<void> ensureInitialized() async {
    await _ensureSlotPlayer(slot0);
    if (!singleSlotMode) {
      await _ensureSlotPlayer(slot1);
    }
  }

  Future<void> _ensureSlotPlayer(FeedDecodeSlot slot) async {
    if (slot.player != null && slot.videoController != null) {
      return;
    }
    final player = Player(
      configuration: const PlayerConfiguration(muted: true),
    );
    slot.player = player;
    slot.videoController = VideoController(player);
  }

  Future<FeedPresentResult?> presentReel({
    required String key,
    required String sourceUrl,
    required int openToken,
    required bool suspended,
    required bool userPaused,
  }) async {
    await ensureInitialized();
    _openToken = openToken;
    _prefetchToken = openToken;

    if (singleSlotMode) {
      _activeIndex = 0;
      var openedMedia = false;
      if (_active.boundKey != key) {
        openedMedia = await _openOnSlot(
          _active,
          key: key,
          sourceUrl: sourceUrl,
          audible: false,
        );
      } else {
        _syncSlotUrl(_active, sourceUrl);
        await _seekToStartIfNeeded(_active);
      }
      if (isStaleOpen(openToken)) {
        return null;
      }
      await _applyPresentAudioPolicy();
      return FeedPresentResult(
        key: key,
        player: _active.player!,
        activeSlotIndex: 0,
        flipped: false,
        openedMedia: openedMedia,
      );
    }

    final plan = FeedPingPongLogic.planPresent(
      activeKey: _active.boundKey,
      activeUrl: _active.boundUrl,
      hiddenKey: _hidden.boundKey,
      hiddenUrl: _hidden.boundUrl,
      requestKey: key,
      requestUrl: sourceUrl,
    );

    switch (plan) {
      case FeedPresentPlan.flipToHidden:
        var openedMedia = false;
        if (_hidden.boundKey != key) {
          openedMedia = await _openOnSlot(
            _hidden,
            key: key,
            sourceUrl: sourceUrl,
            audible: false,
          );
        } else {
          _syncSlotUrl(_hidden, sourceUrl);
        }
        if (isStaleOpen(openToken)) {
          return null;
        }
        _flipActiveSlot();
        if (isStaleOpen(openToken)) {
          return null;
        }
        await _applyPresentAudioPolicy();
        return FeedPresentResult(
          key: key,
          player: _active.player!,
          activeSlotIndex: _activeIndex,
          flipped: true,
          openedMedia: openedMedia,
        );

      case FeedPresentPlan.keepActive:
        await _seekToStartIfNeeded(_active);
        if (isStaleOpen(openToken)) {
          return null;
        }
        await _applyPresentAudioPolicy();
        return FeedPresentResult(
          key: key,
          player: _active.player!,
          activeSlotIndex: _activeIndex,
          flipped: false,
          openedMedia: false,
        );

      case FeedPresentPlan.openOnHiddenThenFlip:
        final openedMedia = await _openOnSlot(
          _hidden,
          key: key,
          sourceUrl: sourceUrl,
          audible: false,
        );
        if (isStaleOpen(openToken)) {
          return null;
        }
        _flipActiveSlot();
        if (isStaleOpen(openToken)) {
          return null;
        }
        await _applyPresentAudioPolicy();
        return FeedPresentResult(
          key: key,
          player: _active.player!,
          activeSlotIndex: _activeIndex,
          flipped: true,
          openedMedia: openedMedia,
        );
    }
  }

  /// Swap which slot is visible. [Video] widgets keep stable keys per slot.
  void _flipActiveSlot() {
    _activeIndex = FeedPingPongLogic.flippedActiveIndex(_activeIndex);
  }

  /// Mute both slots on present — active unmutes when the video surface is revealed.
  Future<void> _applyPresentAudioPolicy() async {
    await _disableSlotAudio(_hidden);
    await _disableSlotAudio(_active);
  }

  Future<void> prefetchReel({
    required String key,
    required String sourceUrl,
    required int prefetchToken,
  }) async {
    if (singleSlotMode) {
      return;
    }
    await ensureInitialized();
    _prefetchToken = prefetchToken;

    final plan = FeedPingPongLogic.planPrefetch(
      activeKey: _active.boundKey,
      hiddenKey: _hidden.boundKey,
      hiddenUrl: _hidden.boundUrl,
      requestKey: key,
      requestUrl: sourceUrl,
    );

    switch (plan) {
      case FeedPrefetchPlan.skipAlreadyBound:
      case FeedPrefetchPlan.skipSameAsActive:
        return;
      case FeedPrefetchPlan.openOnHidden:
        if (isStalePrefetch(prefetchToken)) {
          return;
        }
        await _openOnSlot(
          _hidden,
          key: key,
          sourceUrl: sourceUrl,
          audible: false,
        );
    }
  }

  Future<void> silenceAllSlots() async {
    await ensureInitialized();
    await _silenceSlot(slot0);
    if (!singleSlotMode || slot1.player != null) {
      await _silenceSlot(slot1);
    }
  }

  Future<void> muteHiddenSlot() async {
    await ensureInitialized();
    await _silenceSlot(_hidden);
  }

  /// Unmute when the [Video] surface is revealed (or tab return when already audible).
  Future<void> resumeActiveAudible({
    required bool alreadyAudible,
    String? expectedKey,
  }) async {
    if (alreadyAudible) {
      return;
    }
    await ensureInitialized();
    if (expectedKey != null &&
        expectedKey.isNotEmpty &&
        _active.boundKey != expectedKey) {
      return;
    }
    await _enableSlotAudio(_active);
  }

  Future<void> muteActiveForUser() async {
    await pauseActiveForUser();
  }

  /// User tap pause — mute and freeze decode (not swipe-away silence).
  Future<void> pauseActiveForUser() async {
    await ensureInitialized();
    await _disableSlotAudio(_active);
    final player = _active.player;
    if (player == null) {
      return;
    }
    try {
      if (player.state.playing) {
        await player.pause();
      }
    } catch (_) {}
  }

  /// User tap resume after [pauseActiveForUser].
  Future<void> resumeActiveForUser({String? expectedKey}) async {
    await ensureInitialized();
    if (expectedKey != null &&
        expectedKey.isNotEmpty &&
        _active.boundKey != expectedKey) {
      return;
    }
    final player = _active.player;
    if (player == null) {
      return;
    }
    try {
      if (!player.state.playing) {
        await player.play();
      }
    } catch (_) {}
    await _enableSlotAudio(_active);
  }

  Future<void> disposeAll() async {
    for (final slot in [slot0, slot1]) {
      final player = slot.player;
      slot.player = null;
      slot.videoController = null;
      slot.resetBinding();
      slot.openCount = 0;
      if (player != null) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
    _activeIndex = 0;
    _openToken = 0;
    _prefetchToken = 0;
  }

  Player? playerForSlot(int index) => slotAt(index).player;

  VideoController? videoControllerForSlot(int index) =>
      slotAt(index).videoController;

  int slotGeneration(int index) => slotAt(index).generation;

  Future<bool> _openOnSlot(
    FeedDecodeSlot slot, {
    required String key,
    required String sourceUrl,
    required bool audible,
  }) {
    final completer = Completer<bool>();
    final previous = _slotOpenChain;
    _slotOpenChain = previous.then((_) async {
      try {
        completer.complete(
          await _openOnSlotLocked(
            slot,
            key: key,
            sourceUrl: sourceUrl,
            audible: audible,
          ),
        );
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });
    return completer.future;
  }

  Future<bool> _openOnSlotLocked(
    FeedDecodeSlot slot, {
    required String key,
    required String sourceUrl,
    required bool audible,
  }) async {
    final player = slot.player!;
    final sameMedia = slot.boundKey == key && key.isNotEmpty;
    var openedMedia = false;
    if (!sameMedia) {
      if (!identical(slot, _active)) {
        await _disableSlotAudio(slot);
      }
      if (identical(slot, _active)) {
        await DeviceConstraints.instance.ensureInitialized();
        if (DeviceConstraints.instance.needsConstrainedSurfaceRecovery &&
            !_isLocalPlaybackUrl(sourceUrl)) {
          // Let the outgoing poster settle before Player.open tears down ImageReader.
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
      await player.open(Media(sourceUrl), play: true);
      await player.setVolume(0);
      if (identical(slot, _active) &&
          DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
        final postOpenMs = _isLocalPlaybackUrl(sourceUrl) ? 24 : 64;
        await Future<void>.delayed(Duration(milliseconds: postOpenMs));
      }
      slot.boundKey = key;
      slot.boundUrl = sourceUrl;
      slot.openCount++;
      slot.isPrimed = true;
      openedMedia = true;
      ReelsPerf.log(
        'pingpong open slot=${slot.index} key=$key tier=${_tierFromUrl(sourceUrl)}',
      );
      if (identical(slot, _active)) {
        await DeviceConstraints.instance.ensureInitialized();
        if (!DeviceConstraints.instance.needsConstrainedSurfaceRecovery) {
          await _seekToStartAfterColdOpen(slot);
        }
      }
    } else {
      _syncSlotUrl(slot, sourceUrl);
      if (identical(slot, _active)) {
        await _seekToStartIfNeeded(slot);
      }
    }
    if (identical(slot, _active) && audible) {
      await _enableSlotAudio(slot);
    } else if (!identical(slot, _active)) {
      await _disableSlotAudio(slot);
    }
    return openedMedia;
  }

  void _syncSlotUrl(FeedDecodeSlot slot, String sourceUrl) {
    if (sourceUrl.isNotEmpty) {
      slot.boundUrl = sourceUrl;
    }
  }

  Future<void> _seekToStartIfNeeded(FeedDecodeSlot slot) async {
    if (!identical(slot, _active)) {
      return;
    }
    final player = slot.player;
    if (player == null) {
      return;
    }
    try {
      // Mid-reel rewind on revisit thrashes MTK flush index — restart only at EOS.
      if (player.state.completed) {
        await player.seek(Duration.zero);
      }
    } catch (_) {}
  }

  /// After cold open, align to t=0 so the first painted frame is stable (reduces
  /// visible “frame crawl” when the decoder starts mid-buffer).
  Future<void> _seekToStartAfterColdOpen(FeedDecodeSlot slot) async {
    final player = slot.player;
    if (player == null) {
      return;
    }
    try {
      await player.seek(Duration.zero);
    } catch (_) {}
  }

  Future<void> _silenceSlot(FeedDecodeSlot slot) async {
    await _disableSlotAudio(slot);
    final player = slot.player;
    if (player == null) {
      return;
    }
    try {
      if (player.state.playing) {
        await player.pause();
      }
    } catch (_) {}
  }

  Future<void> _muteSlot(FeedDecodeSlot slot) async {
    await _silenceSlot(slot);
  }

  Future<void> _unmuteSlot(FeedDecodeSlot slot) async {
    await _enableSlotAudio(slot);
  }

  Future<void> _disableSlotAudio(FeedDecodeSlot slot) async {
    final player = slot.player;
    if (player == null) {
      return;
    }
    try {
      if (player.state.volume == 0) {
        return;
      }
      await player.setVolume(0);
    } catch (_) {}
  }

  Future<void> _enableSlotAudio(FeedDecodeSlot slot) async {
    if (!identical(slot, _active)) {
      return;
    }
    final player = slot.player;
    if (player == null) {
      return;
    }
    try {
      if (player.state.volume > 50) {
        return;
      }
      await player.setVolume(100);
    } catch (_) {}
  }

  Future<void> _scheduleHiddenRecycle(int openToken) async {
    if (!hiddenSlotRecycleEnabled) {
      return;
    }
    final token = ++_recycleDeferToken;
    await Future<void>.delayed(recycleDefer);
    if (token != _recycleDeferToken || isStaleOpen(openToken)) {
      return;
    }
    if (FeedPingPongLogic.shouldRecycleHidden(
      hiddenOpenCount: _hidden.openCount,
      recycleAfterOpens: hiddenRecycleAfterOpens,
    )) {
      await _recycleHiddenSlotNow();
    }
  }

  Future<void> _recycleHiddenSlotNow() async {
    if (!hiddenSlotRecycleEnabled) {
      return;
    }
    final hidden = _hidden;
    final retiring = hidden.player;
    hidden.player = Player();
    hidden.videoController = VideoController(hidden.player!);
    hidden.openCount = 0;
    hidden.resetBinding();
    onSlotsChanged?.call();
    if (retiring != null) {
      unawaited(
        Future<void>.delayed(recycleDefer, () async {
          try {
            await retiring.dispose();
          } catch (_) {}
        }),
      );
    }
  }

  String _tierFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/1080') || lower.contains('_1080')) {
      return '1080';
    }
    if (lower.contains('/720') || lower.contains('_720')) {
      return '720';
    }
    if (lower.contains('/360') || lower.contains('_360')) {
      return '360';
    }
    return 'other';
  }

  static bool _isLocalPlaybackUrl(String url) {
    if (url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.startsWith('file://') ||
        (!lower.startsWith('http') && !lower.contains('.m3u8'));
  }
}
