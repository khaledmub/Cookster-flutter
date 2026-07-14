import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/profile_reel_prefetch.dart';
import 'package:cookster/modules/collection_reel/collection_reel_screen.dart';

import '../../appUtils/colorUtils.dart';
import '../../core/widgets/paginated_scroll_mixin.dart';
import '../../loaders/pulseLoader.dart';
import 'liked_videos_controller/liked_videos_controller.dart';
import 'liked_videos_model/liked_videos_model.dart';

class LikedVideosScreen extends StatefulWidget {
  final String userId;

  const LikedVideosScreen({super.key, required this.userId});

  @override
  State<LikedVideosScreen> createState() => _LikedVideosScreenState();
}

class _LikedVideosScreenState extends State<LikedVideosScreen>
    with PaginatedScrollMixin {
  late final LikedVideosController controller;
  bool _openingReel = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LikedVideosController>();
    initPaginatedScroll(() {
      if (controller.hasMore && !controller.isLoadingMore.value) {
        controller.fetchMoreLikedVideos();
      }
    });
  }

  @override
  void dispose() {
    disposePaginatedScroll();
    super.dispose();
  }

  bool _likedTileIsPhoto(LikedVideos video) {
    return isReelGridPhotoPost(
      isImage: video.isImage,
      videoUrl: video.videoUrl,
      video: video.video,
      thumbnailUrl: video.thumbnailUrl,
      imageUrl: video.imageUrl,
      image: video.image,
      transcodeStatus: video.transcodeStatus,
      processingStatus: video.processingStatus,
    );
  }

  Widget _buildVideoTile(LikedVideos video, int thumbCache) {
    return GestureDetector(
      onTap: () {
        if (_openingReel) {
          return;
        }
        _openingReel = true;
        try {
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
          // Sync silence + session claim only — no awaits. The pushed screen's
          // bootstrap does the full pool dispose. This keeps the tap instant
          // (no ~2s wait that made users tap repeatedly).
          silenceHomeForReelRoute();
          if (!context.mounted) {
            return;
          }
          unawaited(Get.to(
            () => CollectionReelScreen(
              kind: CollectionReelKind.liked,
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
          ));
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
              isPhoto: _likedTileIsPhoto(video),
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
                  "liked_videos".tr,
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
                child: InkWell(
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
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: PulseLogoLoader(logoPath: "assets/images/appLogo.png"),
          );
        }

        final videos = controller.likedVideos;
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
                if (!controller.isLoadingMore.value) {
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
    );
  }
}
