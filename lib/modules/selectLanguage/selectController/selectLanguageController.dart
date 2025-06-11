import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../locale/localizationServices.dart';
import '../../../services/apiClient.dart';

class LanguageController extends GetxController {
  var selectedLanguage = 'English'.obs; // Stores the applied language
  var selectedTempLanguage = 'English'.obs; // Stores the temporary selection

  @override
  void onInit() {
    super.onInit();
    loadLanguage(); // Load saved language on initialization
  }

  void selectLanguage(String lang) {
    selectedTempLanguage.value = lang;
  }

  Future<void> applyLanguageChange() async {
    selectedLanguage.value = selectedTempLanguage.value;
    String languageCode = selectedLanguage.value == "English" ? "en" : "ar";

    // Update locale for UI translations
    LocalizationService().changeLocale(languageCode);

    // Save to SharedPreferences for LanguageController
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', selectedLanguage.value);

    print("PRINTING THE SELECTED LANGUAGE CODE: $languageCode"); // Updated print statement

    // Update ApiClient language
    await ApiClient.updateLanguage(languageCode);
  }

  Future<void> loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedLang = prefs.getString('selectedLanguage');

    print("PRINTING THE SAVED LANGUAGE: $savedLang");

    if (savedLang != null) {
      selectedLanguage.value = savedLang;
      selectedTempLanguage.value = savedLang;
      String languageCode = savedLang == "English" ? "en" : "ar";
      LocalizationService().changeLocale(languageCode);
      // Ensure ApiClient uses the saved language
      await ApiClient.updateLanguage(languageCode);
    }
  }
}
