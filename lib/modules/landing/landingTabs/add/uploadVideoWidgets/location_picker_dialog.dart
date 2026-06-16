import 'dart:async';

import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Country picker with debounced search and reliable tap selection.
Future<void> showUploadCountryPicker(
  BuildContext context, {
  int? initialCountryId,
}) async {
  final controller = Get.find<VideoAddController>();
  final profileController = Get.find<ProfileController>();
  final cityController = Get.find<CityController>();

  final countries = profileController.videoUploadSettings.value?.countries;
  if (countries == null || countries.isEmpty) return;

  final countryMap = <String, int>{};
  final countryNames = <String>[];
  for (final country in countries) {
    final name = country.name?.trim();
    final id = country.id;
    if (name == null || name.isEmpty || id == null) continue;
    countryMap[name] = id;
    countryNames.add(name);
  }
  countryNames.sort((a, b) => a.compareTo(b));

  var initialName = controller.selectedCountry.value.trim();
  if (initialCountryId != null) {
    for (final entry in countryMap.entries) {
      if (entry.value == initialCountryId) {
        initialName = entry.key;
        break;
      }
    }
  }

  final picked = await Get.dialog<String>(
    _LocationPickerDialog(
      title: 'select_country_label'.tr,
      searchHint: 'search_country_placeholder'.tr,
      items: countryNames,
      initialSelection: initialName,
    ),
    barrierDismissible: true,
  );

  if (picked == null || picked.isEmpty) return;
  final selectedId = countryMap[picked];
  if (selectedId == null) return;

  controller.selectLocation(picked, selectedId);
  controller.selectedCity.value = '';
  controller.selectedCityId.value = -1;
  await cityController.fetchCities(selectedId);
  if (!context.mounted) return;
  await showUploadCityPicker(context);
}

/// City picker with debounced search and reliable tap selection.
Future<void> showUploadCityPicker(
  BuildContext context, {
  int? initialCityId,
}) async {
  final controller = Get.find<VideoAddController>();
  final cityController = Get.find<CityController>();

  final cityMap = <String, int>{};
  final cityNames = <String>[];
  for (final city in cityController.cityList) {
    final name = city.name?.trim();
    final id = city.id;
    if (name == null || name.isEmpty || id == null) continue;
    cityMap[name] = id;
    cityNames.add(name);
  }
  cityNames.sort((a, b) => a.compareTo(b));

  if (cityNames.isEmpty) {
    Get.snackbar(
      'select_city_label'.tr,
      'select_country_error'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return;
  }

  var initialName = controller.selectedCity.value.trim();
  if (initialCityId != null) {
    for (final entry in cityMap.entries) {
      if (entry.value == initialCityId) {
        initialName = entry.key;
        break;
      }
    }
  }

  final picked = await Get.dialog<String>(
    _LocationPickerDialog(
      title: 'select_city_dialog_label'.tr,
      searchHint: 'search_city_placeholder'.tr,
      items: cityNames,
      initialSelection: initialName,
    ),
    barrierDismissible: true,
  );

  if (picked == null || picked.isEmpty) return;
  final selectedId = cityMap[picked];
  if (selectedId == null) return;

  controller.selectCity(picked, selectedId);
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.initialSelection,
  });

  final String title;
  final String searchHint;
  final List<String> items;
  final String initialSelection;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late final TextEditingController _searchController;
  late List<String> _filtered;
  late String _selected;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = List<String>.from(widget.items);
    _selected = widget.initialSelection;
    if (_selected.isNotEmpty && widget.items.contains(_selected)) {
      // no-op: valid initial
    } else {
      _selected = '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final q = query.trim().toLowerCase();
      setState(() {
        if (q.isEmpty) {
          _filtered = List<String>.from(widget.items);
        } else {
          _filtered = widget.items
              .where((item) => item.toLowerCase().contains(q))
              .toList();
        }
      });
    });
  }

  void _selectItem(String item) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selected = item);
    Get.back(result: item);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: SizedBox(
        width: 350.w,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.black),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: ColorUtils.primaryColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10.h,
                    horizontal: 12.w,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 230.h,
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'try_to_change'.tr,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1.h,
                          color: Colors.grey.shade300,
                        ),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final isSelected = _selected == item;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectItem(item),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: ColorUtils.primaryColor,
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? ColorUtils.primaryColor
                                            : Colors.white,
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              size: 12.sp,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy entry points used across upload UI.
void showLocationDialog(BuildContext context, {int? initialCountryId}) {
  unawaited(showUploadCountryPicker(context, initialCountryId: initialCountryId));
}

void showCityDialog(BuildContext context, {int? initialCityId}) {
  unawaited(showUploadCityPicker(context, initialCityId: initialCityId));
}
