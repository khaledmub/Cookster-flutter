import 'dart:async';

import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/material.dart';

/// Shared warm / attach / resume behavior for home, profile, collection, hashtag reels.
class ReelScreenPlaybackHelpers {
  ReelScreenPlaybackHelpers._();

  /// Hide poster only when this reel is still the live feed decoder with a painted frame.
  /// Never use [hadRecentPaint] alone — that hides the poster while [Player.open] runs → black.
  static bool shouldKeepPosterHidden(String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return false;
    }
    final pool = MediaKitPlayerPool.instance;
    return pool.isFeedVisibleKey(videoId) &&
        pool.isFrameReady(videoId) &&
        pool.canInstantResume(videoId);
  }

  /// Backup audible resume when scroll-back skips the poster — only if still muted.
  static void resumeAudibleForReel(String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    final pool = MediaKitPlayerPool.instance;
    if (pool.isActiveAudible(videoId)) {
      return;
    }
    unawaited(pool.feedResumeAudibleWhenReady(videoId));
  }

  static Future<void> warmVisibleIndex({
    required VideoPreloadManager preloadManager,
    required ReelsPlaybackCoordinator coordinator,
    required BuildContext context,
    required int index,
    int maxWaitMs = 200,
  }) async {
    coordinator.precacheVisiblePoster(context, index);
    await preloadManager.prefetchVisibleReel(index, maxWaitMs: maxWaitMs);
  }

  static Future<void> attachVisibleIndex({
    required VideoPreloadManager preloadManager,
    required ReelsPlaybackCoordinator coordinator,
    required BuildContext context,
    required int index,
    GlobalKey<ReelVideoPlayerState>? playerKey,
    bool forcePlayerReattach = false,
    int warmMaxWaitMs = 200,
  }) async {
    await warmVisibleIndex(
      preloadManager: preloadManager,
      coordinator: coordinator,
      context: context,
      index: index,
      maxWaitMs: warmMaxWaitMs,
    );
    if (!context.mounted) {
      return;
    }
    MediaKitPlayerPool.instance.setScreenWidth(
      MediaQuery.sizeOf(context).width,
    );
    preloadManager.onVisiblePageSettled();
    coordinator.onPageSettled(index, context: context);
    if (forcePlayerReattach && playerKey != null) {
      await playerKey.currentState?.resumeAfterRouteOverlay();
    }
  }

  static Future<void> resumeAfterAppForeground({
    required GlobalKey<ReelVideoPlayerState> playerKey,
    required String? videoId,
    required Future<void> Function() attachVisible,
  }) async {
    if (videoId != null && videoId.isNotEmpty) {
      unawaited(
        MediaKitPlayerPool.instance.recoverFeedVisibleSurface(videoId),
      );
    }
    await attachVisible();
    await playerKey.currentState?.resumeAfterAppBackground();
    if (videoId != null && videoId.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.resumeFeedVisible(videoId));
    }
  }
}
