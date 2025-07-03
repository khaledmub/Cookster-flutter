class B2BList {
  bool? status;
  B2bAccountsList? b2bAccountsList;

  B2BList({this.status, this.b2bAccountsList});

  B2BList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    b2bAccountsList =
        json['b2b_accounts_list'] != null
            ? B2bAccountsList.fromJson(json['b2b_accounts_list'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (b2bAccountsList != null) {
      data['b2b_accounts_list'] = b2bAccountsList!.toJson();
    }
    return data;
  }
}

class B2bAccountsList {
  Map<String, List<BusinessAccount>> businessTypes = {};

  B2bAccountsList({required this.businessTypes});

  B2bAccountsList.fromJson(Map<String, dynamic> json) {
    json.forEach((key, value) {
      if (value is List) {
        businessTypes[key] = List<BusinessAccount>.from(
          value.map((item) => BusinessAccount.fromJson(item)),
        );
      }
    });
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    businessTypes.forEach((key, value) {
      data[key] = value.map((e) => e.toJson()).toList();
    });
    return data;
  }
}

class BusinessAccount {
  String? id;
  String? name;
  String? email;
  String? phone;
  String? image;
  String? businessTypeName;

  BusinessAccount({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.image,
    this.businessTypeName,
  });

  BusinessAccount.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    image = json['image'];
    businessTypeName = json['business_type_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['email'] = email;
    data['phone'] = phone;
    data['image'] = image;
    data['business_type_name'] = businessTypeName;
    return data;
  }
}
