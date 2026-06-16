import 'package:get/get.dart';

/// Helpers for unique handles (`user_name`) vs display names (`name`).
class PublicUserIdentity {
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_]{3,30}$');

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? validateUsernameFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'username_required_error'.tr;
    }
    final normalized = normalizeUsername(value);
    if (!usernamePattern.hasMatch(normalized)) {
      return 'username_format_error'.tr;
    }
    return null;
  }

  static String formatAtHandle(String? userName) {
    final handle = userName?.trim();
    if (handle == null || handle.isEmpty) return '';
    return '@$handle';
  }

  static String? subtitleHandle(String? userName) {
    final formatted = formatAtHandle(userName);
    return formatted.isEmpty ? null : formatted;
  }
}
