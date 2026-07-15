import 'dart:async';

import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
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
    WallVideos? Function(int index)? videoForIndex,
  }) : _preloadManager = preloadManager,
       _targetForIndex = targetForIndex,
       _thumbnailUrlForIndex = thumbnailUrlForIndex,
       _videoForIndex = videoForIndex;

  final VideoPreloadManager _preloadManager;
  final VideoPreloadTarget? Function(int index) _targetForIndex;
  final String? Function(int index) _thumbnailUrlForIndex;
  final WallVideos? Function(int index)? _videoForIndex;

  final ValueNotifier<String?> activeVideoId = ValueNotifier<String?>(null);

  void bootstrapFromVisible(int actualIndex) {
    unawaited(_preloadManager.bootstrapFromVisible(actualIndex));
  }

  /// RAM-decode the visible reel poster before playback opens.
  void precacheVisiblePoster(BuildContext context, int index) {
    _precacheTiersForIndex(context, index);
  }

  void onPageScrollToward({
    required int fromActualIndex,
    required int towardActualIndex,
    BuildContext? context,
    double scrollProgress = 0,
    double scrollVelocity = 0,
  }) {
    final fast = scrollVelocity >= kReelsFastScrollVelocityThreshold;
    final extraDepth = fast ? 2 : 1;
    unawaited(
      _preloadManager.onScrollToward(
        fromIndex: fromActualIndex,
        towardIndex: towardActualIndex,
        extraDepth: extraDepth,
      ),
    );
    // Start demux early so the next reel is already buffered when the finger
    // lifts — waiting until 0.45 let fast flings settle cold.
    if (scrollProgress >= 0.12 || fast) {
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
        count: 4 + extraDepth,
      );
      // Also warm the toward page + next so swipe landing never hits a bare
      // black opaqueBase while CachedNetworkImage is still fetching.
      _precacheTiersForIndex(context, towardActualIndex);
      _precacheTiersForIndex(context, towardActualIndex + direction);
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
        count: 3,
      );
      _precacheTiersForIndex(context, actualIndex - 1);
    }
  }

  List<ReelPosterPrecacheTier> _tiersForIndex(int index) {
    final video = _videoForIndex?.call(index);
    if (video != null) {
      return ReelFeedPlayerKit.precachePosterTiers(video);
    }
    final url = _thumbnailUrlForIndex(index);
    if (url == null || url.isEmpty) {
      return const [];
    }
    return [ReelPosterPrecacheTier(url: url, lqip: false)];
  }

  /// RAM-decode posters ahead in scroll direction; disk cache via provider.
  void _precacheDirectionalThumbnails(
    BuildContext context, {
    required int anchorIndex,
    required int direction,
    int count = 5,
  }) {
    for (var step = 1; step <= count; step++) {
      final index = anchorIndex + direction * step;
      _precacheTiersForIndex(context, index);
    }
  }

  void _precacheTiersForIndex(BuildContext context, int index) {
    for (final tier in _tiersForIndex(index)) {
      if (tier.url.isEmpty) {
        continue;
      }
      _precacheTier(context, index, tier);
    }
  }

  void _precacheTier(
    BuildContext context,
    int index,
    ReelPosterPrecacheTier tier,
  ) {
    final video = _videoForIndex?.call(index);
    final provider = tier.lqip
        ? reelPosterLqipPrecacheProvider(tier.url, context)
        : reelPosterPrecacheProvider(tier.url, context);
    unawaited(
      precacheImage(provider, context).then((_) {
        if (video != null && video.isPhotoPost) {
          if (tier.lqip) {
            ReelImagePostCache.putLqip(tier.url, provider);
          } else {
            ReelImagePostCache.putFull(tier.url, provider);
          }
        } else if (tier.lqip) {
          ReelPosterImageCache.put(ReelPosterTierKeys.lqip(tier.url), provider);
        } else {
          ReelPosterImageCache.put(tier.url, provider);
        }
      }).catchError((_) {}),
    );
  }

  void dispose() {
    activeVideoId.dispose();
  }
}
