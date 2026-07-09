import 'dart:convert';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/services/apiClient.dart';

class UsernameCheckResult {
  const UsernameCheckResult({
    required this.checked,
    required this.available,
    this.reason,
  });

  /// `true` when the server answered; `false` on network/parse failure.
  final bool checked;
  final bool available;
  final String? reason;

  bool get isAvailable => checked && available;
  bool get isTaken => checked && reason == 'taken';
  bool get isFormatError => checked && reason == 'format';
  bool get isCheckFailed => !checked;

  /// Legacy tri-state: `true` / `false` / `null` (failed check).
  bool? get availabilityTriState {
    if (!checked) {
      return null;
    }
    return available;
  }
}

class UsernameAvailabilityService {
  const UsernameAvailabilityService._();

  static Future<UsernameCheckResult> check(String rawUsername) async {
    final userName = PublicUserIdentity.normalizeUsername(rawUsername);
    if (PublicUserIdentity.validateUsernameFormat(userName) != null) {
      return const UsernameCheckResult(
        checked: false,
        available: false,
        reason: 'format',
      );
    }

    try {
      final response = await ApiClient.postRequest(
        EndPoints.checkUsername,
        {'user_name': userName},
      );
      if (response.statusCode != 200) {
        return const UsernameCheckResult(checked: false, available: false);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != true) {
        return const UsernameCheckResult(checked: false, available: false);
      }

      final checked = data['checked'] == true;
      if (checked) {
        final reason = data['reason'] as String?;
        return UsernameCheckResult(
          checked: true,
          available: data['available'] == true,
          reason: reason,
        );
      }

      // Legacy API without `checked` — infer from `available`.
      return UsernameCheckResult(
        checked: true,
        available: data['available'] == true,
        reason: data['available'] == true ? 'available' : 'taken',
      );
    } catch (_) {
      return const UsernameCheckResult(checked: false, available: false);
    }
  }

  /// Returns `true` when available, `false` when taken, `null` on network/parse error.
  static Future<bool?> checkAvailability(String rawUsername) async {
    final result = await check(rawUsername);
    return result.availabilityTriState;
  }
}
