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
///
/// Set [forPhotoPost] to skip pool dispose — photo screens don't need a
/// decoder and disposing mid-tap made multi-tap open feel broken.
Future<void> prepareForProfileReelRoute({bool forPhotoPost = false}) async {
  // Sync mute first — do not wait for idle while home can still unmute.
  MediaKitPlayerPool.instance.setFeedUnmuteEnabled(false);
  MediaKitPlayerPool.instance.silenceAllSync();
  MediaKitPlayerPool.instance.pauseAllImmediate();
  if (Get.isRegistered<HomeController>()) {
    Get.find<HomeController>().setReelsTabVisible(false);
  }
  if (forPhotoPost) {
    // Photo viewer has no MediaKit surface — silence is enough.
    await SchedulerBinding.instance.endOfFrame;
    return;
  }
  // Bounded idle wait — a hung native player.dispose() (e.g. left behind by a
  // photo→video transition) must never permanently freeze reel reopening.
  await MediaKitPlayerPool.instance.awaitOperationsIdle(
    timeout: const Duration(milliseconds: 1200),
  );
  if (Get.isRegistered<HomeController>()) {
    final home = Get.find<HomeController>();
    // Do not bump [routeOverlayPauseDepth] here — the pushed reel screen (or
    // visit-profile shell) owns pause/resume pairing. An extra pause left the
    // home feed permanently blocked after closing profile reels.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await home.releaseAllVideoResources();
  } else {
    await MediaKitPlayerPool.instance.disposeAllWithTimeout();
    await VideoPlayerPool.instance.clear();
  }
  await SchedulerBinding.instance.endOfFrame;
  await SchedulerBinding.instance.endOfFrame;
}
