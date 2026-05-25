import 'dart:async';

import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/services/video_settings_service.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../appUtils/appUtils.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../profile/profileControlller/profileController.dart';

class UploadVideoStep2 extends StatefulWidget {
  const UploadVideoStep2({super.key});

  @override
  State<UploadVideoStep2> createState() => _UploadVideoStep2State();
}

class _UploadVideoStep2State extends State<UploadVideoStep2>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final VideoAddController videoAddController = Get.find();
  final ProfileController profileController = Get.find();
  final GlobalKey<FormFieldState> _tagKey = GlobalKey<FormFieldState>();
  final FocusNode _tagFocusNode = FocusNode();
  late final Future<int> _entityFuture;

  String _language = 'en';

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
  }

  @override
  void initState() {
    super.initState();
    _entityFuture = _loadEntity();
    _loadLanguage();
    unawaited(_ensureVideoUploadSettings());
    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) {
        _tagKey.currentState?.validate();
      }
    });
  }

  Future<int> _loadEntity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('entity') ?? 0;
  }

  @override
  void dispose() {
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureVideoUploadSettings() async {
    final profileController = Get.find<ProfileController>();
    if (profileController.videoUploadSettings.value?.videoTypeList.isNotEmpty ==
        true) {
      return;
    }
    await VideoSettingsService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isRtl = _language == 'ar';

    return FutureBuilder<int>(
      future: _entityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('error_loading_entity'.tr));
        }

        final int entity = snapshot.data ?? 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Form(
                      key: videoAddController.step2key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "type_label".tr,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          _Step2VideoTypeField(isRtl: isRtl),
                          SizedBox(height: 16.h),
                          Text(
                            "tag_label".tr,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),

                          Obx(() {
                            final tagsFull =
                                videoAddController.tagsList.length >= 5;
                            return AppUtils.customPasswordTextField(
                            fieldKey: _tagKey,
                            labelText: "enter_tag_here".tr,
                            controller: videoAddController.tagController,
                            focusNode: _tagFocusNode,
                            enabled: !tagsFull,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final badWordError = videoAddController
                                    .checkBadWords(context, value);
                                if (badWordError != null) {
                                  return badWordError;
                                }
                              }
                              if (videoAddController.tagsList.isEmpty) {
                                return "tag_error".tr;
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.contains(",")) {
                                videoAddController.addTag(
                                  value.replaceAll(",", "").trim(),
                                );
                                videoAddController.tagController.clear();
                                _tagKey.currentState?.validate();
                              }
                            },
                            onSubmitted: (value) {
                              final cleanedValue = value.trim();
                              final badWordError = videoAddController
                                  .checkBadWords(context, cleanedValue);
                              if (cleanedValue.isNotEmpty &&
                                  badWordError == null) {
                                videoAddController.addTag(cleanedValue);
                              }
                              videoAddController.tagController.clear();
                              _tagKey.currentState?.validate();
                            },
                            textInputAction: TextInputAction.done,
                          );
                          }),
                          Obx(() {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  children:
                                      videoAddController.tagsList.map((tag) {
                                        return Chip(
                                          backgroundColor:
                                              ColorUtils
                                                  .greyTextFieldBorderColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                          ),
                                          labelStyle: TextStyle(
                                            fontSize: 12.sp,
                                          ),
                                          label: Text(tag),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          onDeleted: () {
                                            videoAddController.tagsList.remove(
                                              tag,
                                            );
                                            _tagKey.currentState?.validate();
                                          },
                                        );
                                      }).toList(),
                                ),
                                if (videoAddController.tagsList.length == 5)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "tag_limit_error".tr,
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "done_to_add_hashtag".tr,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                      // fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                              ],
                            );
                          }),
                          if (entity == 2)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: Text(
                                    "want_to_take_orders".tr,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Obx(() {
                                  return Switch(
                                    activeThumbColor: Colors.yellow.shade700,
                                    value: videoAddController.acceptOrder.value,
                                    onChanged: (value) {
                                      videoAddController.toggleSwitch();
                                    },
                                  );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Step2VideoTypeField extends StatelessWidget {
  const _Step2VideoTypeField({required this.isRtl});

  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final videoAddController = Get.find<VideoAddController>();
    final profileController = Get.find<ProfileController>();

    return Obx(() {
      final settings =
          profileController.videoUploadSettings.value ??
          VideoSettingsService.instance.settings.value;
      final videoTypeMap = <String, int>{};
      final videoTypeNames = <String>[];
      for (final videoType in settings?.videoTypeList ?? const []) {
        final name = videoType.name?.trim();
        final id = videoType.id;
        if (name == null || name.isEmpty || id == null) continue;
        videoTypeMap[name] = id;
        videoTypeNames.add(name);
      }

      final othersLabel = "Others".tr;
      final hasOthers = videoTypeNames.any(
        (name) =>
            name.trim().toLowerCase() == 'others' || name.trim() == 'أخرى',
      );
      if (!hasOthers && videoTypeMap.isNotEmpty) {
        videoTypeMap[othersLabel] = videoTypeMap.values.first;
        videoTypeNames.add(othersLabel);
      }

      String? currentSelectedType;
      if (videoAddController.videoType.value.isNotEmpty) {
        final currentTypeId = int.tryParse(videoAddController.videoType.value);
        if (currentTypeId != null) {
          videoTypeMap.forEach((name, id) {
            if (id == currentTypeId) currentSelectedType = name;
          });
        }
      }

      if (videoTypeNames.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  "select_video_type".tr,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownFlutter<String>(
            initialItem: currentSelectedType,
            validator: (value) {
              if (value == null || value.isEmpty) {
                videoAddController.videoTypeError.value =
                    "select_video_type".tr;
                return "".tr;
              }
              return null;
            },
            closedHeaderPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            decoration: CustomDropdownDecoration(
              closedBorderRadius: BorderRadius.circular(8),
              expandedBorderRadius: BorderRadius.circular(8),
              closedFillColor: Colors.transparent,
              closedBorder: Border.all(
                color: const Color(0xFFBDBDBD).withOpacity(0.3),
                width: 0.8,
              ),
              closedSuffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
            ),
            hintText: "select_video_type".tr,
            items: videoTypeNames,
            onChanged: (String? selectedValue) {
              if (selectedValue != null) {
                final selectedId = videoTypeMap[selectedValue];
                if (selectedId != null) {
                  videoAddController.videoType.value = selectedId.toString();
                  videoAddController.videoTypeError.value = "";
                }
              }
            },
          ),
          if (videoAddController.videoTypeError.value.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8.w, right: 8.w),
              child: Text(
                videoAddController.videoTypeError.value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12.sp,
                ),
              ),
            ),
        ],
      );
    });
  }
}
