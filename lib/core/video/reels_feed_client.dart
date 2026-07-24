import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:flutter/foundation.dart';

/// Shared GET /api/reels client for home tabs and profile reel viewer.
class ReelsFeedClient {
  const ReelsFeedClient._();

  static Future<ReelsFeedResult> fetchPage({
    required bool reset,
    String? nextCursor,
    String feed = 'general',
    String? userId,
    String? videoTypeId,
    String? anchorId,
    String? latitude,
    String? longitude,
    String? city,
    String? country,
  }) async {
    final params = <String, String>{};
    if (!reset) {
      if (nextCursor != null && nextCursor.isNotEmpty) {
        params['cursor'] = nextCursor;
      }
    } else {
      if (feed != 'general') {
        params['feed'] = feed;
      }
      if (userId != null && userId.isNotEmpty) {
        params['user_id'] = userId;
      }
      if (videoTypeId != null && videoTypeId.isNotEmpty) {
        params['video_type'] = videoTypeId;
      }
      if (anchorId != null && anchorId.isNotEmpty) {
        params['anchor_id'] = anchorId;
      }
      if (latitude != null && latitude.isNotEmpty) {
        params['latitude'] = latitude;
      }
      if (longitude != null && longitude.isNotEmpty) {
        params['longitude'] = longitude;
      }
      if (city != null && city.isNotEmpty) {
        params['city'] = city;
      }
      if (country != null && country.isNotEmpty) {
        params['country'] = country;
      }
    }

    var endpoint = EndPoints.reels;
    if (params.isNotEmpty) {
      endpoint = '$endpoint?${Uri(queryParameters: params).query}';
    }

    final response = await ApiClient.getRequest(endpoint);
    if (response.statusCode == 401) {
      return ReelsFeedResult(
        statusCode: 401,
        error: 'Authentication required',
      );
    }
    if (response.statusCode == 404) {
      return ReelsFeedResult(
        statusCode: 404,
        error: 'Not found',
      );
    }
    if (response.statusCode != 200) {
      return ReelsFeedResult(
        statusCode: response.statusCode,
        error: 'Failed to load reels: ${response.statusCode}',
      );
    }
    final parsed = await compute(parseVideoFeed, response.body);
    return ReelsFeedResult(feed: parsed, statusCode: 200);
  }
}

class ReelsFeedResult {
  const ReelsFeedResult({
    this.feed,
    this.statusCode,
    this.error,
  });

  final VideoFeed? feed;
  final int? statusCode;
  final String? error;
}
