import 'dart:async';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/apiClient.dart';
import '../searchModel/b2bCategoryList.dart';
import '../searchModel/b2bList.dart';
import '../searchModel/b2bUsersListModel.dart';
import '../searchModel/searchModel.dart';

class UserSearchController extends GetxController {
  static const Set<int> videoSearchTypes = {1, 2, 3, 4};
  static const int listPageSize = 30;

  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var isCityLoading = false.obs;
  var searchResult = SearchResult().obs;
  var type = 6.obs;
  var selectedType = 0.obs;
  var hasSearched = false.obs;
  var currentCity = "".obs;
  var currentCityId = "".obs;
  var currentCountry = "".obs;
  var currentCountryId = "".obs;
  var b2bList = B2BList().obs;
  var filteredB2bList = B2BList().obs;
  var b2bCategories = B2BCategoryModel().obs;
  var filteredB2bCategories = B2BCategoryModel().obs;
  var b2bUsersList = B2BUsersList().obs; // Add observable for B2BUsersList
  var filteredB2bUsersList =
      B2BUsersList().obs; // Add observable for filtered B2BUsersList


  RxList<String> recentSearches = <String>[].obs;

  /// Only when the user applies the search filter sheet. Do NOT auto-apply
  /// home GPS / Near Me prefs — that forced every keyword search into the
  /// nearest city and made every query look like the same 1 local reel.
  final locationFilterEnabled = false.obs;

  String? _lastKeywords;
  int? _lastIsGeneral;
  int? _lastIsFollowing;
  String? _lastCity;
  String? _lastCountry;
  int _searchRequestId = 0;

  bool get canLoadMoreVideos =>
      videoSearchTypes.contains(type.value) &&
      (searchResult.value.meta?.hasMore ?? false);

  @override
  void onClose() {
    recentSearches.clear();
    super.onClose();
  }

  @override
  void onInit() async {
    super.onInit();
    await loadRecentSearches();
    // Load saved country/city names for the filter UI only — never auto-enable
    // geo restriction on keyword search (see [locationFilterEnabled]).
    await _loadSavedLocationIds();
  }

  /// Enable/disable geo restriction from the search filter sheet.
  void applyLocationFilterFromSheet() {
    locationFilterEnabled.value =
        currentCountryId.value.isNotEmpty || currentCityId.value.isNotEmpty;
  }

  void clearLocationFilter() {
    locationFilterEnabled.value = false;
    currentCityId.value = '';
    currentCountryId.value = '';
    currentCity.value = '';
    currentCountry.value = '';
  }

  Future<void> _loadSavedLocationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final countryId = prefs.getString('currentCountryId') ?? '';
    final cityId = prefs.getString('currentCityId') ?? '';
    final country = prefs.getString('currentCountry') ?? '';
    final city = prefs.getString('currentCity') ?? '';
    if (countryId.isNotEmpty) {
      currentCountryId.value = countryId;
    }
    if (cityId.isNotEmpty) {
      currentCityId.value = cityId;
    }
    if (country.isNotEmpty) {
      currentCountry.value = country;
    }
    if (city.isNotEmpty) {
      currentCity.value = city;
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
    await prefs.setString('currentCityId', currentCityId.value);
    await prefs.setString('currentCountryId', currentCountryId.value);
  }

  Future<void> refetchWithCurrentFilters() async {
    final keywords = _lastKeywords;
    if (keywords == null || keywords.isEmpty) {
      return;
    }
    await fetchSearchResults(
      keywords,
      city: _lastCity,
      country: _lastCountry,
      isGeneral: _lastIsGeneral,
      isFollowing: _lastIsFollowing,
      reset: true,
    );
  }

