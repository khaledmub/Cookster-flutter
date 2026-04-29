import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();
  static const String _dataSaverKey = 'video_data_saver_enabled';

  final ValueNotifier<bool> dataSaverEnabled = ValueNotifier<bool>(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    dataSaverEnabled.value = prefs.getBool(_dataSaverKey) ?? false;
  }

  Future<void> setDataSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSaverKey, enabled);
    dataSaverEnabled.value = enabled;
  }
}
