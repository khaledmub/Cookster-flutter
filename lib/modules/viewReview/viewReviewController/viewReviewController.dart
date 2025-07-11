import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../../../services/apiClient.dart';
import '../viewReviewModel/viewReviewModel.dart';

class ReviewController extends GetxController {
  // Observable for storing the full review model
  final reviewsModel = AllReviewList().obs;

  // Observable for storing review list (userReviews from reviewsModel)
  final reviews = RxList<UserReviews>([]);

  // Observable for loading state
  final isLoading = false.obs;

  // Observable for toggle states
  final toggleStates = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
  }

  // Fetch reviews from API
  Future<void> fetchReviews(String loggedInUser) async {
    print("Fetching reviews for user: $loggedInUser");
    try {
      isLoading.value = true;
      final response = await ApiClient.getRequest(
        '${EndPoints.getReviewList}?user_id=$loggedInUser',
      );

      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final allReviewList = AllReviewList.fromJson(jsonData);

        reviewsModel.value = allReviewList;

        if (allReviewList.status == true && allReviewList.userReviews != null) {
          reviews.assignAll(allReviewList.userReviews!);

          // Initialize toggle states for each reviewer
          toggleStates.assignAll({
            for (var review in allReviewList.userReviews!)
              review.reviewerName ?? 'Unknown': review.isVisible == 1,
          });
        } else {
          reviews.clear();
          toggleStates.clear();
          Get.snackbar('Error', 'No reviews found or invalid response');
        }
      } else {
        Get.snackbar(
          'Error',
          'Failed to fetch reviews: ${response.statusCode}',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch reviews: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Toggle review visibility (local state for UI)
  void toggleReview(String name) {
    toggleStates[name] = !toggleStates[name]!;
    toggleStates.refresh();
  }

  // Approve review
  // Future<void> approveReview(String reviewId) async {
  //   try {
  //     isLoading.value = true;
  //     final response = await ApiClient.postRequest(
  //       EndPoints.updateReviewStatus,
  //       {
  //         'review_id': reviewId,
  //         'status': 1, // 1 for approved
  //         'is_visible': 1,
  //       },
  //     );
  //
  //     if (response.statusCode == 200) {
  //       Get.snackbar('Success', 'Review approved successfully');
  //       // Update local review status
  //       final review = reviews.firstWhere((r) => r.id == reviewId);
  //       review.status = 1;
  //       review.isVisible = 1;
  //       reviews.refresh();
  //       // Update toggle state
  //       toggleStates[review.reviewerName ?? 'Unknown'] = true;
  //       toggleStates.refresh();
  //     } else {
  //       Get.snackbar('Error', 'Failed to approve review: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     Get.snackbar('Error', 'Failed to approve review: $e');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

  // Reject review
  // Future<void> rejectReview(String reviewId) async {
  //   try {
  //     isLoading.value = true;
  //     final response = await ApiClient.postRequest(
  //       EndPoints.updateReviewStatus,
  //       {
  //         'review_id': reviewId,
  //         'status': 0, // 0 for rejected
  //         'is_visible': 0,
  //       },
  //     );
  //
  //     if (response.statusCode == 200) {
  //       Get.snackbar('Success', 'Review rejected successfully');
  //       // Update local review status
  //       final review = reviews.firstWhere((r) => r.id == reviewId);
  //       review.status = 0;
  //       review.isVisible = 0;
  //       reviews.refresh();
  //       // Update toggle state
  //       toggleStates[review.reviewerName ?? 'Unknown'] = false;
  //       toggleStates.refresh();
  //     } else {
  //       Get.snackbar('Error', 'Failed to reject review: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     Get.snackbar('Error', 'Failed to reject review: $e');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }
}