class VideoUploadSettings {
  bool? status;
  VideoTypes? videoTypes;
  List<Countries>? countries;

  VideoUploadSettings({this.status, this.videoTypes, this.countries});

  VideoUploadSettings.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    videoTypes =
        json['video_types'] != null
            ? new VideoTypes.fromJson(json['video_types'])
            : null;
    if (json['countries'] != null) {
      countries = <Countries>[];
      json['countries'].forEach((v) {
        countries!.add(new Countries.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.videoTypes != null) {
      data['video_types'] = this.videoTypes!.toJson();
    }
    if (this.countries != null) {
      data['countries'] = this.countries!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class VideoTypes {
  Key? key;
  List<Values>? values;

  VideoTypes({this.key, this.values});

  VideoTypes.fromJson(Map<String, dynamic> json) {
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

class Countries {
  int? id;
  String? name;

  Countries({this.id, this.name});

  Countries.fromJson(Map<String, dynamic> json) {
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
