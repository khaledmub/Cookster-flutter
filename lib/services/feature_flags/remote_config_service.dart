import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 15),
      ),
    );
    await _remoteConfig.setDefaults(const {
      'reels_preload_enabled': true,
      'reels_preload_limit_wifi': 7,
      // Kept for Remote Config compat — app treats mobile like Wi-Fi and
      // reads [preloadLimitWifi] for both.
      'reels_preload_limit_mobile': 7,
      'reels_data_saver_default': false,
      'reels_device_tier_override': '',
      'reels_dual_slot_enabled': true,
      'reels_phone_warm_slots': 0,
      'reels_dual_tier_preload': true,
      'reels_360_first_uncached': true,
      'reels_scroll_demux_prefetch': true,
      'reels_hls_wifi_enabled': false,
      'reels_fast_frame_gate': true,
      'reels_cache_max_mb_phone': 500,
      'reels_cache_max_mb_tablet': 1024,
    });
    await _remoteConfig.activate();
    unawaited(_fetchInBackground());
  }

  Future<void> _fetchInBackground() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {}
  }

  bool get preloadEnabled => _remoteConfig.getBool('reels_preload_enabled');
  int get preloadLimitWifi => _remoteConfig.getInt('reels_preload_limit_wifi');
  /// Alias of [preloadLimitWifi] — mobile is not throttled separately.
  int get preloadLimitMobile => preloadLimitWifi;
  bool get dataSaverDefault =>
      _remoteConfig.getBool('reels_data_saver_default');

  String get reelsDeviceTierOverride =>
      _remoteConfig.getString('reels_device_tier_override').trim().toLowerCase();

  bool get reelsDualSlotEnabled =>
      _remoteConfig.getBool('reels_dual_slot_enabled');

  int get reelsPhoneWarmSlots => _remoteConfig.getInt('reels_phone_warm_slots');

  bool get reelsDualTierPreload =>
      _remoteConfig.getBool('reels_dual_tier_preload');

  bool get reels360FirstUncached =>
      _remoteConfig.getBool('reels_360_first_uncached');

  bool get reelsScrollDemuxPrefetch =>
      _remoteConfig.getBool('reels_scroll_demux_prefetch');

  bool get reelsHlsWifiEnabled =>
      _remoteConfig.getBool('reels_hls_wifi_enabled');

  bool get reelsFastFrameGate =>
      _remoteConfig.getBool('reels_fast_frame_gate');

  int get reelsCacheMaxMbPhone =>
      _remoteConfig.getInt('reels_cache_max_mb_phone');

  int get reelsCacheMaxMbTablet =>
      _remoteConfig.getInt('reels_cache_max_mb_tablet');
}
