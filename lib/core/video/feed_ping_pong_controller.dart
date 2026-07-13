import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/feed_ping_pong_logic.dart';
import 'package:cookster/core/video/mpv_surface_stability.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// [VideoController] for reel playback. Honor/Huawei/MTK must disable hardware
/// video decode here — NOT on [Player]. [VideoController.create] sets mpv
/// `hwdec=auto-safe` + MediaCodec by default, which ignores any later
/// Player.setProperty('hwdec') and causes the Rendered 0/s flush storm.
VideoController createReelVideoController(Player player) {
  final tier = DeviceConstraints.instance.deviceTierSync;
  final software = DeviceConstraints.instance.preferSoftwareVideoDecode;
  if (software) {
    ReelsPerf.log('reel_video_ctrl software_decode tier=${tier.name}');
    return VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
        hwdec: 'no',
      ),
    );
  }
  return VideoController(player);
}

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
    this.onBeforeSlotRecycle,
    this.onSlotRecycled,
    this.singleSlotMode = true,
  });

  final VoidCallback? onSlotsChanged;
  final void Function(String key)? onBeforeSlotRecycle;
  final VoidCallback? onSlotRecycled;

  /// MTK/Oppo cannot sustain two live [Video] surfaces — one decoder, one
  /// surface, swap media with [Player.open] on the same slot.
  final bool singleSlotMode;

  /// MTK/Oppo: disposing a hidden [Player] tears down ImageReader and spikes
  /// flush index — reuse the same two players for the whole feed session.
  static const bool hiddenSlotRecycleEnabled = false;
  static const int hiddenRecycleAfterOpens = 3;
  /// Default recycle threshold for dual-slot / Tier S/A (Tier B uses [DeviceConstraints]).
  static const int singleSlotRecycleAfterOpens = 8;

  int _recycleAfterOpensSync() =>
      DeviceConstraints.instance.singleSlotRecycleAfterOpensSync;
  static const Duration recycleDefer = Duration(milliseconds: 300);

  final FeedDecodeSlot slot0 = FeedDecodeSlot(index: 0);
  final FeedDecodeSlot slot1 = FeedDecodeSlot(index: 1);

  int _activeIndex = 0;
  int _openToken = 0;
  int _prefetchToken = 0;
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
    await DeviceConstraints.instance.ensureInitialized();
    final player = Player(
      configuration: const PlayerConfiguration(muted: true),
    );
    slot.player = player;
    slot.videoController = createReelVideoController(player);
  }

  Future<FeedPresentResult?> presentReel({
    required String key,
    required String sourceUrl,
    required int openToken,
    required bool suspended,
    required bool userPaused,
    bool fastReopen = false,
  }) async {
    await ensureInitialized();
    _openToken = openToken;
    _prefetchToken = openToken;

    if (singleSlotMode) {
      _activeIndex = 0;
      await DeviceConstraints.instance.ensureInitialized();
      if (_active.boundKey != key &&
          _active.openCount >= _recycleAfterOpensSync() &&
          !DeviceConstraints.instance.shouldDeferDecoderRecycle) {
        await _recycleSlotNow(_active);
      }
      var openedMedia = false;
      if (_active.boundKey != key) {
        openedMedia = await _openOnSlot(
          _active,
          key: key,
          sourceUrl: sourceUrl,
          audible: false,
          fastReopen: fastReopen,
          openToken: openToken,
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
            fastReopen: fastReopen,
            openToken: openToken,
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
          fastReopen: fastReopen,
          openToken: openToken,
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

  /// Poster-unmask audio. Volume-only unmute — never pause (Honor flush storm).
  Future<void> forceRestartActiveAudio({bool forPosterUnmask = false}) async {
    await ensureInitialized();
    final player = _active.player;
    if (player == null) {
      return;
    }
    try {
      await _unmutePlayingDecoder(player, forPosterUnmask: forPosterUnmask);
    } catch (_) {}
  }

  /// Start decode with volume 0 — after [Player.open] on Honor (play:false).
  Future<void> startMutedFeedDecode() async {
    await ensureInitialized();
    final player = _active.player;
    if (player == null) {
      return;
    }
    try {
      await player.setVolume(0);
      if (!player.state.playing) {
        await player.play();
      }
    } catch (_) {}
  }

  /// Unmute without tearing down an active video decode session.
  Future<void> _unmutePlayingDecoder(
    Player player, {
    bool forPosterUnmask = false,
  }) async {
    await DeviceConstraints.instance.ensureInitialized();

    if (!forPosterUnmask && player.state.volume > 50 && player.state.playing) {
      return;
    }

    try {
      await player.setVolume(100);
    } on Object catch (_) {
      return;
    }

    if (!player.state.playing) {
      try {
        await player.play();
      } on Object catch (_) {}
    }
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
    bool fastReopen = false,
    int? openToken,
  }) {
    final tokenAtEnqueue = openToken ?? _openToken;
    final completer = Completer<bool>();
    final previous = _slotOpenChain;
    _slotOpenChain = previous.then((_) async {
      try {
        // Fast-scroll flush: a newer presentReel() already bumped _openToken.
        // Skip the entire locked open so the chain drains immediately.
        if (openToken != null && _openToken > tokenAtEnqueue) {
          ReelsPerf.log(
            'pingpong stale_skip slot=${slot.index} key=$key '
            'token=$tokenAtEnqueue current=$_openToken',
          );
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          return;
        }
        completer.complete(
          await _openOnSlotLocked(
            slot,
            key: key,
            sourceUrl: sourceUrl,
            audible: audible,
            fastReopen: fastReopen,
            openToken: tokenAtEnqueue,
          ),
        );
      } catch (e) {
        // A failed player.open leaves boundKey set while the player has no
        // media — the next swipe would skip the open ("same key, no need to
        // open"). Reset the binding so the slot is clean for the next attempt.
        slot.resetBinding();
        ReelsPerf.log(
          'pingpong open_error slot=${slot.index} key=$key '
          'error=${e.runtimeType}',
        );
        if (!completer.isCompleted) {
          completer.complete(false);
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
    bool fastReopen = false,
    int? openToken,
  }) async {
    final player = slot.player!;
    final sameMedia = slot.boundKey == key && key.isNotEmpty && slot.boundUrl == sourceUrl;
    var openedMedia = false;
    if (!sameMedia) {
      // Fast-scroll bail: a newer presentReel() already bumped _openToken.
      // Skip the expensive Player.open() so the chain drains immediately.
      if (openToken != null && _openToken > openToken) {
        slot.resetBinding();
        return false;
      }
      if (!identical(slot, _active)) {
        await _disableSlotAudio(slot);
      }
      final fastScroll = DeviceConstraints.instance.shouldDeferDecoderRecycle;
      if (identical(slot, _active)) {
        await DeviceConstraints.instance.ensureInitialized();
        if (DeviceConstraints.instance.needsConstrainedSurfaceRecovery && !fastScroll) {
          if (!fastReopen) {
            final local = _isLocalPlaybackUrl(sourceUrl);
            final baseMs = local ? 16 : 80;
            final fatigueMs = local
                ? 0
                : (slot.openCount.clamp(0, 8) * 12).clamp(0, 96);
            if (baseMs + fatigueMs > 0) {
              await Future<void>.delayed(
                Duration(milliseconds: baseMs + fatigueMs),
              );
            }
          }
        } else if (!_isLocalPlaybackUrl(sourceUrl) && !fastReopen && !fastScroll) {
          // 32ms is enough for the previous slot's audio to drain on Qualcomm.
          await Future<void>.delayed(const Duration(milliseconds: 32));
        }
      }
      // Re-check after delays — another swipe may have arrived.
      if (openToken != null && _openToken > openToken) {
        slot.resetBinding();
        return false;
      }
      final honorActiveOpen = identical(slot, _active) &&
          DeviceConstraints.instance.needsConstrainedSurfaceRecovery;
      // Network-only deferred decode on Honor — cached file:// opens with play:true
      // so first frame arrives sooner (no extra startMutedFeedDecode round-trip).
      final honorDeferredDecode =
          honorActiveOpen && !_isLocalPlaybackUrl(sourceUrl);
      try {
        await player.open(
          Media(sourceUrl),
          play: !honorDeferredDecode,
        );
        await stabilizeMpvSurfaceDimensions(player);
        await player.setVolume(0);
        if (honorDeferredDecode) {
          await startMutedFeedDecode();
        }
        slot.boundKey = key;
        slot.boundUrl = sourceUrl;
        slot.openCount++;
        slot.isPrimed = true;
        openedMedia = true;
        ReelsPerf.log(
          'pingpong open slot=${slot.index} key=$key tier=${_tierFromUrl(sourceUrl)} '
          'openCount=${slot.openCount} honorOpen=$honorActiveOpen',
        );
      } catch (e) {
        slot.resetBinding();
        rethrow;
      }
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
      // Mid-reel rewind on revisit thrashes MTK/Honor flush index (constant
      // MediaCodec::flush() → stale buffer callbacks → Rendered 0/s). Restart
      // only at EOS; a resumed position is acceptable on scroll-back.
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
    // Single-slot feed (Honor/MTK): mute only — never pause the active demuxer.
    // Resume is volume-only; pausing here leaves audio silent after swipe/unmute.
    if (singleSlotMode && identical(slot, _active)) {
      return;
    }
    try {
      if (player.state.playing) {
        await player.pause();
      }
    } catch (_) {}
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
    } on Object catch (_) {}
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
      await _unmutePlayingDecoder(player);
    } catch (_) {}
  }

  /// Recycle the active decoder when the single-slot open count is high (Honor).
  Future<bool> recycleActiveDecoderIfStale() async {
    await DeviceConstraints.instance.ensureInitialized();
    if (!singleSlotMode ||
        _active.openCount < _recycleAfterOpensSync() ||
        DeviceConstraints.instance.shouldDeferDecoderRecycle) {
      return false;
    }
    await _recycleSlotNow(_active);
    return true;
  }

  int get activeOpenCount => _active.openCount;

  /// Hard reset of the visible decoder — use when MTK surface is stuck.
  Future<void> forceRecycleActiveDecoder() async {
    await _recycleSlotNow(_active);
  }

  Future<void> _recycleSlotNow(FeedDecodeSlot slot) async {
    final retiringKey = slot.boundKey;
    if (retiringKey != null && retiringKey.isNotEmpty) {
      onBeforeSlotRecycle?.call(retiringKey);
    }
    final retiring = slot.player;
    await _disableSlotAudio(slot);
    final player = Player(
      configuration: const PlayerConfiguration(muted: true),
    );
    slot.player = player;
    slot.videoController = createReelVideoController(player);
    slot.openCount = 0;
    slot.resetBinding();
    slot.generation++;
    onSlotsChanged?.call();
    onSlotRecycled?.call();
    ReelsPerf.log(
      'pingpong recycle slot=${slot.index} mode=${singleSlotMode ? 'single' : 'dual'} '
      'gen=${slot.generation}',
    );
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
