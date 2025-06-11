// notification_service.dart
// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

// This function handles background messages
// This function handles background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  print("Complete message: ${message.data}"); // Print the entire data payload
  print("Notification details:");
  print("Title: ${message.notification?.title}");
  print("Body: ${message.notification?.body}");
  print("Data Payload: ${message.data}");

  String? imageUrl = message.data['thumbnail_url'];
  await _showNetworkImageNotification(
    message.notification?.title,
    message.notification?.body,
    imageUrl ?? '',
  );
}

// Initializes foreground notification handling
void handleForegroundMessages() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print(
        "Foreground message received: ${message.data}"); // Print the entire data payload
    print("Notification details:");
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
    print("Data Payload: ${message.data}");

    if (message.data.containsKey('thumbnail_url')) {
      String? imageUrl = message.data['thumbnail_url'];
      String? title = message.notification?.title ?? message.data['title'];
      String? body = message.notification?.body ?? message.data['body'];

      await _showNetworkImageNotification(title, body, imageUrl!);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Message clicked!');
    print("Message opened: ${message.data}"); // Print the entire data payload
    print("Notification details:");
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
  });
}

// Function to show notification with network image
// Function to show notification with network image and a small icon
// Function to show notification with network image and small icon in collapsed view
Future<void> _showNetworkImageNotification(
    String? title, String? body, String imageUrl) async {
  if (imageUrl.isEmpty) {
    print('Invalid image URL: $imageUrl');
    return;
  }

  try {
    print("Showing notification with title: $title");
    print("Showing notification with body: $body");

    // Fetch the large image for the expanded notification style
    final ByteData largeImageBytes = await _networkImageToByteData(imageUrl);
    final String base64LargeImage =
    base64Encode(largeImageBytes.buffer.asUint8List());

    // Use the same image for the small icon (or replace with another URL if needed)
    final ByteData smallIconBytes = await _networkImageToByteData(imageUrl);
    final String base64SmallIcon =
    base64Encode(smallIconBytes.buffer.asUint8List());

    final bigPictureStyleInformation = BigPictureStyleInformation(
      ByteArrayAndroidBitmap.fromBase64String(base64LargeImage),
      contentTitle: title,
      summaryText: body,
      htmlFormatContentTitle: true,
      htmlFormatSummaryText: true,
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'big_picture_channel',
      'Big Picture Channel',
      channelDescription: 'Channel for showing big picture notifications',
      icon: '@mipmap/ic_launcher',
      largeIcon: ByteArrayAndroidBitmap.fromBase64String(
          base64SmallIcon), // Set small icon here for collapsed view
      styleInformation: bigPictureStyleInformation,
      importance: Importance.high,
      priority: Priority.high,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.cancelAll();
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  } catch (e) {
    print('Error in _showNetworkImageNotification: $e');
  }
}

// Function to fetch image data
Future<ByteData> _networkImageToByteData(String imageUrl) async {
  try {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      final Uint8List bytes = response.bodyBytes;
      return ByteData.sublistView(bytes);
    } else {
      print('Failed to load image, status code: ${response.statusCode}');
      throw Exception('Failed to load network image');
    }
  } catch (e) {
    print('Exception caught: $e');
    throw Exception('Failed to load network image');
  }
}

// Initializes Firebase notifications
Future<void> setupNotifications() async {
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}