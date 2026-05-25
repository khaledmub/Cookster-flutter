import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/modules/visitProfile/visitProfileModel/visitProfileModel.dart'
    as visit_profile;

import 'video_sources.dart';

class FeedMeta {
  int? page;
  int? perPage;
  bool hasMore;
  String? nextCursor;
  int? feedSeed;
  int? premiumIndex;
  int? sponsoredIndex;
  int? patternIndex;
  int? normalOffset;

  FeedMeta({
    this.page,
    this.perPage,
    this.hasMore = false,
    this.nextCursor,
    this.feedSeed,
    this.premiumIndex,
    this.sponsoredIndex,
    this.patternIndex,
    this.normalOffset,
  });

  factory FeedMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return FeedMeta();
    }
    return FeedMeta(
      page: json['page'] as int?,
      perPage: json['per_page'] as int?,
      hasMore: json['has_more'] == true,
      nextCursor: json['next_cursor'] as String?,
      feedSeed: json['feed_seed'] as int?,
      premiumIndex: json['premium_index'] as int?,
      sponsoredIndex: json['sponsored_index'] as int?,
      patternIndex: json['pattern_index'] as int?,
      normalOffset: json['normal_offset'] as int?,
    );
  }

  Map<String, dynamic> toRequestPayload() {
    final payload = <String, dynamic>{
      'paginate': 1,
      'per_page': perPage ?? 15,
      'page': page ?? 1,
    };
    if (feedSeed != null) payload['feed_seed'] = feedSeed;
    if (nextCursor != null && nextCursor!.isNotEmpty) {
      payload['cursor'] = nextCursor;
    }
    if (premiumIndex != null) payload['premium_index'] = premiumIndex;
    if (sponsoredIndex != null) payload['sponsored_index'] = sponsoredIndex;
    if (patternIndex != null) payload['pattern_index'] = patternIndex;
    if (normalOffset != null) payload['normal_offset'] = normalOffset;
    return payload;
  }
}

class VideoFeed {
  bool? status;
  List<WallVideos>? videos;
  FeedMeta? meta;

  VideoFeed({this.status, this.videos, this.meta});

