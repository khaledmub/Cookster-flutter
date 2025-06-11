import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/apiClient.dart';
import 'arabicLocale.dart';
import 'englishLocale.dart';

class LocalizationService extends Translations {
  static const Locale english = Locale('en', 'US');
  static const Locale arabic = Locale('ar', 'SA');

  static final locales = [english, arabic];

  @override
  Map<String, Map<String, String>> get keys => {'en_US': en, 'ar_SA': ar};

  Future<void> changeLocale(String langCode) async {
    Locale locale = langCode == 'en' ? english : arabic;
    await Get.updateLocale(locale); // Await locale update
    await ApiClient.updateLanguage(langCode); // Await language update
    print("Locale changed to: $langCode");
  }
}
