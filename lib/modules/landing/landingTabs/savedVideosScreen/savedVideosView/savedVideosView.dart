import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/profile_reel_prefetch.dart';
import 'package:cookster/modules/collection_reel/collection_reel_screen.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';

import '../../../../../core/widgets/paginated_scroll_mixin.dart';
import '../../../../../appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';

class SavedVideosView extends StatefulWidget {
  const SavedVideosView({super.key});

  @override
  State<SavedVideosView> createState() => _SavedVideosViewState();
}

class _SavedVideosViewState extends State<SavedVideosView>
    with PaginatedScrollMixin {
  final SaveController saveController = Get.find();
  bool _openingReel = false;

  @override
  void initState() {
    super.initState();
    initPaginatedScroll(() {
      if (saveController.hasMore && !saveController.isLoadingMore.value) {
        saveController.fetchMoreSavedVideos();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      saveController.getSavedVideos();
    });
  }

  Future<void> _onRefresh() async {
    await saveController.getSavedVideos();
  }

  @override
  void dispose() {
    disposePaginatedScroll();
    super.dispose();
  }

  Widget _buildVideoTile(SavedVideos video, int thumbCache) {
    return GestureDetector(
      onTap: () async {
        if (_openingReel) {
          return;
        }
        _openingReel = true;
        try {
          if (Get.isRegistered<HomeController>()) {
            await Get.find<HomeController>().awaitPendingReelTeardown();
          }
          final isPhoto = isReelGridPhotoPost(
            isImage: video.isImage,
            videoUrl: video.videoUrl,
            video: video.video,
            thumbnailUrl: video.thumbnailUrl,
            imageUrl: video.imageUrl,
            image: video.image,
            transcodeStatus: video.transcodeStatus,
            processingStatus: video.processingStatus,
          );
          warmProfileReelTap(
            videoUrl: video.videoUrl,
            video: video.video,
            hlsUrl: video.hlsUrl,
            hlsPlaylistUrl: video.hlsPlaylistUrl,
            transcodeStatus: video.transcodeStatus,
            videoSources: video.videoSources,
          );
          await prepareForProfileReelRoute(forPhotoPost: isPhoto);
          if (!context.mounted) {
            return;
          }
          Get.to(
            () => CollectionReelScreen(
              kind: CollectionReelKind.saved,
              anchorId: video.id?.toString(),
              initialPosterUrl: profileReelPosterFromGrid(
                processingStatus: video.processingStatus,
                transcodeStatus: video.transcodeStatus,
                thumbnailUrl: video.thumbnailUrl,
                imageUrl: video.imageUrl,
                image: video.image,
              ),
            ),
            preventDuplicates: false,
          );
        } finally {
          _openingReel = false;
        }
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: video.resolvedThumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: video.resolvedThumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    memCacheWidth: thumbCache,
                    memCacheHeight: (thumbCache * 1.33).round(),
                  )
                : Image.asset(
                    'assets/images/food1.jpg',
                    fit: BoxFit.cover,
                  ),
          ),
          Center(
            child: ReelGridMediaTypeIcon(
              isPhoto: isReelGridPhotoPost(
                isImage: video.isImage,
                videoUrl: video.videoUrl,
                video: video.video,
                thumbnailUrl: video.thumbnailUrl,
                imageUrl: video.imageUrl,
                image: video.image,
                transcodeStatus: video.transcodeStatus,
                processingStatus: video.processingStatus,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 20;
    final thumbCache = gridThumbnailMemCacheSize(100.w);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          padding: EdgeInsets.only(top: 20.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: const LinearGradient(
              colors: [Color(0XFFFFD700), Color(0XFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  "Saved Reels".tr,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                left:
                    Directionality.of(context) == TextDirection.rtl ? null : 16,
                right:
                    Directionality.of(context) == TextDirection.rtl ? 16 : null,
                top: 25,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => navigateBack(),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6BE00),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back,
                        color: ColorUtils.darkBrown,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0XFFFFD700),
        backgroundColor: Colors.white,
        child: Obx(() {
          if (saveController.isLoading.value) {
            return const Center(
              child: PulseLogoLoader(logoPath: "assets/images/appLogo.png"),
            );
          }

          final videos = saveController.savedVideos;
          if (videos.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: Center(
                    child: Image.asset(
                      "assets/images/notfound.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            controller: paginatedScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 100.w / 133.h,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildVideoTile(videos[index], thumbCache),
                    childCount: videos.length,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Obx(() {
                  if (!saveController.isLoadingMore.value) {
                    return SizedBox(height: bottomPadding);
                  }
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}
