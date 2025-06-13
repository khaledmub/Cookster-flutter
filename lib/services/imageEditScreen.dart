import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

// import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import 'dart:io';
import '../basicVideoEditor/audioSelector.dart';
import '../basicVideoEditor/videoEditorControllers/audioSelectorController.dart';
import '../modules/landing/landingTabs/add/videoAddView/videoAddView.dart';

class ImageEditScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditScreen({required this.imagePath, super.key});

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  File? _editedImage;
  File? _processedVideo;
  bool _isProcessing = false;
  bool _isInitialized = false; // Flag to track screen initialization

  // Define a list of custom text styles with different fonts
  final List<TextStyle> customTextStyles = [
    const TextStyle(fontFamily: 'Arial', fontSize: 20, color: Colors.white),
    const TextStyle(fontFamily: 'Courier', fontSize: 20, color: Colors.white),
    const TextStyle(
      fontFamily: 'Times New Roman',
      fontSize: 20,
      color: Colors.white,
    ),
    const TextStyle(
      fontFamily: 'Comic Sans MS',
      fontSize: 20,
      color: Colors.white,
    ),
  ];
  final AudioSelectorController audioController = Get.put(
    AudioSelectorController(),
  );

  @override
  void initState() {
    super.initState();
    // Initialize audio controller

    // Set initialization flag after a short delay to avoid catching initial value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isInitialized = true;
      });
    });

    // Listen for changes in selected audio and control playback
    ever(audioController.selectedFilePathRx, (String? newPath) {
      if (_isInitialized) {
        if (newPath != null && newPath.isNotEmpty) {
          // Play audio only if it's not already playing to avoid restarting
          if (!audioController.isPlaying) {
            audioController.playAudio().catchError((e) {
              Get.snackbar('Error', 'Failed to play audio: $e');
              return e;
            });
          }
        } else {
          // Stop playback if no audio is selected
          audioController.stopPreview();
        }
      }
    });
  }

  // Show custom bottom sheet when processing
  void _showProcessingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      isDismissible: false,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          height: 250,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'processing'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _convertToVideo() async {
    setState(() {
      _isProcessing = true;
    });
    _showProcessingBottomSheet(context);
    final AudioSelectorController audioController =
        Get.find<AudioSelectorController>();
    try {
      final tempDir = await getTemporaryDirectory();
      File finalImage; // Handle image
      if (_editedImage != null && await _editedImage!.exists()) {
        finalImage = _editedImage!;
        print('Using edited image: ${finalImage.path}');
      } else {
        final inputFile = File(widget.imagePath);
        if (!await inputFile.exists()) {
          print('Input file does not exist: ${widget.imagePath}');
          Get.snackbar('Error', 'Input image file not found');
          setState(() {
            _isProcessing = false;
          });
          Navigator.pop(context);
          return;
        }
        finalImage = await inputFile.copy('${tempDir.path}/final_image.jpg');
        print('Using original image: ${finalImage.path}');
      }
      final outputPath =
          '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Output path: $outputPath');

      String command;
      double videoDuration = 1.0; // Default duration if no audio
      if (audioController.selectedFilePath.isNotEmpty) {
        final audioPath = audioController.selectedFilePath;
        videoDuration = audioController.selectedDuration.toDouble();
        print('Using audio: $audioPath, Duration: $videoDuration seconds');
        // FFmpeg command with H.264 and explicit AAC-LC
        command =
            '-loop 1 -i "${finalImage.path}" -i "$audioPath" '
            '-c:v libx264 -r 30 -preset fast -pix_fmt yuv420p -profile:v main -level 4.0 '
            '-c:a aac -b:a 192k -ar 44100 -t $videoDuration -shortest -movflags +faststart '
            '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$outputPath"';
      } else {
        // FFmpeg command without audio, using H.264
        command =
            '-loop 1 -i "${finalImage.path}" '
            '-c:v libx264 -r 30 -preset fast -pix_fmt yuv420p -profile:v main -level 4.0 '
            '-t $videoDuration -movflags +faststart '
            '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$outputPath"';
      }
      print('Executing FFmpeg Command: $command');
      final session = await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        final allLogs = await session.getAllLogsAsString();
        print('Return Code: $returnCode');
        print('FFmpeg Logs: $allLogs');
        if (returnCode?.isValueSuccess() == true) {
          final outputFile = File(outputPath);
          if (await outputFile.exists()) {
            print(
              'Output video created: $outputPath, Size: ${await outputFile.length()} bytes',
            );
            setState(() {
              _processedVideo = outputFile;
              _isProcessing = false;
            });
            Navigator.pop(context);
            Get.to(
              () =>
                  VideoPreviewScreen(videoFile: _processedVideo!, isImage: "1"),
            );
          } else {
            print('Output file not found at: $outputPath');
            Get.snackbar('Error', 'Video file was not created');
            Navigator.pop(context);
            setState(() {
              _isProcessing = false;
            });
          }
        } else {
          print('FFmpeg failed with return code: $returnCode');
          Get.snackbar('Error', 'Failed to convert image to video: $allLogs');
          Navigator.pop(context);
          setState(() {
            _isProcessing = false;
          });
        }
      }, (log) => print('FFmpeg Log: ${log.getMessage()}'));
    } catch (e) {
      print('Exception during conversion: $e');
      Get.snackbar('Error', 'An unexpected error occurred: $e');
      Navigator.pop(context);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ProImageEditor.file(
                  File(widget.imagePath),
                  configs: ProImageEditorConfigs(
                    textEditor: TextEditorConfigs(
                      customTextStyles: customTextStyles,
                      showSelectFontStyleBottomBar: true,
                      showTextAlignButton: true,
                    ),
                  ),
                  callbacks: ProImageEditorCallbacks(
                    onImageEditingComplete: (Uint8List bytes) async {
                      final tempDir = await getTemporaryDirectory();
                      final editedFile = File(
                        '${tempDir.path}/edited_image.jpg',
                      );
                      await editedFile.writeAsBytes(bytes);

                      setState(() {
                        _editedImage = editedFile;
                      });

                      await _convertToVideo();
                      await audioController.stopPreview();
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(left: 50, top: 40, child: AudioSelector()),
        ],
      ),
    );
  }
}
