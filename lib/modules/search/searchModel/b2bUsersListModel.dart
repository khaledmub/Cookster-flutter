class B2BUsersList {
  bool? status;
  List<B2bAccountsList>? b2bAccountsList;

  B2BUsersList({this.status, this.b2bAccountsList});

  B2BUsersList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['b2b_accounts_list'] != null) {
      b2bAccountsList = <B2bAccountsList>[];
      json['b2b_accounts_list'].forEach((v) {
        b2bAccountsList!.add(new B2bAccountsList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.b2bAccountsList != null) {
      data['b2b_accounts_list'] =
          this.b2bAccountsList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class B2bAccountsList {
  String? id;
  String? name;
  String? email;
  String? phone;
  dynamic image;

  B2bAccountsList({this.id, this.name, this.email, this.phone, this.image});

  B2bAccountsList.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['image'] = this.image;
    return data;
  }
}
