import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Pops the current route via the nearest navigator or GetX.
bool popCurrentRoute([dynamic result]) {
  final ctx = Get.context;
  if (ctx != null) {
    final navigator = Navigator.of(ctx);
    if (navigator.canPop()) {
      navigator.pop(result);
      return true;
    }
  }

  final root = Get.key.currentState;
  if (root != null && root.canPop()) {
    root.pop(result);
    return true;
  }

  return false;
}

/// Reliable back navigation for app bar / overlay back buttons.
void navigateBack([dynamic result]) {
  if (popCurrentRoute(result)) {
    return;
  }
  try {
    Get.back(result: result);
  } catch (_) {}
}
