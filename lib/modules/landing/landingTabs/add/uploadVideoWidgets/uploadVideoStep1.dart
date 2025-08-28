import 'dart:io';

import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import '../../../../../appUtils/appUtils.dart';
import '../../../../../appUtils/colorUtils.dart';

class UploadVideoStep1 extends StatefulWidget {
  final File videoFile;

  const UploadVideoStep1({super.key, required this.videoFile});

  @override
  _UploadVideoStep1State createState() => _UploadVideoStep1State();
}

class _UploadVideoStep1State extends State<UploadVideoStep1> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  RxBool isPlaying = false.obs;
  final ProfileController profileController = Get.find();
  final VideoAddController videoAddController = Get.find();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoPlayerController = VideoPlayerController.file(widget.videoFile);

    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      showControls: false,
      autoPlay: false,
      looping: false,
    );

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rest of your existing build method remains unchanged
    Map<String, int> videoTypeMap = {};
    List<String> videoTypeNames = [];
    if (profileController.videoUploadSettings.value != null &&
        profileController.videoUploadSettings.value!.videoTypes != null &&
        profileController.videoUploadSettings.value!.videoTypes!.values !=
            null) {
      videoTypeNames =
          profileController.videoUploadSettings.value!.videoTypes!.values!.map((
            videoType,
          ) {
            videoTypeMap[videoType.name!] = videoType.id!;
            return videoType.name!;
          }).toList();
    }

    String? currentSelectedType;
    if (videoAddController.videoType.value.isNotEmpty) {
      int? currentTypeId = int.tryParse(videoAddController.videoType.value);
      if (currentTypeId != null) {
        videoTypeMap.forEach((name, id) {
          if (id == currentTypeId) {
            currentSelectedType = name;
          }
        });
      }
    }

    final titleKey = GlobalKey<FormFieldState>();
    final descriptionKey = GlobalKey<FormFieldState>();
    final tagKey = GlobalKey<FormFieldState>();
    final FocusNode tagFocusNode = FocusNode();

    tagFocusNode.addListener(() {
      if (tagFocusNode.hasFocus) {
        tagKey.currentState?.validate();
      }
    });

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
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  height: 150,
                  width: 90,
                  child:
                      _isInitialized && _chewieController != null
                          ? GestureDetector(
                            onTap: () {
                              if (_videoPlayerController.value.isPlaying) {
                                _videoPlayerController.pause();
                                isPlaying.value = false;
                              } else {
                                _videoPlayerController.play();
                                isPlaying.value = true;
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Chewie(controller: _chewieController!),
                                ),
                                Positioned(
                                  child: Obx(
                                    () => Icon(
                                      isPlaying.value
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  child: InkWell(
                                    onTap: () {
                                      Get.back();
                                    },
                                    child: Icon(
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

                    Obx(
                      () => Container(
                        width: Get.width * 0.55,
                        child: Text(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          videoAddController.videoTitle.value.isEmpty
                              ? "video_title_here".tr
                              : videoAddController.videoTitle.value,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Obx(
                      () => IntrinsicWidth(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            videoAddController.videoDescription.value.isEmpty
                                ? "video_description_placeholder".tr
                                : videoAddController.videoDescription.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ColorUtils.greyTextFieldBorderColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
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
                        fieldKey: titleKey,
                        controller: videoAddController.titleController,
                        labelText: "enter_video_title".tr,
                        // maxLength: 70, // Enforces 70-character limit and prevents further typing
                        // decoration: InputDecoration(
                        //   labelText: "enter_video_title".tr,
                        //   hintText: "video_title_hint".tr, // Optional hint
                        //   counterStyle: TextStyle(
                        //     color: Colors.grey,
                        //     fontSize: 12,
                        //   ),
                        // ),
                        validator: (value) {
                          // Check for empty input
                          if (value == null || value.isEmpty) {
                            return "video_title_error".tr;
                          }
                          // Check for maximum length of 70 characters (redundant with maxLength but kept for custom error)
                          if (value.length > 70) {
                            return "video_title_length_error".tr;
                          }
                          // Check for bad words
                          final badWordError = videoAddController.checkBadWords(
                            context,
                            value,
                          );
                          if (badWordError != null) {
                            return badWordError;
                          }
                          return null;
                        },
                        onChanged: (value) {
                          videoAddController.updateTitle(value);
                          // No need for manual rebuild since maxLength handles counter
                        },
                      ),
                      Obx((){
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              textAlign: TextAlign.end,
                              "${videoAddController.videoTitle.value.characters.length}/70", style: TextStyle(fontSize: 12),),
                          ],
                        );
                      }),

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
                    fieldKey: descriptionKey,
                    controller: videoAddController.descriptionController,
                    labelText: "enter_video_description".tr,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        // Check minimum length

                        // Check for bad words
                        final badWordError = videoAddController.checkBadWords(
                          context,
                          value,
                        );
                        if (badWordError != null) {
                          return badWordError;
                        }
                      }
                      return null; // Empty description is valid
                    },
                    onChanged: (value) {
                      videoAddController.updateDescription(value);
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
