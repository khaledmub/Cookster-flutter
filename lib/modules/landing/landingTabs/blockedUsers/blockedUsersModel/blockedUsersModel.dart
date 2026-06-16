class BlockedUsersList {
  bool? status;
  List<BlockedUsers>? blockedUsers;

  BlockedUsersList({this.status, this.blockedUsers});

  BlockedUsersList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['blocked_users'] != null) {
      blockedUsers = <BlockedUsers>[];
      json['blocked_users'].forEach((v) {
        blockedUsers!.add(new BlockedUsers.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.blockedUsers != null) {
      data['blocked_users'] =
          this.blockedUsers!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BlockedUsers {
  String? id;
  String? name;
  String? userName;
  String? email;
  dynamic image;

  BlockedUsers({this.id, this.name, this.userName, this.email, this.image});

  BlockedUsers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    userName = json['user_name'];
    email = json['email'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['user_name'] = this.userName;
    data['email'] = this.email;
    data['image'] = this.image;
    return data;
  }
}
