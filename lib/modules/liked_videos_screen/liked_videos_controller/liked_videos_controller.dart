import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Import for ScaffoldMessenger
import 'package:get/get.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../liked_videos_model/liked_videos_model.dart'; // Use provided model

class LikedVideosController extends GetxController {
  final String userId;
  final BuildContext context; // Add context for ScaffoldMessenger
  final RxList<String> videoIds = <String>[].obs; // Firestore video IDs
  final RxInt totalLikes = 0.obs; // Firestore total likes count
  final RxString commaSeparatedIds = ''.obs; // Firestore comma-separated IDs
  final RxList<LikedVideos> likedVideos =
      <LikedVideos>[].obs; // API-fetched videos
  final RxBool isLoading = false.obs; // Loading state for API
  String?
  _previousCommaSeparatedIds; // Track previous IDs to avoid duplicate API calls

  LikedVideosController({required this.userId, required this.context});

  @override
  void onInit() {
    super.onInit();
    // Bind Firestore streams to reactive variables
    bindStreams();
  }

  // Bind Firestore streams to reactive variables
  void bindStreams() {
    // Stream for total likes count
    FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .listen(
          (QuerySnapshot querySnapshot) {
            totalLikes.value = querySnapshot.docs.length;
          },
          onError:
              (e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error fetching total likes: $e'),
                  duration: Duration(seconds: 3),
                ),
              ),
        );

    // Stream for liked video IDs
    FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .listen(
          (QuerySnapshot querySnapshot) {
            videoIds.value = querySnapshot.docs.map((doc) => doc.id).toList();
            commaSeparatedIds.value = videoIds.join(',');

            // Send to API only if IDs have changed and not empty
            if (commaSeparatedIds.value != _previousCommaSeparatedIds &&
                commaSeparatedIds.value.isNotEmpty) {
              _previousCommaSeparatedIds = commaSeparatedIds.value;
              sendVideoIdsToApi(commaSeparatedIds.value);
            }
          },
          onError:
              (e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error fetching video IDs: $e'),
                  duration: Duration(seconds: 3),
                ),
              ),
        );
  }

  // Function to send comma-separated IDs to the API and fetch liked videos
  Future<void> sendVideoIdsToApi(String commaSeparatedIds) async {
    try {
      isLoading(true);
      print(
        '📤 Sending POST request to ${EndPoints.myLikedVideos} with body: {"video_ids": "$commaSeparatedIds"}',
      );

      final response = await ApiClient.postRequest(EndPoints.myLikedVideos, {
        'video_ids': commaSeparatedIds,
      });

      print('📥 Response received with status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final likedVideosModel = LikedVideosModel.fromJson(
          jsonDecode(response.body),
        );

        if (likedVideosModel.videos != null) {
          print('✅ Fetched ${likedVideosModel.videos!.length} liked videos.');
          likedVideos.assignAll(likedVideosModel.videos!);
        } else {
          print('⚠️ No videos found in response.');
          likedVideos.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No liked videos found'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('❌ Failed to fetch liked videos: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch liked videos: ${response.statusCode}',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('🔥 Error fetching liked videos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching liked videos: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      isLoading(false);
      print('✅ Loading finished.');
    }
  }
}
