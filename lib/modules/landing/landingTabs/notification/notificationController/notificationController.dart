import 'dart:convert';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../appUtils/apiEndPoints.dart';
import '../../../../../services/apiClient.dart';
import '../notificationModel/notificationModel.dart';

class NotificationController extends GetxController {
  var notificationData = NotificationModel().obs;
  var isLoading = false.obs;

  Future<void> fetchNotifications(BuildContext context) async {
    isLoading.value = true;

    try {
      final response = await ApiClient.getRequest(EndPoints.notifications);

      if (kDebugMode) {
        debugPrint('Notifications response length: ${response.body.length}');
      }

      if (response.statusCode == 200) {
        final parsed = await compute(parseNotificationsFull, response.body);
        notificationData.value = parsed;
      } else {
        // Decode the response body to extract the server message
        final responseBody = jsonDecode(response.body);
        final String message =
            responseBody['message'] ?? "Failed to fetch notifications";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Something went wrong: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void clearNotifications() {
    notificationData.value = NotificationModel();
  }

  @override
  void onClose() {
    clearNotifications();
    super.onClose();
  }
}
