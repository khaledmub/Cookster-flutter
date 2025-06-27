import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

String token =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGlrZXkiOiJjNTRlYmI0Ni1jZWI5LTQ0N2EtOTM5OS02OGI2OTA4ZDU1ZjgiLCJwZXJtaXNzaW9ucyI6WyJhbGxvd19qb2luIl0sImlhdCI6MTc1MDg0ODkxNCwiZXhwIjoxNzUxNDUzNzE0fQ.YYaERyioPdxu2s84NKyZ1Hn0jIN0i_ZNoLqdZp5M3pU";

// Set to track ongoing like operations to prevent rapid tapping
final Set<String> _ongoingLikeOperations = <String>{};

Future<String> createLivestream() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');

  print('User ID from SharedPreferences: $userId');

  if (userId == null) {
    throw Exception('User ID not found in SharedPreferences');
  }

  final Uri getLivestreamIdUrl = Uri.parse(
    'https://api.videosdk.live/v2/rooms',
  );
  final http.Response liveStreamIdResponse = await http.post(
    getLivestreamIdUrl,
    headers: {"Authorization": token, "Content-Type": "application/json"},
    body: jsonEncode({}),
  );

  if (liveStreamIdResponse.statusCode != 200) {
    throw Exception(json.decode(liveStreamIdResponse.body)["error"]);
  }

  var liveStreamID = json.decode(liveStreamIdResponse.body)['roomId'];

  // Add livestream to Firestore with userId, comments, likes, likedBy, and status
  try {
    await FirebaseFirestore.instance
        .collection('liveVideos')
        .doc(liveStreamID)
        .set({
          'livestreamId': liveStreamID,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'joinedUsersCount': 0,
          'comments': [],
          'likes': 0,
          'likedBy': [], // Initialize empty array for users who liked
          'status': 'active',
        });
  } catch (e) {
    throw Exception('Failed to save livestream to Firestore: $e');
  }

  return liveStreamID;
}

Future<void> endLivestream(String liveStreamId) async {
  try {
    await FirebaseFirestore.instance
        .collection('liveVideos')
        .doc(liveStreamId)
        .update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'joinedUsersCount': 0,
          'likes': 0, // Reset likes when ending
          'likedBy': [], // Clear likedBy array
        });
  } catch (e) {
    throw Exception('Failed to end livestream in Firestore: $e');
  }
}

Future<void> incrementJoinedUsersCount(String liveStreamId) async {
  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(liveStreamId);
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Livestream document does not exist');
      }

      int currentCount = snapshot.get('joinedUsersCount') ?? 0;
      transaction.update(docRef, {'joinedUsersCount': currentCount + 1});
    });
  } catch (e) {
    throw Exception('Failed to increment joined users count: $e');
  }
}

Future<void> decrementJoinedUsersCount(String liveStreamId) async {
  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(liveStreamId);
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Livestream document does not exist');
      }

      int currentCount = snapshot.get('joinedUsersCount') ?? 0;
      if (currentCount > 0) {
        transaction.update(docRef, {'joinedUsersCount': currentCount - 1});
      }
    });
  } catch (e) {
    throw Exception('Failed to decrement joined users count: $e');
  }
}

/// Toggle like/unlike functionality with rapid tap prevention
/// Returns true if liked, false if unliked
Future<bool> toggleLikeLivestream(String liveStreamId) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');

  print("Here printing the userId: $userId");

  if (userId == null) {
    throw Exception('User ID not found in SharedPreferences');
  }

  // Create unique key for this user-livestream combination
  final String operationKey = '${userId}_$liveStreamId';

  print("here printing the operationKey: $operationKey");

  // Check if operation is already in progress
  if (_ongoingLikeOperations.contains(operationKey)) {
    throw Exception('Like operation already in progress');
  }

  // Add to ongoing operations
  _ongoingLikeOperations.add(operationKey);

  try {
    bool isLiked = false;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(liveStreamId);
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Livestream document does not exist');
      }

      List<dynamic> likedBy = snapshot.get('likedBy') ?? [];
      int currentLikes = snapshot.get('likes') ?? 0;

      if (likedBy.contains(userId)) {
        // User has already liked, so unlike
        if (currentLikes > 0) {
          transaction.update(docRef, {
            'likes': currentLikes - 1,
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        }
        isLiked = false;
      } else {
        // User hasn't liked, so like
        transaction.update(docRef, {
          'likes': currentLikes + 1,
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        isLiked = true;
      }
    });

    return isLiked;
  } catch (e) {
    throw Exception('Failed to toggle like on livestream: $e');
  } finally {
    // Always remove from ongoing operations
    _ongoingLikeOperations.remove(operationKey);
  }
}

/// Check if current user has already liked the livestream
Future<bool> hasUserLikedLivestream(String liveStreamId) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');

  if (userId == null) {
    return false;
  }

  try {
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('liveVideos')
            .doc(liveStreamId)
            .get();

    if (!snapshot.exists) {
      return false;
    }

    List<dynamic> likedBy = snapshot.get('likedBy') ?? [];
    return likedBy.contains(userId);
  } catch (e) {
    print('Error checking like status: $e');
    return false;
  }
}

Future<void> addComment(String liveStreamId, String commentText) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');

  if (userId == null) {
    throw Exception('User ID not found in SharedPreferences');
  }

  try {
    // Fetch user details from users collection
    DocumentSnapshot userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userSnapshot.exists) {
      throw Exception('User document does not exist');
    }

    String userName = userSnapshot.get('name') ?? 'Anonymous';
    String profilePicture = userSnapshot.get('image') ?? '';

    // Create the comment object with client-side timestamp
    Map<String, dynamic> comment = {
      'userId': userId,
      'name': userName,
      'profilePicture': profilePicture,
      'comment': commentText,
      'timestamp': DateTime.now().toIso8601String(), // Client-side timestamp
    };

    // Reference to the livestream document
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('liveVideos')
        .doc(liveStreamId);

    // Check if document exists
    DocumentSnapshot snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('Livestream document does not exist');
    }

    print("Adding comment to Firestore");

    // Add the comment to the comments array
    await docRef.update({
      'comments': FieldValue.arrayUnion([comment]),
    });

    print("Comment added successfully");
  } catch (e, stackTrace) {
    print('Error adding comment: $e');
    print('Stack trace: $stackTrace');
    throw Exception('Failed to add comment to livestream: ${e.toString()}');
  }
}
