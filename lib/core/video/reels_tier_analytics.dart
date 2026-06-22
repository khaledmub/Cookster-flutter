import 'dart:io';

import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reel_render_telemetry.dart';
import 'package:cookster/core/video/reels_device_capability_store.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase analytics for adaptive reel tier changes and render failures.
class ReelsTierAnalytics {
  ReelsTierAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  Map<String, String>? _deviceParams;

  Future<void> ensureDeviceParams() async {
    if (_deviceParams != null) {
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      _deviceParams = const {};
      return;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceParams = {
        'manufacturer': info.manufacturer,
        'model': info.model,
        'hardware': info.hardware,
        'board': info.board,
      };
    } catch (_) {
      _deviceParams = const {};
    }
  }

  Future<void> logTierPromoted({
    required ReelsDeviceTier fromTier,
    required ReelsDeviceTier toTier,
  }) async {
    await ensureDeviceParams();
    await _analytics.logEvent(
      name: 'reel_tier_promoted',
      parameters: {
        'from_tier': fromTier.name,
        'to_tier': toTier.name,
        'measured_tier': toTier.name,
        ...?_deviceParams,
      },
    );
  }

  Future<void> logTierDemoted({
    required ReelsDeviceTier fromTier,
    required ReelsDeviceTier toTier,
    required String signature,
  }) async {
    await ensureDeviceParams();
    debugPrint(
      '[ReelRender] reel_tier_demoted ${fromTier.name}->${toTier.name} '
      'sig=$signature',
    );
    await _analytics.logEvent(
      name: 'reel_tier_demoted',
      parameters: {
        'from_tier': fromTier.name,
        'to_tier': toTier.name,
        'measured_tier': toTier.name,
        'signature': signature,
        ...?_deviceParams,
      },
    );
  }

  Future<void> logRenderFailure(ReelRenderStallEvent event) async {
    await ensureDeviceParams();
    final tier =
        ReelsDeviceCapabilityStore.instance.profile.measuredTier.name;
    debugPrint(
      '[ReelRender] reel_tier_analytics reel_render_failure '
      'sig=${event.signature} slot=${event.slotIndex} tier=$tier',
    );
    await _analytics.logEvent(
      name: 'reel_render_failure',
      parameters: {
        'signature': event.signature,
        'slot_index': event.slotIndex,
        'player_handle': event.playerHandle,
        'measured_tier': tier,
        ...?_deviceParams,
      },
    );
  }
}

final reelsTierAnalytics = ReelsTierAnalytics();
