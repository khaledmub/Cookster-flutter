import 'package:cookster/modules/auth/signUp/registrationSettingsModel/registrationModel.dart';

class UserDetails {
  bool? status;
  User? user;
  AdditionalData? additionalData;
  List<VideoTypes>? videoTypes;
  FormSettings? formSettings;
  List<String>? followers;
  List<String>? following;
  Subscription? subscription; // Added subscription field

  UserDetails({
    this.status,
    this.user,
    this.additionalData,
    this.videoTypes,
    this.formSettings,
    this.followers,
    this.following,
    this.subscription,
  });

  UserDetails.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    user = json['user'] != null ? new User.fromJson(json['user']) : null;
    if (json['video_types'] != null) {
      videoTypes = <VideoTypes>[];
      json['video_types'].forEach((v) {
        videoTypes!.add(new VideoTypes.fromJson(v));
      });
    }
    additionalData =
        json['additional_data'] != null
            ? new AdditionalData.fromJson(json['additional_data'])
            : null;
    formSettings =
        json['form_settings'] != null
            ? new FormSettings.fromJson(json['form_settings'])
            : null;
    print("Parsing followers: ${json['followers']?.runtimeType}");
    followers = json['followers'].cast<String>();
    following = json['following'].cast<String>();
    print("Parsing following: ${json['following']?.runtimeType}");

    subscription =
        json['subscription'] != null
            ? Subscription.fromJson(json['subscription'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.videoTypes != null) {
      data['video_types'] = this.videoTypes!.map((v) => v.toJson()).toList();
    }
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    if (this.additionalData != null) {
      data['additional_data'] = this.additionalData!.toJson();
    }
    if (this.formSettings != null) {
      data['form_settings'] = this.formSettings!.toJson();
    }
    data['followers'] = this.followers;
    data['following'] = this.following;
    if (subscription != null) {
      data['subscription'] = subscription!.toJson(); // Serialize subscription
    }
    return data;
  }
}

class Subscription {
  String? id;
  int? systemId;
  String? frontUserId;
  String? packageId;
  String? startDate;
  String? endDate;
  int? duration;
  int? amount;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? title;
  String? description;

  Subscription({
    this.id,
    this.systemId,
    this.frontUserId,
    this.packageId,
    this.startDate,
    this.endDate,
    this.duration,
    this.amount,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.title,
    this.description,
  });

