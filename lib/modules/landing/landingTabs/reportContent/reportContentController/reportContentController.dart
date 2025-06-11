import 'package:cookster/services/apiClient.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import '../reportContentModel/reportContentModel.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // Add this import

class ReportContentController extends GetxController {
  var isLoading = true.obs;
  var isReportSubmitting = false.obs; // Changed to false initially
  var reportContent = ReportContent().obs;
  var selectedReasonId = Rxn<String>();
  final RxBool showTextField = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchReportContent();
  }

  Future<void> submitReport(String videoId, String comment) async {
    print(comment);
    try {
      isReportSubmitting.value = true;

      final response = await ApiClient.postRequest(EndPoints.submitReport, {
        'video_id': videoId,
        'category_id': selectedReasonId.value!,
        'comments': comment,
      });

      print("Response from server: ${response.body}");
      print(response.statusCode);

      final responseBody = jsonDecode(response.body);

      final message = responseBody['message'];

      if (response.statusCode == 201) {
        // Success dialog
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          title: 'success'.tr,
          desc: message,
          btnOkText: 'ok'.tr,
          btnOkOnPress: () {
            selectedReasonId.value = null;
            showTextField.value = false;
            Get.back();
          },
          dismissOnTouchOutside: false,
        )..show();
      } else if (responseBody['status'] == false && responseBody['errors'] != null) {
        // Extract error messages from validation errors
        String errorMessages = '';
        int count = 1;

        responseBody['errors'].forEach((key, value) {
          if (value is List) {
            for (var msg in value) {
              errorMessages += '${count++}. $msg\n';
            }
          }
        });

        // Show validation error dialog
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          animType: AnimType.bottomSlide,
          title: 'error'.tr,
          desc: errorMessages.trim(),
          btnOkText: 'ok'.tr,
          btnOkOnPress: () {},
        )..show();
      } else {
        // Generic error
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          animType: AnimType.bottomSlide,
          title: 'error'.tr,
          desc: 'Failed to submit report. Please try again.',
          btnOkText: 'OK',
          btnOkOnPress: () {},
        )..show();
      }
    } catch (e) {
      print("Error submitting report: $e");
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'error'.tr,
        desc: 'An error occurred while submitting your report.',
        btnOkText: 'ok'.tr,
        btnOkOnPress: () {},
      )..show();
    } finally {
      isReportSubmitting.value = false;
    }
  }

  Future<void> fetchReportContent() async {
    try {
      isLoading(true);
      final response = await ApiClient.getRequest(EndPoints.contentReport);

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        reportContent.value = ReportContent.fromJson(jsonData);
      } else {
        Get.snackbar('Error', 'Failed to fetch data');
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading(false);
    }
  }

  void setSelectedReason(String reasonId) {
    selectedReasonId.value = reasonId;
  }
}
