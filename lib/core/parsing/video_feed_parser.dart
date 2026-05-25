import 'dart:convert';

import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';

VideoFeed parseVideoFeed(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return VideoFeed(status: false, videos: []);
  }
  return VideoFeed.fromJson(decoded);
}
