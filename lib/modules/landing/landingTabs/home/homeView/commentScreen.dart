import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../appUtils/colorUtils.dart'; // For formatting timestamps

class VideoCommentsScreen extends StatefulWidget {
  final String videoId;
  final String userId;
  final String userImage;

  const VideoCommentsScreen({
    Key? key,
    required this.videoId,
    required this.userId,
    required this.userImage,
  }) : super(key: key);

  @override
  _VideoCommentsScreenState createState() => _VideoCommentsScreenState();
}

class _VideoCommentsScreenState extends State<VideoCommentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, Map<String, dynamic>> _userCache = {};
  String? _replyingToCommentId;
  final FocusNode _textFieldFocusNode = FocusNode();
  String? _replyingToUsername;

  @override
  void dispose() {
    _commentController.dispose();
    _replyControllers.forEach((key, controller) => controller.dispose());
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // Add Comment
  Future<void> _addComment(String text) async {
    if (text.isEmpty) return;

    await _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .add({
          'userId': widget.userId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'likes': [],
        });
    _commentController.clear();
  }

  // Toggle Like for Comment
  Future<void> _toggleCommentLike(String commentId) async {
    final commentRef = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(commentId);

    try {
      // Get the comment document to check current state
      final commentDoc = await commentRef.get();

      // If document doesn't exist, initialize it with userId in likes
      if (!commentDoc.exists) {
        await commentRef.set({
          'likes': [widget.userId], // Initialize with userId in likes array
        });
        return;
      }

      final commentData = commentDoc.data() as Map<String, dynamic>;
      final List<dynamic> likes = commentData['likes'] ?? [];
      final bool isLiked = likes.contains(widget.userId);

      // Toggle like based on whether user has already liked
      await commentRef.update({
        'likes':
            isLiked
                ? FieldValue.arrayRemove([widget.userId])
                : FieldValue.arrayUnion([widget.userId]),
      });
    } catch (e) {
      // Handle error (e.g., log it or show a message)
      rethrow;
    }
  }

  // Add Reply to a Comment
  Future<void> _addReply(String commentId, String text) async {
    if (text.isEmpty) return;

    await _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
          'userId': widget.userId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'likes': [],
        });

    _replyControllers[commentId]?.clear();
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
      _textFieldFocusNode.unfocus();
    });
  }

  // Track in-progress operations with Completer objects
  final Map<String, Completer<void>> _pendingOperations = {};

  Future<void> _toggleReplyLike(String commentId, String replyId) async {
    final replyRef = _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    try {
      // Get the reply document to check current state
      final replyDoc = await replyRef.get();

      // If document doesn't exist, initialize it with userId in likes
      if (!replyDoc.exists) {
        await replyRef.set({
          'likes': [widget.userId], // Initialize with userId in likes array
        });
        return;
      }

      final replyData = replyDoc.data() as Map<String, dynamic>;
      final List<dynamic> likes = replyData['likes'] ?? [];
      final bool isLiked = likes.contains(widget.userId);

      // Toggle like based on whether user has already liked
      await replyRef.update({
        'likes':
            isLiked
                ? FieldValue.arrayRemove([widget.userId])
                : FieldValue.arrayUnion([widget.userId]),
      });
    } catch (e) {
      // Handle error (e.g., log it or show a message)
      rethrow;
    }
  }

  // Fetch user data with caching
  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData =
        userDoc.exists
            ? userDoc.data() as Map<String, dynamic>
            : {'name': 'Unknown'};
    _userCache[userId] = userData;
    return userData;
  }

  // Format timestamp to Instagram-like format (e.g., "a moment ago")
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'just now';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'a moment ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      // Start at 80% of the screen height
      minChildSize: 0.3,
      // Minimum size when dragged down
      maxChildSize: 0.9,
      // Maximum size when dragged up
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: true, // Ensure keyboard pushes content up
            body: Column(
              children: [
                // Header with drag handle and title
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Column(
                    children: [
                      Container(
                        width: 40.w,
                        height: 5.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Text(
                              'Comments'.tr,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade300,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(CupertinoIcons.xmark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Comments List (Real-Time)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        _firestore
                            .collection('videos')
                            .doc(widget.videoId)
                            .collection('comments')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return Center(child: CircularProgressIndicator());
                      final comments = snapshot.data!.docs;

                      return ListView.separated(
                        controller: scrollController,
                        // Attach the scroll controller
                        itemCount: comments.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                              indent: 16.w,
                              endIndent: 16.w,
                            ),
                        // Add divider between comments
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final commentData =
                              comment.data() as Map<String, dynamic>;
                          final isLiked =
                              (commentData['likes'] as List<dynamic>? ?? [])
                                  .contains(widget.userId);
                          final userId = commentData['userId'] as String;
                          final timestamp =
                              commentData['timestamp'] as Timestamp?;

                          if (!_replyControllers.containsKey(comment.id)) {
                            _replyControllers[comment.id] =
                                TextEditingController();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Comment Row
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Profile Picture
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _fetchUserData(userId),
                                      builder: (context, userSnapshot) {
                                        if (!userSnapshot.hasData) {
                                          return CircleAvatar(
                                            radius: 16.r,
                                            child: Icon(
                                              Icons.person,
                                              size: 16.sp,
                                            ),
                                          );
                                        }
                                        final userData = userSnapshot.data!;
                                        final name =
                                            userData['name'] ?? 'Unknown';
                                        final profileImage =
                                            userData['image'] as String?;

                                        return CircleAvatar(
                                          radius: 16.r,
                                          backgroundImage:
                                              profileImage != null
                                                  ? NetworkImage(
                                                    '${Common.profileImage}/$profileImage',
                                                  )
                                                  : null,
                                          child:
                                              profileImage == null
                                                  ? Text(
                                                    name[0],
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                    ),
                                                  )
                                                  : null,
                                        );
                                      },
                                    ),
                                    SizedBox(width: 12.w),
                                    // Username, Comment Text, and Timestamp
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              // Username
                                              FutureBuilder<
                                                Map<String, dynamic>
                                              >(
                                                future: _fetchUserData(userId),
                                                builder: (
                                                  context,
                                                  userSnapshot,
                                                ) {
                                                  if (!userSnapshot.hasData) {
                                                    return Text('Loading...');
                                                  }
                                                  final userData =
                                                      userSnapshot.data!;
                                                  final name =
                                                      userData['name'] ??
                                                      'Unknown';

                                                  return Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                      fontSize: 14.sp,
                                                    ),
                                                  );
                                                },
                                              ),
                                              Spacer(),
                                              // Timestamp
                                              Text(
                                                _formatTimestamp(timestamp),
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          // Comment Text (below username)
                                          Text(
                                            commentData['text'] ?? 'No text',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14.sp,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap:
                                                    () => _toggleCommentLike(
                                                      comment.id,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      color:
                                                          isLiked
                                                              ? Colors.red
                                                              : Colors.grey,
                                                      size: 16.sp,
                                                    ),

                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                      ),
                                                      child: Text(
                                                        '${commentData['likes']?.length ?? 0} ${commentData['likes']?.length == 1 ? 'Like' : 'Likes'}',
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 16.w),
                                              GestureDetector(
                                                onTap: () async {
                                                  final userData =
                                                      await _fetchUserData(
                                                        userId,
                                                      );
                                                  final username =
                                                      userData['name'] ??
                                                      'Unknown';
                                                  setState(() {
                                                    _replyingToCommentId =
                                                        comment.id;
                                                    _replyingToUsername =
                                                        username;
                                                    _replyControllers[comment
                                                            .id]
                                                        ?.clear();
                                                    FocusScope.of(
                                                      context,
                                                    ).requestFocus(
                                                      _textFieldFocusNode,
                                                    );
                                                  });
                                                },
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.reply),
                                                    Text(
                                                      'Reply',
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Reply Count and Replies List
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    _firestore
                                        .collection('videos')
                                        .doc(widget.videoId)
                                        .collection('comments')
                                        .doc(comment.id)
                                        .collection('replies')
                                        .orderBy('timestamp', descending: false)
                                        .snapshots(),
                                builder: (context, replySnapshot) {
                                  if (!replySnapshot.hasData)
                                    return SizedBox.shrink();
                                  final replies = replySnapshot.data!.docs;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (replies.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: 60.w,
                                            bottom: 4.h,
                                          ),
                                          child: Text(
                                            '${replies.length} reply',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: 44.w,
                                          right: 16,
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          itemCount: replies.length,
                                          itemBuilder: (context, replyIndex) {
                                            final reply = replies[replyIndex];
                                            final replyData =
                                                reply.data()
                                                    as Map<String, dynamic>;
                                            final replyUserId =
                                                replyData['userId'] as String;
                                            final isReplyLiked =
                                                (replyData['likes']
                                                            as List<dynamic>? ??
                                                        [])
                                                    .contains(widget.userId);
                                            final replyTimestamp =
                                                replyData['timestamp']
                                                    as Timestamp?;

                                            return Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 2.h,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Profile Picture
                                                  FutureBuilder<
                                                    Map<String, dynamic>
                                                  >(
                                                    future: _fetchUserData(
                                                      replyUserId,
                                                    ),
                                                    builder: (
                                                      context,
                                                      userSnapshot,
                                                    ) {
                                                      if (!userSnapshot
                                                          .hasData) {
                                                        return CircleAvatar(
                                                          radius: 16.r,
                                                          child: Icon(
                                                            Icons.person,
                                                            size: 16.sp,
                                                          ),
                                                        );
                                                      }
                                                      final userData =
                                                          userSnapshot.data!;
                                                      final name =
                                                          userData['name'] ??
                                                          'Unknown';
                                                      final profileImage =
                                                          userData['image']
                                                              as String?;

                                                      return CircleAvatar(
                                                        radius: 16.r,
                                                        backgroundImage:
                                                            profileImage != null
                                                                ? NetworkImage(
                                                                  '${Common.profileImage}/$profileImage',
                                                                )
                                                                : null,
                                                        child:
                                                            profileImage == null
                                                                ? Text(
                                                                  name[0],
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                )
                                                                : null,
                                                      );
                                                    },
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  // Username, Reply Text, and Timestamp
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            // Username
                                                            FutureBuilder<
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >
                                                            >(
                                                              future:
                                                                  _fetchUserData(
                                                                    replyUserId,
                                                                  ),
                                                              builder: (
                                                                context,
                                                                userSnapshot,
                                                              ) {
                                                                if (!userSnapshot
                                                                    .hasData) {
                                                                  return Text(
                                                                    'Loading...',
                                                                  );
                                                                }
                                                                final userData =
                                                                    userSnapshot
                                                                        .data!;
                                                                final name =
                                                                    userData['name'] ??
                                                                    'Unknown';

                                                                return Text(
                                                                  name,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        Colors
                                                                            .black,
                                                                    fontSize:
                                                                        14.sp,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            Spacer(),
                                                            // Timestamp
                                                            Text(
                                                              _formatTimestamp(
                                                                replyTimestamp,
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 12.sp,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 4.h),
                                                        // Reply Text (below username)
                                                        Text(
                                                          replyData['text'] ??
                                                              'No text',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 14.sp,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4.h),
                                                        GestureDetector(
                                                          onTap:
                                                              () =>
                                                                  _toggleReplyLike(
                                                                    comment.id,
                                                                    reply.id,
                                                                  ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                isReplyLiked
                                                                    ? Icons
                                                                        .favorite
                                                                    : Icons
                                                                        .favorite_border,
                                                                color:
                                                                    isReplyLiked
                                                                        ? Colors
                                                                            .red
                                                                        : Colors
                                                                            .grey,
                                                                size: 16.sp,
                                                              ),

                                                              Padding(
                                                                padding:
                                                                    EdgeInsets.only(
                                                                      left: 4.w,
                                                                    ),
                                                                child: Text(
                                                                  '${replyData['likes']?.length ?? 0} Like',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                  ),
                                                                ),
                                                              ),

                                                              SizedBox(
                                                                width: 16.w,
                                                              ),
                                                              GestureDetector(
                                                                onTap: () async {
                                                                  final userData =
                                                                      await _fetchUserData(
                                                                        userId,
                                                                      );
                                                                  final username =
                                                                      userData['name'] ??
                                                                      'Unknown';
                                                                  setState(() {
                                                                    _replyingToCommentId =
                                                                        comment
                                                                            .id;
                                                                    _replyingToUsername =
                                                                        username;
                                                                    _replyControllers[comment
                                                                            .id]
                                                                        ?.clear();
                                                                    FocusScope.of(
                                                                      context,
                                                                    ).requestFocus(
                                                                      _textFieldFocusNode,
                                                                    );
                                                                  });
                                                                },
                                                                child: Row(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .reply,
                                                                    ),
                                                                    Text(
                                                                      'Reply',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            12.sp,
                                                                        color:
                                                                            Colors.grey,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                // Add Comment/Reply Input (Fixed at Bottom)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show "Reply to: [Username]" with a cross icon if replying
                      if (_replyingToCommentId != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8.h, left: 16.w),
                          child: Row(
                            children: [
                              Text(
                                'Reply to: $_replyingToUsername',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyingToCommentId = null;
                                    _replyingToUsername = null;
                                    _textFieldFocusNode.unfocus();
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // User Avatar
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: Colors.grey[200],
                            child: CachedNetworkImage(
                              imageUrl:
                                  '${Common.profileImage}/${widget.userImage}',
                              imageBuilder:
                                  (context, imageProvider) => CircleAvatar(
                                    radius: 20.r,
                                    backgroundImage: imageProvider,
                                  ),
                              placeholder:
                                  (context, url) => Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => CircleAvatar(
                                    radius: 20.r,
                                    backgroundImage: const AssetImage(
                                      "assets/images/logo.png",
                                    ),
                                  ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // TextField Container
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.only(
                                left:
                                    Get.locale?.languageCode == 'ar' ? 0 : 16.w,
                                right:
                                    Get.locale?.languageCode == 'ar' ? 16.w : 0,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(50.r),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _replyingToCommentId == null
                                              ? _commentController
                                              : _replyControllers[_replyingToCommentId],
                                      focusNode: _textFieldFocusNode,
                                      decoration: InputDecoration(
                                        hintText:
                                            _replyingToCommentId == null
                                                ? 'write_a_comment'.tr
                                                : 'Write a reply...'.tr,
                                        border: InputBorder.none,
                                      ),
                                      onSubmitted: (value) {
                                        if (value.trim().isNotEmpty) {
                                          if (_replyingToCommentId == null) {
                                            _addComment(
                                              _commentController.text,
                                            );
                                          } else {
                                            _addReply(
                                              _replyingToCommentId!,
                                              _replyControllers[_replyingToCommentId]!
                                                  .text,
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      if (_replyingToCommentId == null) {
                                        _addComment(_commentController.text);
                                      } else {
                                        _addReply(
                                          _replyingToCommentId!,
                                          _replyControllers[_replyingToCommentId]!
                                              .text,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ColorUtils.darkBrown,
                                      ),
                                      child: SvgPicture.asset(
                                        "assets/icons/send.svg",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Function to show the comments as a bottom sheet
void showCommentsBottomSheetNew(
  BuildContext context,
  String videoId,
  String userId,
  String userImage,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => SafeArea(
          child: VideoCommentsScreen(
            videoId: videoId,
            userId: userId,
            userImage: userImage,
          ),
        ),
  );
}
