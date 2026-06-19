import 'package:cookster/core/media/playback_media.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/profileModel.dart'
    as pro_profile;
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/simpleUserProfileModel.dart'
    as simple_profile;
import 'package:cookster/modules/liked_videos_screen/liked_videos_model/liked_videos_model.dart';
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
  /// True when Near Me geo filter returned nothing and the server fell back
  /// to the general reels feed (`GET /api/reels?feed=near_me`).
  bool geoFallback;

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
    this.geoFallback = false,
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
      geoFallback: json['geo_fallback'] == true,
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
  bool? playbackReady;
  String? title;
  int? videoType;
  String? description;
  String? tags;
  String? menu;
  int? publishType;
  int? takeOrder;
  int? allowComments;
  /// Comments are enabled unless the API explicitly sets `allow_comments` to 0.
  bool get commentsEnabled => allowComments != 0;

  static int? parseAllowComments(dynamic raw) {
    if (raw == null) {
      return 1;
    }
    if (raw is bool) {
      return raw ? 1 : 0;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      final lower = raw.trim().toLowerCase();
      if (lower == 'true' || lower == '1') {
        return 1;
      }
      if (lower == 'false' || lower == '0') {
        return 0;
      }
      return int.tryParse(raw) ?? 1;
    }
    return 1;
  }

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
  String? creatorHandle;
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
    this.playbackReady,
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
    this.creatorHandle,
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
    allowComments = parseAllowComments(json['allow_comments']);
    isImage = json['is_image'];
    playbackReady = PlaybackMedia.parseOptionalFlag(json['playback_ready']);
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
    creatorHandle = json['creator_handle'] as String?;
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
      userName ??= (user['user_name'] ?? user['name']) as String?;
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
    w.imageUrl = v.imageUrl?.toString();
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
    w.playbackReady = PlaybackMedia.parseOptionalFlag(v.playbackReady);
    w.allowComments = parseAllowComments(v.allowComments);
    w.createdAt = v.createdAt?.toString();
    return w;
  }

  static WallVideos fromSavedVideo(SavedVideos v) {
    return _fromGridVideo(
      id: v.id,
      frontUserId: v.frontUserId,
      title: v.title,
      description: v.description,
      tags: v.tags,
      videoUrl: v.videoUrl,
      video: v.video,
      image: v.image,
      imageUrl: v.imageUrl,
      thumbnailUrl: v.thumbnailUrl,
      hlsUrl: v.hlsUrl,
      hlsPlaylistUrl: v.hlsPlaylistUrl,
      transcodeStatus: v.transcodeStatus,
      processingStatus: v.processingStatus,
      videoSources: v.videoSources,
      userName: v.userName,
      userImage: v.userImage,
      followersCount: v.followersCount,
      allowComments: v.allowComments,
      createdAt: v.createdAt,
    );
  }

  static WallVideos fromLikedVideo(LikedVideos v) {
    return _fromGridVideo(
      id: v.id,
      frontUserId: v.frontUserId,
      title: v.title,
      description: v.description,
      tags: v.tags,
      videoUrl: v.videoUrl,
      video: v.video,
      image: v.image,
      imageUrl: v.imageUrl,
      thumbnailUrl: v.thumbnailUrl,
      hlsUrl: v.hlsUrl,
      hlsPlaylistUrl: v.hlsPlaylistUrl,
      transcodeStatus: v.transcodeStatus,
      processingStatus: v.processingStatus,
      videoSources: v.videoSources,
      userName: v.userName,
      userImage: v.userImage,
      followersCount: v.followersCount,
      allowComments: v.allowComments,
      createdAt: v.createdAt,
    );
  }

  static WallVideos fromSimpleUserVideo(
    simple_profile.UserVideos v, {
    String? ownerId,
    String? ownerName,
    String? ownerImage,
    int? ownerFollowers,
  }) {
    return _fromGridVideo(
      id: v.id,
      frontUserId: v.frontUserId ?? ownerId,
      title: v.title,
      description: v.description,
      tags: v.tags,
      videoUrl: v.videoUrl,
      video: v.video,
      image: v.image,
      imageUrl: v.imageUrl,
      thumbnailUrl: v.thumbnailUrl,
      hlsUrl: v.hlsUrl,
      hlsPlaylistUrl: v.hlsPlaylistUrl,
      transcodeStatus: v.transcodeStatus,
      processingStatus: v.processingStatus,
      videoSources: v.videoSources,
      userName: v.userName ?? ownerName,
      userImage: v.userImage ?? ownerImage,
      followersCount: ownerFollowers,
      allowComments: v.allowComments,
      isImage: v.isImage,
      createdAt: v.createdAt,
      likesCount: v.likeCount,
    );
  }

  static WallVideos fromProfessionalVideo(
    pro_profile.ProfessionalVideos v, {
    String? ownerId,
    String? ownerName,
    String? ownerImage,
    int? ownerFollowers,
  }) {
    return _fromGridVideo(
      id: v.id,
      frontUserId: v.frontUserId ?? ownerId,
      title: v.title,
      description: v.description,
      tags: v.tags,
      videoUrl: v.videoUrl,
      video: v.video,
      image: v.image,
      imageUrl: v.imageUrl,
      thumbnailUrl: v.thumbnailUrl,
      hlsUrl: v.hlsUrl,
      hlsPlaylistUrl: v.hlsPlaylistUrl,
      transcodeStatus: v.transcodeStatus,
      processingStatus: v.processingStatus,
      videoSources: v.videoSources,
      userName: v.userName ?? ownerName,
      userImage: v.userImage ?? ownerImage,
      followersCount: ownerFollowers,
      allowComments: v.allowComments,
      isImage: v.isImage,
      createdAt: v.createdAt,
      likesCount: v.likeCount,
      userEmail: v.userEmail,
    );
  }

  static WallVideos _fromGridVideo({
    dynamic id,
    dynamic frontUserId,
    dynamic title,
    dynamic description,
    dynamic tags,
    dynamic videoUrl,
    dynamic video,
    dynamic image,
    dynamic imageUrl,
    dynamic thumbnailUrl,
    dynamic hlsUrl,
    dynamic hlsPlaylistUrl,
    dynamic transcodeStatus,
    dynamic processingStatus,
    VideoSources? videoSources,
    dynamic userName,
    dynamic userImage,
    dynamic followersCount,
    dynamic allowComments,
    dynamic isImage,
    bool? playbackReady,
    dynamic createdAt,
    dynamic likesCount,
    dynamic userEmail,
  }) {
    final w = WallVideos();
    w.id = id?.toString();
    w.frontUserId = frontUserId?.toString();
    w.title = title?.toString();
    w.description = description?.toString();
    w.tags = tags?.toString();
    w.videoUrl = videoUrl?.toString();
    w.video = video?.toString();
    w.image = image?.toString();
    w.imageUrl = imageUrl?.toString();
    w.thumbnailUrl = thumbnailUrl?.toString();
    w.hlsUrl = hlsUrl?.toString();
    w.hlsPlaylistUrl = hlsPlaylistUrl?.toString();
    w.transcodeStatus = transcodeStatus?.toString();
    w.processingStatus = processingStatus?.toString();
    w.videoSources = videoSources;
    w.userName = userName?.toString();
    w.userImage = userImage?.toString();
    w.userEmail = userEmail?.toString();
    w.followersCount = parseApiCount(followersCount);
    w.likesCount = parseApiCount(likesCount);
    w.isImage = isImage;
    w.playbackReady = playbackReady;
    w.allowComments = parseAllowComments(allowComments);
    w.createdAt = createdAt?.toString();
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
    data['playback_ready'] = playbackReady;
    data['contact_email'] = contactEmail;
    data['website'] = website;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}
