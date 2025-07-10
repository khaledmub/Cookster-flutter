import 'package:cookster/appUtils/appUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appUtils/colorUtils.dart';
import '../addReview/addReviewView/addReviewView.dart';
import '../viewReviewController/viewReviewController.dart';

// GetX Controller for managing review states

class ViewReviews extends StatefulWidget {
  final String professionalId;

  ViewReviews({super.key, required this.professionalId});

  @override
  State<ViewReviews> createState() => _ViewReviewsState();
}

class _ViewReviewsState extends State<ViewReviews> {
  String _language = 'en'; // Default to English
  String loggedInUser = '';
  final ReviewController reviewController = Get.put(ReviewController());

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
      loggedInUser = prefs.getString('user_id') ?? '';
      print("Logged In User: $loggedInUser");
    });
  }

  @override
  void initState() {
    _loadLanguage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    bool isProfessional = widget.professionalId == loggedInUser;

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
      body: Padding(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Score
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "4.0",
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.darkBrown,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < 4
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFFFD700),
                                size: 20.sp,
                              );
                            }),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "based_on_reviews".tr.replaceAll("{count}", "24"),
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
                              0.7,
                              const Color(0xFF4CAF50),
                            ),
                            SizedBox(height: 8.h),
                            _buildRatingBar(
                              "good".tr,
                              4,
                              0.5,
                              const Color(0xFF8BC34A),
                            ),
                            SizedBox(height: 8.h),
                            _buildRatingBar(
                              "average".tr,
                              3,
                              0.3,
                              const Color(0xFFFFEB3B),
                            ),
                            SizedBox(height: 8.h),
                            _buildRatingBar(
                              "poor".tr,
                              2,
                              0.1,
                              const Color(0xFFFF9800),
                            ),
                            SizedBox(height: 8.h),
                            _buildRatingBar(
                              "terrible".tr,
                              1,
                              0.05,
                              const Color(0xFFF44336),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Reviews List
            Expanded(
              child: Obx(
                () => ListView(
                  children: [
                    _buildReviewCard(
                      "Jean Perkins",
                      "assets/images/user1.png",
                      5,
                      "1 week ago",
                      "Service is great but delivery was a bit slow. Overall good experience. Will definitely order again when I need fresh fish. The quality is excellent and the fish was very fresh.",
                      reviewController.toggleStates["Jean Perkins"]!,
                      () => reviewController.toggleReview("Jean Perkins"),
                      () => reviewController.approveReview("Jean Perkins"),
                      () => reviewController.rejectReview("Jean Perkins"),
                      isProfessional,
                    ),
                    SizedBox(height: 16.h),
                    _buildReviewCard(
                      "Frank Garrett",
                      "assets/images/user2.png",
                      4,
                      "4 days ago",
                      "Assolutement parfait. Muiam consequat ipsum tellus tempor non mauris. Consequat est sed velit sed faucibus aliquet.",
                      reviewController.toggleStates["Frank Garrett"]!,
                      () => reviewController.toggleReview("Frank Garrett"),
                      () => reviewController.approveReview("Frank Garrett"),
                      () => reviewController.rejectReview("Frank Garrett"),
                      isProfessional,
                    ),
                    SizedBox(height: 16.h),
                    _buildReviewCard(
                      "Randy Palmer",
                      "assets/images/user3.png",
                      5,
                      "1 month ago",
                      "Amazing amb nice, pryvate non rutting tempor, velit et gravida elit.",
                      reviewController.toggleStates["Randy Palmer"]!,
                      () => reviewController.toggleReview("Randy Palmer"),
                      () => reviewController.approveReview("Randy Palmer"),
                      () => reviewController.rejectReview("Randy Palmer"),
                      isProfessional,
                    ),
                  ],
                ),
              ),
            ),

            if (!isProfessional) ...[
              SizedBox(height: 16.h),
              SafeArea(
                child: AppButton(
                  onTap: () {
                    Get.to(
                      AddReviewView(professionalId: widget.professionalId),
                    );
                  },
                  text: "write_review".tr,
                ),
              ),
            ],
          ],
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
              widthFactor: progress,
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
              CircleAvatar(
                radius: 20.r,
                backgroundColor: Colors.grey[300],
                child: Icon(Icons.person, color: Colors.grey[600], size: 24.sp),
                // Use this when you have actual images:
                // backgroundImage: AssetImage(avatarPath),
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
                        if (isProfessional)
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
            ),
          ],
        ],
      ),
    );
  }
}
