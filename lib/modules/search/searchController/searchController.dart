import 'dart:async';
import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/apiClient.dart';
import '../searchModel/b2bCategoryList.dart';
import '../searchModel/b2bList.dart';
import '../searchModel/b2bUsersListModel.dart';
import '../searchModel/searchModel.dart';

class UserSearchController extends GetxController {
  var isLoading = false.obs;
  var searchResult = SearchResult().obs;
  var type = 1.obs;
  var hasSearched = false.obs;
  var currentCity = "".obs;
  var currentCityId = "".obs;
  var currentCountry = "".obs;
  var b2bList = B2BList().obs;
  var filteredB2bList = B2BList().obs;
  var b2bCategories = B2BCategoryModel().obs;
  var filteredB2bCategories = B2BCategoryModel().obs;
  var b2bUsersList = B2BUsersList().obs; // Add observable for B2BUsersList
  var filteredB2bUsersList =
      B2BUsersList().obs; // Add observable for filtered B2BUsersList
  RxList<String> recentSearches = <String>[].obs;

  final HomeController homeController = Get.find();

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
    filteredB2bList.value = b2bList.value;
    filteredB2bCategories.value = b2bCategories.value;
    filteredB2bUsersList.value =
        b2bUsersList.value; // Clear filtered B2B users list
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

  Future<void> saveLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentCountry', currentCountry.value);
    await prefs.setString('currentCity', currentCity.value);
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
      String? finalCity = city ?? currentCity.value;
      String? finalCountry = country ?? currentCountry.value;

      if (keywords.isNotEmpty) {
        await _saveSearchQuery(keywords);
        print(
          "Searching for: $keywords in city: $finalCity, country: $finalCountry, isGeneral: $isGeneral, isFollowing: $isFollowing",
        );
      }

      final requestBody = <String, dynamic>{};

      if (isFollowing == 1) {
        requestBody["is_following"] = isFollowing;
        requestBody["type"] = type.value;
        requestBody["keywords"] = keywords;
      } else {
        requestBody["type"] = type.value;
        requestBody["keywords"] = keywords;

        if (isGeneral != 1 || city != null || country != null) {
          // Always add latitude and longitude
          requestBody['latitude'] =
              homeController.latitude.value; // Use .value to get the raw value
          requestBody['longitude'] =
              homeController.longitude.value; // Use .value to get the raw value

          // Add city and country only if currentCityId is not null or empty
          if (currentCityId.value != null && currentCityId.value.isNotEmpty) {
            requestBody['city'] = currentCityId.value;
            requestBody['country'] = finalCountry;
          }

          // Print the request body
          print('Request body: $requestBody');
        }
      }

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

  // Search B2B categories by name
  void searchB2BCategories(String query) {
    final trimmedQuery = query.trim();
    final source = b2bCategories.value;

    if (trimmedQuery.isEmpty || source.businessTypes?.values == null) {
      filteredB2bCategories.value = source;
      return;
    }

    final filteredValues =
        source.businessTypes!.values!
            .where(
              (item) =>
                  item.name?.toLowerCase().contains(
                    trimmedQuery.toLowerCase(),
                  ) ??
                  false,
            )
            .toList();

    filteredB2bCategories.value = B2BCategoryModel(
      status: source.status,
      businessTypes: BusinessTypes(
        key: source.businessTypes!.key,
        values: filteredValues,
      ),
    );

    _saveSearchQuery(trimmedQuery);
  }

  // Search B2B users by name (new method for B2BUsersList)
  void searchB2BUsers(String query) {
    print(query);
    if (query.isEmpty) {
      filteredB2bUsersList.value = b2bUsersList.value;
      return;
    }

    B2BUsersList filtered = B2BUsersList(
      status: b2bUsersList.value.status,
      b2bAccountsList: [],
    );

    if (b2bUsersList.value.b2bAccountsList != null) {
      filtered.b2bAccountsList =
          b2bUsersList.value.b2bAccountsList!
              .where(
                (account) =>
                    account.name != null &&
                    account.name!.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }

    filteredB2bUsersList.value = filtered;

    if (query.isNotEmpty) {
      _saveSearchQuery(query);
    }
  }

  // Fetch B2B categories
  Future<void> fetchB2BCategories() async {
    isLoading.value = true;

    try {
      final response = await ApiClient.getRequest(EndPoints.getB2BCategoryList);

      print(
        'B2B Categories API Request: ${ApiClient.baseUrl}${EndPoints.getB2BCategoryList}',
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        b2bCategories.value = B2BCategoryModel.fromJson(jsonResponse);
        filteredB2bCategories.value = b2bCategories.value;
      } else {
        Get.snackbar("Error", "Failed to fetch B2B categories");
        b2bCategories.value = B2BCategoryModel();
        filteredB2bCategories.value = B2BCategoryModel();
      }
    } catch (e) {
      print('Error fetching B2B categories: $e');
      Get.snackbar("Error", "Something went wrong: $e");
      b2bCategories.value = B2BCategoryModel();
      filteredB2bCategories.value = B2BCategoryModel();
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch B2B list with optional category ID
  Future<void> fetchB2BList({int? categoryId}) async {
    isLoading.value = true;

    try {
      String endpoint = EndPoints.getB2BList;
      if (categoryId != null) {
        endpoint += '?category_id=$categoryId';
      }

      final response = await ApiClient.getRequest(endpoint);

      print('B2B List API Request: ${ApiClient.baseUrl}$endpoint');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        b2bList.value = B2BList.fromJson(jsonResponse);
        filteredB2bList.value = b2bList.value;
      } else {
        Get.snackbar("Error", "Failed to fetch B2B list");
        b2bList.value = B2BList();
        filteredB2bList.value = B2BList();
      }
    } catch (e) {
      print('Error fetching B2B list: $e');
      Get.snackbar("Error", "Something went wrong: $e");
      b2bList.value = B2BList();
      filteredB2bList.value = B2BList();
    } finally {
      isLoading.value = false;
    }
  }

  // New method to fetch B2B users list with optional category ID
  Future<void> fetchB2BUsersList({
    int? categoryId,
    String? city,
    String? country,
  }) async {
    isLoading.value = true;

    try {
      String endpoint = 'b2b/b2b_accounts_list'; // Base endpoint
      if (categoryId != null) {
        endpoint +=
            '?category_id=${categoryId}&country=${country}&city=${city}';
      }

      final response = await ApiClient.getRequest(endpoint);

      print('B2B Users List API Request: ${ApiClient.baseUrl}$endpoint');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        b2bUsersList.value = B2BUsersList.fromJson(jsonResponse);
        filteredB2bUsersList.value = b2bUsersList.value;
      } else {
        Get.snackbar("Error", "Failed to fetch B2B users list");
        b2bUsersList.value = B2BUsersList();
        filteredB2bUsersList.value = B2BUsersList();
      }
    } catch (e) {
      print('Error fetching B2B users list: $e');
      Get.snackbar("Error", "Something went wrong: $e");
      b2bUsersList.value = B2BUsersList();
      filteredB2bUsersList.value = B2BUsersList();
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
