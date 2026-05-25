import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/addCommentControllr.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/commentScreen.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/video_likes_screen/video_likes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// Right-side like / view / comment / share / save column (home reel feed).
class ReelOverlayColumn extends StatelessWidget {
  const ReelOverlayColumn({
    super.key,
    required this.video,
    required this.isAuthenticated,
    this.listenLive = true,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final bool listenLive;

  @override
  Widget build(BuildContext context) {
    final videoId = video.id ?? '';
    return Positioned(
      right: 10,
      bottom: Platform.isAndroid ? Get.height * 0.02 : Get.height * 0.02,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(50),
            ),
            child: _buildStatsColumn(context, videoId),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsColumn(BuildContext context, String videoId) {
    Widget column(ReelVideoStats stats) {
      final comments = Get.find<VideoCommentsController>();
      final saveController = Get.find<SaveController>();
      final profileController = Get.find<ProfileController>();
      final professionalProfileController =
          Get.find<ProfessionalProfileController>();

      final currentUserDetails =
          profileController.simpleUserDetails.value?.user;
      final currentUser =
          professionalProfileController.userDetails.value?.user;
      final userId = currentUserDetails?.id ?? currentUser?.id ?? '';
      final isLiked = stats.likes.contains(userId);
      final commentCount = stats.commentCount > 0
          ? stats.commentCount
          : (video.commentsCount ?? 0);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () async {
              if (!isAuthenticated) {
                Get.toNamed(AppRoutes.signIn);
                return;
              }
              if (video.id == null || userId.isEmpty) {
                return;
              }
              HapticFeedback.lightImpact();
              await comments.toggleVideoLike(video.id!, userId);
            },
            child: SizedBox(
              height: 20.h,
              width: 20.h,
              child: SvgPicture.asset(
                'assets/icons/heart.svg',
                fit: BoxFit.fill,
                colorFilter: ColorFilter.mode(
                  isLiked ? Colors.red : Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(height: 2),
          InkWell(
            onTap: () {
              if (video.id != null) {
                Get.to(VideoLikesScreen(videoId: video.id!));
              }
            },
            child: Text(
              ReelVideoStats.formatCount(stats.likeCount),
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
          ),
          SizedBox(
            height: 20.h,
            width: 20.h,
            child: SvgPicture.asset(
              'assets/icons/eye.svg',
              fit: BoxFit.fill,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          Text(
            ReelVideoStats.formatCount(stats.viewCount),
            style: TextStyle(color: Colors.white, fontSize: 10.sp),
          ),
          if (video.allowComments == 1) ...[
            SizedBox(height: 8),
            InkWell(
              onTap: () {
                if (!isAuthenticated) {
                  Get.toNamed(AppRoutes.signIn);
                  return;
                }
                final uid = currentUserDetails?.id ?? currentUser?.id;
                final avatar =
                    currentUserDetails?.image ?? currentUser?.image ?? '';
                if (video.id == null || uid == null) {
                  return;
                }
                showCommentsBottomSheetNew(
                  context,
                  video.id!,
                  uid,
                  avatar,
                );
              },
              child: SizedBox(
                height: 20.h,
                width: 20.h,
                child: SvgPicture.asset(
                  'assets/icons/comment.svg',
                  fit: BoxFit.fill,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SizedBox(height: 2),
            Text(
              ReelVideoStats.formatCount(commentCount),
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
            SizedBox(height: 8),
          ],
          InkWell(
            onTap: () => _shareVideo(video),
            child: SizedBox(
              height: 20.h,
              width: 20.h,
              child: SvgPicture.asset(
                'assets/icons/share.svg',
                fit: BoxFit.fill,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'share'.tr,
            style: TextStyle(color: Colors.white, fontSize: 10.sp),
          ),
          SizedBox(height: 8),
          if (video.sponsorType == null)
            Obx(() {
              final isSaved = saveController.savedVideos.any(
                (v) => v.id.toString() == video.id.toString(),
              );
              return Column(
                children: [
                  InkWell(
                    onTap: () async {
                      if (!isAuthenticated) {
                        Get.toNamed(AppRoutes.signIn);
                        return;
                      }
                      if (video.id == null) {
                        return;
                      }
                      if (isSaved) {
                        saveController.savedVideos.removeWhere(
                          (v) => v.id.toString() == video.id.toString(),
                        );
                      } else {
                        saveController.savedVideos.add(
                          SavedVideos(id: video.id, title: video.title),
                        );
                      }
                      await saveController.saveVideo(video.id!);
                    },
                    child: SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                        size: 20.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'save'.tr,
                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                  ),
                ],
              );
            }),
        ],
      );
    }

    if (!listenLive || videoId.isEmpty) {
      return column(ReelVideoStats.empty);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        return column(ReelVideoStats.fromDoc(snapshot.data));
      },
    );
  }

  void _shareVideo(WallVideos video) {
    final id = video.id;
    if (id == null || id.isEmpty) {
      return;
    }
    final appUrl = 'cookster://open.cookster.app/video?id=$id';
    final webUrl = 'https://cookster.org/web/visitSingleVideo?id=$id';
    Share.share(
      'Check out this amazing video on Cookster!\n$appUrl\n\n'
      'If the app does not open, use this web link:\n$webUrl',
      subject: 'Cookster Video',
    );
  }
}
