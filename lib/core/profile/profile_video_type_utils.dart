import 'package:get/get.dart';

/// Shared helpers for profile video-type tabs (Meals, Drinks, Others, …).
class ProfileVideoTypeUtils {
  ProfileVideoTypeUtils._();

  static bool isOthersVideoTypeName(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) {
      return false;
    }
    final lower = raw.toLowerCase();
    if (lower == 'others' || lower == 'other') {
      return true;
    }
    const arabicVariants = <String>{
      'أخرى',
      'اخرى',
      'اخرون',
      'آخرون',
      'آخرى',
      'اخري',
      'أخري',
    };
    return arabicVariants.contains(raw);
  }

  static String displayLabel(String? name) {
    if (isOthersVideoTypeName(name)) {
      return 'Others'.tr;
    }
    return (name ?? 'Unknown').toString();
  }
}
