import 'dart:convert';

import 'package:cookster/modules/followersFollowing/followersListModel/followersListModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/nearBusiness/nearBusinessModel/nearBusinessModel.dart';
import 'package:cookster/modules/landing/landingTabs/notification/notificationModel/notificationModel.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/profileModel.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/simpleUserProfileModel.dart';
import 'package:cookster/modules/liked_videos_screen/liked_videos_model/liked_videos_model.dart';
import 'package:cookster/modules/search/searchModel/b2bCategoryList.dart';
import 'package:cookster/modules/search/searchModel/b2bList.dart';
import 'package:cookster/modules/search/searchModel/b2bUsersListModel.dart';
import 'package:cookster/modules/search/searchModel/searchModel.dart';
import 'package:cookster/modules/visitProfile/visitProfileModel/visitProfileModel.dart';

VideoFeed parseVideoFeed(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return VideoFeed(status: false, videos: []);
  }
  return VideoFeed.fromJson(decoded);
}

SearchResult parseSearchResult(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return SearchResult();
  }
  return SearchResult.fromJson(decoded);
}

SavedVideosModel parseSavedVideos(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return SavedVideosModel();
  }
  return SavedVideosModel.fromJson(decoded);
}

LikedVideosModel parseLikedVideos(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return LikedVideosModel();
  }
  return LikedVideosModel.fromJson(decoded);
}

Map<String, dynamic> parseNotificationsJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return <String, dynamic>{};
}

NotificationModel parseNotificationsFull(String body) {
  final decoded = parseNotificationsJson(body);
  return NotificationModel.fromJson(decoded);
}

SimpleUserDetails parseProfileDetails(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return SimpleUserDetails();
  }
  return SimpleUserDetails.fromJson(decoded);
}

UserDetails parseProfessionalProfileDetails(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return UserDetails();
  }
  return UserDetails.fromJson(decoded);
}

VisitProfile parseVisitProfile(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return VisitProfile();
  }
  return VisitProfile.fromJson(decoded);
}

SocialResponse parseFollowersList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return SocialResponse(status: false, followers: [], following: []);
  }
  return SocialResponse.fromJson(decoded);
}

B2BCategoryModel parseB2BCategories(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return B2BCategoryModel();
  }
  return B2BCategoryModel.fromJson(decoded);
}

B2BList parseB2BList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return B2BList();
  }
  return B2BList.fromJson(decoded);
}

B2BUsersList parseB2BUsers(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return B2BUsersList();
  }
  return B2BUsersList.fromJson(decoded);
}

NearBusinessModel parseNearBusinesses(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return NearBusinessModel();
  }
  return NearBusinessModel.fromJson(decoded);
}

int parseApiCount(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
