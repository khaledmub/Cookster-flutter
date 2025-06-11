class SiteSettings {
  bool? status;
  Settings? settings;

  SiteSettings({this.status, this.settings});

  SiteSettings.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    settings =
        json['settings'] != null
            ? new Settings.fromJson(json['settings'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.settings != null) {
      data['settings'] = this.settings!.toJson();
    }
    return data;
  }
}

class Settings {
  String? email;
  String? phone;
  String? address;
  String? facebook;
  String? twitter;
  String? instagram;
  String? linkedin;
  dynamic basicSponsoredVideoPrice;
  dynamic premiumSponsoredVideoPrice;
  dynamic sponsorVideoDiscount;
  dynamic allowGeneralVideos;
  dynamic allowFollowingVideos;
  dynamic currencySymbol;

  Settings({
    this.email,
    this.phone,
    this.address,
    this.facebook,
    this.twitter,
    this.instagram,
    this.linkedin,
    this.basicSponsoredVideoPrice,
    this.premiumSponsoredVideoPrice,
    this.sponsorVideoDiscount,
    this.currencySymbol,

    this.allowGeneralVideos,
    this.allowFollowingVideos,
  });

  Settings.fromJson(Map<String, dynamic> json) {
    email = json['email'];
    phone = json['phone'];
    address = json['address'];
    facebook = json['facebook'];
    twitter = json['twitter'];
    instagram = json['instagram'];
    linkedin = json['linkedin'];
    basicSponsoredVideoPrice = json['basic_sponsored_video_price'];
    premiumSponsoredVideoPrice = json['premium_sponsored_video_price'];
    sponsorVideoDiscount = json['sponsor_video_discount'];
    allowGeneralVideos = json['allow_general_videos'];
    currencySymbol = json['currency_symbol'];
    allowFollowingVideos = json['allow_following_videos'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['address'] = this.address;
    data['facebook'] = this.facebook;
    data['twitter'] = this.twitter;
    data['instagram'] = this.instagram;
    data['linkedin'] = this.linkedin;
    data['basic_sponsored_video_price'] = this.basicSponsoredVideoPrice;
    data['premium_sponsored_video_price'] = this.premiumSponsoredVideoPrice;
    data['sponsor_video_discount'] = this.sponsorVideoDiscount;
    data['allow_general_videos'] = this.allowGeneralVideos;
    data['currency_symbol'] = this.currencySymbol;
    data['allow_following_videos'] = this.allowFollowingVideos;
    return data;
  }
}
