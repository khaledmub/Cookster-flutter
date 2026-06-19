import 'dart:io';

import 'package:cookster/core/video/reels_perf.dart';
import 'package:cookster/services/feature_flags/remote_config_service.dart';
import 'package:cookster/services/settings/settings_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Graduated device capability for reel decode / prefetch.
enum ReelsDeviceTier {
  /// Pixel / Samsung — dual-slot ping-pong + hidden prefetch.
  s,

  /// Qualcomm (non-Honor) — single surface, buffer warm + scroll demux.
  a,

  /// Honor / Huawei / MTK / Oppo family — single surface, disk + scroll demux.
  b,

  /// Data saver / constrained — disk 360 only, no warm slots.
  c,
}

class DeviceConstraints {
  DeviceConstraints._();

  static final DeviceConstraints instance = DeviceConstraints._();

  ReelsDeviceTier? _tier;
  bool? _needsSingleSlotFeed;
  DateTime? _lastSwipeAt;

  /// Safe default until [ensureInitialized] completes — MTK-style single slot.
  bool get needsSingleSlotFeedSync => _needsSingleSlotFeed ?? true;

  ReelsDeviceTier get deviceTierSync => _tier ?? ReelsDeviceTier.b;

  bool get feedDualSlotEnabled =>
      !needsSingleSlotFeedSync &&
      RemoteConfigService.instance.reelsDualSlotEnabled;

  int get phoneWarmSlots {
    final rc = RemoteConfigService.instance.reelsPhoneWarmSlots;
    if (rc > 0) {
      return rc.clamp(0, 2);
    }
    return switch (deviceTierSync) {
      ReelsDeviceTier.s => 1,
      ReelsDeviceTier.a => 1,
      ReelsDeviceTier.b => 0,
      ReelsDeviceTier.c => 0,
    };
  }

  bool get scrollDemuxPrefetchEnabled =>
      RemoteConfigService.instance.reelsScrollDemuxPrefetch &&
      deviceTierSync != ReelsDeviceTier.c;

  /// Honor/MTK/Oppo — surface often decodes but Rendered stays 0/s.
  bool get needsConstrainedSurfaceRecovery =>
      deviceTierSync == ReelsDeviceTier.b ||
      deviceTierSync == ReelsDeviceTier.c;

  /// Cold network opens should start at 360p, not 720p.
  bool get prefer360ColdOpen => needsConstrainedSurfaceRecovery;

  /// Buffer-only warm competes with the visible decoder on Honor.
  bool get suppressScrollDecoderWarm =>
      deviceTierSync == ReelsDeviceTier.b;

  /// Throttle decoder warm-up during burst swipes — disk prefetch is never skipped.
  bool shouldThrottleDecoderWarm() {
    final now = DateTime.now();
    final last = _lastSwipeAt;
    _lastSwipeAt = now;
    if (last == null) {
      return false;
    }
    return now.difference(last).inMilliseconds < 150;
  }

  Future<void> ensureInitialized() async {
    if (_tier != null) {
      return;
    }
    _tier = await _detectTier();
    _needsSingleSlotFeed = _tier != ReelsDeviceTier.s ||
        !RemoteConfigService.instance.reelsDualSlotEnabled;
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'device_init',
        deviceTier: _tier!.name,
        feedMode: _needsSingleSlotFeed! ? 'single_slot' : 'dual_slot',
      ),
    );
  }

  Future<ReelsDeviceTier> _detectTier() async {
    final override = RemoteConfigService.instance.reelsDeviceTierOverride;
    if (override.isNotEmpty) {
      return switch (override) {
        's' => ReelsDeviceTier.s,
        'a' => ReelsDeviceTier.a,
        'b' => ReelsDeviceTier.b,
        'c' => ReelsDeviceTier.c,
        _ => ReelsDeviceTier.b,
      };
    }
    if (SettingsService.instance.dataSaverEnabled.value) {
      return ReelsDeviceTier.c;
    }
    if (!Platform.isAndroid) {
      return ReelsDeviceTier.s;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final hardware = info.hardware.toLowerCase();
      final manufacturer = info.manufacturer.toLowerCase();
      final brand = info.brand.toLowerCase();
      final board = info.board.toLowerCase();
      final model = info.model.toLowerCase();

      const mtkPatterns = ['mt', 'mediatek', 'mtk'];
      const tierBBrands = [
        'oppo',
        'realme',
        'vivo',
        'oneplus',
        'infinix',
        'tecno',
        'itel',
        'honor',
        'huawei',
        'hihonor',
        'hinova',
      ];

      for (final pattern in mtkPatterns) {
        if (hardware.contains(pattern) || board.contains(pattern)) {
          return ReelsDeviceTier.b;
        }
      }
      for (final constrained in tierBBrands) {
        if (manufacturer.contains(constrained) ||
            brand.contains(constrained) ||
            model.contains(constrained)) {
          return ReelsDeviceTier.b;
        }
      }

      const tierSBrands = ['google', 'samsung'];
      for (final allowed in tierSBrands) {
        if (manufacturer.contains(allowed) || brand.contains(allowed)) {
          return ReelsDeviceTier.s;
        }
      }

      // Remaining Qualcomm / other Android — tier A.
      return ReelsDeviceTier.a;
    } catch (_) {
      return ReelsDeviceTier.b;
    }
  }

  Future<bool> isBatteryLow() async {
    return false;
  }
}
