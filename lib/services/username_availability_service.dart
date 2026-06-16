import 'dart:convert';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/services/apiClient.dart';

class UsernameAvailabilityService {
  const UsernameAvailabilityService._();

  /// Returns `true` when available, `false` when taken, `null` on network/parse error.
  static Future<bool?> checkAvailability(String rawUsername) async {
    final userName = PublicUserIdentity.normalizeUsername(rawUsername);
    if (PublicUserIdentity.validateUsernameFormat(userName) != null) {
      return null;
    }

    try {
      final response = await ApiClient.postRequest(
        EndPoints.checkUsername,
        {'user_name': userName},
      );
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != true) {
        return null;
      }
      return data['available'] == true;
    } catch (_) {
      return null;
    }
  }
}
