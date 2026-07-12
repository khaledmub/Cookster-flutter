import 'dart:io';

import 'package:cookster/core/video/reels_device_capability_store.dart';
import 'package:cookster/core/video/reels_perf.dart';
import 'package:cookster/services/feature_flags/remote_config_service.dart';
import 'package:cookster/services/settings/settings_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  /// Hardware-derived worst-case floor. Measured promotion can never go below
  /// this — a constrained Honor/MTK device must not self-promote to S/A off a
  /// false poster_unmask (Rendered 0/s while the surface never paints).
  ReelsDeviceTier _brandFloor = ReelsDeviceTier.s;

  static int _rankOf(ReelsDeviceTier tier) => switch (tier) {
        ReelsDeviceTier.s => 0,
        ReelsDeviceTier.a => 1,
        ReelsDeviceTier.b => 2,
        ReelsDeviceTier.c => 3,
      };

  static ReelsDeviceTier _tierOfRank(int rank) => switch (rank.clamp(0, 3)) {
        0 => ReelsDeviceTier.s,
        1 => ReelsDeviceTier.a,
        2 => ReelsDeviceTier.b,
        _ => ReelsDeviceTier.c,
      };

  /// Clamp a measured tier so it is never *better* (lower rank) than the floor.
  /// Demotion (higher rank) is always honored.
  ReelsDeviceTier _clampToFloor(ReelsDeviceTier measured) =>
      _tierOfRank(_rankOf(measured) > _rankOf(_brandFloor)
          ? _rankOf(measured)
          : _rankOf(_brandFloor));

  /// Safe default until [ensureInitialized] — attempt Tier S path.
  bool get needsSingleSlotFeedSync => _needsSingleSlotFeed ?? false;

  ReelsDeviceTier get deviceTierSync => _tier ?? ReelsDeviceTier.s;

  bool get feedDualSlotEnabled =>
      !needsSingleSlotFeedSync &&
      RemoteConfigService.instance.reelsDualSlotEnabled;

  int get phoneWarmSlots {
    final rc = RemoteConfigService.instance.reelsPhoneWarmSlots;
    if (rc > 0) {
      return rc.clamp(0, 2);
    }
    // S/A: warm one ahead so the next swipe is already demuxed.
    // B/C: disk-only prefetch — concurrent decode stalls MediaTek surfaces.
    return switch (deviceTierSync) {
      ReelsDeviceTier.s => 2,
      ReelsDeviceTier.a => 1,
      ReelsDeviceTier.b => 0,
      ReelsDeviceTier.c => 0,
    };
  }

  bool get scrollDemuxPrefetchEnabled =>
      RemoteConfigService.instance.reelsScrollDemuxPrefetch &&
      deviceTierSync != ReelsDeviceTier.c;

  bool get needsConstrainedSurfaceRecovery =>
      deviceTierSync == ReelsDeviceTier.b ||
      deviceTierSync == ReelsDeviceTier.c;

  /// Honor/Huawei/MTK (tier b/c): the MediaCodec (`c2.qti.avc.decoder`) path
  /// fails to bind its render surface ("codec was not configured for a new
  /// surface") and enters an endless flush storm (Rendered 0/s, Discarded
  /// 30/s) that kills playback. copy-mode hwdec did not help because media_kit
  /// already decodes to ByteBuffers on Android. Fall back to pure software
  /// decode (libavcodec) which removes MediaCodec from the pipeline entirely.
  ///
  /// Before [ensureInitialized] completes, default Android to software decode
  /// so the first [VideoController] is not created with MediaCodec on Honor.
  bool get preferSoftwareVideoDecode {
    if (!Platform.isAndroid) {
      return false;
    }
    if (_tier != null) {
      return deviceTierSync == ReelsDeviceTier.b ||
          deviceTierSync == ReelsDeviceTier.c;
    }
    return true;
  }

  /// libmpv `hwdec` value for this device. `no` forces software decode on
  /// devices whose MediaCodec surface path is broken; `auto-safe` is the
  /// media_kit default hardware path used on capable devices.
  String get mpvHwdecMode => preferSoftwareVideoDecode ? 'no' : 'auto-safe';

  bool get prefer360ColdOpen => deviceTierSync == ReelsDeviceTier.c;

  bool get suppressScrollDecoderWarm => deviceTierSync == ReelsDeviceTier.b;

  int get singleSlotRecycleAfterOpensSync {
    final tier = deviceTierSync;
    // Recycling forces a cold MediaCodec reopen (~1-2s). Defer during fast
    // scroll ([shouldDeferDecoderRecycle]) and only recycle after many opens.
    if (tier == ReelsDeviceTier.c) {
      return 20;
    }
    if (tier == ReelsDeviceTier.b) {
      return 24;
    }
    return 32;
  }

  /// True during rapid swiping — skip proactive decoder recycle so scroll stays smooth.
  bool get shouldDeferDecoderRecycle {
    final last = _lastSwipeAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last).inMilliseconds < 800;
  }

  bool shouldThrottleDecoderWarm() {
    final now = DateTime.now();
    final last = _lastSwipeAt;
    _lastSwipeAt = now;
    if (last == null) {
      return false;
    }
    return now.difference(last).inMilliseconds < 150;
  }

  /// Call on every reel page change so recycle defer tracks fast scroll bursts.
  void recordSwipe() {
    _lastSwipeAt = DateTime.now();
  }

  Future<void> ensureInitialized() async {
    if (_tier != null) {
      return;
    }
    final appVersion = await _appVersion();
    await ReelsDeviceCapabilityStore.instance.load(
      currentAppVersion: appVersion,
    );
    final brandPrior = await _brandPriorTier();
    _brandFloor = brandPrior;
    await ReelsDeviceCapabilityStore.instance.seedInitialTierIfNeeded(
      brandPrior,
    );
    _tier = await _resolveEffectiveTier();
    _applyFeedModeForTier(_tier!);
    ReelsPerf.emit(
      ReelsPerfEvent(
        name: 'device_init',
        deviceTier: _tier!.name,
        feedMode: _needsSingleSlotFeed! ? 'single_slot' : 'dual_slot',
      ),
    );
  }

  /// Re-read measured tier after promotion/demotion (ignores RC override).
  void refreshFromMeasuredProfile() {
    final override = RemoteConfigService.instance.reelsDeviceTierOverride;
    if (override.isNotEmpty) {
      return;
    }
    if (SettingsService.instance.dataSaverEnabled.value) {
      _tier = ReelsDeviceTier.c;
    } else if (!Platform.isAndroid) {
      _tier = _brandFloor;
    } else {
      final profile = ReelsDeviceCapabilityStore.instance.profile;
      if (!profile.hasCompletedFirstMeasuredOpen) {
        return;
      }
      _tier = _clampToFloor(profile.measuredTier);
    }
    _applyFeedModeForTier(_tier!);
  }

  void _applyFeedModeForTier(ReelsDeviceTier tier) {
    _needsSingleSlotFeed = tier != ReelsDeviceTier.s ||
        !RemoteConfigService.instance.reelsDualSlotEnabled;
  }

  Future<ReelsDeviceTier> _resolveEffectiveTier() async {
    final override = RemoteConfigService.instance.reelsDeviceTierOverride;
    if (override.isNotEmpty) {
      return switch (override) {
        's' => ReelsDeviceTier.s,
        'a' => ReelsDeviceTier.a,
        'b' => ReelsDeviceTier.b,
        'c' => ReelsDeviceTier.c,
        _ => ReelsDeviceTier.s,
      };
    }
    if (SettingsService.instance.dataSaverEnabled.value) {
      return ReelsDeviceTier.c;
    }
    if (!Platform.isAndroid) {
      return _brandFloor;
    }
    final profile = ReelsDeviceCapabilityStore.instance.profile;
    if (!profile.hasCompletedFirstMeasuredOpen) {
      return _brandFloor;
    }
    return _clampToFloor(profile.measuredTier);
  }

  Future<ReelsDeviceTier> _brandPriorTier() async {
    try {
      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final machine = info.utsname.machine.toLowerCase();
        
        // A-series constrained (iPhone 8, SE 2nd/3rd, older iPads)
        const tierAModels = [
          'iphone10,1', 'iphone10,4', // iPhone 8
          'iphone10,2', 'iphone10,5', // iPhone 8 Plus
          'iphone12,8', // SE 2nd Gen
          'iphone14,6', // SE 3rd Gen
          'ipad11,1', 'ipad11,2', // iPad mini 5
        ];
        
        if (tierAModels.contains(machine)) {
          return ReelsDeviceTier.a;
        }
        return ReelsDeviceTier.s;
      }

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

      return ReelsDeviceTier.a;
    } catch (_) {
      return Platform.isIOS ? ReelsDeviceTier.s : ReelsDeviceTier.b;
    }
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  Future<bool> isBatteryLow() async {
    return false;
  }
}
