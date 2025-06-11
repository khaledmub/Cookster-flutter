class SearchResult {
  bool? status;
  List<Videos>? videos;
  List<BusinessAccounts>? businessAccounts;
  List<ChefAccounts>? chefAccounts;

  SearchResult({
    this.status,
    this.videos,
    this.businessAccounts,
    this.chefAccounts,
  });

  SearchResult.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['videos'] != null) {
      videos = <Videos>[];
      json['videos'].forEach((v) {
        videos!.add(new Videos.fromJson(v));
      });
    }
    if (json['business_accounts'] != null) {
      businessAccounts = <BusinessAccounts>[];
      json['business_accounts'].forEach((v) {
        businessAccounts!.add(new BusinessAccounts.fromJson(v));
      });
    }
    if (json['chef_accounts'] != null) {
      chefAccounts = <ChefAccounts>[];
      json['chef_accounts'].forEach((v) {
        chefAccounts!.add(new ChefAccounts.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.videos != null) {
      data['videos'] = this.videos!.map((v) => v.toJson()).toList();
    }
    if (this.businessAccounts != null) {
      data['business_accounts'] =
          this.businessAccounts!.map((v) => v.toJson()).toList();
    }
    if (this.chefAccounts != null) {
      data['chef_accounts'] =
          this.chefAccounts!.map((v) => v.toJson()).toList();
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
  dynamic state;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic videoTypeName;
  dynamic userName;
  dynamic userImage;
  dynamic followersCount;
  dynamic followingCount;
  dynamic contactEmail;
  dynamic contactPhone;
  dynamic website;
  dynamic isImage;
  dynamic locationName;
  dynamic latitude;
  dynamic longitude;

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
    this.state,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.videoTypeName,
    this.userName,
    this.userImage,
    this.followersCount,
    this.followingCount,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.locationName,
    this.latitude,
    this.isImage,
  });

  Videos.fromJson(Map<String, dynamic> json) {
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
    contactEmail = json['contact_email'];
    contactPhone = json['contact_phone'];
    website = json['website'];
    locationName = json['location_name'];
    latitude = json['latitude'];
    isImage = json['is_image'];
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
    data['contact_email'] = this.contactEmail;
    data['contact_phone'] = this.contactPhone;
    data['website'] = this.website;
    data['location_name'] = this.locationName;
    data['latitude'] = this.latitude;
    data['is_image'] = this.isImage;
    return data;
  }
}

class BusinessAccounts {
  dynamic id;
  dynamic systemId;
  dynamic name;
  dynamic email;
  dynamic phone;
  dynamic password;
  dynamic dob;
  dynamic image;
  dynamic entity;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic contactPhone;
  dynamic contactEmail;
  dynamic website;
  dynamic location;
  dynamic latitude;
  dynamic longitude;
  dynamic businessTypeName;

  BusinessAccounts({
    this.id,
    this.systemId,
    this.name,
    this.email,
    this.phone,
    this.password,
    this.dob,
    this.image,
    this.entity,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.location,
    this.latitude,
    this.longitude,
    this.businessTypeName,
  });

  BusinessAccounts.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    password = json['password'];
    dob = json['dob'];
    image = json['image'];
    entity = json['entity'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
    website = json['website'];
    location = json['location'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    businessTypeName = json['business_type_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['password'] = this.password;
    data['dob'] = this.dob;
    data['image'] = this.image;
    data['entity'] = this.entity;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['contact_phone'] = this.contactPhone;
    data['contact_email'] = this.contactEmail;
    data['website'] = this.website;
    data['location'] = this.location;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    data['business_type_name'] = this.businessTypeName;
    return data;
  }
}

class ChefAccounts {
  dynamic id;
  dynamic systemId;
  dynamic name;
  dynamic email;
  dynamic phone;
  dynamic password;
  dynamic dob;
  dynamic image;
  dynamic entity;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic contactPhone;
  dynamic contactEmail;

  ChefAccounts({
    this.id,
    this.systemId,
    this.name,
    this.email,
    this.phone,
    this.password,
    this.dob,
    this.image,
    this.entity,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.contactPhone,
    this.contactEmail,
  });

  ChefAccounts.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    password = json['password'];
    dob = json['dob'];
    image = json['image'];
    entity = json['entity'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['password'] = this.password;
    data['dob'] = this.dob;
    data['image'] = this.image;
    data['entity'] = this.entity;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['contact_phone'] = this.contactPhone;
    data['contact_email'] = this.contactEmail;
    return data;
  }
}
