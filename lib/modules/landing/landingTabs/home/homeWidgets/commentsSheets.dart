import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart'; // Add shimmer package to pubspec.yaml

import '../../../../../appUtils/apiEndPoints.dart';
import '../homeController/addCommentControllr.dart';

void showCommentBottomSheet(
  BuildContext context,
  String videoId,
  String currentUserId,
  currentUserPhotoUrl,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.9, // Take up 90% of screen height
        child: CommentSection(
          videoId: videoId,
          currentUserId: currentUserId,
          currentUserPhotoUrl: currentUserPhotoUrl,
        ),
      );
    },
  );
}

class CommentSection extends StatefulWidget {
  final String videoId;
  final String currentUserId;
  final String currentUserPhotoUrl;

  const CommentSection({
    Key? key,
    required this.videoId,
    required this.currentUserId,
    required this.currentUserPhotoUrl,
  }) : super(key: key);

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final ScrollController scrollController = ScrollController();
  final FocusNode commentFocusNode = FocusNode();
  final TextEditingController commentController = TextEditingController();
  bool isKeyboardVisible = false;

  // Use the VideoCommentsController with GetX
  final VideoCommentsController commentsController = Get.find();

  @override
  void initState() {
    super.initState();
    // Add listener to focus node to detect keyboard visibility
    commentFocusNode.addListener(_onFocusChange);

    // Fetch comments for this video
    commentsController.fetchComments(widget.videoId);
  }

  void _onFocusChange() {
    setState(() {
      isKeyboardVisible = commentFocusNode.hasFocus;
    });
  }

