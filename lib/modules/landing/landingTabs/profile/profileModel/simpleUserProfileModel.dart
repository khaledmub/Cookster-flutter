class SimpleUserDetails {
  bool? status;
  SimpleUser? user;
  List<VideoTypes>? videoTypes;
  List<String>? followers;
  List<String>? following;
  FormSettings? formSettings;
  AdditionalData? additionalData;

  SimpleUserDetails({
    this.status,
    this.user,
    this.videoTypes,
    this.followers,
    this.following,
    this.additionalData,
  });

  SimpleUserDetails.fromJson(Map<String, dynamic> json) {
    print("Parsing SimpleUserDetails. JSON keys: ${json.keys}");

    status = json['status'];

    print("Parsing user: ${json['user']?.runtimeType}");
    if (json['user'] != null) {
      if (json['user'] is Map<String, dynamic>) {
        user = SimpleUser.fromJson(json['user']);
      } else {
        print(
          "Error: user is not a Map<String, dynamic>, got ${json['user'].runtimeType}",
        );
        user = null;
      }
    } else {
      user = null;
    }

    print("Parsing video_types: ${json['video_types']?.runtimeType}");
    if (json['video_types'] != null) {
      if (json['video_types'] is List<dynamic>) {
        videoTypes = <VideoTypes>[];
        try {
          json['video_types'].forEach((v) {
            if (v is Map<String, dynamic>) {
              videoTypes!.add(VideoTypes.fromJson(v));
            } else {
              print("Skipping invalid video_types item: $v");
            }
          });
        } catch (e) {
          print("Error parsing video_types: $e");
        }
      } else {
        print(
          "Error: video_types is not a List<dynamic>, got ${json['video_types'].runtimeType}",
        );
      }
    }

    print("Parsing additional_data: ${json['additional_data']?.runtimeType}");
    if (json['additional_data'] != null) {
      if (json['additional_data'] is Map<String, dynamic>) {
        additionalData = AdditionalData.fromJson(json['additional_data']);
      } else {
        print(
          "Error: additional_data is not a Map<String, dynamic>, got ${json['additional_data'].runtimeType}",
        );
        additionalData = null;
      }
    } else {
      additionalData = null;
    }

    print("Parsing form_settings: ${json['form_settings']?.runtimeType}");
    if (json['form_settings'] != null) {
      if (json['form_settings'] is Map<String, dynamic>) {
        formSettings = FormSettings.fromJson(json['form_settings']);
      } else {
        print(
          "Error: form_settings is not a Map<String, dynamic>, got ${json['form_settings'].runtimeType}",
        );
        formSettings = null;
      }
    } else {
      formSettings = null;
    }

    print("Parsing followers: ${json['followers']?.runtimeType}");
    followers = json['followers'].cast<String>();
    following = json['following'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    if (this.additionalData != null) {
      data['additional_data'] = this.additionalData!.toJson();
    }

    if (this.videoTypes != null) {
      data['video_types'] = this.videoTypes!.map((v) => v.toJson()).toList();
    }
    if (this.formSettings != null) {
      data['form_settings'] = this.formSettings!.toJson();
    }
    data['followers'] = this.followers;
    data['following'] = this.following;
    return data;
  }
}

class SimpleUser {
  dynamic id;
  dynamic systemId;
  dynamic name;
  dynamic email;
  dynamic phone;
  dynamic dob;
  dynamic image;
  dynamic entity;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic country;
  dynamic city;

  SimpleUser({
    this.id,
    this.systemId,
    this.name,
    this.email,
    this.phone,
    this.dob,
    this.image,
    this.entity,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.country,
    this.city,
  });

  SimpleUser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    dob = json['dob'];
    image = json['image'];
    entity = json['entity'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    country = json['country'];
    city = json['city'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['dob'] = this.dob;
    data['image'] = this.image;
    data['entity'] = this.entity;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['country'] = this.country;
    data['city'] = this.city;

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
  List<UserVideos>? videos;

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
      videos = <UserVideos>[];
      json['videos'].forEach((v) {
        videos!.add(new UserVideos.fromJson(v));
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

class FormSettings {
  List<Countries>? countries;
  List<Cities>? cities;
  TypeOfAccount? typeOfAccount;

  FormSettings({this.countries, this.cities, this.typeOfAccount});

  FormSettings.fromJson(Map<String, dynamic> json) {
    if (json['countries'] != null) {
      countries = <Countries>[];
      json['countries'].forEach((v) {
        countries!.add(Countries.fromJson(v));
      });
    }
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(Cities.fromJson(v));
      });
    }
    // Handle type_of_account gracefully
    if (json['type_of_account'] != null) {
      try {
        typeOfAccount = TypeOfAccount.fromJson(json['type_of_account']);
      } catch (e) {
        print('Error parsing type_of_account: $e');
        typeOfAccount = null; // Set to null if parsing fails
      }
    } else {
      typeOfAccount = null; // Explicitly handle null case
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (countries != null) {
      data['countries'] = countries!.map((v) => v.toJson()).toList();
    }
    if (cities != null) {
      data['cities'] = cities!.map((v) => v.toJson()).toList();
    }
    if (typeOfAccount != null) {
      data['type_of_account'] = typeOfAccount!.toJson();
    }
    return data;
  }
}

class TypeOfAccount {
  Key? key;
  List<Values>? values;
  List<dynamic>? rawList; // Store List<dynamic> if received

  TypeOfAccount({this.key, this.values, this.rawList});

  TypeOfAccount.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json['key'] != null) {
        key = Key.fromJson(json['key']);
      }
      if (json['values'] != null) {
        values = <Values>[];
        json['values'].forEach((v) {
          values!.add(Values.fromJson(v));
        });
      }
    } else if (json is List<dynamic>) {
      rawList = json;
      values = <Values>[];
      try {
        // Attempt to parse list elements as Values
        for (var v in json) {
          if (v is Map<String, dynamic>) {
            values!.add(Values.fromJson(v));
          } else {
            print('Skipping non-Map element in type_of_account list: $v');
          }
        }
      } catch (e) {
        print('Error parsing List<dynamic> into Values: $e');
      }
    } else {
      print('Unexpected type_of_account type: ${json.runtimeType}');
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (key != null) {
      data['key'] = key!.toJson();
    }
    if (values != null) {
      data['values'] = values!.map((v) => v.toJson()).toList();
    }
    if (rawList != null) {
      data['raw_list'] = rawList;
    }
    return data;
  }
}

class Key {
  int? id;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? keyName;

  Key({this.id, this.status, this.createdAt, this.updatedAt, this.keyName});

  Key.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    keyName = json['key_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['key_name'] = keyName;
    return data;
  }
}

class Values {
  int? id;
  int? keyId;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? name;

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
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['key_id'] = keyId;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['name'] = name;
    return data;
  }
}

class UserVideos {
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
  dynamic videoUrl;
  dynamic country;
  dynamic city;
  dynamic status;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic userName;
  dynamic isImage;
  dynamic userImage;

  dynamic sponsorType;
  dynamic cities;
  dynamic days;
  dynamic startDate;
  dynamic endDate;
  dynamic perDayPrice;
  dynamic discountPercentage;
  dynamic discountAmount;
  dynamic totalAmount;

  UserVideos({
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
    this.videoUrl,
    this.country,
    this.city,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.userImage,
    this.isImage,
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

  UserVideos.fromJson(Map<String, dynamic> json) {
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
    videoUrl = json['video_url'];
    country = json['country'];
    city = json['city'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    userName = json['user_name'];
    userImage = json['user_image'];
    sponsorType = json['sponsor_type'];
    isImage = json['is_image'];
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
    data['video_url'] = this.videoUrl;
    data['country'] = this.country;
    data['city'] = this.city;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['user_name'] = this.userName;
    data['user_image'] = this.userImage;
    data['sponsor_type'] = this.sponsorType;
    data['is_image'] = this.isImage;
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

class Countries {
  int? id;
  String? name;
  String? iso3;
  String? capital;
  String? currency;
  String? currencySymbol;

  Countries({
    this.id,
    this.name,
    this.iso3,
    this.capital,
    this.currency,
    this.currencySymbol,
  });

  Countries.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    iso3 = json['iso3'];
    capital = json['capital'];
    currency = json['currency'];
    currencySymbol = json['currency_symbol'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['iso3'] = this.iso3;
    data['capital'] = this.capital;
    data['currency'] = this.currency;
    data['currency_symbol'] = this.currencySymbol;
    return data;
  }
}

class Cities {
  int? id;
  String? name;

  Cities({this.id, this.name});

  Cities.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;

    return data;
  }
}

class AdditionalData {
  int? id;
  String? frontUserId;
  int? businessType;
  String? contactPhone;
  String? contactEmail;
  String? website;
  String? location;
  String? latitude;
  String? longitude;
  int? status;
  String? createdAt;
  String? updatedAt;
  dynamic typeOfAccount;

  AdditionalData({
    this.id,
    this.frontUserId,
    this.businessType,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.location,
    this.latitude,
    this.longitude,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.typeOfAccount,
  });

  AdditionalData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    frontUserId = json['front_user_id'];
    businessType = json['business_type'];
    contactPhone = json['contact_phone'];
    contactEmail = json['contact_email'];
    website = json['website'];
    location = json['location'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    typeOfAccount = json['type_of_account'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['front_user_id'] = this.frontUserId;
    data['business_type'] = this.businessType;
    data['contact_phone'] = this.contactPhone;
    data['contact_email'] = this.contactEmail;
    data['website'] = this.website;
    data['location'] = this.location;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['type_of_account'] = this.typeOfAccount;
    return data;
  }
}
