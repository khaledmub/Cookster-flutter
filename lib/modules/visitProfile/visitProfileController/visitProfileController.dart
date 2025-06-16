import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:like_button/like_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../appRoutes/appRoutes.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../services/apiClient.dart';
import '../visitProfileModel/visitProfileModel.dart';

class VisitProfileController extends GetxController {
  var isLoading = false.obs;
  var visitProfile =
      Rxn<VisitProfile>(); // Observable to store VisitProfile data

  var isLikedByCurrentUser = false.obs;
  var profileLikesCount = 0.obs;
  var isLikeProcessing = false.obs;

  // Call this method when profile is loaded
  Future<void> checkProfileLikeStatus(
    String profileId,
    String currentUserId,
  ) async {
    try {
      // Check if the profile document exists in 'profileLikes' collection
      final profileLikeDoc =
          await FirebaseFirestore.instance
              .collection('profileLikes')
              .doc(profileId)
              .get();

      if (profileLikeDoc.exists) {
        // Get the likes data
        final data = profileLikeDoc.data() as Map<String, dynamic>;
        final List<dynamic> likedBy = data['likedBy'] ?? [];

        // Update the likes count
        profileLikesCount.value = likedBy.length;

        // Check if current user has liked this profile
        isLikedByCurrentUser.value = likedBy.contains(currentUserId);
      } else {
        // Initialize document if it doesn't exist
        profileLikesCount.value = 0;
        isLikedByCurrentUser.value = false;
      }
    } catch (e) {
      print("Error checking profile like status: $e");
    }
  }

  // Toggle like/unlike profile
  Future<bool> toggleProfileLike(String profileId, String currentUserId) async {
    if (isLikeProcessing.value) return isLikedByCurrentUser.value;

    isLikeProcessing.value = true;
    try {
      final profileLikeRef = FirebaseFirestore.instance
          .collection('profileLikes')
          .doc(profileId);

      // Get current document
      final doc = await profileLikeRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> likedBy = List.from(data['likedBy'] ?? []);

        if (likedBy.contains(currentUserId)) {
          // Unlike profile
          likedBy.remove(currentUserId);
          isLikedByCurrentUser.value = false;
        } else {
          // Like profile
          likedBy.add(currentUserId);
          isLikedByCurrentUser.value = true;
        }

        // Update document
        await profileLikeRef.update({
          'likedBy': likedBy,
          'likeCount': likedBy.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        profileLikesCount.value = likedBy.length;
      } else {
        // Create new document
        await profileLikeRef.set({
          'likedBy': [currentUserId],
          'likeCount': 1,
          'profileId': profileId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        profileLikesCount.value = 1;
        isLikedByCurrentUser.value = true;
      }

      return isLikedByCurrentUser.value;
    } catch (e) {
      print("Error toggling profile like: $e");
      return isLikedByCurrentUser.value;
    } finally {
      isLikeProcessing.value = false;
    }
  }

  Future<void> fetchUserProfile(String userId) async {
    print('PRINTING THE USER ID: $userId');
    try {
      isLoading.value = true;
      visitProfile.value = null;

      final response = await ApiClient.getRequest(
        "${EndPoints.userProfile}?id=$userId",
      );

      print("Searching the following id $userId");

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        print("Response JSON: $jsonData"); // API Response print karna
        visitProfile.value = VisitProfile.fromJson(jsonData);

        print(
          "Visit Profile: ${visitProfile.value}",
        ); // Converted Model print karna
      } else {
        Get.snackbar("Error", "Failed to load profile");
      }
    } catch (e) {
      Get.snackbar("There", e.toString());
      print("Error: $e"); // Error print karna
    } finally {
      isLoading.value = false;
    }
  }
}

class ProfileLikeButton extends StatelessWidget {
  final String profileId;
  final String currentUserId;
  final VisitProfileController controller;

  const ProfileLikeButton({
    Key? key,
    required this.profileId,
    required this.currentUserId,
    required this.controller,
  }) : super(key: key);

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ColorUtils.primaryColor),
        ),
        child: Center(
          child: LikeButton(
            likeCountPadding: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            size: 30,
            isLiked: controller.isLikedByCurrentUser.value,
            onTap: (isLiked) async {
              bool isAuthenticated = await _isUserAuthenticated();
              if (!isAuthenticated) {
                Get.toNamed(AppRoutes.signIn);
                return isLiked; // Return current state to prevent like action
              }
              final result = await controller.toggleProfileLike(
                profileId,
                currentUserId,
              );
              return result;
            },
          ),
        ),
      );
    });
  }
}
