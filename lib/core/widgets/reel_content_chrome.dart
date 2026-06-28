import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

export 'package:cookster/core/media/wall_video_media.dart'
    show isReelPhotoPostFlag, isReelGridPhotoPost;

/// TikTok-style in-feed chrome: photos are static, videos play — badge + layout differ.
class ReelPhotoBadge extends StatelessWidget {
  const ReelPhotoBadge({
    super.key,
    this.belowFeedTabs = false,
  });

  /// Home feed has category tabs + search — badge sits below that header row.
  final bool belowFeedTabs;

  static const double _searchTop = 50;
  static const double _searchControlHeight = 38;

  double _topInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    if (!belowFeedTabs) {
      return safeTop + 8;
    }
    // Sit below the search control on whichever side the locale uses.
    return safeTop + _searchTop + _searchControlHeight + 10;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Positioned(
      top: _topInset(context),
      left: isRtl ? 16 : null,
      right: isRtl ? null : 16,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                  size: 16.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile / search grid: play for video, stacked-photo icon for image posts.
class ReelGridMediaTypeIcon extends StatelessWidget {
  const ReelGridMediaTypeIcon({
    super.key,
    this.video,
    this.isPhoto,
    this.size,
  }) : assert(video != null || isPhoto != null);

  final WallVideos? video;
  final bool? isPhoto;
  final double? size;

  bool get _isPhoto => isPhoto ?? video!.isPhotoPost;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 30.sp;
    if (_isPhoto) {
      return Icon(
        Icons.collections_rounded,
        color: Colors.white.withValues(alpha: 0.85),
        size: iconSize,
      );
    }
    return Icon(
      Icons.play_circle_outline,
      color: Colors.white.withValues(alpha: 0.7),
      size: iconSize,
    );
  }
}

/// Profile grid: centered badge so it does not overlap menu, sponsor, or stats.
class ProfileGridMediaTypeOverlay extends StatelessWidget {
  const ProfileGridMediaTypeOverlay({
    super.key,
    required this.isPhoto,
    this.iconSize,
  });

  final bool isPhoto;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(7.w),
          child: ReelGridMediaTypeIcon(
            isPhoto: isPhoto,
            size: iconSize ?? 18.sp,
          ),
        ),
      ),
    );
  }
}

/// Wraps reel media; shows [ReelPhotoBadge] on active photo pages (TikTok feed pattern).
class ReelFeedPageMediaChrome extends StatelessWidget {
  const ReelFeedPageMediaChrome({
    super.key,
    required this.video,
    required this.child,
    required this.isActivePage,
    this.belowFeedTabs = false,
    this.showPhotoBadge = true,
  });

  final WallVideos video;
  final Widget child;
  final bool isActivePage;
  final bool belowFeedTabs;
  final bool showPhotoBadge;

  @override
  Widget build(BuildContext context) {
    if (!kReleaseMode && isActivePage) {
      final poolKey = video.id;
      final opened = poolKey != null && poolKey.isNotEmpty
          ? MediaKitPlayerPool.instance.sourceUrlForKey(poolKey)
          : null;
      final playback = video.isPhotoPost
          ? video.resolvedPhotoDisplayUrl?.split('?').first
          : (opened?.split('?').first ??
              (video.qualityMp4Urls.isNotEmpty
                  ? video.qualityMp4Urls.last.split('?').first
                  : video.resolvedPlaybackUrl?.split('?').first));
      debugPrint(
        '[ReelChrome] reel=${video.id} photo=${video.isPhotoPost} '
        'is_image=${video.isImage} playback_ready=${video.playbackReady} '
        'playback=$playback '
        'poster=${ReelFeedPlayerKit.posterUrl(video).split('?').first}',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showPhotoBadge && isActivePage && video.isPhotoPost)
          ReelPhotoBadge(belowFeedTabs: belowFeedTabs),
      ],
    );
  }
}
