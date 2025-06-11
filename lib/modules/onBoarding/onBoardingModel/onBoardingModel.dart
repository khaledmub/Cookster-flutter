class OnBoardingModel {
  bool? status;
  List<Screens>? screens;

  OnBoardingModel({this.status, this.screens});

  OnBoardingModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['screens'] != null) {
      screens = <Screens>[];
      json['screens'].forEach((v) {
        screens!.add(new Screens.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.screens != null) {
      data['screens'] = this.screens!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Screens {
  int? id;
  String? image;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? title;
  String? subTitle;
  String? shortDescription;

  Screens({
    this.id,
    this.image,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.title,
    this.subTitle,
    this.shortDescription,
  });

  Screens.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    image = json['image'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    title = json['title'];
    subTitle = json['sub_title'];
    shortDescription = json['short_description'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['image'] = this.image;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['title'] = this.title;
    data['sub_title'] = this.subTitle;
    data['short_description'] = this.shortDescription;
    return data;
  }
}
