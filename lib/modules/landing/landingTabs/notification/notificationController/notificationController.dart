import 'dart:convert';
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

      print(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        notificationData.value = NotificationModel.fromJson(jsonResponse);
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
      print("Error fetching notifications: $e");
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
}
