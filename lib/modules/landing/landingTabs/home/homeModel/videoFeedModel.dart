class VideoFeed {
  bool? status;
  List<WallVideos>? videos;

  VideoFeed({this.status, this.videos});

  VideoFeed.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['videos'] != null) {
      videos = <WallVideos>[];
      json['videos'].forEach((v) {
        videos!.add(new WallVideos.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.videos != null) {
      data['videos'] = this.videos!.map((v) => v.toJson()).toList();
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

  WallVideos.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    frontUserId = json['front_user_id'];
    sponsorType = json['sponsor_type'];
    title = json['title'];
    videoType = json['video_type'];
    description = json['description'];
    tags = json['tags'];
    menu = json['menu'];
    publishType = json['publish_type'];
    takeOrder = json['take_order'];
    allowComments = json['allow_comments'];
    isImage = json['is_image'];
    location = json['location'];
    image = json['image'];
    video = json['video'];
    videoUrl = json['video_url'];
    state = json['state'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    videoTypeName = json['video_type_name'];
    userName = json['user_name'];
    userImage = json['user_image'];
    userEmail = json['user_email'];
    followersCount = json['followers_count'];
    followingCount = json['following_count'];
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
    website = json['website'];
    latitude = json['latitude'];
    longitude = json['longitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['front_user_id'] = this.frontUserId;
    data['title'] = this.title;
    data['video_type'] = this.videoType;
    data['sponsor_type'] = this.sponsorType;
    data['description'] = this.description;
    data['tags'] = this.tags;
    data['menu'] = this.menu;
    data['publish_type'] = this.publishType;
    data['take_order'] = this.takeOrder;
    data['allow_comments'] = this.allowComments;
    data['location'] = this.location;
    data['image'] = this.image;
    data['video'] = this.video;
    data['video_url'] = this.videoUrl;
    data['state'] = this.state;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['video_type_name'] = this.videoTypeName;
    data['user_name'] = this.userName;
    data['user_image'] = this.userImage;
    data['user_email'] = this.userEmail;
    data['followers_count'] = this.followersCount;
    data['following_count'] = this.followingCount;
    data['contact_phone'] = this.contactPhone;
    data['is_image'] = this.isImage;
    data['contact_email'] = this.contactEmail;
    data['website'] = this.website;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    return data;
  }
}
