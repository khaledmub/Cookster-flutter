class SocialResponse {
  bool status;
  List<FFUser> followers;
  List<FFUser> following;

  SocialResponse({
    required this.status,
    required this.followers,
    required this.following,
  });

  factory SocialResponse.fromJson(Map<String, dynamic> json) {
    return SocialResponse(
      status: json['status'] as bool,
      followers: (json['followers'] as List<dynamic>)
          .map((e) => FFUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      following: (json['following'] as List<dynamic>)
          .map((e) => FFUser.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'followers': followers.map((e) => e.toJson()).toList(),
      'following': following.map((e) => e.toJson()).toList(),
    };
  }
}

class FFUser {
  String id;
  String name;
  String email;
  String? image;

  FFUser({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory FFUser.fromJson(Map<String, dynamic> json) {
    return FFUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'image': image,
    };
  }
}