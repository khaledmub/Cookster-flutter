import 'package:cloud_firestore/cloud_firestore.dart';

import 'video_view_tracker.dart';

/// Parsed denormalized stats from a `videos/{id}` Firestore document.
class ReelVideoStats {
  const ReelVideoStats({
    required this.likes,
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
    required this.averageRating,
  });

  final List<dynamic> likes;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final double averageRating;

  static const empty = ReelVideoStats(
    likes: [],
    likeCount: 0,
    viewCount: 0,
    commentCount: 0,
    averageRating: 0,
  );

  factory ReelVideoStats.fromDoc(DocumentSnapshot? snapshot) {
    if (snapshot == null || !snapshot.exists) {
      return empty;
    }
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final likes = List<dynamic>.from(data['likes'] ?? []);
    final denormLikes = data['likeCount'];
    final likeCount = denormLikes is num
        ? denormLikes.toInt()
        : likes.length;
    final denormComments = data['commentCount'];
    final commentCount = denormComments is num ? denormComments.toInt() : 0;
    final rating = data['averageRating'] ?? data['average_rating'];
    final averageRating = rating is num ? rating.toDouble() : 0.0;
    return ReelVideoStats(
      likes: likes,
      likeCount: likeCount,
      viewCount: VideoViewTracker.resolveDisplayCount(data),
      commentCount: commentCount,
      averageRating: averageRating,
    );
  }

  static String formatCount(int count) {
    if (count > 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
