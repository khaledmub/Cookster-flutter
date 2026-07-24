import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:cookster/core/widgets/tiktok_feed_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_feed_player_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

export 'package:cookster/core/media/wall_video_media.dart'
    show isReelPhotoPostFlag, isReelGridPhotoPost, isReelGridProcessing;

/// Full-cell overlay for a grid tile whose video is still transcoding on the
/// server. Solid dark tile + spinner — never show a stale/default food photo.
class ReelGridProcessingOverlay extends StatelessWidget {
  const ReelGridProcessingOverlay({
    super.key,
    this.borderRadius = 12,
  });

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: const ColoredBox(
          color: Color(0xFF121212),
          child: Center(
            child: _ReelGridProcessingContent(),
          ),
        ),
      ),
    );
  }
}

class _ReelGridProcessingContent extends StatelessWidget {
  const _ReelGridProcessingContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24.w,
          height: 24.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Text(
            'processing'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small inline "Photo" chip shown beside the creator name (TikTok-style).
class ReelPhotoInlineBadge extends StatelessWidget {
  const ReelPhotoInlineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_rounded,
            color: Colors.white,
            size: 12.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            'Photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              height: 1.1,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy top-center badge — prefer [ReelPhotoInlineBadge] beside creator name.
@Deprecated('Use ReelPhotoInlineBadge beside username in VideoDescriptionWidget')
class ReelPhotoBadge extends StatelessWidget {
  const ReelPhotoBadge({
    super.key,
    this.belowFeedTabs = false,
  });

  /// Home feed has category tabs in the top chrome row.
  final bool belowFeedTabs;

  double _topInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    if (!belowFeedTabs) {
      return safeTop + 8;
    }
    // Below the floating tab row (search/filter now live in that row).
    return safeTop + TikTokFeedChrome.feedTabBarHeight + 8;
  }

  @override
  Widget build(BuildContext context) {
    // Top-center so the badge never overlaps corner controls (search/filter,
    // back, action column) in either LTR or RTL — it stands alone.
    return Positioned(
      top: _topInset(context),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
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

/// Wraps reel media; photo posts are indicated beside the creator name in captions.
class ReelFeedPageMediaChrome extends StatelessWidget {
  const ReelFeedPageMediaChrome({
    super.key,
    required this.video,
    required this.child,
    required this.isActivePage,
    this.belowFeedTabs = false,
  });

  final WallVideos video;
  final Widget child;
  final bool isActivePage;
  final bool belowFeedTabs;

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
      children: [child],
    );
  }
}
