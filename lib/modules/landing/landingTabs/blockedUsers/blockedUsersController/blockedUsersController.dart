import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../../../services/apiClient.dart';
import '../blockedUsersModel/blockedUsersModel.dart';

class BlockedUsersController extends GetxController {
  var isLoading = true.obs;
  var blockedUsersList = <BlockedUsers>[].obs;
  var filteredBlockedUsersList =
      <BlockedUsers>[].obs; // New observable for filtered list
  var errorMessage = ''.obs;

  // Fetch blocked users list
  Future<void> fetchBlockUsersList() async {
    try {
      isLoading(true);
      errorMessage('');

      final response = await ApiClient.getRequest(
        '${EndPoints.blockedUsersList}',
      );

      print("PRINTING BLOCKED USERS LIST");
      print(response.body);

      if (response.statusCode == 200) {
        final blockedUsers = BlockedUsersList.fromJson(
          jsonDecode(response.body),
        );
        blockedUsersList.assignAll(blockedUsers.blockedUsers ?? []);
        filteredBlockedUsersList.assignAll(
          blockedUsers.blockedUsers ?? [],
        ); // Initialize filtered list
      } else {
        errorMessage('Failed to load blocked users: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error fetching blocked users: $e');
    } finally {
      isLoading(false);
    }
  }

  // Search blocked users
  void searchBlockedUsers(String query) {
    final lowerQuery = query.toLowerCase();
    if (query.isEmpty) {
      filteredBlockedUsersList.assignAll(blockedUsersList);
    } else {
      filteredBlockedUsersList.assignAll(
        blockedUsersList.where((user) {
          final name = (user.name ?? '').toLowerCase();
          final email = (user.email ?? '').toLowerCase();
          return name.contains(lowerQuery) || email.contains(lowerQuery);
        }).toList(),
      );
    }
  }

  // Unblock user
  Future<void> unblockUser(String targetUserId) async {
    try {
      final endpoint = '${EndPoints.blockUser}';
      final response = await ApiClient.postRequest(endpoint, {
        "blocked_user": targetUserId,
      });

      print("UNBLOCK USER RESPONSE");
      print(response.body);

      if (response.statusCode == 200) {
        // Remove the unblocked user from both lists
        blockedUsersList.removeWhere((user) => user.id == targetUserId);
        filteredBlockedUsersList.removeWhere((user) => user.id == targetUserId);
      } else {
        errorMessage('Failed to unblock user: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error unblocking user: $e');
    }
  }
}
