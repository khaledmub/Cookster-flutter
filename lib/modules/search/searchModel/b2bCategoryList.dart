class B2BCategoryModel {
  bool? status;
  List<BusinessTypes>? businessTypes;

  B2BCategoryModel({this.status, this.businessTypes});

  B2BCategoryModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['business_types'] != null) {
      businessTypes = <BusinessTypes>[];
      json['business_types'].forEach((v) {
        businessTypes!.add(new BusinessTypes.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.businessTypes != null) {
      data['business_types'] =
          this.businessTypes!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BusinessTypes {
  int? id;
  String? name;

  BusinessTypes({this.id, this.name});

  BusinessTypes.fromJson(Map<String, dynamic> json) {
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
