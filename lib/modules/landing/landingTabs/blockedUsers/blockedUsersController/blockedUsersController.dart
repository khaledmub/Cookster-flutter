import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
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
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      final response = await ApiClient.postRequest(EndPoints.blockUser, {
        "blocked_user": targetUserId,
      });

      print("UNBLOCK USER RESPONSE");
      print(response.body);
      print(response.statusCode);

      if (response.statusCode == 200) {
        // final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        // Update Firestore to remove the user from blockedBy array
        if (currentUserId != null) {
          final chatId = _getChatId(currentUserId, targetUserId);
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .update({
                'blockedBy': FieldValue.arrayRemove([currentUserId]),
              });
          print(
            '✅ Updated Firestore: User $targetUserId unblocked in chat $chatId',
          );
        }

        // Remove the unblocked user from both lists
        blockedUsersList.removeWhere((user) => user.id == targetUserId);
        filteredBlockedUsersList.removeWhere((user) => user.id == targetUserId);

        // Show success message
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text('User unblocked successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );

        // Refresh the video feed to restore unblocked user's videos
        // await fetchVideos();
      } else {
        errorMessage('Failed to unblock user: ${response.statusCode}');
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text('Failed to unblock user: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      errorMessage('Error unblocking user: $e');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Error unblocking user: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();

    print('Chat ID: ${ids[0]}_${ids[1]}');
    return '${ids[0]}_${ids[1]}';
  }
}
