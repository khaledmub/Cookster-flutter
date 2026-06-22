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

  /// Merge duplicate "Others" tabs, then ensure each video id appears in only
  /// one tab (matches [video.videoType] when the API leaves stale copies).
  static List<T> normalizeVideoTypeTabs<T>(List<T>? sourceTypes) {
    final existing = List<T>.from(sourceTypes ?? <T>[]);
    final deduped = <dynamic>[];
    dynamic othersKeeper;
    for (final type in existing) {
      final dynamic tab = type;
      if (isOthersVideoTypeName(tab.name?.toString())) {
        if (othersKeeper == null) {
          othersKeeper = tab;
          deduped.add(tab);
        } else {
          othersKeeper.videos = <dynamic>[
            ...?othersKeeper.videos as List<dynamic>?,
            ...?tab.videos as List<dynamic>?,
          ];
        }
        continue;
      }
      deduped.add(tab);
    }
    if (othersKeeper == null) {
      // Caller may append an empty Others tab in profile-specific builders.
    }
    _dedupeVideosAcrossTabs(deduped);
    return deduped.cast<T>();
  }

  static void _dedupeVideosAcrossTabs(List<dynamic> types) {
    if (types.isEmpty) {
      return;
    }

    final validTypeIds = <String>{
      for (final type in types)
        if ((type.id?.toString() ?? '').isNotEmpty) type.id.toString(),
    };

    final ownership = <String, String>{};

    for (final type in types) {
      final videos = (type.videos as List<dynamic>?) ?? const [];
      for (final video in videos) {
        final videoId = video.id?.toString();
        if (videoId == null || videoId.isEmpty) {
          continue;
        }
        final declared = video.videoType?.toString();
        if (declared != null &&
            declared.isNotEmpty &&
            validTypeIds.contains(declared)) {
          ownership[videoId] = declared;
        }
      }
    }

    for (final type in types) {
      final typeId = type.id?.toString() ?? '';
      final videos = (type.videos as List<dynamic>?) ?? const [];
      for (final video in videos) {
        final videoId = video.id?.toString();
        if (videoId == null ||
            videoId.isEmpty ||
            ownership.containsKey(videoId)) {
          continue;
        }
        if (typeId.isNotEmpty) {
          ownership[videoId] = typeId;
        }
      }
    }

    for (final type in types) {
      final typeId = type.id?.toString() ?? '';
      final videos = (type.videos as List<dynamic>?) ?? const [];
      type.videos = videos.where((video) {
        final videoId = video.id?.toString();
        if (videoId == null || videoId.isEmpty) {
          return true;
        }
        final ownerType = ownership[videoId];
        return ownerType == null || ownerType == typeId;
      }).toList();
    }
  }
}
