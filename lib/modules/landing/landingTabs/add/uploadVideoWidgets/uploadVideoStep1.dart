import 'dart:async';
import 'dart:io';

import 'package:cookster/core/video/upload_video_preview_service.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../../../appUtils/appUtils.dart';
import '../../../../../appUtils/colorUtils.dart';

class UploadVideoStep1 extends StatefulWidget {
  final File videoFile;

  const UploadVideoStep1({super.key, required this.videoFile});

  @override
  State<UploadVideoStep1> createState() => _UploadVideoStep1State();
}

class _UploadVideoStep1State extends State<UploadVideoStep1> {
  final VideoAddController videoAddController = Get.find();

  final GlobalKey<FormFieldState> _titleKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _descriptionKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    unawaited(videoAddController.prepareThumbnail(widget.videoFile));
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Form(
          key: videoAddController.step1key,
          child: Column(
            spacing: 2,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step1PreviewRow(
                videoFile: widget.videoFile,
                titleController: videoAddController.titleController,
                descriptionController: videoAddController.descriptionController,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "video_information".tr,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  spacing: 8.h,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "video_title_label".tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppUtils.customPasswordTextField(
                          fieldKey: _titleKey,
                          controller: videoAddController.titleController,
                          labelText: "enter_video_title".tr,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "video_title_error".tr;
                            }
                            if (value.length > 70) {
                              return "video_title_length_error".tr;
                            }
                            return videoAddController.checkBadWords(
                              context,
                              value,
                            );
                          },
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: videoAddController.titleController,
                          builder: (context, value, _) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "${value.text.characters.length}/70",
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      "description_label".tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppUtils.customPasswordTextField(
                      maxLines: 3,
                      fieldKey: _descriptionKey,
                      controller: videoAddController.descriptionController,
                      labelText: "enter_video_description".tr,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          return videoAddController.checkBadWords(
                            context,
                            value,
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview + live title/description summary. Rebuilds only when keyboard opens/closes.
class _Step1PreviewRow extends StatelessWidget {
  const _Step1PreviewRow({
    required this.videoFile,
    required this.titleController,
    required this.descriptionController,
  });

  final File videoFile;
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return _KeyboardOpenBuilder(
      builder: (context, keyboardOpen) {
        if (keyboardOpen) return const SizedBox.shrink();
        return Row(
          children: [
            _UploadVideoPreview(videoFile: videoFile),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: titleController,
                    builder: (context, value, _) {
                      final text = value.text;
                      return Text(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text.isEmpty ? "video_title_here".tr : text,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: descriptionController,
                    builder: (context, value, _) {
                      final text = value.text;
                      return Text(
                        text.isEmpty
                            ? "video_description_placeholder".tr
                            : text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ColorUtils.greyTextFieldBorderColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Isolates MediaQuery keyboard inset — does not rebuild the whole step.
class _KeyboardOpenBuilder extends StatelessWidget {
  const _KeyboardOpenBuilder({required this.builder});

  final Widget Function(BuildContext context, bool keyboardOpen) builder;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return builder(context, keyboardOpen);
  }
}

/// Small inline video preview — isolated state so typing in the form does not rebuild it.
class _UploadVideoPreview extends StatefulWidget {
  const _UploadVideoPreview({required this.videoFile});

  final File videoFile;

  @override
  State<_UploadVideoPreview> createState() => _UploadVideoPreviewState();
}

class _UploadVideoPreviewState extends State<_UploadVideoPreview> {
  final VideoAddController _videoAddController = Get.find();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPreparing = true;
  bool _isPlaying = false;
  bool _previewUnavailable = false;
  File? _fallbackThumb;
  late final Worker _stepWorker;

  @override
  void initState() {
    super.initState();
    unawaited(_initPlayer());
    unawaited(_videoAddController.prepareThumbnail(widget.videoFile));
    _stepWorker = ever(_videoAddController.currentStep, (step) {
      if (step != 1) {
        _controller?.pause();
        if (mounted && _isPlaying) {
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  Future<void> _initPlayer() async {
    try {
      final playable = await UploadVideoPreviewService.resolvePlayableFile(
        widget.videoFile,
      );
      final controller = VideoPlayerController.file(playable);
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {
        _isInitialized = true;
        _isPreparing = false;
      });
    } catch (e) {
      debugPrint('UploadVideoPreview init failed: $e');
      final thumb = await _videoAddController.ensureThumbnail(widget.videoFile);
      if (!mounted) return;
      setState(() {
        _previewUnavailable = true;
        _fallbackThumb = thumb;
        _isPreparing = false;
      });
    }
  }

  @override
  void dispose() {
    _stepWorker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
      setState(() => _isPlaying = false);
    } else {
      controller.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 150,
        width: 90,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isPreparing) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_previewUnavailable) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _fallbackThumb != null
                ? Image.file(
                    _fallbackThumb!,
                    height: 150,
                    width: 90,
                    fit: BoxFit.cover,
                  )
                : ColoredBox(
                    color: Colors.black12,
                    child: SizedBox(height: 150, width: 90),
                  ),
          ),
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
          _buildCancelButton(),
        ],
      );
    }

    final controller = _controller!;
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 9 / 16;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 150,
              width: 90,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: Colors.white,
            size: 40,
          ),
          _buildCancelButton(),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Positioned(
      bottom: 10,
      child: InkWell(
        onTap: Get.back,
        child: const Icon(
          Icons.cancel_rounded,
          color: Colors.red,
          size: 30,
        ),
      ),
    );
  }
}
