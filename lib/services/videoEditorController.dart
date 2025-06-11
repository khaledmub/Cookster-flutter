// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:ve_sdk_flutter/export_result.dart';
// import 'package:ve_sdk_flutter/features_config.dart';
// import 'package:ve_sdk_flutter/ve_sdk_flutter.dart';
//
// import '../modules/landing/landingTabs/add/videoAddView/videoAddView.dart';
//
// const _licenseToken =
//     "Qk5CIGpjR9IdBFQeQBMPCoUIuNLndEo52nek+tQo570cc78Xf9UKadspJou+1Am7bR1m7VVeco7P11wKtQTUv0HRQF7Ydpekz4cLCf/GiwPLTgW2a4cgEjOVwUTre4fMkb3/S7I2+WSPr2U1PKN9NZcXjRHqDoxCQoXdtFOr+LtVYZB0oQoc9LKQ7LhFgkuQNUc/1NkSqe4JUxBHRqh7N61tRXDWK/thAL0KS+UwGUz+51+YcXIJojD0OWdYiyKmqpfg+KcXhkj67wnaHsDXDfCWB3GAD8JE3nOgZ6SukIBpbs3dVudgC+3Z1wzx1SF73UanayRO7qAbhZKaN0253+vVNi4C70qzF8yetV6/JTnyMWi9hzJSPK/fWMEHjijGx8nxP1vKhOcC7wwHx2F2u69aNe0Q37WBWw8HTPL/STel1FAebiUuegxHnF2ibKkQSMBOV1W20f265xrrwMsJT8jACPP6fjcgoFgkV374XkUV/+uK7r9mIj0/W02EWs2x5G4Rk9qnmFw0NNWZ7VAVwlEAsWpaALDKpBGyy2MLN3uZZE74eciq7PeuHMWzxJjSKZxipjHMKiuo22fUmaM3XeiZe9nebv2wmmWKa20+slz4Kmz02+6mqqhIhBpQaJNbRklzd2wBKodY1ohAZ8kB4Q==";
//
// class VideoEditorController extends GetxController {
//   final VeSdkFlutter _veSdkFlutterPlugin = VeSdkFlutter();
//   String _errorMessage = '';
//
//   Future<void> startVideoEditorInCameraMode() async {
//     // Specify your Config params in the builder below
//
//     final config =
//         FeaturesConfigBuilder()
//             // .setAiCaptions(...)
//             // ...
//             .build();
//
//     // Export data example
//
//     // const exportData = ExportData(exportedVideos: [
//     //   ExportedVideo(
//     //       fileName: "export_HD",
//     //       videoResolution: VideoResolution.hd720p
//     //   )],
//     //     watermark: Watermark(
//     //        imagePath: "assets/watermark.png",
//     //        alignment: WatermarkAlignment.topLeft
//     //     )
//     // );
//
//     try {
//       dynamic exportResult = await _veSdkFlutterPlugin.openCameraScreen(
//         _licenseToken,
//         config,
//       );
//       _handleExportResult(exportResult);
//     } on PlatformException catch (e) {
//       _handlePlatformException(e);
//     }
//   }
//
//   Future<void> startVideoEditorInPipMode() async {
//     // Specify your Config params in the builder below
//
//     final config =
//         FeaturesConfigBuilder()
//             // .setAudioBrowser(...)
//             // ...
//             .build();
//     final ImagePicker picker = ImagePicker();
//     final videoFile = await picker.pickVideo(source: ImageSource.gallery);
//
//     final sourceVideoFile = videoFile?.path;
//     if (sourceVideoFile == null) {
//       debugPrint(
//         'Error: Cannot start video editor in pip mode: please pick video file',
//       );
//       return;
//     }
//
//     try {
//       dynamic exportResult = await _veSdkFlutterPlugin.openPipScreen(
//         _licenseToken,
//         config,
//         sourceVideoFile,
//       );
//       _handleExportResult(exportResult);
//     } on PlatformException catch (e) {
//       _handlePlatformException(e);
//     }
//   }
//
//   Future<void> startVideoEditorInTrimmerMode(BuildContext context) async {
//     final config = FeaturesConfigBuilder().build();
//     final ImagePicker picker = ImagePicker();
//     final videoFiles = await picker.pickMultipleMedia(imageQuality: 3);
//
//     if (videoFiles.isEmpty) {
//       debugPrint('Error: Please pick video files');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: Please pick a video file'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     final sources = videoFiles.map((f) => f.path).toList();
//
//     try {
//       dynamic exportResult = await _veSdkFlutterPlugin.openTrimmerScreen(
//         _licenseToken,
//         config,
//         sources,
//       );
//       _handleExportResult(exportResult);
//     } on PlatformException catch (e) {
//       _handlePlatformException(e);
//     }
//   }
//
//   void _handlePlatformException(PlatformException exception) {
//     _errorMessage = exception.message ?? 'unknown error';
//     debugPrint("Error: code = ${exception.code}, message = $_errorMessage");
//   }
//
//   void _handleExportResult(ExportResult? result) {
//     if (result == null) {
//       debugPrint(
//         'No export result! The user has closed video editor before export',
//       );
//       return;
//     }
//
//     debugPrint('Exported video files = ${result.videoSources}');
//     // Convert the first video path into a File object before passing
//     Get.to(VideoPreviewScreen(videoFile: File(result.videoSources.first)));
//     debugPrint('Exported preview file = ${result.previewFilePath}');
//     debugPrint('Exported meta file = ${result.metaFilePath}');
//   }
// }
