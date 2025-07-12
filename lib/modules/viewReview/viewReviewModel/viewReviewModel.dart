class AllReviewList {
  bool? status;
  List<UserReviews>? userReviews;
  ReviewCounters? reviewCounters;

  AllReviewList({this.status, this.userReviews, this.reviewCounters});

  AllReviewList.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['user_reviews'] != null) {
      userReviews = <UserReviews>[];
      json['user_reviews'].forEach((v) {
        userReviews!.add(UserReviews.fromJson(v));
      });
    }
    reviewCounters = json['review_counters'] != null
        ? ReviewCounters.fromJson(json['review_counters'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (userReviews != null) {
      data['user_reviews'] = userReviews!.map((v) => v.toJson()).toList();
    }
    if (reviewCounters != null) {
      data['review_counters'] = reviewCounters!.toJson();
    }
    return data;
  }
}

class UserReviews {
  String? id;
  int? systemId;
  String? reviewerId;
  String? reviewedUserId;
  double? rating;
  String? review;
  int? isVisible;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? reviewerName;
  String? reviewerImage;
  String? utcTime;

  UserReviews({
    this.id,
    this.systemId,
    this.reviewerId,
    this.reviewedUserId,
    this.rating,
    this.review,
    this.isVisible,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.reviewerName,
    this.reviewerImage,
    this.utcTime,
  });

  UserReviews.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    systemId = json['system_id'];
    reviewerId = json['reviewer_id'];
    reviewedUserId = json['reviewed_user_id'];
    rating = json['rating']?.toDouble(); // Ensure rating is parsed as double
    review = json['review'];
    isVisible = json['is_visible'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    reviewerName = json['reviewer_name'];
    reviewerImage = json['reviewer_image'];
    utcTime = json['human_utc_date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['system_id'] = systemId;
    data['reviewer_id'] = reviewerId;
    data['reviewed_user_id'] = reviewedUserId;
    data['rating'] = rating;
    data['review'] = review;
    data['is_visible'] = isVisible;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['reviewer_name'] = reviewerName;
    data['reviewer_image'] = reviewerImage;
    data['human_utc_date'] = utcTime;
    return data;
  }
}

class ReviewCounters {
  int? totalReviews;
  double? averageRating;
  Ratings? ratings;

  ReviewCounters({this.totalReviews, this.averageRating, this.ratings});

  ReviewCounters.fromJson(Map<String, dynamic> json) {
    totalReviews = json['total_reviews'];
    averageRating = json['average_rating']?.toDouble(); // Ensure double
    ratings = json['ratings'] != null ? Ratings.fromJson(json['ratings']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_reviews'] = totalReviews;
    data['average_rating'] = averageRating;
    if (ratings != null) {
      data['ratings'] = ratings!.toJson();
    }
    return data;
  }
}

class Ratings {
  int? one;
  int? two;
  int? three;
  int? four;
  int? five;

  Ratings({this.one, this.two, this.three, this.four, this.five});

  Ratings.fromJson(Map<String, dynamic> json) {
    one = json['1'];
    two = json['2'];
    three = json['3'];
    four = json['4'];
    five = json['5'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['1'] = one;
    data['2'] = two;
    data['3'] = three;
    data['4'] = four;
    data['5'] = five;
    return data;
  }
}