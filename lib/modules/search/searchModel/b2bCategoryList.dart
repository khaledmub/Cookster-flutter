class B2BCategoryModel {
  bool? status;
  BusinessTypes? businessTypes;

  B2BCategoryModel({this.status, this.businessTypes});

  B2BCategoryModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    businessTypes = json['business_types'] != null
        ? new BusinessTypes.fromJson(json['business_types'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.businessTypes != null) {
      data['business_types'] = this.businessTypes!.toJson();
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
  int? id;
  int? keyId;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? name;

  Values(
      {this.id,
        this.keyId,
        this.status,
        this.createdAt,
        this.updatedAt,
        this.name});

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
