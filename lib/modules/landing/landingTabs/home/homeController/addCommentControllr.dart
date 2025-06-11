import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class VideoCommentsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final isLoading = false.obs;

  // Comments List
  var comments = <QueryDocumentSnapshot>[].obs;

  // Video likes count
  var videoLikes = 0.obs;

  // Pagination variables
  DocumentSnapshot? _lastCommentDoc;
  final int _commentsPerPage = 10;
  StreamSubscription? _commentsSubscription;

  @override
  void onClose() {
    _commentsSubscription?.cancel();
    super.onClose();
  }

  // Fetch Video Likes (One-time fetch instead of stream)
  Future<void> fetchVideoLikes(String videoId) async {
    try {
      final snapshot = await _firestore.collection('videos').doc(videoId).get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        videoLikes.value = data['likeCount'] ?? 0;
      } else {
        videoLikes.value = 0;
      }
    } catch (e) {
      print('Error fetching video likes: $e');
      videoLikes.value = 0;
    }
  }

  // Check if video is liked by user (One-time check instead of stream)
  Future<bool> isVideoLikedByUser(String videoId, String userId) async {
    try {
      final snapshot = await _firestore.collection('videos').doc(videoId).get();
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> likes = data['likes'] ?? [];
      return likes.contains(userId);
    } catch (e) {
      print('Error checking video like: $e');
      return false;
    }
  }

  // Toggle Like for a Video
  Future<void> toggleVideoLike(String videoId, String userId) async {
    print("🔄 Function called: toggleVideoLike");
    print("📌 Video ID: $videoId, User ID: $userId");

    final videoRef = _firestore.collection('videos').doc(videoId);

    try {
      final videoDoc = await videoRef.get();

      // If document doesn't exist, initialize it with the userId in likes
      if (!videoDoc.exists) {
        await videoRef.set({
          'likes': [userId] // Initialize with userId in likes array
        });
        return;
      }

      final videoData = videoDoc.data() as Map<String, dynamic>;
      final List<dynamic> likes = videoData['likes'] ?? [];
      final bool isLiked = likes.contains(userId);

      // Update likes array
      await videoRef.update({
        'likes': isLiked
            ? FieldValue.arrayRemove([userId])
            : FieldValue.arrayUnion([userId]),
      });

      // Count will be derived from the length of likes array in the UI
    } catch (error) {
      print("⚠️ Error toggling like: $error");
      rethrow; // Rethrow to handle errors in the UI if needed
    }
  }

  // Fetch Comments (One-time fetch with pagination)
  Future<void> fetchComments(String videoId, {bool loadMore = false}) async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      Query query = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(_commentsPerPage);

      if (loadMore && _lastCommentDoc != null) {
        query = query.startAfterDocument(_lastCommentDoc!);
      }

      final snapshot = await query.get();
      if (loadMore) {
        comments.addAll(snapshot.docs);
      } else {
        comments.value = snapshot.docs;
      }
      _lastCommentDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    } catch (e) {
      print('Error fetching comments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Optional: Real-time listener (use only if needed)
  void fetchCommentsRealtime(String videoId) {
    if (isLoading.value) return;

    isLoading.value = true;
    _commentsSubscription?.cancel();

    _commentsSubscription = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(_commentsPerPage)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docChanges.isNotEmpty) {
              comments.value = snapshot.docs;
              _lastCommentDoc =
                  snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            }
            isLoading.value = false;
          },
          onError: (error) {
            print('Error fetching comments: $error');
            isLoading.value = false;
          },
        );
  }

  // Add Comment
  Future<void> addComment(String videoId, String userId, String text) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
            'userId': userId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'likeCount': 0,
            'likes': [],
          });
      // Refresh comments manually instead of relying on stream
      await fetchComments(videoId);
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  // Fetch Replies (One-time fetch instead of stream)
  Future<List<QueryDocumentSnapshot>> fetchReplies(
    String videoId,
    String commentId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('videos')
              .doc(videoId)
              .collection('comments')
              .doc(commentId)
              .collection('replies')
              .orderBy('timestamp', descending: true)
              .get();
      return snapshot.docs;
    } catch (e) {
      print('Error fetching replies: $e');
      return [];
    }
  }

  // Add Reply to a Comment
  Future<void> addReply(
    String videoId,
    String commentId,
    String userId,
    String text,
  ) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .add({
            'userId': userId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'likeCount': 0,
            'likes': [],
          });
    } catch (e) {
      print('Error adding reply: $e');
    }
  }

  // Toggle Like for a Comment
  Future<void> toggleCommentLike(
    String videoId,
    String commentId,
    String userId,
  ) async {
    final commentRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId);

    try {
      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return;

      final commentData = commentDoc.data() as Map<String, dynamic>;
      final List<dynamic> likes = commentData['likes'] ?? [];
      final bool isLiked = likes.contains(userId);

      if (isLiked) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
      // Refresh comments manually
      await fetchComments(videoId);
    } catch (e) {
      print('Error toggling comment like: $e');
    }
  }

  // Toggle Like for a Reply
  Future<void> toggleReplyLike(
    String videoId,
    String commentId,
    String replyId,
    String userId,
  ) async {
    final replyRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    try {
      final replyDoc = await replyRef.get();
      if (!replyDoc.exists) return;

      final replyData = replyDoc.data() as Map<String, dynamic>;
      final List<dynamic> likes = replyData['likes'] ?? [];
      final bool isLiked = likes.contains(userId);

      if (isLiked) {
        await replyRef.update({
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await replyRef.update({
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error toggling reply like: $e');
    }
  }

  // Check if user liked a comment
  bool isCommentLikedByUser(DocumentSnapshot comment, String userId) {
    final commentData = comment.data() as Map<String, dynamic>;
    final List<dynamic> likes = commentData['likes'] ?? [];
    return likes.contains(userId);
  }

  // Check if user liked a reply
  bool isReplyLikedByUser(DocumentSnapshot reply, String userId) {
    final replyData = reply.data() as Map<String, dynamic>;
    final List<dynamic> likes = replyData['likes'] ?? [];
    return likes.contains(userId);
  }
}
