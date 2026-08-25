import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// Canonical web profile URL that the server actually serves.
///
/// `/web/visitProfile?userId=` and `/profile?email=` currently 302 to the
/// homepage. `/web/visitProfile?id=` returns a real landing page.
String profileShareUrl({String? email, String? userId}) {
  final trimmedId = userId?.trim() ?? '';
  if (trimmedId.isNotEmpty) {
    return 'https://cookster.org/web/visitProfile?id=$trimmedId';
  }
  final trimmedEmail = email?.trim() ?? '';
  if (trimmedEmail.isNotEmpty) {
    // Legacy fallback — prefer userId whenever available.
    return 'https://cookster.org/profile?email=${Uri.encodeComponent(trimmedEmail)}';
  }
  return 'https://cookster.org';
}

String profileAppUrl({required String userId}) {
  return 'cookster://open.cookster.app/web/visitProfile?id=${userId.trim()}';
}

Future<void> shareProfile({
  required BuildContext context,
  String? email,
  String? userId,
  String? displayName,
}) async {
  final trimmedId = userId?.trim() ?? '';
  final webUrl = profileShareUrl(email: email, userId: userId);
  final name = displayName?.trim();

  final String message;
  if (trimmedId.isNotEmpty) {
    final appUrl = profileAppUrl(userId: trimmedId);
    message = name != null && name.isNotEmpty
        ? 'Check out $name on Cookster!\n$webUrl\n\nDirect app link:\n$appUrl'
        : 'Check out this profile on Cookster!\n$webUrl\n\nDirect app link:\n$appUrl';
  } else {
    message = name != null && name.isNotEmpty
        ? 'Check out $name on Cookster!\n$webUrl'
        : 'Check out this profile on Cookster!\n$webUrl';
  }

  final box = context.findRenderObject() as RenderBox?;
  try {
    await Share.share(
      message,
      subject: 'Cookster Profile',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  } catch (e) {
    Get.snackbar(
      'Error',
      'Could not share this profile',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}
