import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../appRoutes/appRoutes.dart';

class DeepLinkManager extends GetxService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _subscription;
  final Rx<Uri?> currentUri = Rx<Uri?>(null);

  Future<DeepLinkManager> init() async {
    // Handle case where app is started by a link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        currentUri.value = initialUri;
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial uri: $e');
    }

    // Handle case where app is resumed by a link
    _subscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
        currentUri.value = uri;
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error in deep link stream: $err');
      },
    );

    return this;
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Got deep link: $uri');

    // Handle video links
    if (uri.host == 'video' || uri.pathSegments.contains('video')) {
      // Extract video ID from the URI
      final videoId = uri.queryParameters['id'] ?? '';

      if (videoId.isNotEmpty) {
        // Navigate to the SingleVideoScreen with the video ID
        Get.toNamed(AppRoutes.singleVideo, arguments: {'videoId': videoId});
      } else {
        // If no video ID is provided, show an error
        Get.snackbar(
          'Error',
          'Invalid video link',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}