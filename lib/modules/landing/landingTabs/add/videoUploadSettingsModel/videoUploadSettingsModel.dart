class VideoUploadSettings {
  bool? status;
  VideoTypes? videoTypes;
  List<Countries>? countries;

  VideoUploadSettings({this.status, this.videoTypes, this.countries});

  VideoUploadSettings.fromJson(Map<String, dynamic> json) {
    final root = _unwrapPayload(json);
    status = root['status'] as bool? ?? json['status'] as bool?;
    videoTypes = VideoTypes.parse(root['video_types']);
    if (root['countries'] != null) {
      countries = <Countries>[];
      for (final v in root['countries'] as List) {
        if (v is Map) {
          countries!.add(
            Countries.fromJson(Map<String, dynamic>.from(v)),
          );
        }
      }
    }
  }

  /// Flat list of selectable video types (handles legacy and array API shapes).
  List<Values> get videoTypeList => videoTypes?.values ?? const [];

  static Map<String, dynamic> _unwrapPayload(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
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
      for (final v in json['values'] as List) {
        if (v is Map) {
          values!.add(Values.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }
  }

  /// Supports `video_types` as `{ key, values }` or a plain array from the API.
  static VideoTypes? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final list = <Values>[];
      for (final item in raw) {
        if (item is Map) {
          list.add(Values.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return VideoTypes(values: list);
    }
    if (raw is Map<String, dynamic>) {
      return VideoTypes.fromJson(raw);
    }
    if (raw is Map) {
      return VideoTypes.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
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
    final rawId = json['id'];
    if (rawId is int) {
      id = rawId;
    } else if (rawId != null) {
      id = int.tryParse(rawId.toString());
    }
    keyId = json['key_id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    name =
        json['name']?.toString() ??
        json['title']?.toString() ??
        json['label']?.toString() ??
        json['type_name']?.toString();
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