  // Fetch search results
  Future<void> fetchSearchResults(
    String keywords, {
    String? city,
    String? country,
    int? isGeneral = 0,
    int? isFollowing = 0,
    bool reset = true,
  }) async {
    if (keywords.isEmpty) {
      clearSearchResults();
      return;
    }

    if (reset) {
      isLoading.value = true;
    } else {
      if (isLoadingMore.value) return;
      if (!canLoadMoreVideos) return;
      isLoadingMore.value = true;
    }
    hasSearched.value = true;
    final requestId = reset ? ++_searchRequestId : _searchRequestId;

    try {
      if (reset && keywords.isNotEmpty) {
        await _saveSearchQuery(keywords);
      }

      final page = reset
          ? 1
          : (searchResult.value.meta?.page ?? 1) + 1;
      final requestBody = <String, dynamic>{};

      if (videoSearchTypes.contains(type.value)) {
        requestBody['paginate'] = 1;
        requestBody['per_page'] = listPageSize;
        if (reset) {
          requestBody['page'] = 1;
        } else {
          final meta = searchResult.value.meta;
          if (meta != null) {
            requestBody.addAll(meta.toRequestPayload());
          } else {
            requestBody['page'] = page;
          }
        }
      }

      if (isFollowing == 1) {
        requestBody['is_following'] = isFollowing;
        requestBody['type'] = type.value;
        requestBody['keywords'] = keywords;
      } else {
        requestBody['type'] = type.value;
        requestBody['keywords'] = keywords;

        // Geo only when the user applied the search filter — never from home GPS.
        // Sending lat/lng makes the backend call nearestCityId() and collapse
        // every query to the same local reel.
        if (locationFilterEnabled.value) {
          if (currentCityId.value.isNotEmpty) {
            requestBody['city'] = currentCityId.value;
          }
          if (currentCountryId.value.isNotEmpty) {
            requestBody['country'] = currentCountryId.value;
          }
        }
      }

      final response = await ApiClient.postRequest(
        EndPoints.search,
        requestBody,
      );

      if (response.statusCode == 200) {
        if (reset && requestId != _searchRequestId) {
          return;
        }
        final parsed = await compute(parseSearchResult, response.body);
        if (reset && requestId != _searchRequestId) {
          return;
        }

        if (reset) {
          searchResult.value = parsed;
        } else {
          final current = searchResult.value;
          current.meta = parsed.meta;
          final incoming = parsed.videos ?? [];
          if (incoming.isNotEmpty) {
            current.videos ??= [];
            final existingIds = current.videos!
                .map((v) => v.id?.toString())
                .whereType<String>()
                .toSet();
            current.videos!.addAll(
              incoming.where((v) {
                final id = v.id?.toString();
                return id != null && !existingIds.contains(id);
              }),
            );
          } else if (current.meta != null) {
            current.meta!.hasMore = false;
          }
          searchResult.refresh();
        }

        _lastKeywords = keywords;
        _lastIsGeneral = isGeneral;
        _lastIsFollowing = isFollowing;
        _lastCity = city;
        _lastCountry = country;
      } else {
        Get.snackbar('Error', 'Failed to fetch results');
      }
    } catch (e) {
      Get.snackbar('Error', 'Something went wrong: $e');
    } finally {
      if (reset) {
        if (requestId == _searchRequestId) {
          isLoading.value = false;
        }
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> fetchMoreSearchResults() async {
    if (_lastKeywords == null || _lastKeywords!.isEmpty) return;
    await fetchSearchResults(
      _lastKeywords!,
      city: _lastCity,
      country: _lastCountry,
      isGeneral: _lastIsGeneral,
      isFollowing: _lastIsFollowing,
      reset: false,
    );
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
                (account) {
                  final queryLower = query.toLowerCase();
                  final name = account.name?.toLowerCase() ?? '';
                  final handle = account.userName?.toLowerCase() ?? '';
                  return name.contains(queryLower) ||
                      handle.contains(queryLower);
                },
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
        b2bCategories.value = await compute(parseB2BCategories, response.body);
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
        b2bList.value = await compute(parseB2BList, response.body);
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
      String endpoint = 'b2b/b2b_accounts_list';
      final params = <String, String>{};
      if (categoryId != null) {
        params['category_id'] = categoryId.toString();
      }
      final resolvedCountry =
          (country != null && country.isNotEmpty) ? country : currentCountryId.value;
      final resolvedCity =
          (city != null && city.isNotEmpty) ? city : currentCityId.value;
      if (resolvedCountry.isNotEmpty) {
        params['country'] = resolvedCountry;
      }
      if (resolvedCity.isNotEmpty) {
        params['city'] = resolvedCity;
      }
      if (params.isNotEmpty) {
        endpoint += '?${Uri(queryParameters: params).query}';
      }

      final response = await ApiClient.getRequest(endpoint);

      print('B2B Users List API Request: ${ApiClient.baseUrl}$endpoint');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        b2bUsersList.value = await compute(parseB2BUsers, response.body);
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

  // B2B users search helpers above — geo helpers removed; keyword search is
  // global unless the user applies the search filter sheet.
}
