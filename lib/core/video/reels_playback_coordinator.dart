import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'video_preload_manager.dart';
import 'video_preload_target.dart';

/// Lightweight coordinator for home reels: preloads ahead and tracks the
/// active video id without rebuilding the whole screen on every swipe.
class ReelsPlaybackCoordinator {
  ReelsPlaybackCoordinator({
    required VideoPreloadManager preloadManager,
    required VideoPreloadTarget? Function(int index) targetForIndex,
    required String? Function(int index) thumbnailUrlForIndex,
  }) : _preloadManager = preloadManager,
       _targetForIndex = targetForIndex,
       _thumbnailUrlForIndex = thumbnailUrlForIndex;

  final VideoPreloadManager _preloadManager;
  final VideoPreloadTarget? Function(int index) _targetForIndex;
  final String? Function(int index) _thumbnailUrlForIndex;

  final ValueNotifier<String?> activeVideoId = ValueNotifier<String?>(null);

  void bootstrapFromVisible(int actualIndex) {
    unawaited(_preloadManager.bootstrapFromVisible(actualIndex));
  }

  void onPageScrollToward({
    required int fromActualIndex,
    required int towardActualIndex,
    BuildContext? context,
  }) {
    unawaited(
      _preloadManager.onScrollToward(
        fromIndex: fromActualIndex,
        towardIndex: towardActualIndex,
      ),
    );
    if (context != null) {
      _precacheForwardThumbnails(context, fromActualIndex);
    }
  }

  void onPageSettled(int actualIndex, {BuildContext? context}) {
    final target = _targetForIndex(actualIndex);
    activeVideoId.value = target?.key;
    unawaited(_preloadManager.onVisibleIndexChanged(actualIndex));
    if (context != null) {
      _precacheForwardThumbnails(context, actualIndex);
    }
  }

  void _precacheForwardThumbnails(BuildContext context, int actualIndex) {
    for (var step = 1; step <= 4; step++) {
      final url = _thumbnailUrlForIndex(actualIndex + step);
      if (url == null || url.isEmpty) {
        continue;
      }
      unawaited(precacheImage(CachedNetworkImageProvider(url), context));
    }
  }

  void dispose() {
    activeVideoId.dispose();
  }
}
