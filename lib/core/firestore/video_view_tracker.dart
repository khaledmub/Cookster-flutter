import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class VideoViewTracker {
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id != null && id.isNotEmpty) return id;

    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      id = (await deviceInfo.androidInfo).id;
    } else if (Platform.isIOS) {
      id = (await deviceInfo.iosInfo).identifierForVendor;
    } else {
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }
    await prefs.setString('device_id', id!);
    return id;
  }

  static Future<void> trackUniqueView({
    required String videoId,
    String? userId,
    required bool isAuthenticated,
  }) async {
    if (videoId.isEmpty) return;

    final viewerKey = isAuthenticated && userId != null && userId.isNotEmpty
        ? userId
        : await deviceId();
    final videoRef =
        FirebaseFirestore.instance.collection('videos').doc(videoId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(videoRef);
      final views = List<String>.from(
        (snap.data()?['views'] as List?)?.map((e) => e.toString()) ?? [],
      );
      if (views.contains(viewerKey)) return;
      tx.set(
        videoRef,
        {
          'views': FieldValue.arrayUnion([viewerKey]),
          'viewCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    });
  }

  static int resolveDisplayCount(Map<String, dynamic> data) {
    final denormalized = data['viewCount'];
    if (denormalized is num) return denormalized.toInt();
    final views = data['views'];
    if (views is List) return views.length;
    return 0;
  }
}
