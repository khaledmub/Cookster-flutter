class NearBusinessModel {
  bool? status;
  List<Accounts>? accounts;

  NearBusinessModel({this.status, this.accounts});

  NearBusinessModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['accounts'] != null) {
      accounts = <Accounts>[];
      json['accounts'].forEach((v) {
        accounts!.add(new Accounts.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.accounts != null) {
      data['accounts'] = this.accounts!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Accounts {
  String? id;
  String? name;
  String? email;
  String? contactEmail;
  String? phone;
  String? contactPhone;
  String? image;
  String? location;
  String? latitude;
  String? longitude;
  double? distance;

  Accounts(
      {this.id,
        this.name,
        this.email,
        this.phone,
        this.contactPhone,
        this.contactEmail,
        this.image,
        this.location,
        this.latitude,
        this.longitude,
        this.distance});

  Accounts.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    contactEmail = json['contact_email'];
    contactPhone = json['contact_phone'];
    image = json['image'];
    location = json['location'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    distance = json['distance'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['contact_email'] = this.contactEmail;
    data['contact_phone'] = this.contactPhone;
    data['image'] = this.image;
    data['location'] = this.location;
    data['latitude'] = this.latitude;
    data['longitude'] = this.longitude;
    data['distance'] = this.distance;
    return data;
  }
}
