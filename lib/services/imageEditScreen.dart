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

/// Result returned to the caller (Landing / camera) which then opens the upload
/// form. ImageEdit must NOT navigate to the form itself — stacking or
/// replacing while ProImageEditor is still closing pops the form (~1–4s).
class PreparedUploadMedia {
  final File file;
  /// `'1'` still image, `'0'` image+audio (mp4).
  final String isImage;

  const PreparedUploadMedia({required this.file, required this.isImage});
}

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
  PreparedUploadMedia? _pendingUpload;
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
    if (_didNavigate || _pendingUpload != null) {
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
        _pendingUpload = PreparedUploadMedia(file: finalImage, isImage: '1');
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
          _pendingUpload =
              PreparedUploadMedia(file: outputFile, isImage: '0');
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

    final media = _pendingUpload;
    if (media != null) {
      _didNavigate = true;
      _pendingUpload = null;
      await audioController.stopPreview();
      // ProImageEditor calls setState AFTER onCloseEditor returns. Pop after
      // that rebuild so we don't tear down mid-activate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_returnPreparedMedia(media));
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
      if (mounted && !_didNavigate) {
        Get.back<PreparedUploadMedia?>();
      }
    });
  }

  Future<void> _returnPreparedMedia(PreparedUploadMedia media) async {
    _clearEditorOverlays();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    // Hand media back to Landing/camera — never Get.to/off the upload form from
    // here (that races ProImageEditor teardown and pops the form).
    if (mounted) {
      Get.back<PreparedUploadMedia?>(result: media);
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