  VideoFeed.fromJson(Map<String, dynamic> json) {
    status = json['status'] == true;
    final rawList = json['videos'] ?? json['data'];
    if (rawList is List) {
      videos = rawList
          .whereType<Map<String, dynamic>>()
          .map(WallVideos.fromJson)
          .toList();
    }
    if (json['meta'] != null) {
      meta = FeedMeta.fromJson(json['meta'] as Map<String, dynamic>);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (videos != null) {
      data['videos'] = videos!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class WallVideos {
  String? id;
  int? systemId;
  String? frontUserId;
  dynamic sponsorType;
  dynamic isImage;
  String? title;
  int? videoType;
  String? description;
  String? tags;
  String? menu;
  int? publishType;
  int? takeOrder;
  int? allowComments;
  String? location;
  String? image;
  String? video;
  String? videoUrl;
  String? thumbnailUrl;
  String? thumbnailBlur;
  String? imageUrl;
  String? processingStatus;
  String? transcodeStatus;
  String? hlsUrl;
  String? hlsPlaylistUrl;
  VideoSources? videoSources;
  int? likesCount;
  int? commentsCount;
  int? state;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? videoTypeName;
  String? userName;
  String? userImage;
  String? userEmail;
  int? followersCount;
  int? followingCount;
  dynamic contactPhone;
  dynamic contactEmail;
  dynamic website;
  dynamic latitude;
  dynamic longitude;

  WallVideos({
    this.id,
    this.systemId,
    this.frontUserId,
    this.sponsorType,
    this.title,
    this.videoType,
    this.description,
    this.isImage,
    this.tags,
    this.menu,
    this.publishType,
    this.takeOrder,
    this.allowComments,
    this.location,
    this.image,
    this.video,
    this.videoUrl,
    this.thumbnailUrl,
    this.thumbnailBlur,
    this.imageUrl,
    this.processingStatus,
    this.transcodeStatus,
    this.hlsUrl,
    this.hlsPlaylistUrl,
    this.videoSources,
    this.likesCount,
    this.commentsCount,
    this.state,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.videoTypeName,
    this.userName,
    this.userImage,
    this.userEmail,
    this.followersCount,
    this.followingCount,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.latitude,
    this.longitude,
  });

  bool get isTranscodeReady => transcodeStatus == 'ready';

  WallVideos.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    systemId = json['system_id'] as int?;
    frontUserId = json['front_user_id']?.toString();
    sponsorType = json['sponsor_type'];
    title = json['title'] as String?;
    videoType = json['video_type'] as int?;
    description = json['description'] as String?;
    tags = json['tags'] as String?;
    menu = json['menu'] as String?;
    publishType = json['publish_type'] as int?;
    takeOrder = json['take_order'] as int?;
    allowComments = json['allow_comments'] as int?;
    isImage = json['is_image'];
    location = json['location'] as String?;
    image = json['image'] as String?;
    video = json['video'] as String?;
    videoUrl = json['video_url'] as String?;
    thumbnailUrl = (json['thumbnail_url'] ?? json['thumbnail']) as String?;
    thumbnailBlur = json['thumbnail_blur'] as String?;
    imageUrl = json['image_url'] as String?;
    processingStatus = json['processing_status'] as String?;
    transcodeStatus = json['transcode_status'] as String?;
    hlsUrl = json['hls_url'] as String?;
    hlsPlaylistUrl = json['hls_playlist_url'] as String?;
    if (json['video_sources'] != null) {
      videoSources = VideoSources.fromJson(json['video_sources']);
    }
    likesCount = json['likes_count'] as int?;
    commentsCount = json['comments_count'] as int?;
    state = json['state'] as int?;
    status = json['status'] as int?;
    createdAt = json['created_at'] as String?;
    updatedAt = json['updated_at'] as String?;
    videoTypeName = json['video_type_name'] as String?;
    userName = json['user_name'] as String?;
    userEmail = json['user_email'] as String?;
    followersCount = parseApiCount(
      json['followers_count'] ?? json['followers'],
    );
    followingCount = parseApiCount(
      json['following_count'] ?? json['following'],
    );
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
    website = json['website'];
    latitude = json['latitude'];
    longitude = json['longitude'];

    String? userImageFromNested;
    final user = json['user'];
    if (user is Map<String, dynamic>) {
      frontUserId ??= user['id']?.toString();
      userName ??= user['name'] as String?;
      userImageFromNested = (user['image_url'] ?? user['image']) as String?;
      final nestedFollowers = parseApiCount(
        user['followers_count'] ?? user['followers'],
      );
      if (nestedFollowers > 0) {
        followersCount = nestedFollowers;
      }
    }
    // GET /api/reels: avatar on user.image; feeds may send user_image_url.
    userImage = userImageFromNested ??
        (json['user_image_url'] ?? json['user_image']) as String?;
  }

  /// Maps a profile-grid [visit_profile.Videos] row into feed [WallVideos] for reel playback.
  static WallVideos fromProfileVideo(
    visit_profile.Videos v, {
    String? ownerId,
    String? ownerName,
    String? ownerImage,
    int? ownerFollowers,
  }) {
    final w = WallVideos();
    w.id = v.id?.toString();
    w.frontUserId = v.frontUserId?.toString() ?? ownerId;
    w.title = v.title?.toString();
    w.description = v.description?.toString();
    w.tags = v.tags?.toString();
    w.videoUrl = v.videoUrl?.toString();
    w.video = v.video?.toString();
    w.image = v.image?.toString();
    w.thumbnailUrl = v.thumbnailUrl?.toString();
    w.hlsUrl = v.hlsUrl?.toString();
    w.hlsPlaylistUrl = v.hlsPlaylistUrl?.toString();
    w.transcodeStatus = v.transcodeStatus?.toString();
    w.processingStatus = v.processingStatus?.toString();
    if (v.videoSources != null) {
      w.videoSources = v.videoSources;
    }
    w.userName = v.userName?.toString() ?? ownerName;
    w.userImage = v.userImage?.toString() ?? ownerImage;
    w.followersCount = parseApiCount(v.followersCount ?? ownerFollowers);
    w.isImage = v.isImage;
    final allow = v.allowComments;
    if (allow is int) {
      w.allowComments = allow;
    } else if (allow != null) {
      w.allowComments = int.tryParse(allow.toString());
    }
    w.createdAt = v.createdAt?.toString();
    return w;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['system_id'] = systemId;
    data['front_user_id'] = frontUserId;
    data['title'] = title;
    data['video_type'] = videoType;
    data['sponsor_type'] = sponsorType;
    data['description'] = description;
    data['tags'] = tags;
    data['menu'] = menu;
    data['publish_type'] = publishType;
    data['take_order'] = takeOrder;
    data['allow_comments'] = allowComments;
    data['location'] = location;
    data['image'] = image;
    data['video'] = video;
    data['video_url'] = videoUrl;
    data['thumbnail_url'] = thumbnailUrl;
    data['thumbnail_blur'] = thumbnailBlur;
    data['image_url'] = imageUrl;
    data['processing_status'] = processingStatus;
    data['transcode_status'] = transcodeStatus;
    data['hls_url'] = hlsUrl;
    data['hls_playlist_url'] = hlsPlaylistUrl;
    data['likes_count'] = likesCount;
    data['comments_count'] = commentsCount;
    data['state'] = state;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['video_type_name'] = videoTypeName;
    data['user_name'] = userName;
    data['user_image'] = userImage;
    data['user_email'] = userEmail;
    data['followers_count'] = followersCount;
    data['following_count'] = followingCount;
    data['contact_phone'] = contactPhone;
    data['is_image'] = isImage;
    data['contact_email'] = contactEmail;
    data['website'] = website;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}
