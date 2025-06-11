class RegistrationSettings {
  bool? status;
  List<Entities>? entities;
  List<Countries>? countries;
  BusinessTypes? businessTypes;
  BusinessTypes? typeOfAccounts;


  RegistrationSettings({
    this.status,
    this.entities,
    this.countries,
    this.businessTypes,
    this.typeOfAccounts
  });

  RegistrationSettings.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['entities'] != null) {
      entities = <Entities>[];
      json['entities'].forEach((v) {
        entities!.add(new Entities.fromJson(v));
      });
    }
    if (json['countries'] != null) {
      countries = <Countries>[];
      json['countries'].forEach((v) {
        countries!.add(new Countries.fromJson(v));
      });
    }
    businessTypes =
        json['business_types'] != null
            ? new BusinessTypes.fromJson(json['business_types'])
            : null;
    typeOfAccounts =
    json['type_of_account'] != null
        ? new BusinessTypes.fromJson(json['type_of_account'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.entities != null) {
      data['entities'] = this.entities!.map((v) => v.toJson()).toList();
    }
    if (this.countries != null) {
      data['countries'] = this.countries!.map((v) => v.toJson()).toList();
    }
    if (this.businessTypes != null) {
      data['business_types'] = this.businessTypes!.toJson();
    }
    if (this.typeOfAccounts != null) {
      data['type_of_account'] = this.typeOfAccounts!.toJson();
    }
    return data;
  }
}

class Entities {
  int? id;
  String? name;
  dynamic isSubscriptionRequired;
  dynamic isSponsored;

  Entities({this.id, this.name, this.isSubscriptionRequired, this.isSponsored});

  Entities.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    isSubscriptionRequired = json['subscription_required'];
    isSponsored = json['is_sponsored'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['subscription_required'] = this.isSubscriptionRequired;
    data['is_sponsored'] = this.isSponsored;
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

