import 'dart:convert';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:get/get.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../services/apiClient.dart';
import '../singleVideoModel/singleVisitVideoModel.dart';

class SingleVisitVideoController extends GetxController {
  var isLoading = true.obs;
  var singleVideoContent = SingleVideoDetail().obs;
  String? _currentVideoId; // Track the current video ID
  String? _latestRequestedVideoId; // Track the latest requested video ID

  @override
  void onInit() {
    super.onInit();
    resetVideoContent();
  }

  void resetVideoContent() {
    singleVideoContent.value = SingleVideoDetail();
    _currentVideoId = null;
    _latestRequestedVideoId = null;
    isLoading.value = true;
  }

  Future<void> fetchSingleVideo(String videoId) async {
    if (_currentVideoId == videoId && singleVideoContent.value.video != null) {
      print("Same video ID ($videoId), skipping fetch");
      return;
    }

    final endPoint = '${EndPoints.singleVideoDetails}?id=$videoId';
    print("=========PRINTING THE VIDEO ID=========");
    print(videoId);

    try {
      resetVideoContent();
      _currentVideoId = videoId;
      _latestRequestedVideoId = videoId; // Track the latest request

      var response = await ApiClient.getRequest(endPoint);

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      // Only process the response if it matches the latest requested video ID
      if (_latestRequestedVideoId != videoId) {
        print("Ignoring response for outdated video ID: $videoId");
        return;
      }

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        singleVideoContent.value = SingleVideoDetail.fromJson(responseData);
      } else if (response.statusCode == 401) {
        Get.offAllNamed(AppRoutes.signIn);
      } else {
        Get.snackbar("Error", "Failed to load video details.");
      }
    } catch (e) {
      print("Error fetching video details: $e");
      if (_latestRequestedVideoId == videoId) {
        Get.snackbar("Error", "An error occurred while fetching video details.");
      }
    } finally {
      if (_latestRequestedVideoId == videoId) {
        isLoading.value = false;
      }
    }
  }
}