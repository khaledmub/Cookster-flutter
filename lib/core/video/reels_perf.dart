import 'package:flutter/foundation.dart';

/// Structured reel playback telemetry (debug logs + optional release hook).
class ReelsPerfEvent {
  const ReelsPerfEvent({
    required this.name,
    this.openMs,
    this.frameMs,
    this.cacheHit,
    this.tier,
    this.deviceTier,
    this.feedMode,
    this.flip,
    this.coldOpen,
    this.stuck,
    this.retry,
    this.partialCache,
    Map<String, Object?>? extra,
  }) : extra = extra ?? const {};

  final String name;
  final int? openMs;
  final int? frameMs;
  final bool? cacheHit;
  final String? tier;
  final String? deviceTier;
  final String? feedMode;
  final bool? flip;
  final bool? coldOpen;
  final bool? stuck;
  final bool? retry;
  final bool? partialCache;
  final Map<String, Object?> extra;
}

typedef ReelsPerfListener = void Function(ReelsPerfEvent event);

/// Lightweight timing logs for reel playback tuning.
class ReelsPerf {
  static ReelsPerfListener? onEvent;

  static void emit(ReelsPerfEvent event) {
    if (kDebugMode) {
      final parts = <String>[
        event.name,
        if (event.openMs != null) 'openMs=${event.openMs}',
        if (event.frameMs != null) 'frameMs=${event.frameMs}',
        if (event.cacheHit != null) 'cache=${event.cacheHit! ? 'hit' : 'miss'}',
        if (event.partialCache != null)
          'partial=${event.partialCache! ? 'yes' : 'no'}',
        if (event.tier != null) 'tier=${event.tier}',
        if (event.deviceTier != null) 'deviceTier=${event.deviceTier}',
        if (event.feedMode != null) 'feedMode=${event.feedMode}',
        if (event.flip != null) 'flip=${event.flip}',
        if (event.coldOpen != null) 'coldOpen=${event.coldOpen}',
        if (event.stuck != null) 'stuck=${event.stuck}',
        if (event.retry != null) 'retry=${event.retry}',
      ];
      debugPrint('[ReelsPerf] ${parts.join(' ')}');
    }
    onEvent?.call(event);
  }

  static void log(String message) {
    emit(ReelsPerfEvent(name: message));
  }
}
