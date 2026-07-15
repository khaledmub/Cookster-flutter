import 'dart:async';
import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../../services/apiClient.dart';
import '../registrationSettingsModel/cities.dart';

class CityController extends GetxController {
  var isLoading = false.obs;
  var cityList = <Cities>[].obs;
  var selectedCityId = ''.obs;
  var selectedCityName = ''.obs;

  /// Last country id whose cities are currently in [cityList].
  int? _loadedCountryId;
  int _fetchGeneration = 0;

  int? get loadedCountryId => _loadedCountryId;

  /// Fetches cities for [countryId], ignoring stale responses when the user
  /// switches country mid-flight (race that caused lag / wrong city lists).
  Future<void> fetchCities(
    int countryId, {
    String? acceptLanguage,
  }) async {
    final generation = ++_fetchGeneration;
    try {
      isLoading(true);
      if (_loadedCountryId != countryId) {
        cityList.clear();
      }

      final endpoint = '${EndPoints.getCity}?country_id=$countryId';
      final http.Response response = await ApiClient.getRequest(
        endpoint,
        acceptLanguage: acceptLanguage,
      );

      if (generation != _fetchGeneration) {
        return;
      }

      if (response.statusCode == 200) {
        final City cityData = City.fromJson(jsonDecode(response.body));
        if (cityData.status == true && cityData.cities != null) {
          cityList.assignAll(cityData.cities!);
          _loadedCountryId = countryId;
        } else {
          cityList.clear();
          _loadedCountryId = null;
        }
      } else {
        cityList.clear();
        _loadedCountryId = null;
      }
    } catch (e) {
      if (generation == _fetchGeneration) {
        cityList.clear();
        _loadedCountryId = null;
      }
    } finally {
      if (generation == _fetchGeneration) {
        isLoading(false);
      }
    }
  }

  void selectCity(Cities? city) {
    if (city != null) {
      selectedCityId.value = city.id.toString();
      selectedCityName.value = city.name ?? '';
    } else {
      selectedCityId.value = '';
      selectedCityName.value = '';
    }
  }

  void clearSelection() {
    selectedCityId.value = '';
    selectedCityName.value = '';
    cityList.clear();
    _loadedCountryId = null;
  }
}
