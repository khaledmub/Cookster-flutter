class ChangePlanModel {
  bool? status;
  List<Packages>? packages;

  ChangePlanModel({this.status, this.packages});

  ChangePlanModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['packages'] != null) {
      packages = <Packages>[];
      json['packages'].forEach((v) {
        packages!.add(new Packages.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.packages != null) {
      data['packages'] = this.packages!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Packages {
  String? id;
  int? systemId;
  int? amount;
  int? duration;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? title;
  String? description;

  Packages(
      {this.id,
        this.systemId,
        this.amount,
        this.duration,
        this.status,
        this.createdAt,
        this.updatedAt,
        this.title,
        this.description});

  Packages.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    amount = json['amount'];
    duration = json['duration'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    title = json['title'];
    description = json['description'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['system_id'] = this.systemId;
    data['amount'] = this.amount;
    data['duration'] = this.duration;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['title'] = this.title;
    data['description'] = this.description;
    return data;
  }
}
