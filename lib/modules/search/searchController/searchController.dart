import 'dart:async';
import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/apiClient.dart';
import '../searchModel/searchModel.dart';

class UserSearchController extends GetxController {
  var isLoading = false.obs;
  var searchResult = SearchResult().obs;
  var type = 1.obs;
  var hasSearched = false.obs;
  var currentCity = "".obs;
  var currentCountry = "".obs;

  RxList<String> recentSearches = <String>[].obs;

  @override
  void onInit() async {
    super.onInit();
    await loadRecentSearches();
    try {
      Position position = await _getCurrentPosition();
      Map<String, String?> locationData =
          await _getCityAndCountryFromCoordinates(
            position.latitude,
            position.longitude,
          );
      String? city = locationData['city'];
      String? country = locationData['country'];
      if (city != null && city.isNotEmpty) {
        currentCity.value = city;
      } else {
        currentCity.value = "Unknown";
      }
      if (country != null && country.isNotEmpty) {
        currentCountry.value = country;
      } else {
        currentCountry.value = "Unknown";
      }
    } catch (e) {
      print("Error setting initial location: $e");
      currentCity.value = "Unknown";
      currentCountry.value = "Unknown";
    }
  }

  // Clear search results
  void clearSearchResults() {
    searchResult.value = SearchResult();
    hasSearched.value = false;
  }

  // Load recent searches from SharedPreferences
  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_searches') ?? [];
    recentSearches.assignAll(searches);
  }

  // Save recent searches to SharedPreferences
  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', recentSearches.toList());
  }

  // Add a new search query and save to SharedPreferences
  Future<void> _saveSearchQuery(String query) async {
    if (query.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_searches') ?? [];

    searches.remove(query);
    searches.insert(0, query);

    if (searches.length > 5) {
      searches = searches.sublist(0, 5);
    }

    await prefs.setStringList('recent_searches', searches);
    recentSearches.assignAll(searches);
  }

  // Remove a search query and save to SharedPreferences
  Future<void> removeSearchQuery(String query) async {
    recentSearches.remove(query);
    await _saveRecentSearches();
  }

  // Fetch search results
  Future<void> fetchSearchResults(
      String keywords, {
        String? city,
        String? country,
        int? isGeneral = 0,
        int? isFollowing = 0,
      }) async {
    if (keywords.isEmpty) {
      clearSearchResults();
      return;
    }

    isLoading.value = true;
    hasSearched.value = true;

    try {
      // Step 1: Get city and country - use provided values, else fall back to current values
      String? finalCity = city ?? currentCity.value;
      String? finalCountry = country ?? currentCountry.value;

      if (keywords.isNotEmpty) {
        await _saveSearchQuery(keywords);
        print(
          "Searching for: $keywords in city: $finalCity, country: $finalCountry, isGeneral: $isGeneral, isFollowing: $isFollowing",
        );
      }

      print(isGeneral);

      // Step 2: Prepare API request body
      final requestBody = <String, dynamic>{};

      if (isFollowing == 1) {
        // If isFollowing is 1, only include is_following in the request body
        requestBody["is_following"] = isFollowing;
        requestBody["type"] = type.value;

        requestBody["keywords"] = keywords;
      } else {
        // Otherwise, include the usual fields
        requestBody["type"] = type.value;
        requestBody["keywords"] = keywords;

        // Only include city and country if isGeneral is 0 or if user explicitly provides city/country
        if (isGeneral != 1 || city != null || country != null) {
          requestBody["city"] = finalCity.isNotEmpty ? finalCity : "Unknown";
          requestBody["country"] =
          finalCountry.isNotEmpty ? finalCountry : "Unknown";
        }
      }

      // Step 3: Make API request
      final response = await ApiClient.postRequest(
        EndPoints.search,
        requestBody,
      );

      print(jsonEncode(requestBody));
      print(type.value);
      print(response.body);
      print(response.statusCode);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        searchResult.value = SearchResult.fromJson(jsonResponse);
      } else {
        Get.snackbar("Error", "Failed to fetch results");
      }
    } catch (e) {
      print(e);
      Get.snackbar("Error", "Something went wrong: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Helper function to get current position
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Helper function to get city and country from coordinates
  Future<Map<String, String?>> _getCityAndCountryFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        return {
          'city': placemarks.first.locality,
          'country': placemarks.first.country,
        };
      }
      return {'city': null, 'country': null};
    } catch (e) {
      print("Error getting location data: $e");
      return {'city': null, 'country': null};
    }
  }
}
