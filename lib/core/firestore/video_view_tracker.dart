import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/video/watched_videos_store.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoViewTracker {
  /// Session dedupe so ~2s track + retries don't burn the 60/min API budget.
  static final Set<String> _apiReportedIds = <String>{};

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

    // Optimistic local mark so Home refresh can put this reel after still-
    // unwatched ones even before API/Firestore commits.
    await WatchedVideosStore.instance.markWatched(videoId);

    // Server ranking for page 2+ — fire-and-forget; never block UI / Firebase.
    unawaited(reportViewToApi(videoId));

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

  /// POST /api/reels/{videoId}/view — idempotent; powers unseen_first ranking.
  static Future<void> reportViewToApi(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty || _apiReportedIds.contains(id)) {
      return;
    }
    _apiReportedIds.add(id);
    try {
      final device = await deviceId();
      final response = await ApiClient.postRequest(
        EndPoints.reelView(id),
        {
          if (device.isNotEmpty) 'device_id': device,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Allow a later retry this session if the server rejected the write.
        _apiReportedIds.remove(id);
        if (kDebugMode) {
          debugPrint(
            '[ReelView] API ${response.statusCode} for $id: ${response.body}',
          );
        }
      }
    } catch (e) {
      _apiReportedIds.remove(id);
      if (kDebugMode) {
        debugPrint('[ReelView] API error for $id: $e');
      }
    }
  }

  /// POST /api/reels/views — batch (max 20). Optional helper for catch-up sync.
  ///
  /// [force] resends ids already reported this session (idempotent). Home
  /// refresh uses that so the next unseen-first GET sees the local watched set.
  static Future<void> reportViewsBatchToApi(
    List<String> videoIds, {
    bool force = false,
  }) async {
    final ids = videoIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && (force || !_apiReportedIds.contains(e)))
        .take(20)
        .toList();
    if (ids.isEmpty) {
      return;
    }
    _apiReportedIds.addAll(ids);
    try {
      final device = await deviceId();
      final response = await ApiClient.postRequest(
        EndPoints.reelsViewsBatch,
        {
          if (device.isNotEmpty) 'device_id': device,
          'video_ids': ids,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        for (final id in ids) {
          _apiReportedIds.remove(id);
        }
        if (kDebugMode) {
          debugPrint(
            '[ReelView] batch API ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      for (final id in ids) {
        _apiReportedIds.remove(id);
      }
      if (kDebugMode) {
        debugPrint('[ReelView] batch API error: $e');
      }
    }
  }

  static int resolveDisplayCount(Map<String, dynamic> data) {
    final denormalized = data['viewCount'];
    if (denormalized is num) return denormalized.toInt();
    final views = data['views'];
    if (views is List) return views.length;
    return 0;
  }
}
