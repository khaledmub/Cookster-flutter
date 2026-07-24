import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists upload [feed_hint] (or a client fallback) and sends `pin_video_id`
/// on the first matching reels page. Server pins when rules match.
class ReelsFeedPinStore {
  ReelsFeedPinStore._();

  static final ReelsFeedPinStore instance = ReelsFeedPinStore._();

  static const _prefPinVideoId = 'reelsFeedPinVideoId';
  static const _prefPinExpiresAt = 'reelsFeedPinExpiresAt';
  static const _prefPinCountry = 'reelsFeedPinCountry';
  static const _prefPinCity = 'reelsFeedPinCity';
  static const _prefPinSortBy = 'reelsFeedPinSortBy';

  String? _pinVideoId;
  String? _countryId;
  String? _cityId;
  String? _sortBy;
  DateTime? _expiresAt;

  bool get hasPendingPin =>
      (_pinVideoId?.isNotEmpty ?? false) && !_isExpired();

  Future<void> restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _pinVideoId = prefs.getString(_prefPinVideoId);
    _countryId = prefs.getString(_prefPinCountry);
    _cityId = prefs.getString(_prefPinCity);
    _sortBy = prefs.getString(_prefPinSortBy);
    final expiresRaw = prefs.getString(_prefPinExpiresAt);
    _expiresAt =
        expiresRaw != null && expiresRaw.isNotEmpty
            ? DateTime.tryParse(expiresRaw)
            : null;
    if (_isExpired()) {
      await clearPin();
    }
  }

  /// Saves pin from upload [feed_hint], or falls back to upload location ids.
  Future<void> saveFromUpload({
    required String responseBody,
    required String? videoId,
    required String countryId,
    required String cityId,
  }) async {
    final savedFromHint = await _trySaveFromFeedHint(responseBody);
    if (savedFromHint || hasPendingPin) {
      return;
    }
    final id = videoId?.trim();
    if (id == null || id.isEmpty || countryId.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[FeedPin] no feed_hint in upload response and no video id fallback',
        );
      }
      return;
    }
    await _persistPin(
      videoId: id,
      countryId: countryId.trim(),
      cityId: cityId.trim(),
      sortBy: 'newest',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
      source: 'fallback',
    );
  }

  Future<bool> _trySaveFromFeedHint(String responseBody) async {
    try {
      final data = jsonDecode(responseBody);
      if (data is! Map<String, dynamic>) {
        return false;
      }
      final hint = data['feed_hint'];
      if (hint is! Map<String, dynamic>) {
        return false;
      }
      final query = hint['reels_query'];
      if (query is! Map<String, dynamic>) {
        return false;
      }
      final pinId = query['pin_video_id']?.toString().trim();
      if (pinId == null || pinId.isEmpty) {
        return false;
      }

      final expiresRaw = hint['pin_expires_at']?.toString();
      final expires =
          expiresRaw != null && expiresRaw.isNotEmpty
              ? DateTime.tryParse(expiresRaw)
              : null;

      await _persistPin(
        videoId: pinId,
        countryId: query['country']?.toString() ?? '',
        cityId: query['city']?.toString() ?? '',
        sortBy: query['sort_by']?.toString() ?? 'newest',
        expiresAt: expires ?? DateTime.now().toUtc().add(const Duration(hours: 24)),
        source: 'feed_hint',
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedPin] feed_hint parse failed: $e');
      }
      return false;
    }
  }

  Future<void> _persistPin({
    required String videoId,
    required String countryId,
    required String cityId,
    required String sortBy,
    required DateTime? expiresAt,
    required String source,
  }) async {
    _pinVideoId = videoId;
    _countryId = countryId;
    _cityId = cityId;
    _sortBy = sortBy;
    _expiresAt = expiresAt;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPinVideoId, videoId);
    await prefs.setString(_prefPinCountry, countryId);
    await prefs.setString(_prefPinCity, cityId);
    await prefs.setString(_prefPinSortBy, sortBy);
    if (expiresAt != null) {
      await prefs.setString(
        _prefPinExpiresAt,
        expiresAt.toUtc().toIso8601String(),
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[FeedPin] saved ($source) pin=$videoId country=$countryId '
        'city=$cityId sort=$sortBy expires=$expiresAt',
      );
    }
  }

  bool _isExpired() {
    final expires = _expiresAt;
    if (expires == null) {
      return false;
    }
    return DateTime.now().isAfter(expires);
  }

  /// Returns `pin_video_id` for the first page when hint matches the request.
  String? pinVideoIdForFirstPage({
    required String feedMode,
    String? requestCountry,
    String? requestCity,
    required String requestSortBy,
  }) {
    if (feedMode == 'following') {
      return null;
    }
    final pinId = _pinVideoId;
    if (pinId == null || pinId.isEmpty || _isExpired()) {
      return null;
    }
    final hintSort = _sortBy ?? 'newest';
    if (hintSort.isNotEmpty && hintSort != requestSortBy) {
      return null;
    }

    if (feedMode == 'general') {
      if (requestCountry == null ||
          requestCountry.isEmpty ||
          _countryId == null ||
          _countryId!.isEmpty ||
          requestCountry != _countryId) {
        return null;
      }
      final filterCity = requestCity ?? '';
      final hintCity = _cityId ?? '';
      if (filterCity.isNotEmpty &&
          hintCity.isNotEmpty &&
          filterCity != hintCity) {
        return null;
      }
    } else if (feedMode == 'near_me' &&
        _countryId != null &&
        _countryId!.isNotEmpty) {
      // Upload tagged with country/city is meant for filtered General — do not
      // consume the pin on the default Near Me tab before the user opens General.
      return null;
    }

    return pinId;
  }

  Future<void> clearPin() async {
    _pinVideoId = null;
    _countryId = null;
    _cityId = null;
    _sortBy = null;
    _expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPinVideoId);
    await prefs.remove(_prefPinExpiresAt);
    await prefs.remove(_prefPinCountry);
    await prefs.remove(_prefPinCity);
    await prefs.remove(_prefPinSortBy);
  }
}
