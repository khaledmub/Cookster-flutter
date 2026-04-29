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
      'reels_preload_limit_wifi': 2,
      'reels_preload_limit_mobile': 1,
      'reels_data_saver_default': false,
    });
    await _remoteConfig.fetchAndActivate();
  }

  bool get preloadEnabled => _remoteConfig.getBool('reels_preload_enabled');
  int get preloadLimitWifi => _remoteConfig.getInt('reels_preload_limit_wifi');
  int get preloadLimitMobile =>
      _remoteConfig.getInt('reels_preload_limit_mobile');
  bool get dataSaverDefault =>
      _remoteConfig.getBool('reels_data_saver_default');
}
