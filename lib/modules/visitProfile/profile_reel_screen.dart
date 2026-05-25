import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart'
    show VideoDescriptionWidget;
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_overlay_column.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/videoPlayerWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vertical reel viewer from a visit profile — same overlays as the home feed.
class ProfileReelScreen extends StatefulWidget {
  const ProfileReelScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.ownerId,
    this.ownerName,
    this.ownerImage,
    this.ownerFollowers = 0,
  });

  final List<WallVideos> videos;
  final int initialIndex;
  final String? ownerId;
  final String? ownerName;
  final String? ownerImage;
  final int ownerFollowers;

  @override
  State<ProfileReelScreen> createState() => _ProfileReelScreenState();
}

class _ProfileReelScreenState extends State<ProfileReelScreen> {
  late final PageController _pageController;
  late int _visibleIndex;
  bool _isAuthenticated = false;
  final Set<String> _trackedVideoIds = {};
  Timer? _viewTrackDebounce;
  late final HomeController _homeController;

  @override
  void initState() {
    super.initState();
    ensureVisitProfileDependencies();
    _homeController = Get.find<HomeController>();
    final maxIndex = widget.videos.isEmpty ? 0 : widget.videos.length - 1;
    _visibleIndex = widget.initialIndex.clamp(0, maxIndex);
    _pageController = PageController(initialPage: _visibleIndex);
    MediaKitPlayerPool.instance.pauseAllImmediate();
    unawaited(_loadAuth());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_activateVisible(_visibleIndex));
      _scheduleViewTrack(widget.videos[_visibleIndex]);
    });
  }

  @override
  void dispose() {
    _viewTrackDebounce?.cancel();
    _pageController.dispose();
    MediaKitPlayerPool.instance.pauseAllImmediate();
    super.dispose();
  }

  Future<void> _loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (mounted) {
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
      });
    }
  }

  Future<void> _activateVisible(int index) async {
    if (index < 0 || index >= widget.videos.length) {
      return;
    }
    final video = widget.videos[index];
    final key = video.id ?? video.resolvedPlaybackUrl ?? '';
    if (key.isEmpty) {
      return;
    }
    await MediaKitPlayerPool.instance.prepareVisiblePlayback(key);
    await MediaKitPlayerPool.instance.activateVisible(key);
  }

  void _scheduleViewTrack(WallVideos video) {
    final videoId = video.id;
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    if (_trackedVideoIds.contains(videoId)) {
      return;
    }
    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) {
        return;
      }
      _trackedVideoIds.add(videoId);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      await VideoViewTracker.trackUniqueView(
        videoId: videoId,
        userId: userId,
        isAuthenticated: _isAuthenticated,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _visibleIndex = index);
    unawaited(_activateVisible(index));
    _scheduleViewTrack(widget.videos[index]);
  }

  Widget _buildVideoLayer(WallVideos video, int index) {
    final isActive = index == _visibleIndex;
    if (video.isImage == 1) {
      return VideoPlayerWidget(
        key: ValueKey('profile_img_${video.id}_$index'),
        videoUrl: video.resolvedPlaybackUrl ?? '',
        thumbnailUrl: video.resolvedReelPosterUrl ?? '',
        isImage: video.isImage,
        videoId: video.id,
        autoPlay: isActive,
        useMediaKit: true,
        fillScreen: true,
      );
    }
    return VideoPlayerWidget(
      key: ValueKey('profile_reel_${video.id}_$index'),
      videoUrl: video.resolvedPlaybackUrl ?? '',
      thumbnailUrl: video.resolvedReelPosterUrl ?? '',
      isImage: video.isImage,
      videoId: video.id,
      playerPoolKey: video.id,
      hlsUrl: video.resolvedHlsUrl,
      qualityMp4Urls: video.isTranscodeReady ? video.qualityMp4Urls : const [],
      autoPlay: isActive,
      useMediaKit: true,
      fillScreen: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;
    if (videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No videos', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final video = videos[index];
          final isActive = index == _visibleIndex;
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoLayer(video, index),
              if (isActive) ...[
                VideoDescriptionWidget(
                  title: video.title,
                  description: video.description,
                  tags: video.tags,
                  controller: _homeController,
                ),
                ReelOverlayColumn(
                  video: video,
                  isAuthenticated: _isAuthenticated,
                ),
              ],
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: topInset > 0 ? 4 : 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      if (widget.ownerImage != null &&
                          widget.ownerImage!.isNotEmpty)
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: MediaUrlResolver.profileImageUrl(
                                  widget.ownerImage,
                                ) ??
                                '',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            memCacheWidth: avatarMemCacheSize(36),
                            memCacheHeight: avatarMemCacheSize(36),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 18,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.ownerName ??
                                  video.userName ??
                                  '',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.ownerFollowers > 0 ? widget.ownerFollowers : video.displayFollowersCount} ${'Followers'.tr}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
