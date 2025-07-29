import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/loaders/pulseLoader.dart';
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
        () => RefreshIndicator(
          onRefresh: () async {
            await reviewController.fetchReviews(widget.professionalId);
          },
          child:
              reviewController.isLoading.value
                  ? const Center(
                    child: PulseLogoLoader(
                      logoPath: "assets/images/appLogo.png",
                    ),
                  )
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
                                      child: PulseLogoLoader(
                                        logoPath: "assets/images/appLogo.png",
                                      ),
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

                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 16.h,
                                                ),
                                                child: _buildReviewCard(
                                                  reviewerName,
                                                  reviewerImage,
                                                  rating,
                                                  createdAt,
                                                  // Pass raw createdAt
                                                  reviewText,
                                                  reviewController
                                                          .toggleStates[reviewerName] ??
                                                      false,
                                                  () => reviewController
                                                      .toggleReviewVisibility(
                                                        context,
                                                        review.id!,
                                                      ),
                                                  () => reviewController
                                                      .updateReviewStatus(
                                                        context,
                                                        review.id!,
                                                        1,
                                                      ),
                                                  () => reviewController
                                                      .updateReviewStatus(
                                                        context,
                                                        review.id!,
                                                        2,
                                                      ),
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
      // Input format: "July 29, 2025 at 11:58:07 AM UTC+3"
      print('Original input: $createdAt');

      // Extract timezone offset
      final utcRegex = RegExp(r'UTC([+-]\d{1,2})(?::\d{2})?(?!\d)');
      final match = utcRegex.firstMatch(createdAt);

      if (match != null) {
        final offsetString = match.group(1)!; // e.g., "+3" or "-3"
        final offsetHours = int.parse(offsetString);

        // Remove the UTC part and parse the base date in UTC
        final baseDateString = createdAt.replaceAll(utcRegex, '');
        print('Base date string: $baseDateString');

        // Parse the date without timezone (as if it's UTC)
        final dateFormat = DateFormat("MMMM d, yyyy 'at' h:mm:ss a");
        final parsedDateUtc = dateFormat.parse(
          baseDateString,
          true,
        ); // Parse as UTC
        print('Parsed as UTC: $parsedDateUtc');

        // Convert from the original timezone to UTC
        // If the original time is UTC+3, we need to subtract 3 hours to get UTC
        final actualUtcTime = parsedDateUtc.subtract(
          Duration(hours: offsetHours),
        );
        print('Actual UTC time: $actualUtcTime');

        // Convert UTC to local time (Pakistan UTC+5)
        final localTime = actualUtcTime.toLocal();
        print('Local time (Pakistan): $localTime');

        // Get current local time
        final now = DateTime.now();
        print('Current local time: $now');

        // Calculate the difference
        final difference = now.difference(localTime);
        print('Time difference: ${difference.inMinutes} minutes');

        // Handle negative differences (future dates)
        if (difference.isNegative) {
          final futureDiff = localTime.difference(now);
          if (futureDiff.inMinutes < 2) {
            return "just_now".tr;
          }
          return "in_future".tr;
        }

        // Format the time ago string
        if (difference.inDays > 365) {
          final years = (difference.inDays / 365).floor();
          return "$years ${years == 1 ? 'year' : 'years'} ${"ago".tr}";
        } else if (difference.inDays > 30) {
          final months = (difference.inDays / 30).floor();
          return "$months ${months == 1 ? 'month' : 'months'} ${"ago".tr}";
        } else if (difference.inDays > 0) {
          return "${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ${"ago".tr}";
        } else if (difference.inHours > 0) {
          return "${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ${"ago".tr}";
        } else if (difference.inMinutes > 0) {
          return "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ${"ago".tr}";
        } else {
          return "just_now".tr;
        }
      } else {
        // Fallback if no timezone info found
        print('No timezone info found, using fallback parsing');
        final dateFormat = DateFormat("MMMM d, yyyy 'at' h:mm:ss a");
        final parsedDate = dateFormat.parse(createdAt);
        final now = DateTime.now();
        final difference = now.difference(parsedDate);

        if (difference.inMinutes > 0) {
          return "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ${"ago".tr}";
        } else {
          return "just_now".tr;
        }
      }
    } catch (e) {
      print('Error parsing date: $e for input: $createdAt');
      return "unknown_time".tr;
    }
  }

  Widget _buildReviewCard(
    String name,
    String avatarPath,
    int rating,
    String createdAt, // Changed to pass raw createdAt
    String review,
    bool isToggled,
    VoidCallback onToggle,
    VoidCallback onApprove,
    VoidCallback onReject,
    bool isProfessional,
    bool isApproved,
  ) {
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
                  color: Colors.grey[200],
                ),
                child: CachedNetworkImage(
                  imageUrl: '${Common.profileImage}/$avatarPath',
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
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 60)),
                          builder: (context, snapshot) {
                            return Text(
                              _formatTimeAgo(createdAt),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            );
                          },
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
                if (!isApproved) ...[
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
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
