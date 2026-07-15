import 'dart:async';

import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/reels_playback_coordinator.dart';
import 'package:cookster/core/video/video_preload_manager.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    if (!pool.isFeedVisibleKey(videoId) || !pool.isFrameReady(videoId)) {
      return;
    }
    if (pool.isActiveAudible(videoId)) {
      return;
    }
    unawaited(pool.ensureFeedAudibleWithRetry(videoId));
  }

  static Future<void> warmVisibleIndex({
    required VideoPreloadManager preloadManager,
    required ReelsPlaybackCoordinator coordinator,
    required BuildContext context,
    required int index,
    int maxWaitMs = 700,
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
    ReelVideoPlayerState? Function()? resolveState,
    bool forcePlayerReattach = false,
    int warmMaxWaitMs = 700,
  }) async {
    // Photo→video: the player only mounts on the next frame after visibleIndex
    // flips. Wait for state FIRST — warming before the mount made us
    // finish attach while state was still null and silently no-op.
    var state = await _waitForPlayerState(
      context,
      playerKey: playerKey,
      resolveState: resolveState,
    );
    if (!context.mounted) {
      return;
    }

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

    // Re-resolve after warm — mount can complete during the await.
    state = _readState(playerKey: playerKey, resolveState: resolveState) ??
        await _waitForPlayerState(
          context,
          playerKey: playerKey,
          resolveState: resolveState,
        );
    if (state == null || !context.mounted) {
      return;
    }
    if (forcePlayerReattach) {
      await state.resumeAfterRouteOverlay();
    } else {
      // Session-cold mounts skip initState auto-open when openCount==0 so
      // warm can finish first — open here after prefetch.
      await state.ensureVisibleOpen();
    }
  }

  static ReelVideoPlayerState? _readState({
    GlobalKey<ReelVideoPlayerState>? playerKey,
    ReelVideoPlayerState? Function()? resolveState,
  }) {
    return resolveState?.call() ?? playerKey?.currentState;
  }

  static Future<ReelVideoPlayerState?> _waitForPlayerState(
    BuildContext context, {
    GlobalKey<ReelVideoPlayerState>? playerKey,
    ReelVideoPlayerState? Function()? resolveState,
  }) async {
    if (playerKey == null && resolveState == null) {
      return null;
    }
    var state = _readState(playerKey: playerKey, resolveState: resolveState);
    if (state != null) {
      return state;
    }
    for (var i = 0; i < 12 && context.mounted; i++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!context.mounted) {
        return null;
      }
      state = _readState(playerKey: playerKey, resolveState: resolveState);
      if (state != null) {
        return state;
      }
    }
    return _readState(playerKey: playerKey, resolveState: resolveState);
  }

  static Future<void> resumeAfterAppForeground({
    GlobalKey<ReelVideoPlayerState>? playerKey,
    ReelVideoPlayerState? Function()? resolveState,
    required String? videoId,
    required Future<void> Function() attachVisible,
  }) async {
    if (videoId != null && videoId.isNotEmpty) {
      unawaited(
        MediaKitPlayerPool.instance.recoverFeedVisibleSurface(videoId),
      );
    }
    await attachVisible();
    await _readState(playerKey: playerKey, resolveState: resolveState)
        ?.resumeAfterAppBackground();
    if (videoId != null && videoId.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.resumeFeedVisible(videoId));
    }
  }
}
