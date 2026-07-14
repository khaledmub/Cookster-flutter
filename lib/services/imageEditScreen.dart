import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../basicVideoEditor/audioSelector.dart';
import '../basicVideoEditor/videoEditorControllers/audioSelectorController.dart';
import '../modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import '../modules/landing/landingTabs/add/videoAddView/videoAddView.dart';

class ImageEditScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditScreen({required this.imagePath, super.key});

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  File? _editedImage;
  /// Prepared in [onImageEditingComplete]; navigation happens in
  /// [onCloseEditor] AFTER ProImageEditor hides LoadingDialog.
  File? _pendingUploadFile;
  bool _acceptAttempted = false;
  bool _isInitialized = false;
  bool _didNavigate = false;
  Worker? _audioWorker;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });

    _audioWorker = ever(audioController.selectedFilePathRx, (String? newPath) {
      if (!_isInitialized) {
        return;
      }
      if (newPath != null && newPath.isNotEmpty) {
        if (!audioController.isPlaying) {
          audioController.playAudio().catchError((e) {
            Get.snackbar('Error', 'Failed to play audio: $e');
            return e;
          });
        }
      } else {
        audioController.stopPreview();
      }
    });
  }

  @override
  void dispose() {
    _audioWorker?.dispose();
    _clearEditorOverlays();
    super.dispose();
  }

  void _clearEditorOverlays() {
    try {
      while (LoadingDialog.instance.hasActiveOverlay) {
        LoadingDialog.instance.hide();
      }
    } catch (_) {}
  }

  Future<void> _prepareUploadMedia() async {
    if (_didNavigate || _pendingUploadFile != null) {
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final File finalImage;
      if (_editedImage != null && await _editedImage!.exists()) {
        finalImage = _editedImage!;
      } else {
        final inputFile = File(widget.imagePath);
        if (!await inputFile.exists()) {
          Get.snackbar('Error', 'Input image file not found');
          return;
        }
        finalImage = await inputFile.copy('${tempDir.path}/final_image.jpg');
      }

      // No audio → upload the still image (is_image=1).
      if (audioController.selectedFilePath.isEmpty) {
        _pendingUploadFile = finalImage;
        return;
      }

      final outputPath =
          '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final audioPath = audioController.selectedFilePath;
      final videoDuration = audioController.selectedDuration.toDouble();
      final command =
          '-loop 1 -i "${finalImage.path}" -i "$audioPath" '
          '-c:v libx264 -r 30 -preset fast -pix_fmt yuv420p -profile:v main -level 4.0 '
          '-c:a aac -b:a 192k -ar 44100 -t $videoDuration -shortest -movflags +faststart '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final allLogs = await session.getAllLogsAsString();

      if (returnCode?.isValueSuccess() == true) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          _pendingUploadFile = outputFile;
          return;
        }
        Get.snackbar('Error', 'Video file was not created');
      } else {
        Get.snackbar('Error', 'Failed to convert image to video: $allLogs');
      }
    } catch (e) {
      Get.snackbar('Error', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _handleEditorClose() async {
    if (_didNavigate) {
      return;
    }

    final media = _pendingUploadFile;
    if (media != null) {
      _didNavigate = true;
      _pendingUploadFile = null;
      await audioController.stopPreview();
      // ProImageEditor calls setState AFTER onCloseEditor returns. Navigating
      // synchronously left a half-deactivated StatefulElement (null state on
      // activate → white crash). Wait until that rebuild finishes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_openUploadForm(media));
        });
      });
      return;
    }

    // Accept ran but prepare failed — stay on editor so the user can retry.
    if (_acceptAttempted) {
      _acceptAttempted = false;
      _clearEditorOverlays();
      return;
    }

    // User cancelled the editor.
    await audioController.stopPreview();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearEditorOverlays();
      if (mounted) {
        Get.back();
      }
    });
  }

  Future<void> _openUploadForm(File media) async {
    _clearEditorOverlays();
    // One more yield so LoadingDialog overlay entries finish removing.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!Get.isRegistered<VideoAddController>()) {
      Get.put(VideoAddController());
    }
    Get.off(
      () => VideoPreviewScreen(videoFile: media, isImage: '1'),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<VideoAddController>()) {
          Get.put(VideoAddController());
        }
      }),
    );
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
                      _acceptAttempted = true;
                      final tempDir = await getTemporaryDirectory();
                      final editedFile = File(
                        '${tempDir.path}/edited_image.jpg',
                      );
                      await editedFile.writeAsBytes(bytes);
                      if (!mounted) {
                        return;
                      }
                      setState(() => _editedImage = editedFile);
                      // Prepare only. ProImageEditor keeps LoadingDialog open
                      // until this callback returns, then hide() + onCloseEditor.
                      await _prepareUploadMedia();
                    },
                    onCloseEditor: (_) {
                      unawaited(_handleEditorClose());
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 50,
            top: 10,
            child: SafeArea(child: AudioSelector()),
          ),
        ],
      ),
    );
  }
}
