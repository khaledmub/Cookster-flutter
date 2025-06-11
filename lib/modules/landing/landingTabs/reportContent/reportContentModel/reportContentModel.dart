class ReportContent {
  bool? status;
  List<Categories>? categories;

  ReportContent({this.status, this.categories});

  ReportContent.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['categories'] != null) {
      categories = <Categories>[];
      json['categories'].forEach((v) {
        categories!.add(new Categories.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.categories != null) {
      data['categories'] = this.categories!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Categories {
  String? id;
  int? systemId;
  int? type;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? name;

  Categories(
      {this.id,
        this.systemId,
        this.type,
        this.status,
        this.createdAt,
        this.updatedAt,
        this.name});

  Categories.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    type = json['type'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['type'] = this.type;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['name'] = this.name;
    return data;
  }
}
