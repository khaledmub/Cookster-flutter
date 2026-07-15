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

class _UploadVideoStep2State extends State<UploadVideoStep2> {
  final VideoAddController videoAddController = Get.find();
  final ProfileController profileController = Get.find();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    videoAddController.validateStep2Form = _validateStep2;
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
    if (identical(videoAddController.validateStep2Form, _validateStep2)) {
      videoAddController.validateStep2Form = null;
    }
    _tagFocusNode.dispose();
    super.dispose();
  }

  bool _validateStep2() => _formKey.currentState?.validate() ?? false;

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
                      key: _formKey,
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

                          GetBuilder<VideoAddController>(
                            id: VideoAddController.idUploadTags,
                            builder: (c) {
                              final tagsFull = c.tagsList.length >= 5;
                              return AppUtils.customPasswordTextField(
                                fieldKey: _tagKey,
                                labelText: "enter_tag_here".tr,
                                controller: c.tagController,
                                focusNode: _tagFocusNode,
                                enabled: !tagsFull,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final badWordError =
                                        c.checkBadWords(context, value);
                                    if (badWordError != null) {
                                      return badWordError;
                                    }
                                  }
                                  if (c.tagsList.isEmpty) {
                                    return "tag_error".tr;
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  if (value.contains(",")) {
                                    c.addTag(value.replaceAll(",", "").trim());
                                    c.tagController.clear();
                                    _tagKey.currentState?.validate();
                                  }
                                },
                                onSubmitted: (value) {
                                  final cleanedValue = value.trim();
                                  final badWordError =
                                      c.checkBadWords(context, cleanedValue);
                                  if (cleanedValue.isNotEmpty &&
                                      badWordError == null) {
                                    c.addTag(cleanedValue);
                                  }
                                  c.tagController.clear();
                                  _tagKey.currentState?.validate();
                                },
                                textInputAction: TextInputAction.done,
                              );
                            },
                          ),
                          _UploadTagChips(
                            controller: videoAddController,
                            onTagsChanged: () => _tagKey.currentState?.validate(),
                          ),
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

class _UploadTagChips extends StatelessWidget {
  const _UploadTagChips({
    required this.controller,
    required this.onTagsChanged,
  });

  final VideoAddController controller;
  final VoidCallback onTagsChanged;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VideoAddController>(
      id: VideoAddController.idUploadTags,
      builder: (c) {
      final tags = c.tagsList.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: tags
                .map(
                  (tag) => Chip(
                    backgroundColor: ColorUtils.greyTextFieldBorderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    labelStyle: TextStyle(fontSize: 12.sp),
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      c.tagsList.remove(tag);
                      onTagsChanged();
                    },
                  ),
                )
                .toList(),
          ),
          if (tags.length == 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "tag_limit_error".tr,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "done_to_add_hashtag".tr,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      );
      },
    );
  }
}

class _Step2VideoTypeField extends StatefulWidget {
  const _Step2VideoTypeField({required this.isRtl});

  final bool isRtl;

  @override
  State<_Step2VideoTypeField> createState() => _Step2VideoTypeFieldState();
}

class _Step2VideoTypeFieldState extends State<_Step2VideoTypeField> {
  Map<String, int> _videoTypeMap = {};
  List<String> _videoTypeNames = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTypes());
  }

  Future<void> _loadTypes() async {
    final profileController = Get.find<ProfileController>();
    if (profileController.videoUploadSettings.value?.videoTypeList.isEmpty !=
        false) {
      await VideoSettingsService.instance.load();
    }
    if (!mounted) return;

    final settings =
        profileController.videoUploadSettings.value ??
        VideoSettingsService.instance.settings.value;

    final map = <String, int>{};
    final names = <String>[];
    for (final videoType in settings?.videoTypeList ?? const []) {
      final name = videoType.name?.trim();
      final id = videoType.id;
      if (name == null || name.isEmpty || id == null) continue;
      map[name] = id;
      names.add(name);
    }

    final othersLabel = "Others".tr;
    final hasOthers = names.any(
      (name) =>
          name.trim().toLowerCase() == 'others' || name.trim() == 'أخرى',
    );
    if (!hasOthers && map.isNotEmpty) {
      map[othersLabel] = map.values.first;
      names.add(othersLabel);
    }

    setState(() {
      _videoTypeMap = map;
      _videoTypeNames = names;
      _loaded = true;
    });
  }

  String? _selectedName(VideoAddController c) {
    final currentTypeId = int.tryParse(c.videoType.value);
    if (currentTypeId == null) return null;
    for (final entry in _videoTypeMap.entries) {
      if (entry.value == currentTypeId) return entry.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final videoAddController = Get.find<VideoAddController>();

    if (!_loaded || _videoTypeNames.isEmpty) {
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

    return GetBuilder<VideoAddController>(
      id: VideoAddController.idUploadVideoType,
      builder: (c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownFlutter<String>(
              key: ValueKey(_selectedName(c)),
              initialItem: _selectedName(c),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  c.videoTypeError.value = "select_video_type".tr;
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
              items: _videoTypeNames,
              onChanged: (String? selectedValue) {
                if (selectedValue != null) {
                  final selectedId = _videoTypeMap[selectedValue];
                  if (selectedId != null) {
                    c.videoType.value = selectedId.toString();
                    c.videoTypeError.value = "";
                  }
                }
              },
            ),
            if (c.videoTypeError.value.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 8.w, right: 8.w),
                child: Text(
                  c.videoTypeError.value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.sp,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
