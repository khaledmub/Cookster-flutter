class NotificationModel {
  bool? status;
  List<Notifications>? notifications;

  NotificationModel({this.status, this.notifications});

  NotificationModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['notifications'] != null) {
      notifications = <Notifications>[];
      json['notifications'].forEach((v) {
        notifications!.add(new Notifications.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.notifications != null) {
      data['notifications'] =
          this.notifications!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Notifications {
  int? id;
  int? toType;
  int? frontUserCategory;
  int? type;
  int? pushNotificationId;
  int? readStatus;
  int? status;
  String? createdAt;
  Details? details;

  Notifications(
      {this.id,
        this.toType,
        this.frontUserCategory,
        this.type,
        this.pushNotificationId,
        this.readStatus,
        this.status,
        this.createdAt,
        this.details});

  Notifications.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    toType = json['to_type'];
    frontUserCategory = json['front_user_category'];
    type = json['type'];
    pushNotificationId = json['push_notification_id'];
    readStatus = json['read_status'];
    status = json['status'];
    createdAt = json['created_at'];
    details =
    json['details'] != null ? new Details.fromJson(json['details']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['to_type'] = this.toType;
    data['front_user_category'] = this.frontUserCategory;
    data['type'] = this.type;
    data['push_notification_id'] = this.pushNotificationId;
    data['read_status'] = this.readStatus;
    data['status'] = this.status;
    data['created_at'] = this.createdAt;
    if (this.details != null) {
      data['details'] = this.details!.toJson();
    }
    return data;
  }
}

class Details {
  String? href;
  String? title;
  String? text;
  String? dateTime;

  Details({this.href, this.title, this.text, this.dateTime});

  Details.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    title = json['title'];
    text = json['text'];
    dateTime = json['date_time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    data['title'] = this.title;
    data['text'] = this.text;
    data['date_time'] = this.dateTime;
    return data;
  }
}