  Future<void> _addComment() async {
    if (commentController.text.trim().isNotEmpty) {
      await commentsController.addComment(
        widget.videoId,
        widget.currentUserId,
        commentController.text.trim(),
      );
      commentController.clear();

      // Unfocus the text field
      commentFocusNode.unfocus();

      // Scroll to the top after adding comment
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    commentFocusNode.removeListener(_onFocusChange);
    commentFocusNode.dispose();
    commentController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the keyboard height
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Important: This makes the bottom padding respect the keyboard height
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    "Comments".tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      Get.back();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0XFFEBEBEB),
                      ),
                      child: Icon(Icons.close, size: 14.sp),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0XFFE3E3E3), thickness: 0.3),

            // Comment List - Uses Obx to listen to changes in comments collection
            Expanded(
              child: Obx(() {
                // Check if comments are still loading
                if (commentsController.isLoading.value) {
                  return ListView.builder(
                    itemCount: 5, // Show 5 shimmer placeholders
                    itemBuilder: (context, index) {
                      return _buildCommentShimmer();
                    },
                  );
                }

                // Check if comments list is empty
                if (commentsController.comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/icons/no_comments.svg",
                          height: 80.h,
                          width: 80.h,
                          color: ColorUtils.grey.withOpacity(0.5),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "No Comments Yet".tr,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: ColorUtils.grey,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Be the first to comment!".tr,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: ColorUtils.grey.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Show the comments if we have them
                return ListView.builder(
                  controller: scrollController,
                  itemCount: commentsController.comments.length,
                  itemBuilder: (context, index) {
                    final commentDoc = commentsController.comments[index];
                    final commentData =
                        commentDoc.data() as Map<String, dynamic>;
                    final commentId = commentDoc.id;

                    // Fetch user info from the comment
                    final userId = commentData['userId'] as String;
                    final commentText = commentData['text'] as String;
                    final timestamp = commentData['timestamp'] as Timestamp?;
                    final likeCount = commentData['likeCount'] ?? 0;
                    final isLiked = commentsController.isCommentLikedByUser(
                      commentDoc,
                      widget.currentUserId,
                    );
                    final dateFormatted =
                        timestamp != null
                            ? timeago.format(timestamp.toDate())
                            : 'Just now';

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                      builder: (context, snapshot) {
                        // Show shimmer while loading user data
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildUserDataShimmer(
                            commentText,
                            dateFormatted,
                          );
                        }

                        String userName = 'User';
                        String profilePic =
                            'https://ui-avatars.com/api/?name=User';

                        if (snapshot.hasData && snapshot.data != null) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          if (userData != null) {
                            userName = userData['name'] ?? 'User';
                            profilePic = userData['image'] ?? profilePic;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile Picture
                                  Container(
                                    height: 40.h,
                                    width: 40.h,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white),
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl:
                                            '${Common.profileImage}/$profilePic',
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) =>
                                                Shimmer.fromColors(
                                                  baseColor: Colors.grey[300]!,
                                                  highlightColor:
                                                      Colors.grey[100]!,
                                                  child: Container(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        errorWidget:
                                            (context, url, error) =>
                                                Image.asset(
                                                  "assets/images/logo.png",
                                                  fit: BoxFit.cover,
                                                ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Name & Date
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              userName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16.sp,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              dateFormatted,
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w200,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        // Comment Text
                                        Text(
                                          commentText,
                                          style: TextStyle(
                                            color: ColorUtils.grey,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w200,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                commentsController
                                                    .toggleCommentLike(
                                                      widget.videoId,
                                                      commentId,
                                                      widget.currentUserId,
                                                    );
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isLiked
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    size: 16.sp,
                                                    color:
                                                        isLiked
                                                            ? Colors.red
                                                            : ColorUtils
                                                                .darkBrown,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    likeCount > 0
                                                        ? "$likeCount ${likeCount == 1 ? 'Like'.tr : 'Likes'.tr}"
                                                        : "Like".tr,
                                                    style: TextStyle(
                                                      color:
                                                          ColorUtils.darkBrown,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(
                                              Icons.reply,
                                              size: 16.sp,
                                              color: ColorUtils.darkBrown,
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () {
                                                // Handle reply to this comment
                                                _showReplyDialog(commentId);
                                              },
                                              child: Text(
                                                "Reply".tr,
                                                style: TextStyle(
                                                  color: ColorUtils.darkBrown,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Show replies section
                                        _buildRepliesSection(commentId),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                color: Color(0XFFE3E3E3),
                                thickness: 0.3,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              }),
            ),

            // Comment Input Section - This will stay above the keyboard
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 8 + (keyboardHeight > 0 ? 8 : 0),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isKeyboardVisible) ...[
                    Text(
                      "Comment".tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      // User Avatar
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200], // Default background
                        child: CachedNetworkImage(
                          imageUrl:
                              '${Common.profileImage}/${widget.currentUserPhotoUrl}',
                          imageBuilder:
                              (context, imageProvider) => CircleAvatar(
                                radius: 30,
                                backgroundImage: imageProvider,
                              ),
                          placeholder:
                              (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => CircleAvatar(
                                radius: 30,
                                backgroundImage: AssetImage(
                                  "assets/images/logo.png",
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // TextField Container
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(
                            left: Get.locale?.languageCode == 'ar' ? 0 : 16,
                            right: Get.locale?.languageCode == 'ar' ? 16 : 0,
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
                                  controller: commentController,
                                  focusNode: commentFocusNode,
                                  textDirection:
                                      Get.locale?.languageCode == 'ar'
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                  decoration: InputDecoration(
                                    hintText: "Write a comment...".tr,
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _addComment(),
                                ),
                              ),
                              InkWell(
                                onTap: _addComment,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        commentController.text.trim().isEmpty
                                            ? ColorUtils.darkBrown
                                            : ColorUtils.darkBrown,
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
  }

  // Build shimmer effect for comments
  Widget _buildCommentShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Shimmer
                Container(
                  height: 40.h,
                  width: 40.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                // Content Shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Username Shimmer
                          Container(
                            width: 100,
                            height: 14,
                            color: Colors.white,
                          ),
                          const Spacer(),
                          // Date Shimmer
                          Container(width: 50, height: 10, color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Comment Text Shimmer
                      Container(
                        width: double.infinity,
                        height: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      // Likes and Reply Shimmer
                      Row(
                        children: [
                          Container(width: 60, height: 12, color: Colors.white),
                          const SizedBox(width: 16),
                          Container(width: 40, height: 12, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0XFFE3E3E3), thickness: 0.3),
          ],
        ),
      ),
    );
  }

  // Shimmer for when user data is being loaded
  Widget _buildUserDataShimmer(String commentText, String dateFormatted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Shimmer
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 40.h,
                  width: 40.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Content with Shimmer for username only
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Username Shimmer
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            width: 100,
                            height: 16,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateFormatted,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Display the actual comment text
                    Text(
                      commentText,
                      style: TextStyle(
                        color: ColorUtils.grey,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Like and Reply buttons
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 16.sp,
                              color: ColorUtils.darkBrown,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Like".tr,
                              style: TextStyle(color: ColorUtils.darkBrown),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.reply,
                          size: 16.sp,
                          color: ColorUtils.darkBrown,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Reply".tr,
                          style: TextStyle(color: ColorUtils.darkBrown),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0XFFE3E3E3), thickness: 0.3),
        ],
      ),
    );
  }

  // Build replies section widget
  Widget _buildRepliesSection(String commentId) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: commentsController.fetchReplies(widget.videoId, commentId),
      builder: (context, snapshot) {
        // Show shimmer while loading replies
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 80, height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 10,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        }

        // Handle errors or no data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${replies.length} ${replies.length == 1 ? 'reply'.tr : 'replies'.tr}",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: ColorUtils.darkBrown,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: replies.length > 3 ? 3 : replies.length,
                // Show only 3 replies max
                itemBuilder: (context, index) {
                  final replyData =
                      replies[index].data() as Map<String, dynamic>;
                  final replyUserId = replyData['userId'] as String;
                  final replyText = replyData['text'] as String;
                  final replyTimestamp = replyData['timestamp'] as Timestamp?;
                  final replyDateFormatted =
                      replyTimestamp != null
                          ? timeago.format(replyTimestamp.toDate())
                          : 'Just now';

                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(replyUserId)
                            .get(),
                    builder: (context, userSnapshot) {
                      // Show shimmer while loading user data for replies
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  height: 30.h,
                                  width: 30.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyText,
                                      style: TextStyle(
                                        color: ColorUtils.grey,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w200,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      String replyUserName = 'User';
                      String replyProfilePic =
                          'https://ui-avatars.com/api/?name=User';

                      if (userSnapshot.hasData && userSnapshot.data != null) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        if (userData != null) {
                          replyUserName = userData['name'] ?? 'User';
                          replyProfilePic =
                              userData['image'] ?? replyProfilePic;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reply Profile Picture (smaller than main comments)
                            Container(
                              height: 30.h,
                              width: 30.h,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      '${Common.profileImage}/$replyProfilePic',
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(color: Colors.white),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Image.asset(
                                        "assets/images/logo.png",
                                        fit: BoxFit.cover,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Reply Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        replyUserName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        replyDateFormatted,
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w200,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    replyText,
                                    style: TextStyle(
                                      color: ColorUtils.grey,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w200,
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

              // Show "View all replies" if there are more than 3
              if (replies.length > 3)
                TextButton(
                  onPressed: () {
                    _showAllRepliesBottomSheet(commentId);
                  },
                  child: Text(
                    "View all replies".tr,
                    style: TextStyle(
                      color: ColorUtils.darkBrown,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReplyDialog(String commentId) {
    final TextEditingController replyController = TextEditingController();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      // Keeps it simple without a header
      animType: AnimType.scale,
      // Smooth scaling animation
      padding: const EdgeInsets.all(16.0),
      // Consistent padding
      body: Column(
        mainAxisSize: MainAxisSize.min, // Compact size
        crossAxisAlignment: CrossAxisAlignment.start, // Align content neatly
        children: [
          Text(
            "Reply to comment".tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600, // Slightly lighter bold for elegance
              color: Colors.black87, // Softer black for readability
            ),
          ),
          const SizedBox(height: 12), // Subtle spacing
          TextField(
            controller: replyController,
            decoration: InputDecoration(
              hintText: "Write your reply...".tr,
              hintStyle: const TextStyle(color: Colors.grey),
              // Subtle hint
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0), // Rounded corners
                borderSide: const BorderSide(
                  color: Colors.grey,
                  width: 1,
                ), // Light border
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: ColorUtils.darkBrown,
                  width: 1.5,
                ), // Highlight on focus
              ),
              filled: true,
              fillColor: Colors.grey[50],
              // Light background for contrast
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ), // Better padding
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 16), // Readable text size
          ),
        ],
      ),
      btnCancelText: "Cancel".tr,
      btnCancelColor: Colors.grey[400],
      // Muted cancel button
      btnCancelOnPress: () {},
      btnOkText: "Reply".tr,
      btnOkColor: ColorUtils.darkBrown,
      // Consistent theme color
      btnOkOnPress: () {
        if (replyController.text.trim().isNotEmpty) {
          commentsController.addReply(
            widget.videoId,
            commentId,
            widget.currentUserId,
            replyController.text.trim(),
          );
        }
      },
      dialogBackgroundColor: Colors.white,
      // Clean white background
      borderSide: const BorderSide(
        color: Colors.grey,
        width: 0.5,
      ), // Subtle dialog border
    ).show();
  }

  // Show all replies in a bottom sheet
  void _showAllRepliesBottomSheet(String commentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7, // Take up 70% of screen height
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      "Replies".tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0XFFEBEBEB),
                        ),
                        child: Icon(Icons.close, size: 14.sp),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0XFFE3E3E3), thickness: 0.3),

                // Replies list
                Expanded(
                  child: FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: commentsController.fetchReplies(
                      widget.videoId,
                      commentId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: ColorUtils.darkBrown,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text("No replies yet".tr));
                      }

                      final replies = snapshot.data!;

                      return ListView.builder(
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final replyData =
                              replies[index].data() as Map<String, dynamic>;
                          final replyUserId = replyData['userId'] as String;
                          final replyText = replyData['text'] as String;
                          final replyTimestamp =
                              replyData['timestamp'] as Timestamp?;
                          final replyDateFormatted =
                              replyTimestamp != null
                                  ? timeago.format(replyTimestamp.toDate())
                                  : 'Just now';

                          return FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(replyUserId)
                                    .get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return _buildUserDataShimmer(
                                  replyText,
                                  replyDateFormatted,
                                );
                              }

                              String replyUserName = 'User';
                              String replyProfilePic =
                                  'https://ui-avatars.com/api/?name=User';

                              if (userSnapshot.hasData &&
                                  userSnapshot.data != null) {
                                final userData =
                                    userSnapshot.data!.data()
                                        as Map<String, dynamic>?;
                                if (userData != null) {
                                  replyUserName = userData['name'] ?? 'User';
                                  replyProfilePic =
                                      userData['image'] ?? replyProfilePic;
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Reply Profile Picture
                                    Container(
                                      height: 40.h,
                                      width: 40.h,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white),
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              '${Common.profileImage}/$replyProfilePic',
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (context, url) =>
                                                  Shimmer.fromColors(
                                                    baseColor:
                                                        Colors.grey[300]!,
                                                    highlightColor:
                                                        Colors.grey[100]!,
                                                    child: Container(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Image.asset(
                                                    "assets/images/logo.png",
                                                    fit: BoxFit.cover,
                                                  ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Reply Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                replyUserName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                replyDateFormatted,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w200,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            replyText,
                                            style: TextStyle(
                                              color: ColorUtils.grey,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w400,
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
                      );
                    },
                  ),
                ),

                // Reply input
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // User Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        child: CachedNetworkImage(
                          imageUrl: widget.currentUserPhotoUrl,
                          imageBuilder:
                              (context, imageProvider) => CircleAvatar(
                                radius: 20,
                                backgroundImage: imageProvider,
                              ),
                          placeholder:
                              (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => CircleAvatar(
                                radius: 20,
                                backgroundImage: AssetImage(
                                  "assets/images/logo.png",
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // TextField Container
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(
                            left: Get.locale?.languageCode == 'ar' ? 0 : 16,
                            right: Get.locale?.languageCode == 'ar' ? 16 : 0,
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
                                  controller: TextEditingController(),
                                  textDirection:
                                      Get.locale?.languageCode == 'ar'
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                  decoration: InputDecoration(
                                    hintText: "Write a reply...".tr,
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty) {
                                      commentsController.addReply(
                                        widget.videoId,
                                        commentId,
                                        widget.currentUserId,
                                        value.trim(),
                                      );
                                    }
                                  },
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  // Get text from controller and add reply
                                  final text =
                                      TextEditingController().text.trim();
                                  if (text.isNotEmpty) {
                                    commentsController.addReply(
                                      widget.videoId,
                                      commentId,
                                      widget.currentUserId,
                                      text,
                                    );
                                    TextEditingController().clear();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
