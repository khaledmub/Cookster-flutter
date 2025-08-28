import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
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
  final isApproving = false.obs;

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

  // Toggle review visibility (API call)
  Future<void> toggleReviewVisibility(
    BuildContext context,
    String reviewId,
  ) async {
    try {
      isApproving.value = true;
      final review = reviews.firstWhere(
        (r) => r.id == reviewId,
        orElse: () => UserReviews(),
      );
      if (review.id == null) throw Exception('Review not found');

      // Determine the new visibility state (toggle between 0 and 1)
      final newIsVisible = review.isVisible == 1 ? 0 : 1;

      final response = await ApiClient.postRequest(
        EndPoints.updateReviewVisibility,
        // Use the correct endpoint for visibility
        {'id': reviewId, 'is_visible': newIsVisible},
      );

      print(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final successMessage =
            jsonResponse['message'] as String? ?? 'Updated successfully.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Update local state
        review.isVisible = newIsVisible;
        reviews.refresh();
        toggleStates[review.reviewerName ?? 'Unknown'] = newIsVisible == 1;
        toggleStates.refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to toggle review visibility: ${response.statusCode}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to toggle review visibility: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isApproving.value = false;
    }
  }

  // Update review status (approve or reject)
  Future<void> updateReviewStatus(
      BuildContext context,
      String reviewId,
      int action,
      ) async {
    try {
      isApproving.value = true;
      int status;
      int isVisible;
      if (action == 0) {
        // Pending state
        status = 0;
        isVisible = 0;
      } else if (action == 1) {
        // Approve
        status = 1;
        isVisible = 1;
      } else if (action == 2) {
        // Reject
        status = 2;
        isVisible = 0;
      } else {
        throw Exception('Invalid action value');
      }

      print("Status: $status");
      final response = await ApiClient.postRequest(
        EndPoints.updateReviewStatus,
        {'id': reviewId, 'status': status},
      );

      print(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final successMessage = jsonResponse['message'] as String? ?? 'Updated successfully.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        final review = reviews.firstWhere(
              (r) => r.id == reviewId,
          orElse: () => UserReviews(),
        );
        if (review.id != null) {
          review.status = status;
          review.isVisible = isVisible;
          if (action == 2) {
            // Remove the review from the list when rejected
            reviews.removeWhere((r) => r.id == reviewId);
          } else {
            reviews.refresh();
          }
          toggleStates[review.reviewerName ?? 'Unknown'] = action == 1;
          toggleStates.refresh();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update review status: ${response.statusCode}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update review status: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isApproving.value = false;
    }
  }
}
