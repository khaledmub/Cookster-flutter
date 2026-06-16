import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

String profileShareUrl({String? email, String? userId}) {
  final trimmedEmail = email?.trim() ?? '';
  if (trimmedEmail.isNotEmpty) {
    return 'https://cookster.org/profile?email=${Uri.encodeComponent(trimmedEmail)}';
  }
  final trimmedId = userId?.trim() ?? '';
  if (trimmedId.isNotEmpty) {
    return 'https://cookster.org/web/visitProfile?userId=$trimmedId';
  }
  return 'https://cookster.org';
}

Future<void> shareProfile({
  required BuildContext context,
  String? email,
  String? userId,
  String? displayName,
}) async {
  final url = profileShareUrl(email: email, userId: userId);
  final name = displayName?.trim();
  final message = name != null && name.isNotEmpty
      ? 'Check out $name on Cookster!\n$url'
      : 'Check out this profile on Cookster!\n$url';

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
