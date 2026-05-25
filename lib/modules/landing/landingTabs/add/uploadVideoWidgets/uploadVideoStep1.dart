import 'dart:async';
import 'dart:io';

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

class _UploadVideoStep1State extends State<UploadVideoStep1>
    with AutomaticKeepAliveClientMixin {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  final VideoAddController videoAddController = Get.find();

  final GlobalKey<FormFieldState> _titleKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _descriptionKey = GlobalKey<FormFieldState>();

  late final Worker _stepWorker;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    unawaited(videoAddController.prepareThumbnail(widget.videoFile));
    _stepWorker = ever(videoAddController.currentStep, (step) {
      if (step != 1 && _isInitialized) {
        _videoPlayerController.pause();
        if (mounted) setState(() => _isPlaying = false);
      }
    });
  }

  Future<void> _initializeVideo() async {
    _videoPlayerController = VideoPlayerController.file(widget.videoFile);
    await _videoPlayerController.initialize();
    if (!mounted) return;
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _stepWorker.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Container(
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
            if (!keyboardOpen)
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 150,
                    width: 90,
                    child: _isInitialized
                      ? GestureDetector(
                          onTap: () {
                            if (_videoPlayerController.value.isPlaying) {
                              _videoPlayerController.pause();
                              setState(() => _isPlaying = false);
                            } else {
                              _videoPlayerController.play();
                              setState(() => _isPlaying = true);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio:
                                      _videoPlayerController.value.aspectRatio >
                                              0
                                          ? _videoPlayerController
                                              .value
                                              .aspectRatio
                                          : 9 / 16,
                                  child: VideoPlayer(_videoPlayerController),
                                ),
                              ),
                              Positioned(
                                child: Icon(
                                  _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                child: InkWell(
                                  onTap: Get.back,
                                  child: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.red,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: Get.width * 0.55,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: videoAddController.titleController,
                        builder: (context, value, _) {
                          final text = value.text;
                          return Text(
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            text.isEmpty
                                ? "video_title_here".tr
                                : text,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.sp,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable:
                              videoAddController.descriptionController,
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
                      ),
                    ),
                  ],
                  ),
                ],
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
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "${value.text.characters.length}/70",
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.end,
                              ),
                            ],
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
                        return videoAddController.checkBadWords(context, value);
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
    );
  }
}
