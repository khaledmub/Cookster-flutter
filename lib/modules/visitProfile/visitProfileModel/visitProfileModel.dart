class VisitProfile {
  bool? status;
  User? user;
  List<AdditionalData> additionalData;
  List<VideoTypes>? videoTypes;
  dynamic followers;
  dynamic following;

  VisitProfile({
    this.status,
    this.user,
    List<AdditionalData>? additionalData,
    this.videoTypes,
    this.followers,
    this.following,
  }) : additionalData = additionalData ?? [];

  VisitProfile.fromJson(Map<dynamic, dynamic> json) : additionalData = [] {
    // Initialize in constructor list
    status = json['status'] as bool?;
    user =
        json['user'] != null
            ? User.fromJson(json['user'] as Map<dynamic, dynamic>)
            : null;
    if (json['user'] != null) {
      user = User.fromJson(json['user'] as Map<dynamic, dynamic>);
    }

    // Handle additional_data as List or Map, default to empty list
    if (json['additional_data'] != null) {
      if (json['additional_data'] is List) {
        additionalData =
            (json['additional_data'] as List)
                .where((v) => v is Map<dynamic, dynamic>)
                .map((v) => AdditionalData.fromJson(v as Map<dynamic, dynamic>))
                .toList();
      } else if (json['additional_data'] is Map<dynamic, dynamic>) {
        additionalData = [
          AdditionalData.fromJson(
            json['additional_data'] as Map<dynamic, dynamic>,
          ),
        ];
      }
    }

    if (json['video_types'] != null && json['video_types'] is List) {
      videoTypes =
          (json['video_types'] as List)
              .where((v) => v is Map<dynamic, dynamic>)
              .map((v) => VideoTypes.fromJson(v as Map<dynamic, dynamic>))
              .toList();
    }
    followers = json['followers'] as dynamic;
    following = json['following'] as dynamic;
  }

  // Helper method to safely get the first AdditionalData or null
  AdditionalData? getFirstAdditionalData() {
    return additionalData.isNotEmpty ? additionalData.first : null;
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = <dynamic, dynamic>{};
    data['status'] = status;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    data['additional_data'] = additionalData.map((v) => v.toJson()).toList();
    if (videoTypes != null) {
      data['video_types'] = videoTypes!.map((v) => v.toJson()).toList();
    }
    data['followers'] = followers;
    data['following'] = following;
    return data;
  }
}

class User {
  dynamic id;
  dynamic systemId;
  dynamic name;
  dynamic email;
  dynamic phone;
  dynamic password;
  dynamic dob;
  dynamic image;
  dynamic coverImage;
  dynamic country;
  dynamic state;
  dynamic city;
  dynamic uuid;
  dynamic entity;
  dynamic currentSubscriptionId;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;

