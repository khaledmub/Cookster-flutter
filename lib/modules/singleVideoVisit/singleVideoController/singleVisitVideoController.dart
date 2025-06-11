import 'dart:convert';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:get/get.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../services/apiClient.dart';
import '../singleVideoModel/singleVisitVideoModel.dart';

class SingleVisitVideoController extends GetxController {
  var isLoading = true.obs;
  var singleVideoContent = SingleVideoDetail().obs;

  Future<void> fetchSingleVideo(String videoId) async {
    final endPoint = '${EndPoints.singleVideoDetails}?id=$videoId';

    print("=========PRINTING THE VIDEO ID=========");
    print(videoId);

    try {
      isLoading.value = true;

      var response = await ApiClient.getRequest(endPoint);

      // Print the response status code and body
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        singleVideoContent.value = SingleVideoDetail.fromJson(responseData);
      } else if (response.statusCode == 401) {
        Get.offAllNamed(
          AppRoutes.signIn,
        ); // Navigate to the login screen and clear the stack
      } else {
        Get.snackbar("Error", "Failed to load video details.");
      }
    } catch (e) {
      print("Error fetching video details: $e");
      Get.snackbar("Error", "An error occurred while fetching video details.");
    } finally {
      isLoading.value = false;
    }
  }
}
