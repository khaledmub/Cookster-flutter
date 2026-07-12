import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();
  static const String _dataSaverKey = 'video_data_saver_enabled';
  /// One-time clear of the old Remote Config → prefs latch that forced tier C.
  static const String _dataSaverLatchClearedKey =
      'video_data_saver_rc_latch_cleared_v1';

  final ValueNotifier<bool> dataSaverEnabled = ValueNotifier<bool>(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_dataSaverLatchClearedKey) ?? false)) {
      await prefs.setBool(_dataSaverKey, false);
      await prefs.setBool(_dataSaverLatchClearedKey, true);
      dataSaverEnabled.value = false;
      return;
    }
    dataSaverEnabled.value = prefs.getBool(_dataSaverKey) ?? false;
  }

  Future<void> setDataSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, enabled);
    dataSaverEnabled.value = enabled;
  }
}
