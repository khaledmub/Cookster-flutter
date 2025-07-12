import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appUtils/colorUtils.dart';
import '../addReview/addReviewView/addReviewView.dart';
import '../viewReviewController/viewReviewController.dart';

class ViewReviews extends StatefulWidget {
  final String professionalId;

  ViewReviews({super.key, required this.professionalId});

  @override
  State<ViewReviews> createState() => _ViewReviewsState();
}

class _ViewReviewsState extends State<ViewReviews> {
  String _language = 'en';
  final RxString loggedInUser = ''.obs;
  final ReviewController reviewController = Get.put(ReviewController());
  bool _hasInitiallyFetched = false;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
      loggedInUser.value = prefs.getString('user_id') ?? '';
      print("Logged In User: ${loggedInUser.value}");
    });

    if (loggedInUser.value.isNotEmpty && !_hasInitiallyFetched) {
      _hasInitiallyFetched = true;
      reviewController.fetchReviews(widget.professionalId);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    bool isProfessional = widget.professionalId == loggedInUser.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(155.h),
        child: Container(
          padding: EdgeInsets.only(top: 40.h),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  try {
                    Get.back();
                  } catch (e) {
                    print("Error navigating back: $e");
                  }
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  height: 40.h,
                  width: 40.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6BE00),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isRtl ? Icons.arrow_back : Icons.arrow_back,
                      color: ColorUtils.darkBrown,
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  textAlign: TextAlign.center,
                  "reviews".tr,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 56.w),
            ],
          ),
        ),
      ),
      body: Obx(
        () =>
            reviewController.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Overview Section
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Obx(() {
                          final reviewCounters =
                              reviewController
                                  .reviewsModel
                                  .value
                                  .reviewCounters;
                          final averageRating =
                              reviewCounters?.averageRating?.toStringAsFixed(
                                1,
                              ) ??
                              "0.0";
                          final totalReviews =
                              reviewCounters?.totalReviews?.toString() ?? "0";
                          final ratings = reviewCounters?.ratings;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Rating Score
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        averageRating,
                                        style: TextStyle(
                                          fontSize: 32.sp,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.darkBrown,
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index <
                                                    double.parse(
                                                      averageRating,
                                                    ).round()
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: const Color(0xFFFFD700),
                                            size: 20.sp,
                                          );
                                        }),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        "based_on_reviews".tr.replaceAll(
                                          "{count}",
                                          totalReviews,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 24.w),
                                  // Rating Breakdown
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildRatingBar(
                                          "excellent".tr,
                                          5,
                                          _calculateProgress(
                                            ratings?.five ?? 0,
                                            totalReviews,
                                          ),
                                          const Color(0xFF4CAF50),
                                        ),
                                        SizedBox(height: 8.h),
                                        _buildRatingBar(
                                          "good".tr,
                                          4,
                                          _calculateProgress(
                                            ratings?.four ?? 0,
                                            totalReviews,
                                          ),
                                          const Color(0xFF8BC34A),
                                        ),
                                        _buildRatingBar(
                                          "average".tr,
                                          3,
                                          _calculateProgress(
                                            ratings?.three ?? 0,
                                            totalReviews,
                                          ),
                                          const Color(0xFFFFEB3B),
                                        ),
                                        _buildRatingBar(
                                          "poor".tr,
                                          2,
                                          _calculateProgress(
                                            ratings?.two ?? 0,
                                            totalReviews,
                                          ),
                                          const Color(0xFFFF9800),
                                        ),
                                        _buildRatingBar(
                                          "terrible".tr,
                                          1,
                                          _calculateProgress(
                                            ratings?.one ?? 0,
                                            totalReviews,
                                          ),
                                          const Color(0xFFF44336),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                      SizedBox(height: 24.h),
                      // Reviews List
                      Expanded(
                        child: Obx(
                          () =>
                              reviewController.isLoading.value
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : reviewController.reviews.isEmpty
                                  ? Center(
                                    child: Text(
                                      "no_reviews_found".tr,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: ColorUtils.primaryColor,
                                      ),
                                    ),
                                  )
                                  : () {
                                    // Filter reviews for non-professionals
                                    final reviews =
                                        isProfessional
                                            ? reviewController.reviews
                                            : reviewController.reviews
                                                .where(
                                                  (review) =>
                                                      review.isVisible == 1 &&
                                                      review.status == 1,
                                                )
                                                .toList();
                                    return reviews.isEmpty
                                        ? Center(
                                          child: Text(
                                            "no_reviews".tr,
                                            style: TextStyle(fontSize: 16.sp),
                                          ),
                                        )
                                        : ListView.builder(
                                          itemCount: reviews.length,
                                          itemBuilder: (context, index) {
                                            final review = reviews[index];
                                            final reviewerName =
                                                review.reviewerName ??
                                                'Anonymous';
                                            final rating =
                                                review.rating?.toInt() ?? 0;
                                            final reviewText =
                                                review.review ?? '';
                                            final createdAt =
                                                review.utcTime ?? '';
                                            final reviewerImage =
                                                review.reviewerImage ??
                                                'assets/images/default_user.png';
                                            final isApproved =
                                                review.status == 1;
                                            final status =
                                                review.status ??
                                                0; // Ensure status is passed

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 16.h,
                                              ),
                                              child: _buildReviewCard(
                                                reviewerName,
                                                reviewerImage,
                                                rating,
                                                _formatTimeAgo(createdAt),
                                                reviewText,
                                                reviewController
                                                        .toggleStates[reviewerName] ??
                                                    false,
                                                () => reviewController
                                                    .toggleReviewVisibility(
                                                      context,
                                                      review.id!,
                                                    ),
                                                // Updated to use toggleReviewVisibility
                                                () => reviewController
                                                    .updateReviewStatus(
                                                      context,
                                                      review.id!,
                                                      1,
                                                    ),
                                                // Approve
                                                () => reviewController
                                                    .updateReviewStatus(
                                                      context,
                                                      review.id!,
                                                      2,
                                                    ),
                                                // Reject
                                                isProfessional,
                                                isApproved,
                                              ),
                                            );
                                          },
                                        );
                                  }(),
                        ),
                      ),
                      if (!isProfessional) ...[
                        SizedBox(height: 16.h),
                        SafeArea(
                          child: AppButton(
                            onTap: () {
                              Get.to(
                                AddReviewView(
                                  professionalId: widget.professionalId,
                                ),
                              );
                            },
                            text: "write_review".tr,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildRatingBar(
    String label,
    int stars,
    double progress,
    Color color,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          stars.toString(),
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  double _calculateProgress(int count, String totalReviews) {
    final total = int.tryParse(totalReviews) ?? 0;
    if (total == 0) return 0.0;
    return count / total;
  }

  String _formatTimeAgo(String createdAt) {
    try {
      // Define the input format for "July 9, 2025 at 8:41:44 PM UTC+3"
      final dateFormat = DateFormat("MMMM d, yyyy 'at' h:mm:ss a 'UTC'Z");

      // Parse the input string
      final date = dateFormat.parse(createdAt, true); // true for UTC parsing

      // Convert to local time for comparison
      final localDate = date.toLocal();
      final now = DateTime.now();
      final difference = now.difference(localDate);

      if (difference.inDays > 30) {
        return "${(difference.inDays / 30).floor()} ${"months_ago".tr}";
      } else if (difference.inDays > 0) {
        return "${difference.inDays} ${"days_ago".tr}";
      } else if (difference.inHours > 0) {
        return "${difference.inHours} ${"hours_ago".tr}";
      } else {
        return "just_now".tr;
      }
    } catch (e) {
      print('Error parsing date: $e');
      return "unknown_time".tr;
    }
  }

  Widget _buildReviewCard(
    String name,
    String avatarPath,
    int rating,
    String timeAgo,
    String review,
    bool isToggled,
    VoidCallback onToggle,
    VoidCallback onApprove,
    VoidCallback onReject,
    bool isProfessional,
    bool isApproved, // This is derived from review.status == 1
  ) {
    // Determine the review status (assuming status is passed or derived)
    // Note: Since isApproved is derived as review.status == 1, we need the actual status
    // Assuming the review object has a status field
    int status =
        isApproved
            ? 1
            : 0; // Default to 0 if not approved, adjust based on your model

    // You may need to pass the actual status from the review object
    // For example, if review.status is available, use it directly:
    // int status = review.status ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      Colors
                          .grey[200], // Optional: background color for the container
                ),
                child: CachedNetworkImage(
                  imageUrl: '${Common.profileImage}/${avatarPath}',
                  imageBuilder:
                      (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  placeholder:
                      (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[400],
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 24.sp,
                        ),
                      ),
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.darkBrown,
                          ),
                        ),
                        if (isProfessional && isApproved)
                          Switch(
                            value: isToggled,
                            onChanged: (value) => onToggle(),
                            activeColor: ColorUtils.primaryColor,
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFD700),
                              size: 16.sp,
                            );
                          }),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            review,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
          if (isProfessional) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 0) ...[
                  // Show both Approve and Reject buttons when status is 0 (pending)
                  TextButton(
                    onPressed: onApprove,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'approve'.tr,
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'reject'.tr,
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (status == 1) ...[
                  // Show disabled Approve button when status is 1 (approved)
                  TextButton(
                    onPressed: null, // Disabled
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'approved'.tr,
                      style: TextStyle(
                        color: Colors.green[400],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (status == 2) ...[
                  // Show disabled Reject button when status is 2 (rejected)
                  TextButton(
                    onPressed: null, // Disabled
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'rejected'.tr,
                      style: TextStyle(
                        color: Colors.red[400],
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
