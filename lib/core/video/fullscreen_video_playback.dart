import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_player_pool.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
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
