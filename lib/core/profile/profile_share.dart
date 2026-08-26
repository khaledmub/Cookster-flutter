import 'package:cookster/core/share/cookster_share_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// Canonical web profile URL that the server serves.
String profileShareUrl({String? email, String? userId}) {
  return CooksterShareLinks.profileWebUrl(userId: userId, email: email);
}

String profileAppUrl({required String userId}) {
  return CooksterShareLinks.profileAppUrl(userId);
}

Future<void> shareProfile({
  required BuildContext context,
  String? email,
  String? userId,
  String? displayName,
}) async {
  final message = CooksterShareLinks.profileShareMessage(
    userId: userId,
    email: email,
    displayName: displayName,
  );

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