  Subscription.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    frontUserId = json['front_user_id'];
    packageId = json['package_id'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    duration = json['duration'];
    amount = json['amount'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    title = json['title'];
    description = json['description'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['system_id'] = systemId;
    data['front_user_id'] = frontUserId;
    data['package_id'] = packageId;
    data['start_date'] = startDate;
    data['end_date'] = endDate;
    data['duration'] = duration;
    data['amount'] = amount;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['title'] = title;
    data['description'] = description;
    return data;
  }
}

class User {
  dynamic id;
  dynamic systemId;
  dynamic country;
  dynamic countryName;
  dynamic city;
  dynamic cityName;
  dynamic name;
  dynamic email;
  dynamic phone;
  dynamic dob;
  String? image;
  String? coverImage;
  dynamic entity;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;

  User({
    this.id,
    this.systemId,
    this.name,
    this.coverImage,
    this.email,
    this.phone,
    this.country,
    this.countryName,
    this.cityName,
    this.city,
    this.dob,
    this.image,
    this.entity,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    country = json['country'];
    countryName = json['country_name'];
    cityName = json['city_name'];
    city = json['city'];
    dob = json['dob'];
    image = json['image'];
    coverImage = json['cover_image'];
    entity = json['entity'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['dob'] = this.dob;
    data['country'] = this.country;
    data['country_name'] = this.countryName;
    data['city'] = this.city;
    data['city_name'] = this.cityName;
    data['cover_image'] = this.coverImage;
    data['image'] = this.image;
    data['entity'] = this.entity;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class AdditionalData {
  int? id;
  String? frontUserId;
  int? businessType;
  dynamic businessTypeName;
  String? contactPhone;
  String? contactEmail;
  String? website;
  String? location;
  String? latitude;
  String? longitude;
  int? status;
  String? createdAt;
  String? updatedAt;
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

  AdditionalData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    frontUserId = json['front_user_id'];
    businessType = json['business_type'];
    businessTypeName = json['business_type_name'];
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
    website = json['website'];
    location = json['location'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    isB2B = json['is_b2b'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['front_user_id'] = this.frontUserId;
    data['business_type'] = this.businessType;
    data['business_type_name'] = this.businessTypeName;
    data['contact_phone'] = this.contactPhone;
    data['contact_email'] = this.contactEmail;
    data['website'] = this.website;
    data['location'] = this.location;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['is_b2b'] = this.isB2B;
    return data;
  }
}

class FormSettings {
  BusinessTypes? businessTypes;
  List<Countries>? countries;
  List<Cities>? cities;

  FormSettings({this.businessTypes, this.countries, this.cities});

  FormSettings.fromJson(Map<String, dynamic> json) {
    businessTypes =
        json['business_types'] != null
            ? new BusinessTypes.fromJson(json['business_types'])
            : null;
    if (json['countries'] != null) {
      countries = <Countries>[];
      json['countries'].forEach((v) {
        countries!.add(new Countries.fromJson(v));
      });
    }
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(new Cities.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.businessTypes != null) {
      data['business_types'] = this.businessTypes!.toJson();
    }
    if (this.countries != null) {
      data['countries'] = this.countries!.map((v) => v.toJson()).toList();
    }
    if (this.cities != null) {
      data['cities'] = this.cities!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BusinessTypes {
  Key? key;
  List<Values>? values;

  BusinessTypes({this.key, this.values});

  BusinessTypes.fromJson(Map<String, dynamic> json) {
    key = json['key'] != null ? new Key.fromJson(json['key']) : null;
    if (json['values'] != null) {
      values = <Values>[];
      json['values'].forEach((v) {
        values!.add(new Values.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.key != null) {
      data['key'] = this.key!.toJson();
    }
    if (this.values != null) {
      data['values'] = this.values!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Key {
  dynamic id;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic keyName;

  Key({this.id, this.status, this.createdAt, this.updatedAt, this.keyName});

  Key.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    keyName = json['key_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['key_name'] = this.keyName;
    return data;
  }
}

class Values {
  dynamic id;
  dynamic keyId;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic name;

  Values({
    this.id,
    this.keyId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.name,
  });

  Values.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    keyId = json['key_id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key_id'] = this.keyId;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['name'] = this.name;
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
  List<ProfessionalVideos>? videos;

  VideoTypes({
    this.id,
    this.keyId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.name,
    this.videos,
  });

  VideoTypes.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    keyId = json['key_id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    name = json['name'];
    if (json['videos'] != null) {
      videos = <ProfessionalVideos>[];
      json['videos'].forEach((v) {
        videos!.add(new ProfessionalVideos.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key_id'] = this.keyId;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['name'] = this.name;
    if (this.videos != null) {
      data['videos'] = this.videos!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ProfessionalVideos {
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
  dynamic country;
  dynamic city;
  dynamic location;
  dynamic image;
  dynamic video;
  dynamic state;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic userName;
  dynamic userImage;
  dynamic userEmail;
  dynamic isImage;
  dynamic sponsorType;
  dynamic cities;
  dynamic days;
  dynamic startDate;
  dynamic endDate;
  dynamic perDayPrice;
  dynamic discountPercentage;
  dynamic discountAmount;
  dynamic totalAmount;

  ProfessionalVideos({
    this.id,
    this.systemId,
    this.frontUserId,
    this.country,
    this.city,
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
    this.userName,
    this.userEmail,
    this.isImage,
    this.userImage,
    this.sponsorType,
    this.cities,
    this.days,
    this.startDate,
    this.endDate,
    this.perDayPrice,
    this.discountPercentage,
    this.discountAmount,
    this.totalAmount,
  });

  ProfessionalVideos.fromJson(Map<String, dynamic> json) {
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
    userName = json['user_name'];
    userImage = json['user_email'];
    country = json['country'];
    city = json['city'];
    userImage = json['user_image'];
    isImage = json['is_image'];
    sponsorType = json['sponsor_type'];
    cities = json['city_names'];
    days = json['days'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    perDayPrice = json['per_day_price'];
    discountPercentage = json['discount_percentage'];
    discountAmount = json['discount_amount'];
    totalAmount = json['total_amount'];
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
    data['country'] = this.country;
    data['city'] = this.city;
    data['state'] = this.state;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['user_name'] = this.userName;
    data['user_image'] = this.userImage;
    data['user_email'] = this.userEmail;
    data['is_image'] = this.isImage;
    data['sponsor_type'] = this.sponsorType;
    data['city_names'] = this.cities;
    data['days'] = this.days;
    data['start_date'] = this.startDate;
    data['end_date'] = this.endDate;
    data['per_day_price'] = this.perDayPrice;
    data['discount_percentage'] = this.discountPercentage;
    data['discount_amount'] = this.discountAmount;
    data['total_amount'] = this.totalAmount;
    return data;
  }
}
