import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/core/widgets/tiktok_feed_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/addCommentControllr.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/commentScreen.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/contactNowDialog.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reviewSheet.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import 'package:cookster/modules/video_likes_screen/video_likes_screen.dart';
import 'package:cookster/core/share/cookster_share_links.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// Layout presets — each player keeps different chrome, same Cookster pill rail.
enum ReelActionRailLayout {
  /// Home feed: avatar + follow, review, contact, full counts in rail.
  home,

  /// Profile reels: counts for likes/views live in the top bar; rail is icon-only.
  profile,

  /// Saved / liked collections: standard rail with counts, no avatar.
  collection,

  /// Single-video screens: review + contact when applicable.
  standalone,
}

/// Right-side Cookster action rail (glass pill) shared across reel players.
class ReelActionRail extends StatefulWidget {
  const ReelActionRail({
    super.key,
    required this.video,
    required this.isAuthenticated,
    this.layout = ReelActionRailLayout.collection,
    this.listenLive = true,
    this.bottomInset,
    this.fallbackCommentCount,
    this.onBeforeNavigation,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final ReelActionRailLayout layout;
  final bool listenLive;
  final double? bottomInset;
  final int? fallbackCommentCount;
  final VoidCallback? onBeforeNavigation;

  @override
  State<ReelActionRail> createState() => _ReelActionRailState();
}

class _ReelActionRailState extends State<ReelActionRail> {
  static bool _isProcessingFollow = false;

  bool get _showAvatar => widget.layout == ReelActionRailLayout.home;

  bool get _showLikeCount =>
      widget.layout != ReelActionRailLayout.profile;

  bool get _showReview =>
      widget.layout == ReelActionRailLayout.home ||
      widget.layout == ReelActionRailLayout.standalone;

  bool get _showContact =>
      widget.layout == ReelActionRailLayout.home ||
      widget.layout == ReelActionRailLayout.standalone;

  bool get _showBlockReport => true;

  double _resolvedBottomInset(BuildContext context) {
    if (widget.bottomInset != null) {
      return widget.bottomInset!;
    }
    return switch (widget.layout) {
      ReelActionRailLayout.home =>
        MediaQuery.paddingOf(context).bottom +
            TikTokFeedChrome.actionRailBottomInset,
      ReelActionRailLayout.profile ||
      ReelActionRailLayout.collection =>
        MediaQuery.paddingOf(context).bottom + 8,
      ReelActionRailLayout.standalone => MediaQuery.sizeOf(context).height * 0.1,
    };
  }

  void _navigate(VoidCallback action) {
    widget.onBeforeNavigation?.call();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = _resolvedBottomInset(context);
    final profileController = Get.find<ProfileController>();
    final professionalProfileController =
        Get.find<ProfessionalProfileController>();
    final currentUserDetails =
        profileController.simpleUserDetails.value?.user;
    final currentUser = professionalProfileController.userDetails.value?.user;
    final loggedInUserId =
        currentUserDetails?.id ?? currentUser?.id ?? '';

    return Positioned(
      right: 10,
      bottom: bottom,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_showAvatar)
              _CreatorAvatar(
                video: widget.video,
                isAuthenticated: widget.isAuthenticated,
                loggedInUserId: loggedInUserId,
                onBeforeNavigation: widget.onBeforeNavigation,
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: TikTokFeedChrome.actionPillDecoration,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: _StatsColumn(
                    video: widget.video,
                    isAuthenticated: widget.isAuthenticated,
                    listenLive: widget.listenLive,
                    showLikeCount: _showLikeCount,
                    showContact: _showContact,
                    showBlockReport: _showBlockReport,
                    fallbackCommentCount: widget.fallbackCommentCount,
                    onBeforeNavigation: widget.onBeforeNavigation,
                  ),
                ),
              ),
            ),
            if (_showReview &&
                widget.video.sponsorType == null &&
                widget.video.frontUserId?.toString() != loggedInUserId) ...[
              const SizedBox(height: 8),
              _ReviewButton(
                video: widget.video,
                isAuthenticated: widget.isAuthenticated,
                listenLive: widget.listenLive,
                currentUserDetails: currentUserDetails,
                currentUser: currentUser,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({
    required this.video,
    required this.isAuthenticated,
    required this.loggedInUserId,
    this.onBeforeNavigation,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final String loggedInUserId;
  final VoidCallback? onBeforeNavigation;

  @override
  Widget build(BuildContext context) {
    final creatorId = video.frontUserId?.toString();
    if (creatorId == null || creatorId.isEmpty) {
      return const SizedBox(height: 8);
    }

    final profileController = Get.find<ProfileController>();
    final professionalProfileController =
        Get.find<ProfessionalProfileController>();

    return Obx(() {
      final currentUserRx =
          professionalProfileController.userDetails.value?.user;
      final isProfileNull = currentUserRx == null;
      final isFollowing = isProfileNull
          ? profileController.isFollowing(creatorId)
          : professionalProfileController.isFollowing(creatorId);
      final showFollow =
          loggedInUserId != creatorId && video.sponsorType == null;

      return Column(
        children: [
          GestureDetector(
            onTap: () {
              onBeforeNavigation?.call();
              unawaited(Get.to(() => VisitProfileView(userId: creatorId)));
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: TikTokFeedChrome.actionAvatarSize,
                  height: TikTokFeedChrome.actionAvatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: (video.resolvedUserAvatarUrl?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: video.resolvedUserAvatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => ColoredBox(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                if (showFollow && !isFollowing)
                  Positioned(
                    bottom: -6,
                    child: GestureDetector(
                      onTap: () async {
                        if (_ReelActionRailState._isProcessingFollow) return;
                        if (!isAuthenticated) {
                          Get.toNamed(AppRoutes.signIn);
                          return;
                        }
                        _ReelActionRailState._isProcessingFollow = true;
                        final wasFollowing = isFollowing;
                        try {
                          if (isProfileNull) {
                            await profileController.toggleFollowStatus(
                              creatorId,
                            );
                          } else {
                            await professionalProfileController
                                .toggleFollowStatus(creatorId);
                          }
                          if (Get.isRegistered<HomeController>()) {
                            _updateFollowerCountForUser(
                              creatorId,
                              !wasFollowing,
                              Get.find<HomeController>(),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error toggling follow status: $e');
                          if (Get.isRegistered<HomeController>()) {
                            _updateFollowerCountForUser(
                              creatorId,
                              wasFollowing,
                              Get.find<HomeController>(),
                            );
                          }
                        } finally {
                          _ReelActionRailState._isProcessingFollow = false;
                        }
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: ColorUtils.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: ColorUtils.darkBrown,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      );
    });
  }
}

class _StatsColumn extends StatelessWidget {
  const _StatsColumn({
    required this.video,
    required this.isAuthenticated,
    required this.listenLive,
    required this.showLikeCount,
    required this.showContact,
    required this.showBlockReport,
    this.fallbackCommentCount,
    this.onBeforeNavigation,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final bool listenLive;
  final bool showLikeCount;
  final bool showContact;
  final bool showBlockReport;
  final int? fallbackCommentCount;
  final VoidCallback? onBeforeNavigation;

  @override
  Widget build(BuildContext context) {
    final videoId = video.id ?? '';
    final profileController = Get.find<ProfileController>();
    final professionalProfileController =
        Get.find<ProfessionalProfileController>();
    final commentsController = Get.find<VideoCommentsController>();
    final saveController = ensureSaveController();

    Widget buildColumn(ReelVideoStats stats) {
      final currentUserDetails =
          profileController.simpleUserDetails.value?.user;
      final currentUser =
          professionalProfileController.userDetails.value?.user;
      final userId = currentUserDetails?.id ?? currentUser?.id ?? '';
      final isLiked = stats.likes.contains(userId);
      final commentCount = stats.commentCount > 0
          ? stats.commentCount
          : (fallbackCommentCount ?? video.commentsCount ?? 0);
      final formattedLikeCount = ReelVideoStats.formatCount(stats.likeCount);
      final formattedCommentCount = ReelVideoStats.formatCount(commentCount);
      final formattedViewCount = ReelVideoStats.formatCount(stats.viewCount);
      final loggedInUserId = userId;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReelActionTap(
            onTap: () async {
              if (!isAuthenticated) {
                Get.toNamed(AppRoutes.signIn);
                return;
              }
              if (video.id == null || userId.isEmpty) return;
              HapticFeedback.lightImpact();
              await commentsController.toggleVideoLike(video.id!, userId);
            },
            child: _ReelActionSvg(
              'assets/icons/heart.svg',
              color: isLiked ? Colors.red : Colors.white,
            ),
          ),
          if (showLikeCount) ...[
            const SizedBox(height: 2),
            _ReelActionTap(
              onTap: () {
                if (video.id == null) return;
                onBeforeNavigation?.call();
                Get.to(VideoLikesScreen(videoId: video.id!));
              },
              child: Text(
                formattedLikeCount,
                style: TikTokFeedChrome.actionCount,
              ),
            ),
          ],
          if (video.commentsEnabled) ...[
            const SizedBox(height: 10),
            _ReelActionTap(
              onTap: () {
                if (!isAuthenticated) {
                  Get.toNamed(AppRoutes.signIn);
                  return;
                }
                final uid = currentUserDetails?.id ?? currentUser?.id;
                final userImage =
                    currentUserDetails?.image ?? currentUser?.image ?? '';
                if (video.id == null || uid == null || uid.isEmpty) return;
                showCommentsBottomSheetNew(
                  context,
                  video.id!,
                  uid,
                  userImage,
                  videoOwnerId: video.frontUserId,
                );
              },
              child: _ReelActionSvg('assets/icons/comment.svg'),
            ),
            const SizedBox(height: 2),
            Text(
              formattedCommentCount,
              style: TikTokFeedChrome.actionCount,
            ),
          ],
          const SizedBox(height: 10),
          _ReelActionTap(
            onTap: () => ReelActionRailShare.share(context, video),
            child: _ReelActionSvg('assets/icons/share.svg'),
          ),
          if (video.sponsorType == null) ...[
            const SizedBox(height: 10),
            Obx(() {
              saveController.savedIdRevision.value;
              final vid = video.id?.toString() ?? '';
              final isSaved = saveController.isVideoSaved(vid);
              return _ReelActionTap(
                onTap: () async {
                  if (!isAuthenticated) {
                    Get.toNamed(AppRoutes.signIn);
                    return;
                  }
                  if (video.id == null) return;
                  saveController.setVideoSavedLocally(
                    vid,
                    saved: !isSaved,
                  );
                  await saveController.saveVideo(video.id!);
                },
                child: _ReelActionSvg(
                  'assets/icons/bookmark.svg',
                  color: isSaved ? ColorUtils.primaryColor : Colors.white,
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          _ReelActionTap(
            onTap: () {
              if (video.id == null) return;
              ReelActionRailMoreSheet.show(
                context,
                videoId: video.id!,
                frontUserId: video.frontUserId?.toString() ?? '',
                loggedInUserId: loggedInUserId,
                viewCountLabel: formattedViewCount,
                showBlockReport: showBlockReport,
                isAuthenticated: isAuthenticated,
                onBeforeNavigation: onBeforeNavigation,
              );
            },
            child: _ReelActionSvg('assets/icons/more.svg', size: 20),
          ),
          if (showContact &&
              video.takeOrder == 1 &&
              (video.contactPhone?.toString().isNotEmpty == true ||
                  video.contactEmail?.toString().isNotEmpty == true ||
                  video.latitude?.toString().isNotEmpty == true)) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              width: 28,
              height: 1,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            _ReelActionTap(
              onTap: () {
                if (!isAuthenticated) {
                  Get.toNamed(AppRoutes.signIn);
                  return;
                }
                final firestore = FirebaseFirestore.instance;
                final docRef =
                    firestore.collection('countContactClick').doc(video.id);
                firestore.runTransaction((transaction) async {
                  final docSnapshot = await transaction.get(docRef);
                  if (!docSnapshot.exists) {
                    transaction.set(docRef, {
                      'businessId': video.frontUserId,
                      'videoId': video.id,
                      'totalClicks': 1,
                      'userIds': [currentUserDetails!.id],
                    });
                  } else {
                    final data = docSnapshot.data()!;
                    final userIds =
                        List<String>.from(data['userIds'] ?? []);
                    if (!userIds.contains(currentUserDetails!.id)) {
                      transaction.update(docRef, {
                        'totalClicks': FieldValue.increment(1),
                        'userIds': FieldValue.arrayUnion([
                          currentUserDetails.id,
                        ]),
                      });
                    }
                  }
                });
                showContactNowDialog(
                  context,
                  website: video.website?.toString() ?? '',
                  phoneNumber: video.contactPhone?.toString() ?? '',
                  latitude: video.latitude?.toString() ?? '',
                  longitude: video.longitude?.toString() ?? '',
                  email: video.contactEmail?.toString() ?? '',
                  videoId: video.id.toString(),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: ColorUtils.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: _ReelActionSvg(
                  'assets/icons/contact.svg',
                  color: ColorUtils.darkBrown,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (!listenLive || videoId.isEmpty) {
      return buildColumn(ReelVideoStats.empty);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        return buildColumn(ReelVideoStats.fromDoc(snapshot.data));
      },
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.video,
    required this.isAuthenticated,
    required this.listenLive,
    required this.currentUserDetails,
    required this.currentUser,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final bool listenLive;
  final dynamic currentUserDetails;
  final dynamic currentUser;

  @override
  Widget build(BuildContext context) {
    final videoId = video.id ?? '';

    Widget buttonChild(String label) {
      return InkWell(
        onTap: () {
          if (!isAuthenticated) {
            Get.toNamed(AppRoutes.signIn);
            return;
          }
          final userId = currentUserDetails?.id ?? currentUser?.id;
          final userImage =
              currentUserDetails?.image ?? currentUser?.image ?? '';
          if (video.id == null || userId == null) return;
          showReviewsBottomSheet(
            context,
            video.id!,
            userId,
            userImage,
          );
        },
        child: Column(
          children: [
            Icon(
              Icons.star_rounded,
              color: Colors.amberAccent,
              size: TikTokFeedChrome.actionIconSize * 0.85,
              shadows: TikTokFeedChrome.labelShadow,
            ),
            Text(label, style: TikTokFeedChrome.actionCaption),
          ],
        ),
      );
    }

    if (!listenLive || videoId.isEmpty) {
      return buttonChild('0.0');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        final rating = ReelVideoStats.fromDoc(snapshot.data).averageRating;
        final label = rating > 0 ? rating.toStringAsFixed(1) : '0.0';
        return buttonChild(label);
      },
    );
  }
}

class _ReelActionTap extends StatelessWidget {
  const _ReelActionTap({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }
}

class _ReelActionSvg extends StatelessWidget {
  const _ReelActionSvg(this.asset, {this.color, this.size});

  final String asset;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? TikTokFeedChrome.actionIconSize;
    return SizedBox(
      width: dimension,
      height: dimension,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          color ?? Colors.white,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class ReelActionRailShare {
  static Future<void> share(BuildContext context, WallVideos video) async {
    final videoId = video.id?.trim();
    if (videoId == null || videoId.isEmpty) {
      _shareError();
      return;
    }
    try {
      final message = CooksterShareLinks.videoShareMessage(videoId);
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        message,
        subject: 'Cookster Video',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
      _shareError();
    }
  }

  static void _shareError() {
    Get.snackbar(
      'Error',
      'Could not share this video',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}

class ReelActionRailMoreSheet {
  static void show(
    BuildContext context, {
    required String videoId,
    required String frontUserId,
    required String loggedInUserId,
    required String viewCountLabel,
    required bool showBlockReport,
    required bool isAuthenticated,
    VoidCallback? onBeforeNavigation,
  }) {
    final isOwnVideo = frontUserId == loggedInUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorUtils.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.visibility_outlined,
                    color: ColorUtils.grey,
                  ),
                  title: Text(
                    'views'.tr,
                    style: TextStyle(color: Colors.black, fontSize: 14.sp),
                  ),
                  trailing: Text(
                    viewCountLabel,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showBlockReport && !isOwnVideo) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    leading: Icon(Icons.block, color: ColorUtils.grey),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: ColorUtils.grey,
                    ),
                    title: Text(
                      'block_user'.tr,
                      style: TextStyle(color: Colors.black, fontSize: 14.sp),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (!isAuthenticated) {
                        Get.toNamed(AppRoutes.signIn);
                        return;
                      }
                      if (Get.isRegistered<HomeController>()) {
                        Get.find<HomeController>().blockUser(
                          loggedInUserId,
                          frontUserId,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.flag_outlined, color: ColorUtils.grey),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: ColorUtils.grey,
                    ),
                    title: Text(
                      'report-content'.tr,
                      style: TextStyle(color: Colors.black, fontSize: 14.sp),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (!isAuthenticated) {
                        Get.toNamed(AppRoutes.signIn);
                        return;
                      }
                      onBeforeNavigation?.call();
                      Get.to(ReportContentView(videoId: videoId));
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

void _updateFollowerCountForUser(
  String frontUserId,
  bool isFollowing,
  HomeController controller,
) {
  final videos = controller.videoFeed.value.videos;
  if (videos == null) return;

  final countChange = isFollowing ? 1 : -1;
  for (final video in videos) {
    if (video.frontUserId == frontUserId) {
      video.followersCount = (video.followersCount ?? 0) + countChange;
      if ((video.followersCount ?? 0) < 0) {
        video.followersCount = 0;
      }
    }
  }
}

/// Builds a [WallVideos] shell for players that are not backed by feed models.
WallVideos wallVideoForReelActions({
  String? id,
  String? frontUserId,
  dynamic sponsorType,
  int? takeOrder,
  dynamic allowComments,
  String? userName,
  String? userImage,
  dynamic contactPhone,
  dynamic contactEmail,
  dynamic website,
  dynamic latitude,
  dynamic longitude,
}) {
  return WallVideos(
    id: id,
    frontUserId: frontUserId,
    sponsorType: sponsorType,
    takeOrder: takeOrder,
    allowComments: WallVideos.parseAllowComments(allowComments),
    userName: userName,
    userImage: userImage,
    contactPhone: contactPhone,
    contactEmail: contactEmail,
    website: website,
    latitude: latitude,
    longitude: longitude,
  );
}
