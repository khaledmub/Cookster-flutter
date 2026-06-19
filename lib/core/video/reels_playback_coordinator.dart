import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:flutter/material.dart';

import 'prefetch_indices.dart';
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
    double scrollProgress = 0,
    double scrollVelocity = 0,
  }) {
    final extraDepth =
        scrollVelocity >= kReelsFastScrollVelocityThreshold ? 1 : 0;
    unawaited(
      _preloadManager.onScrollToward(
        fromIndex: fromActualIndex,
        towardIndex: towardActualIndex,
        extraDepth: extraDepth,
      ),
    );
    if (scrollProgress >= 0.45) {
      unawaited(
        _preloadManager.onScrollDemuxAhead(
          towardIndex: towardActualIndex,
          fromIndex: fromActualIndex,
        ),
      );
    }
    if (context != null) {
      final direction = towardActualIndex == fromActualIndex
          ? 1
          : (towardActualIndex > fromActualIndex ? 1 : -1);
      _precacheDirectionalThumbnails(
        context,
        anchorIndex: fromActualIndex,
        direction: direction,
        count: 5 + extraDepth,
      );
    }
  }

  void onPageSettled(int actualIndex, {BuildContext? context}) {
    final target = _targetForIndex(actualIndex);
    activeVideoId.value = target?.key;
    unawaited(_preloadManager.onVisibleIndexChanged(actualIndex));
    if (context != null) {
      _precacheDirectionalThumbnails(
        context,
        anchorIndex: actualIndex,
        direction: 1,
        count: 5,
      );
      final behindUrl = _thumbnailUrlForIndex(actualIndex - 1);
      if (behindUrl != null && behindUrl.isNotEmpty) {
        unawaited(
          precacheImage(reelPosterPrecacheProvider(behindUrl, context), context),
        );
      }
    }
  }

  /// RAM-decode posters ahead in scroll direction; disk cache via provider.
  void _precacheDirectionalThumbnails(
    BuildContext context, {
    required int anchorIndex,
    required int direction,
    int count = 5,
  }) {
    for (var step = 1; step <= count; step++) {
      final url = _thumbnailUrlForIndex(anchorIndex + direction * step);
      if (url == null || url.isEmpty) {
        continue;
      }
      unawaited(
        precacheImage(reelPosterPrecacheProvider(url, context), context).then((_) {
          ReelPosterImageCache.put(url, reelPosterPrecacheProvider(url, context));
        }),
      );
    }
  }

  void dispose() {
    activeVideoId.dispose();
  }
}
