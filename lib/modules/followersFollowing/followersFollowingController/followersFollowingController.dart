import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../services/apiClient.dart';
import '../followersListModel/followersListModel.dart';

class SocialListsController extends GetxController {
  var isLoading = true.obs;
  var followers = <FFUser>[].obs;
  var following = <FFUser>[].obs;
  var errorMessage = ''.obs;

  // Fetch social data (followers and following) for a given userId
  Future<void> fetchSocialData(String userId) async {
    try {
      isLoading(true);
      errorMessage('');

      // Assuming the endpoint to fetch followers/following is something like /social/{userId}
      final response = await ApiClient.getRequest('${EndPoints.followerList}?user_id=$userId');

      if (response.statusCode == 200) {
        final socialResponse = SocialResponse.fromJson(
          jsonDecode(response.body),
        );
        followers.assignAll(socialResponse.followers);
        following.assignAll(socialResponse.following);
      } else {
        errorMessage('Failed to load social data: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error fetching social data: $e');
    } finally {
      isLoading(false);
    }
  }

  // Toggle follow status
  Future<void> toggleFollowStatus(String targetUserId) async {
    try {
      final endpoint = '${EndPoints.unfollow}';
      // Assuming endpoint for toggling follow status is /follow/{targetUserId}
      final response = await ApiClient.postRequest(endpoint, {
        'following_id': targetUserId,
      });

      print(response.body);

      if (response.statusCode == 200) {
        // Update local lists if needed (handled in UI)
      } else {
        errorMessage('Failed to toggle follow status: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error toggling follow status: $e');
    }
  }

  Future<void> removeFollower(String targetUserId) async {
    try {
      final endpoint = '${EndPoints.removeFollower}';
      // Assuming endpoint for toggling follow status is /follow/{targetUserId}
      final response = await ApiClient.postRequest(endpoint, {
        'follower_id': targetUserId,
      });

      print(endpoint);

      print(response.body);

      if (response.statusCode == 200) {
        // Update local lists if needed (handled in UI)
      } else {
        errorMessage('Failed to toggle follow status: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error toggling follow status: $e');
    }
  }
}
