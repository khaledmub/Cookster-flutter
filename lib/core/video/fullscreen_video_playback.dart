import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Frees the reels decoder before opening a profile / single-video screen so
/// the shared [MediaKitPlayerPool] can start cleanly.
Future<void> prepareForFullscreenVideoPlayback() async {
  if (Get.isRegistered<HomeController>()) {
    await Get.find<HomeController>().releaseAllVideoResources();
    return;
  }
  await MediaKitPlayerPool.instance.disposeAll();
  await VideoPlayerPool.instance.clear();
}

/// Silences home reels, tears down the pool, and waits one frame so the home
/// feed [ReelVideoPlayer] unmounts before a profile reel route mounts its own
/// surface (Honor/MTK cannot sustain overlapping ImageReaders).
Future<void> prepareForProfileReelRoute() async {
  await MediaKitPlayerPool.instance.awaitOperationsIdle();
  if (Get.isRegistered<HomeController>()) {
    final home = Get.find<HomeController>();
    // Do not bump [routeOverlayPauseDepth] here — the pushed reel screen (or
    // visit-profile shell) owns pause/resume pairing. An extra pause left the
    // home feed permanently blocked after closing profile reels.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await home.releaseAllVideoResources();
  } else {
    await MediaKitPlayerPool.instance.disposeAll();
    await VideoPlayerPool.instance.clear();
  }
  await SchedulerBinding.instance.endOfFrame;
  await SchedulerBinding.instance.endOfFrame;
}