  User({
    this.id,
    this.systemId,
    this.name,
    this.email,
    this.phone,
    this.password,
    this.dob,
    this.image,
    this.coverImage,
    this.country,
    this.state,
    this.city,
    this.uuid,
    this.entity,
    this.currentSubscriptionId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  User.fromJson(Map<dynamic, dynamic> json) {
    id = json['id'] as dynamic;
    systemId = json['system_id'] as dynamic;
    name = json['name'] as dynamic;
    email = json['email'] as dynamic;
    phone = json['phone'] as dynamic;
    password = json['password'] as dynamic;
    dob = json['dob'] as dynamic;
    image = json['image'] as dynamic;
    coverImage = json['cover_image'];
    country = json['country'] as dynamic;
    state = json['state'] as dynamic;
    city = json['city'] as dynamic;
    uuid = json['uuid'] as dynamic;
    entity = json['entity'] as dynamic;
    currentSubscriptionId = json['current_subscription_id'] as dynamic;
    status = json['status'] as dynamic;
    createdAt = json['created_at'] as dynamic;
    updatedAt = json['updated_at'] as dynamic;
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = <dynamic, dynamic>{};
    data['id'] = id;
    data['system_id'] = systemId;
    data['name'] = name;
    data['email'] = email;
    data['phone'] = phone;
    data['password'] = password;
    data['dob'] = dob;
    data['image'] = image;
    data['cover_image'] = coverImage;
    data['country'] = country;
    data['state'] = state;
    data['city'] = city;
    data['uuid'] = uuid;
    data['entity'] = entity;
    data['current_subscription_id'] = currentSubscriptionId;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}

class AdditionalData {
  dynamic id;
  dynamic frontUserId;
  dynamic businessType;
  dynamic businessTypeName;
  dynamic contactPhone;
  dynamic contactEmail;
  dynamic website;
  dynamic location;
  dynamic latitude;
  dynamic longitude;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic isB2B;

  AdditionalData({
    this.id,
    this.frontUserId,
    this.businessType,
    this.businessTypeName,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.location,
    this.latitude,
    this.longitude,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.isB2B
  });

  AdditionalData.fromJson(Map<dynamic, dynamic> json) {
    id = json['id'] as dynamic;
    frontUserId = json['front_user_id'] as dynamic;
    businessType = json['business_type'] as dynamic;
    businessTypeName = json['business_type_name'];
    contactPhone = json['contact_phone'] as dynamic;
    contactEmail = json['contact_email'] as dynamic;
    website = json['website'] as dynamic;
    location = json['location'] as dynamic;
    latitude = json['latitude'] as dynamic;
    longitude = json['longitude'] as dynamic;
    status = json['status'] as dynamic;
    createdAt = json['created_at'] as dynamic;
    updatedAt = json['updated_at'] as dynamic;
    isB2B = json['is_b2b'] as dynamic;
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = <dynamic, dynamic>{};
    data['id'] = id;
    data['front_user_id'] = frontUserId;
    data['business_type'] = businessType;
    data['business_type_name'] = businessTypeName;
    data['contact_phone'] = contactPhone;
    data['contact_email'] = contactEmail;
    data['website'] = website;
    data['location'] = location;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['is_b2b'] = isB2B;
    return data;
  }
}

class VideoTypes {
  dynamic id;
  dynamic keyId;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic name;
  List<Videos>? videos;

  VideoTypes({
    this.id,
    this.keyId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.name,
    this.videos,
  });

  VideoTypes.fromJson(Map<dynamic, dynamic> json) {
    id = json['id'] as dynamic;
    keyId = json['key_id'] as dynamic;
    status = json['status'] as dynamic;
    createdAt = json['created_at'] as dynamic;
    updatedAt = json['updated_at'] as dynamic;
    name = json['name'] as dynamic;
    if (json['videos'] != null && json['videos'] is List) {
      videos =
          (json['videos'] as List)
              .where((v) => v is Map<dynamic, dynamic>)
              .map((v) => Videos.fromJson(v as Map<dynamic, dynamic>))
              .toList();
    }
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = <dynamic, dynamic>{};
    data['id'] = id;
    data['key_id'] = keyId;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['name'] = name;
    if (videos != null) {
      data['videos'] = videos!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Videos {
  dynamic id;
  dynamic systemId;
  dynamic frontUserId;
  dynamic title;
  dynamic videoType;
  dynamic description;
  dynamic tags;
  dynamic menu;
  dynamic publishType;
  dynamic takeOrder;
  dynamic allowComments;
  dynamic location;
  dynamic image;
  dynamic video;
  dynamic country;
  dynamic city;
  dynamic averageRating;
  dynamic isImage;
  dynamic isSponsored;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic userName;
  dynamic userImage;

  Videos({
    this.id,
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
    this.country,
    this.city,
    this.averageRating,
    this.isImage,
    this.isSponsored,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.userImage,
  });

  Videos.fromJson(Map<dynamic, dynamic> json) {
    id = json['id'] as dynamic;
    systemId = json['system_id'] as dynamic;
    frontUserId = json['front_user_id'] as dynamic;
    title = json['title'] as dynamic;
    videoType = json['video_type'] as dynamic;
    description = json['description'] as dynamic;
    tags = json['tags'] as dynamic;
    menu = json['menu'] as dynamic;
    publishType = json['publish_type'] as dynamic;
    takeOrder = json['take_order'] as dynamic;
    allowComments = json['allow_comments'] as dynamic;
    location = json['location'] as dynamic;
    image = json['image'] as dynamic;
    video = json['video'] as dynamic;
    country = json['country'] as dynamic;
    city = json['city'] as dynamic;
    averageRating = json['average_rating'] as dynamic;
    isImage = json['is_image'] as dynamic;
    isSponsored = json['is_sponsored'] as dynamic;
    status = json['status'] as dynamic;
    createdAt = json['created_at'] as dynamic;
    updatedAt = json['updated_at'] as dynamic;
    userName = json['user_name'] as dynamic;
    userImage = json['user_image'] as dynamic;
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = <dynamic, dynamic>{};
    data['id'] = id;
    data['system_id'] = systemId;
    data['front_user_id'] = frontUserId;
    data['title'] = title;
    data['video_type'] = videoType;
    data['description'] = description;
    data['tags'] = tags;
    data['menu'] = menu;
    data['publish_type'] = publishType;
    data['take_order'] = takeOrder;
    data['allow_comments'] = allowComments;
    data['location'] = location;
    data['image'] = image;
    data['video'] = video;
    data['country'] = country;
    data['city'] = city;
    data['average_rating'] = averageRating;
    data['is_image'] = isImage;
    data['is_sponsored'] = isSponsored;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['user_name'] = userName;
    data['user_image'] = userImage;
    return data;
  }
}
