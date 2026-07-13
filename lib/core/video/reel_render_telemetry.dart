import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Android render telemetry — single-shot events via Platform Channel.
class ReelRenderTelemetry {
  ReelRenderTelemetry._();

  static final ReelRenderTelemetry instance = ReelRenderTelemetry._();

  static const _control =
      MethodChannel('com.cookster.cooksterapp/reel_render_control');
  static const _events = EventChannel('com.cookster.cooksterapp/reel_render');

  static const int renderConfirmTimeoutMs = 280;
  static const int stallSignatureMs = 250;

  StreamSubscription<dynamic>? _eventSub;
  final Map<int, _OpenWatch> _watchesByHandle = {};
  void Function(ReelRenderStallEvent event)? onStall;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<void> ensureInitialized() async {
    if (!isSupported) {
      return;
    }
    _eventSub ??= _events.receiveBroadcastStream().listen(_onNativeEvent);
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) {
      return;
    }
    final handle = (raw['playerHandle'] as num?)?.toInt();
    if (handle == null) {
      return;
    }
    final watch = _watchesByHandle[handle];
    if (watch == null) {
      return;
    }
    final type = raw['type']?.toString();
    if (type == 'firstFrame') {
      if (!watch.firstFrameCompleter.isCompleted) {
        watch.firstFrameCompleter.complete();
      }
      return;
    }
    if (type == 'stall') {
      final signature = raw['signature']?.toString() ?? 'unknown';
      final event = ReelRenderStallEvent(
        slotIndex: (raw['slotIndex'] as num?)?.toInt() ?? watch.slotIndex,
        playerHandle: handle,
        signature: signature,
        tsMs: (raw['tsMs'] as num?)?.toInt() ?? 0,
      );
      debugPrint(
        '[ReelRender] decoder_stuck sig=$signature '
        'slot=${event.slotIndex} handle=$handle',
      );
      if (!watch.stallCompleter.isCompleted) {
        watch.stallCompleter.complete(event);
      }
      onStall?.call(event);
    }
  }

  Future<void> registerSlot({
    required int slotIndex,
    required int playerHandle,
  }) async {
    if (!isSupported || playerHandle == 0) {
      return;
    }
    await ensureInitialized();
    _watchesByHandle[playerHandle] = _OpenWatch(slotIndex: slotIndex);
    await _control.invokeMethod<void>('registerSlot', {
      'slotIndex': slotIndex,
      'playerHandle': playerHandle,
    });
  }

  Future<void> unregisterSlot(int playerHandle) async {
    if (!isSupported || playerHandle == 0) {
      return;
    }
    _watchesByHandle.remove(playerHandle);
    try {
      await _control.invokeMethod<void>('unregisterSlot', {
        'playerHandle': playerHandle,
      });
    } catch (_) {}
  }

  Future<void> surfaceRevealed(int playerHandle) async {
    if (!isSupported || playerHandle == 0) {
      return;
    }
    try {
      await _control.invokeMethod<void>('surfaceRevealed', {
        'playerHandle': playerHandle,
      });
    } catch (_) {}
  }

  Future<void> notifySurfaceCleanup(int playerHandle) async {
    if (!isSupported || playerHandle == 0) {
      return;
    }
    // No-op if never registered or already unregistered — avoids emitting a
    // native stall signature into Dart for a watch that is no longer live.
    if (!_watchesByHandle.containsKey(playerHandle)) {
      return;
    }
    try {
      await _control.invokeMethod<void>('notifySurfaceCleanup', {
        'playerHandle': playerHandle,
      });
    } catch (_) {}
  }

  /// Confirms a real painted frame (Dart compositor + decode gate passed).
  Future<void> notifyFirstFrame(int playerHandle) async {
    if (!isSupported || playerHandle == 0) {
      return;
    }
    try {
      await _control.invokeMethod<void>('notifyFirstFrame', {
        'playerHandle': playerHandle,
      });
    } catch (_) {}
  }

  /// Wait until paint is confirmed or a stall/timeout event fires (single-shot).
  ///
  /// When [trustPaintReady] is false (Honor/MTK), never confirm from the initial
  /// [paintReady] flag — [surfaceRevealed] must arm stall timers first, and
  /// [notifyFirstFrame] cancels them only after stable probes beat the 250ms stall.
  Future<bool> waitForRenderConfirm({
    required int playerHandle,
    required bool paintReady,
    bool Function()? paintReadyProbe,
    int timeoutMs = renderConfirmTimeoutMs,
    bool trustPaintReady = true,
  }) async {
    if (!isSupported || playerHandle == 0) {
      return paintReady;
    }
    final watch = _watchesByHandle[playerHandle];
    if (watch == null) {
      return paintReady;
    }

    if (trustPaintReady && paintReady) {
      await notifyFirstFrame(playerHandle);
      return true;
    }

    if (trustPaintReady) {
      var ready = paintReady;
      if (!ready && paintReadyProbe != null) {
        final probeDeadline = DateTime.now().add(
          Duration(milliseconds: stallSignatureMs),
        );
        while (DateTime.now().isBefore(probeDeadline)) {
          if (paintReadyProbe()) {
            ready = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }
      if (ready) {
        await notifyFirstFrame(playerHandle);
        return true;
      }
    }

    // Race stable paint probes against the native stall timer (250ms).
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    var stableSamples = 0;
    while (DateTime.now().isBefore(deadline)) {
      if (watch.stallCompleter.isCompleted) {
        debugPrint(
          '[ReelRender] render_confirm_failed handle=$playerHandle '
          'reason=stall_timer',
        );
        return false;
      }
      if (paintReadyProbe != null && paintReadyProbe()) {
        stableSamples++;
        if (stableSamples >= 4) {
          await notifyFirstFrame(playerHandle);
          debugPrint(
            '[ReelRender] render_confirm_ok handle=$playerHandle '
            'stable=$stableSamples',
          );
          return true;
        }
      } else {
        stableSamples = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    debugPrint(
      '[ReelRender] render_confirm_failed handle=$playerHandle reason=timeout',
    );
    return false;
  }

  Future<int> playerHandleFor(Player player) async {
    try {
      return await player.handle;
    } catch (_) {
      return 0;
    }
  }
}

class ReelRenderStallEvent {
  const ReelRenderStallEvent({
    required this.slotIndex,
    required this.playerHandle,
    required this.signature,
    required this.tsMs,
  });

  final int slotIndex;
  final int playerHandle;
  final String signature;
  final int tsMs;
}

class _OpenWatch {
  _OpenWatch({required this.slotIndex});

  final int slotIndex;
  final Completer<void> firstFrameCompleter = Completer<void>();
  final Completer<ReelRenderStallEvent> stallCompleter =
      Completer<ReelRenderStallEvent>();
}
