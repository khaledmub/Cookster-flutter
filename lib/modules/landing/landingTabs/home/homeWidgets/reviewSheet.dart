import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../appUtils/apiEndPoints.dart';
import '../../../../../appUtils/colorUtils.dart';

class VideoReviewsScreen extends StatefulWidget {
  final String videoId;
  final String userId;
  final String userImage;

  const VideoReviewsScreen({
    Key? key,
    required this.videoId,
    required this.userId,
    required this.userImage,
  }) : super(key: key);

  @override
  _VideoReviewsScreenState createState() => _VideoReviewsScreenState();
}

class _VideoReviewsScreenState extends State<VideoReviewsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reviewController = TextEditingController();
  final Map<String, Map<String, dynamic>> _userCache = {};
  final FocusNode _textFieldFocusNode = FocusNode();
  late Future<bool> _hasSubmittedReviewFuture; // Store the future for review check
  double _rating = 0.0;

  @override
  void initState() {
    super.initState();
    _hasSubmittedReviewFuture = _checkExistingReview(); // Initialize the future
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // Check if user has already submitted a review
  Future<bool> _checkExistingReview() async {
    final querySnapshot = await _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('reviews')
        .where('userId', isEqualTo: widget.userId)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  // Add Review
  Future<void> _addReview(String? text) async {
    if (_rating == 0.0) return;

    await _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('reviews')
        .add({
      'userId': widget.userId,
      'text': text?.trim().isEmpty ?? true ? '' : text,
      'rating': _rating,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _hasSubmittedReviewFuture = Future.value(true); // Update the future
      _reviewController.clear();
      _rating = 0.0;
      _textFieldFocusNode.unfocus();
    });
  }

  // Fetch user data with caching
  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData =
    userDoc.exists ? userDoc.data() as Map<String, dynamic> : {'name': 'Unknown'};
    _userCache[userId] = userData;
    return userData;
  }

  // Calculate average rating
  Stream<double> _getAverageRating() {
    return _firestore
        .collection('videos')
        .doc(widget.videoId)
        .collection('reviews')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0.0;
      double totalRating = 0.0;
      for (var doc in snapshot.docs) {
        totalRating += (doc['rating'] as num?)?.toDouble() ?? 0.0;
      }
      return totalRating / snapshot.docs.length;
    });
  }

  // Format timestamp (e.g., "a moment ago")
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'just_now'.tr;
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'a_moment_ago'.tr;
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
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<bool>(
          future: _hasSubmittedReviewFuture,
          builder: (context, snapshot) {
            // Show CircularProgressIndicator while waiting for review check
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            // Handle error case (optional, for robustness)
            if (snapshot.hasError) {
              return Center(
                child: Text('error_loading_reviews'.tr),
              );
            }

            final hasSubmittedReview = snapshot.data ?? false;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Scaffold(
                backgroundColor: Colors.white,
                resizeToAvoidBottomInset: true,
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
                                  'reviews'.tr,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                // Average Rating
                                StreamBuilder<double>(
                                  stream: _getAverageRating(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || snapshot.data == 0.0) {
                                      return Text(
                                        'no_ratings_yet'.tr,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14.sp,
                                        ),
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Text(
                                          '${snapshot.data!.toStringAsFixed(1)}/5',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 16.sp,
                                        ),
                                      ],
                                    );
                                  },
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
                                      child: Icon(Icons.close),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reviews List (Real-Time)
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('videos')
                            .doc(widget.videoId)
                            .collection('reviews')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          final reviews = snapshot.data!.docs;

                          return ListView.separated(
                            controller: scrollController,
                            itemCount: reviews.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                              indent: 16.w,
                              endIndent: 16.w,
                            ),
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              final reviewData = review.data() as Map<String, dynamic>;
                              final userId = reviewData['userId'] as String;
                              final timestamp = reviewData['timestamp'] as Timestamp?;
                              final rating =
                                  (reviewData['rating'] as num?)?.toDouble() ?? 0.0;

                              return Padding(
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
                                            child: Icon(Icons.person, size: 16.sp),
                                          );
                                        }
                                        final userData = userSnapshot.data!;
                                        final name = userData['name'] ?? 'Unknown';
                                        final profileImage = userData['image'] as String?;

                                        return CircleAvatar(
                                          radius: 16.r,
                                          backgroundImage: profileImage != null
                                              ? NetworkImage(
                                            '${Common.profileImage}/$profileImage',
                                          )
                                              : null,
                                          child: profileImage == null
                                              ? Text(
                                            name[0],
                                            style: TextStyle(fontSize: 12.sp),
                                          )
                                              : null,
                                        );
                                      },
                                    ),
                                    SizedBox(width: 12.w),
                                    // Username, Rating, Review Text, and Timestamp
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              // Username
                                              FutureBuilder<Map<String, dynamic>>(
                                                future: _fetchUserData(userId),
                                                builder: (context, userSnapshot) {
                                                  if (!userSnapshot.hasData) {
                                                    return Text('Loading...');
                                                  }
                                                  final userData = userSnapshot.data!;
                                                  final name =
                                                      userData['name'] ?? 'Unknown';

                                                  return Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                      fontSize: 14.sp,
                                                    ),
                                                  );
                                                },
                                              ),
                                              SizedBox(width: 8.w),
                                              // Rating Stars
                                              RatingBarIndicator(
                                                rating: rating,
                                                itemBuilder: (context, _) => Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.amber,
                                                ),
                                                itemCount: 5,
                                                itemSize: 16.sp,
                                                direction: Axis.horizontal,
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
                                          // Review Text (if available)
                                          if (reviewData['text'] != null &&
                                              reviewData['text'].isNotEmpty)
                                            Text(
                                              reviewData['text'],
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Add Review Input (Fixed at Bottom)
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
                          // Rating Bar
                          if (!hasSubmittedReview)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Row(
                                children: [
                                  Text(
                                    "give_rating".tr,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  RatingBar.builder(
                                    glow: false,
                                    initialRating: _rating,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: false,
                                    itemCount: 5,
                                    itemSize: 30.sp,
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                    ),
                                    onRatingUpdate: (rating) {
                                      setState(() {
                                        _rating = rating;
                                      });
                                    },
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
                                  imageBuilder: (context, imageProvider) =>
                                      CircleAvatar(
                                        radius: 20.r,
                                        backgroundImage: imageProvider,
                                      ),
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => CircleAvatar(
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
                                    left: Get.locale?.languageCode == 'ar' ? 0 : 16.w,
                                    right: Get.locale?.languageCode == 'ar' ? 16.w : 0,
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
                                          controller: _reviewController,
                                          focusNode: _textFieldFocusNode,
                                          enabled: !hasSubmittedReview,
                                          decoration: InputDecoration(
                                            hintText: hasSubmittedReview
                                                ? 'you_have_already_submitted_a_review'
                                                .tr
                                                : 'write_a_review_optional'.tr,
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (value) {
                                            if (_rating > 0 && !hasSubmittedReview) {
                                              _addReview(_reviewController.text);
                                            }
                                          },
                                        ),
                                      ),
                                      if (!hasSubmittedReview)
                                        InkWell(
                                          onTap: () {
                                            if (_rating > 0) {
                                              _addReview(_reviewController.text);
                                            }
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(12.w),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _rating > 0
                                                  ? ColorUtils.darkBrown
                                                  : Colors.grey.shade400,
                                            ),
                                            child: Icon(
                                              Icons.send,
                                              color: Colors.white,
                                              size: 20.sp,
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
      },
    );
  }
}
// Function to show the reviews as a bottom sheet
void showReviewsBottomSheet(
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
          child: VideoReviewsScreen(
            videoId: videoId,
            userId: userId,
            userImage: userImage,
          ),
        ),
  );
}
