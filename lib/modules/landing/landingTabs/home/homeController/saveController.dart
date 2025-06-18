import 'dart:convert';

import 'package:get/get.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../../../../../services/apiClient.dart';
import '../homeModel/userSaveUnsave.dart'; // Adjust path if needed

class SaveController extends GetxController {
  var isLoading = false.obs;
  var savedVideos = <SavedVideos>[].obs;

  @override
  void onInit() {
    super.onInit();
    // getSavedVideos();
  }

  /// Save a video
  Future<bool> saveVideo(String videoId) async {
    try {
      print('🔄 Starting saveVideo for videoId: $videoId');

      isLoading(true);
      print('⏳ Loading state set to true');

      final Map<String, dynamic> payload = {'video_id': videoId};
      print('📤 Sending POST request to ${EndPoints.save} with body: $payload');

      final response = await ApiClient.postRequest(EndPoints.save, payload);

      print('📥 Response received with status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Video saved successfully!');
        return true;
      } else {
        print('❌ Failed to save video');
        return false;
      }
    } catch (e) {
      print('🔥 Error during saveVideo: $e');
      return false;
    } finally {
      isLoading(false);
      print('✅ Loading state set to false');
    }
  }

  /// Fetch saved videos
  /// Fetch saved videos using POST API
  Future<void> getSavedVideos() async {
    try {
      print('🔄 Fetching saved videos (POST API)...');
      isLoading(true);

      final response = await ApiClient.postRequest(
        EndPoints.getSavedVideos,
        {}, // Pass empty map if no body is required
      );

      print('📥 Response received with status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final savedVideosModel = SavedVideosModel.fromJson(
          jsonDecode(response.body),
        );

        if (savedVideosModel.videos != null) {
          print('✅ Fetched ${savedVideosModel.videos!.length} saved videos.');
          savedVideos.assignAll(savedVideosModel.videos!);
        } else {
          print('⚠️ No videos found in response.');
          savedVideos.clear();
        }
      } else {
        print('❌ Failed to fetch saved videos: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error fetching saved videos: $e');
    } finally {
      isLoading(false);
      print('✅ Loading finished.');
    }
  }
}
