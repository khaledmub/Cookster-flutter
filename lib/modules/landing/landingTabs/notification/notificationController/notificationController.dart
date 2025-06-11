import 'dart:convert';
import 'package:get/get.dart';

import '../../../../../appUtils/apiEndPoints.dart';
import '../../../../../services/apiClient.dart';
import '../notificationModel/notificationModel.dart'; // Adjust path to your model

class NotificationController extends GetxController {
  // Observable for notification data
  var notificationData = NotificationModel().obs;

  // Observable for loading state
  var isLoading = false.obs;

  // Fetch notifications from API
  Future<void> fetchNotifications() async {
    isLoading.value = true;

    try {
      final response = await ApiClient.getRequest(EndPoints.notifications);

      print(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        notificationData.value = NotificationModel.fromJson(jsonResponse);
      } else {
        Get.snackbar("Error", "Failed to fetch notifications");
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      Get.snackbar("Error", "Something went wrong: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Optional: Clear notifications
  void clearNotifications() {
    notificationData.value = NotificationModel();
  }
}
