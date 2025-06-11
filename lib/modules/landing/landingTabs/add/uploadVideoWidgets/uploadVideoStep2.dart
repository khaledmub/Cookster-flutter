import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
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
  Future<int> getEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('entity') ?? 0;
  }

  String _language = 'en';

  // Default to English
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    final VideoAddController videoAddController = Get.find();
    final FocusNode menuFocusNode = FocusNode();
    final ProfileController profileController = Get.find();
    final tagKey = GlobalKey<FormFieldState>();
    final FocusNode tagFocusNode = FocusNode();

    tagFocusNode.addListener(() {
      if (tagFocusNode.hasFocus) {
        tagKey.currentState?.validate();
      }
    });

    final menuKey = GlobalKey<FormFieldState>();
    menuFocusNode.addListener(() {
      if (menuFocusNode.hasFocus) {
        menuKey.currentState?.validate();
      }
    });

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

    return FutureBuilder<int>(
      future: getEntity(),
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
                                int? selectedId = videoTypeMap[selectedValue];
                                videoAddController.videoType.value =
                                    selectedId.toString();
                                videoAddController.videoTypeError.value = "";
                              }
                            },
                          ),

                          Obx(() {
                            return videoAddController
                                    .videoTypeError
                                    .value
                                    .isNotEmpty
                                ? Padding(
                                  padding: EdgeInsets.only(
                                    // top: 2.h,
                                    left: isRtl ? 8.w : 8.w,
                                    right: isRtl ? 8.w : 8.w,
                                  ),
                                  child: Text(
                                    videoAddController.videoTypeError.value,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                )
                                : SizedBox.shrink();
                          }),
                          SizedBox(height: 16.h),
                          Text(
                            "tag_label".tr,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),

                          AppUtils.customPasswordTextField(
                            fieldKey: tagKey,
                            labelText: "enter_tag_here".tr,
                            controller: videoAddController.tagController,
                            focusNode: tagFocusNode,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final badWordError = videoAddController.checkBadWords(context, value);
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
                                tagKey.currentState?.validate();
                              }
                            },
                            onSubmitted: (value) {
                              final cleanedValue = value.trim();
                              final badWordError = videoAddController.checkBadWords(context, cleanedValue);

                              if (cleanedValue.isNotEmpty && badWordError == null) {
                                videoAddController.addTag(cleanedValue);
                              }

                              videoAddController.tagController.clear();
                              tagKey.currentState?.validate();
                            },
                            textInputAction: TextInputAction.done,
                          ),
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
                                            tagKey.currentState?.validate();
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
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
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
                                    activeColor: Colors.yellow.shade700,
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
