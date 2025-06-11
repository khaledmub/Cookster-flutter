class SingleVideoDetail {
  bool? status;
  Video? video;

  SingleVideoDetail({this.status, this.video});

  SingleVideoDetail.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    video = json['video'] != null ? new Video.fromJson(json['video']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.video != null) {
      data['video'] = this.video!.toJson();
    }
    return data;
  }
}

class Video {
  String? id;
  int? systemId;
  String? frontUserId;
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
  int? state;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? videoTypeName;
  String? userName;
  String? userImage;
  int? followersCount;
  int? followingCount;

  Video(
      {this.id,
        this.systemId,
        this.frontUserId,
        this.title,
        this.videoType,
        this.description,
        this.tags,
        this.menu,
        this.publishType,
        this.takeOrder,
        this.allowComments,
        this.location,
        this.image,
        this.video,
        this.state,
        this.status,
        this.createdAt,
        this.updatedAt,
        this.videoTypeName,
        this.userName,
        this.userImage,
        this.followersCount,
        this.followingCount});

  Video.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    frontUserId = json['front_user_id'];
    title = json['title'];
    videoType = json['video_type'];
    description = json['description'];
    tags = json['tags'];
    menu = json['menu'];
    publishType = json['publish_type'];
    takeOrder = json['take_order'];
    allowComments = json['allow_comments'];
    location = json['location'];
    image = json['image'];
    video = json['video'];
    state = json['state'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    videoTypeName = json['video_type_name'];
    userName = json['user_name'];
    userImage = json['user_image'];
    followersCount = json['followers_count'];
    followingCount = json['following_count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['front_user_id'] = this.frontUserId;
    data['title'] = this.title;
    data['video_type'] = this.videoType;
    data['description'] = this.description;
    data['tags'] = this.tags;
    data['menu'] = this.menu;
    data['publish_type'] = this.publishType;
    data['take_order'] = this.takeOrder;
    data['allow_comments'] = this.allowComments;
    data['location'] = this.location;
    data['image'] = this.image;
    data['video'] = this.video;
    data['state'] = this.state;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['video_type_name'] = this.videoTypeName;
    data['user_name'] = this.userName;
    data['user_image'] = this.userImage;
    data['followers_count'] = this.followersCount;
    data['following_count'] = this.followingCount;
    return data;
  }
}
