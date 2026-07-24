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
  var isB2bUsersLoading = false.obs;
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

  /// Only when the user applies the search filter sheet (or picks a city in the
  /// filter flow). Persisted so reopening search keeps the filter active.
  final locationFilterEnabled = false.obs;

  /// Bumped when the user submits the search filter sheet so open B2B lists can
  /// refetch without touching Near Me prefs.
  final locationFilterRevision = 0.obs;

  static const _prefSearchLocationFilterActive = 'searchLocationFilterActive';
  static const _prefSearchCountryId = 'searchCountryId';
  static const _prefSearchCityId = 'searchCityId';
  static const _prefSearchCountry = 'searchCountry';
  static const _prefSearchCity = 'searchCity';

  String? _lastKeywords;
  int? _lastIsGeneral;
  int? _lastIsFollowing;
  String? _lastCity;
  String? _lastCountry;
  int _searchRequestId = 0;
  int _b2bUsersRequestId = 0;

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
    await _loadSavedLocationIds();
    await _restoreLocationFilterEnabledFromPrefs();
  }

  Future<void> _restoreLocationFilterEnabledFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_prefSearchLocationFilterActive) ?? false;
    final hasIds =
        currentCityId.value.isNotEmpty || currentCountryId.value.isNotEmpty;
    locationFilterEnabled.value = active && hasIds;
  }

  /// Enable geo restriction from the search filter sheet or city picker.
  void applyLocationFilterFromSheet() {
    locationFilterEnabled.value =
        currentCountryId.value.isNotEmpty || currentCityId.value.isNotEmpty;
    if (locationFilterEnabled.value) {
      locationFilterRevision.value++;
      unawaited(_persistLocationFilterActive(true));
    }
  }

  /// Disable geo for keyword search without wiping saved country/city labels.
  void resetLocationFilterForNewSearchSession() {
    unawaited(_restoreLocationFilterEnabledFromPrefs());
  }

  Future<void> _persistLocationFilterActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSearchLocationFilterActive, active);
  }

  void clearLocationFilter() {
    locationFilterEnabled.value = false;
    locationFilterRevision.value++;
    unawaited(_persistLocationFilterActive(false));
    currentCityId.value = '';
    currentCountryId.value = '';
    currentCity.value = '';
    currentCountry.value = '';
    unawaited(_clearPersistedLocationFilter());
  }

  /// Keep country filter but drop city (e.g. Riyadh picker id ≠ account city group).
  void clearCityKeepCountry() {
    if (currentCountryId.value.isEmpty) {
      return;
    }
    currentCityId.value = '';
    currentCity.value = '';
    locationFilterEnabled.value = true;
    locationFilterRevision.value++;
    unawaited(saveLocationData());
  }

  Map<String, String> _activeLocationFilterParams() {
    if (!locationFilterEnabled.value) {
      return const {};
    }
    final params = <String, String>{};
    if (currentCityId.value.isNotEmpty) {
      params['city_id'] = currentCityId.value;
    }
    if (currentCountryId.value.isNotEmpty) {
      params['country_id'] = currentCountryId.value;
    }
    return params;
  }

  Future<void> _loadSavedLocationIds() async {
    final prefs = await SharedPreferences.getInstance();
    var countryId = prefs.getString(_prefSearchCountryId) ?? '';
    var cityId = prefs.getString(_prefSearchCityId) ?? '';
    var country = prefs.getString(_prefSearchCountry) ?? '';
    var city = prefs.getString(_prefSearchCity) ?? '';

    // One-time read from legacy shared Near Me keys if search filter was saved
    // before keys were split — never write back to those keys.
    if (countryId.isEmpty &&
        cityId.isEmpty &&
        (prefs.getBool(_prefSearchLocationFilterActive) ?? false)) {
      countryId = prefs.getString('currentCountryId') ?? '';
      cityId = prefs.getString('currentCityId') ?? '';
      country = prefs.getString('currentCountry') ?? '';
      city = prefs.getString('currentCity') ?? '';
    }

    currentCountryId.value = countryId;
    currentCityId.value = cityId;
    currentCountry.value = country;
    currentCity.value = city;
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
    await prefs.setString(_prefSearchCountry, currentCountry.value);
    await prefs.setString(_prefSearchCity, currentCity.value);
    await prefs.setString(_prefSearchCityId, currentCityId.value);
    await prefs.setString(_prefSearchCountryId, currentCountryId.value);
    await prefs.setBool(
      _prefSearchLocationFilterActive,
      locationFilterEnabled.value,
    );
  }

  Future<void> _clearPersistedLocationFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSearchLocationFilterActive, false);
    await prefs.remove(_prefSearchCountryId);
    await prefs.remove(_prefSearchCityId);
    await prefs.remove(_prefSearchCountry);
    await prefs.remove(_prefSearchCity);
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
      }

      requestBody.addAll(_activeLocationFilterParams());

      if (kDebugMode) {
        debugPrint(
          '[Search] type=${type.value} keywords=$keywords '
          'filter=${locationFilterEnabled.value} '
          'city_id=${currentCityId.value} country_id=${currentCountryId.value}',
        );
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
    final requestId = ++_b2bUsersRequestId;
    isB2bUsersLoading.value = true;
    // Drop stale rows immediately so a tighter city filter cannot flash old avatars.
    b2bUsersList.value = B2BUsersList(b2bAccountsList: []);
    filteredB2bUsersList.value = b2bUsersList.value;

    try {
      String endpoint = 'b2b/b2b_accounts_list';
      final params = <String, String>{};
      if (categoryId != null) {
        params['category_id'] = categoryId.toString();
      }
      final resolvedCountry = locationFilterEnabled.value
          ? ((country != null && country.isNotEmpty)
              ? country
              : currentCountryId.value)
          : (country ?? '');
      final resolvedCity = locationFilterEnabled.value
          ? ((city != null && city.isNotEmpty) ? city : currentCityId.value)
          : (city ?? '');
      if (resolvedCountry.isNotEmpty) {
        params['country_id'] = resolvedCountry;
      }
      if (resolvedCity.isNotEmpty) {
        params['city_id'] = resolvedCity;
      }
      if (params.isNotEmpty) {
        endpoint += '?${Uri(queryParameters: params).query}';
      }

      final response = await ApiClient.getRequest(endpoint);

      if (kDebugMode) {
        debugPrint('B2B Users List API Request: ${ApiClient.baseUrl}$endpoint');
        debugPrint('Response Status: ${response.statusCode}');
      }

      if (requestId != _b2bUsersRequestId) {
        return;
      }

      if (response.statusCode == 200) {
        b2bUsersList.value = await compute(parseB2BUsers, response.body);
        if (requestId != _b2bUsersRequestId) {
          return;
        }
        filteredB2bUsersList.value = b2bUsersList.value;
        if (kDebugMode) {
          final count = b2bUsersList.value.b2bAccountsList?.length ?? 0;
          debugPrint(
            '[B2B] results=$count category=$categoryId '
            'country_id=$resolvedCountry city_id=$resolvedCity '
            'filter=${locationFilterEnabled.value}',
          );
        }
      } else {
        Get.snackbar("Error", "Failed to fetch B2B users list");
        b2bUsersList.value = B2BUsersList();
        filteredB2bUsersList.value = B2BUsersList();
      }
    } catch (e) {
      if (requestId != _b2bUsersRequestId) {
        return;
      }
      print('Error fetching B2B users list: $e');
      Get.snackbar("Error", "Something went wrong: $e");
      b2bUsersList.value = B2BUsersList();
      filteredB2bUsersList.value = B2BUsersList();
    } finally {
      if (requestId == _b2bUsersRequestId) {
        isB2bUsersLoading.value = false;
      }
    }
  }

  // B2B users search helpers above — geo helpers removed; keyword search is
  // global unless the user applies the search filter sheet.
}
