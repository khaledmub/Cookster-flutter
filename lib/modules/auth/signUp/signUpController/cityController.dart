import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../../services/apiClient.dart';
import '../registrationSettingsModel/cities.dart';
class CityController extends GetxController {
  // Observable variables
  var isLoading = false.obs; // To show loading state
  var cityList = <Cities>[].obs; // List of cities from API
  var selectedCityId = ''.obs; // Selected city ID
  var selectedCityName = ''.obs; // Selected city name

  // Method to fetch cities based on country_id
  Future<void> fetchCities(int countryId) async {
    try {
      // Set loading to true
      isLoading(true);

      // Construct the endpoint (adjust based on your API)
      String endpoint = '${EndPoints.getCity}?country_id=$countryId'; // Example endpoint

      // Make GET request using ApiClient
      http.Response response = await ApiClient.getRequest(endpoint);



      print("Hello I am there");
      print(response.body);

      // Check response status
      if (response.statusCode == 200) {
        // Parse JSON response
        City cityData = City.fromJson(jsonDecode(response.body));

        // Check if status is true and cities are available
        if (cityData.status == true && cityData.cities != null) {
          // Update cityList with fetched cities
          cityList.assignAll(cityData.cities!);
        } else {
          // Handle empty or failed response
          cityList.clear();
          Get.snackbar('Error', 'No cities found for this country');
        }
      } else {
        // Handle API error
        Get.snackbar('Error', 'Failed to fetch cities: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exceptions
      Get.snackbar('Error', 'An error occurred: $e');
    } finally {
      // Set loading to false
      isLoading(false);
    }
  }

  // Method to handle city selection
  void selectCity(Cities? city) {
    if (city != null) {
      selectedCityId.value = city.id.toString();
      selectedCityName.value = city.name ?? '';
    } else {
      selectedCityId.value = '';
      selectedCityName.value = '';
    }
  }

  // Clear selections
  void clearSelection() {
    selectedCityId.value = '';
    selectedCityName.value = '';
    cityList.clear();
  }
}