import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/appUtils/feature_flags.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/profile/profile_share.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/profile_grid_thumbnail.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/core/video/profile_reel_prefetch.dart';
import 'package:cookster/core/profile/profile_video_type_utils.dart';
import 'package:cookster/core/widgets/profile_user_title.dart';
import 'package:cookster/modules/visitProfile/profile_reel_screen.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../followersFollowing/followersFollowingView/followersFollowingView.dart';
import '../../../../liked_videos_screen/liked_videos_screen.dart';
import '../../../../popup_like/popup_like_dialog.dart';
import '../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../../../promoteVideo/promoteVideoView/promoteVideoView.dart';
import '../../add/editVideo/editVideoView.dart';
import '../../packagePopupDialog/packagePopupDialog.dart';
import '../../savedVideosScreen/savedVideosView/savedVideosView.dart';
import '../profileModel/simpleUserProfileModel.dart';
import '../profileWidgets/profileWidgets.dart';
import '../../professionalProfile/profileWidgets/professsionalProfileWidgets.dart'
    show ProfileActionCard;
import 'package:cookster/core/media/media_url_resolver.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  final ProfileController profileController = Get.find();

  final PromoteVideoController promoteVideoController = Get.find();

  int? entity;

  TabController? _tabController;
  Worker? _videoTypesWorker;
  bool _openingProfileReel = false;

  void _applySystemUiStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  Future<void> _loadEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      entity = prefs.getInt('entity');
    });
  }

  void _onTabChanged() {
    if (_tabController?.indexIsChanging ?? false) {
      setState(() {});
    }
  }

  Widget _savedLikedAppBarIcons(String? userId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButtonWidget(
          icon: "assets/icons/bookmark.svg",
          onTap: () => Get.to(SavedVideosView()),
        ),
        SizedBox(width: 8.w),
        IconButtonWidget(
          icon: "assets/icons/heart.svg",
          onTap: () {
            if (userId == null) {
              return;
            }
            Get.to(
              () => LikedVideosScreen(userId: userId),
              binding: LikedVideosBinding(userId),
            );
          },
        ),
      ],
    );
  }

  void _syncTabController() {
    final videoTypes = profileController.simpleUserDetails.value?.videoTypes;
    final displayVideoTypes = _buildDisplayVideoTypes(videoTypes);
    if (displayVideoTypes.isEmpty) {
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = null;
      if (mounted) setState(() {});
      return;
    }
    if (_tabController == null) {
      _tabController = TabController(
        length: displayVideoTypes.length,
        vsync: this,
      );
      _tabController!.addListener(_onTabChanged);
    } else if (_tabController!.length != displayVideoTypes.length) {
      final previousIndex = _tabController!.index;
      _tabController!.removeListener(_onTabChanged);
      _tabController!.dispose();
      _tabController = TabController(
        length: displayVideoTypes.length,
        vsync: this,
        initialIndex: previousIndex.clamp(0, displayVideoTypes.length - 1),
      );
      _tabController!.addListener(_onTabChanged);
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _applySystemUiStyle();
    _loadEntity();
    _videoTypesWorker = ever(profileController.simpleUserDetails, (_) {
      _syncTabController();
    });
    _syncTabController();
  }

  @override
  void dispose() {
    _videoTypesWorker?.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final userId =
        profileController.simpleUserDetails.value?.user?.id?.toString();

    return RefreshIndicator(
        onRefresh: () async {
          await profileController.getUserDetails();
        },
        child: Scaffold(
          backgroundColor: Colors.white,

          appBar: AppBar(
            automaticallyImplyLeading: false,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            centerTitle: true,
            leadingWidth: isRtl ? 104.w : null,
            leading: isRtl
                ? Padding(
                    padding: EdgeInsets.only(left: 8.w, right: 12.w),
                    child: _savedLikedAppBarIcons(userId),
                  )
                : null,
            title: Text(
              "Profile".tr,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (!isRtl)
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: _savedLikedAppBarIcons(userId),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        // Get email from controller
                        final String? email =
                            promoteVideoController
                                .siteSettings
                                .value
                                ?.settings
                                ?.email;

                        if (email == null || email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email address not available'),
                            ),
                          );
                          return;
                        }

                        // Create the mailto URL
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: email,
                          queryParameters: {
                            'subject': '', // Pre-fill subject
                          },
                        );

                        // Launch the mail app
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No email app found')),
                          );
                        }
                      },
                      child: Icon(
                        Icons.support_agent_outlined,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    SizedBox(width: 16),

                    InkWell(
                      onTap: () {
                        Get.toNamed(AppRoutes.editProfile);
                      },
                      child: SvgPicture.asset(
                        "assets/icons/settings.svg",
                        height: 20.h,
                      ),
                    ),
                    SizedBox(width: 16),
                    InkWell(
                      onTap: () async {
                        await profileController.showLogoutDialog(context);
                      },
                      child:
                      Directionality.of(context) == TextDirection.rtl
                          ? Transform.flip(
                        flipX:
                        true, // Flips the icon horizontally for RTL
                        child: SvgPicture.asset(
                          "assets/icons/logout.svg",
                          height: 18.h,
                        ),
                      )
                          : SvgPicture.asset(
                        "assets/icons/logout.svg",
                        height: 18.h,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          body: Stack(
            children: [
              Obx(() {
                if (!profileController.isLoading.value) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PulseLogoLoader(
                          logoPath: "assets/images/appIcon.png",
                          size: 80,
                        ),
                      ],
                    ),
                  ],
                );
              }),
              Obx(() {
                if (profileController.isLoading.value) {
                  return const SizedBox.shrink();
                }

            final userDetails =
                profileController.simpleUserDetails.value?.user;
            final videoTypes =
                profileController.simpleUserDetails.value?.videoTypes;
            final displayVideoTypes = _buildDisplayVideoTypes(videoTypes);

            if (userDetails == null) {
              return const SizedBox.shrink();
            }

            final selectedVideos = (displayVideoTypes.isNotEmpty &&
                    _tabController != null &&
                    _tabController!.index < displayVideoTypes.length)
                ? displayVideoTypes[_tabController!.index].videos
                : null;

            return CustomScrollView(
              cacheExtent: 400,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 80.h,
                                width: 80.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ColorUtils.primaryColor),
                                ),
                                child: ClipOval(
                                  child: userDetails.image == null
                                      ? Image.asset(
                                          "assets/images/sd.png",
                                          fit: BoxFit.cover,
                                        )
                                      : CachedNetworkImage(
                                          imageUrl:
                                              '${MediaUrlResolver.profileImageUrl(userDetails.image!) ?? ''}?v=${profileController.profileImageRefreshToken.value}',
                                          fit: BoxFit.cover,
                                          memCacheWidth:
                                              avatarMemCacheSize(80.h),
                                          memCacheHeight:
                                              avatarMemCacheSize(80.h),
                                          placeholder: (_, __) => Image.asset(
                                            "assets/images/sd.png",
                                            fit: BoxFit.cover,
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Image.asset(
                                            "assets/images/sd.png",
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      if ((userDetails.countryName ?? '').toString().isNotEmpty ||
                          (userDetails.cityName ?? '').toString().isNotEmpty)
                        Text(
                          [
                            userDetails.cityName?.toString(),
                            userDetails.countryName?.toString(),
                          ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ColorUtils.darkBrown.withValues(alpha: 0.8),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      SizedBox(height: 10.h),
                      ProfileUserTitle(
                        displayName: userDetails.name?.toString(),
                        userName: userDetails.userName?.toString(),
                        nameStyle: TextStyle(
                          color: ColorUtils.darkBrown,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        handleStyle: TextStyle(
                          color: ColorUtils.darkBrown.withValues(alpha: 0.55),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Obx(() {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              onTap: () {
                                Get.to(
                                  SocialListsScreen(
                                    initialTab: SocialTab.followers,
                                    userName: userDetails.name,
                                    userId: userDetails.id,
                                  ),
                                )?.then((value) async {
                                  await profileController.getUserDetails();
                                });
                              },
                              child: ProfileStat(
                                number: "${profileController.followersList.length}",
                                label: "Followers".tr,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Get.to(
                                  SocialListsScreen(
                                    initialTab: SocialTab.following,
                                    userName: userDetails.name,
                                    userId: userDetails.id,
                                  ),
                                )?.then((value) async {
                                  await profileController.getUserDetails();
                                });
                              },
                              child: ProfileStat(
                                number: "${profileController.followingList.length}",
                                label: "Following".tr,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return LikePopup(
                                      username: userDetails.name,
                                      likeCount: profileController.totalLikes.value,
                                    );
                                  },
                                );
                              },
                              child: ProfileStat(
                                number: "${profileController.totalLikes}",
                                label: "likes".tr,
                              ),
                            ),
                          ],
                        );
                      }),
                      SizedBox(height: 12.h),
                      ProfileActionCard(
                        onShare: () {
                          shareProfile(
                            context: context,
                            email: userDetails.email?.toString(),
                            userId: userDetails.id?.toString(),
                            displayName: userDetails.name?.toString(),
                          );
                        },
                        onQr: () {
                          showProfileQrCodeDialog(userDetails.email);
                        },
                        onMore: () {
                          showMoreOptionsProfile(
                            context,
                            userDetails.name,
                            userDetails.email,
                          );
                        },
                      ),
                      if (displayVideoTypes.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          width: double.infinity,
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8D6),
                            borderRadius: BorderRadius.circular(50.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(displayVideoTypes.length, (index) {
                              final isSelected = _tabController!.index == index;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _tabController!.animateTo(index),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? ColorUtils.primaryColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(50.r),
                                    ),
                                    child: Center(
                                      child: Text(
                                        ProfileVideoTypeUtils.displayLabel(
                                          displayVideoTypes[index].name
                                              ?.toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ],
                  ),
                ),
                if (displayVideoTypes.isNotEmpty &&
                    (selectedVideos == null || selectedVideos.isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Image.asset(
                          "assets/images/notfound.png",
                          fit: BoxFit.cover,
                          height: 150.h,
                        ),
                      ),
                    ),
                  ),
                if (displayVideoTypes.isNotEmpty &&
                    selectedVideos != null &&
                    selectedVideos.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 100.w / 133.h,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        (context, videoIndex) {
                          final video = selectedVideos[videoIndex];
                          return GestureDetector(
                            onTap: () {
                              unawaited(_openProfileReelFromGrid(
                                video,
                                displayVideoTypes[_tabController!.index],
                              ));
                            },
                            child: Stack(
                              children: [
                                ProfileGridThumbnail(
                                  coverUrl: MediaUrlResolver.reelPosterUrl(
                                    processingStatus:
                                        video.processingStatus?.toString(),
                                    transcodeStatus:
                                        video.transcodeStatus?.toString(),
                                    thumbnailUrl:
                                        video.thumbnailUrl?.toString(),
                                    imageUrl: video.imageUrl?.toString(),
                                    image: video.image?.toString(),
                                  ),
                                  borderRadius: 12.r,
                                  logicalSize: 100,
                                ),
                                ProfileGridMediaTypeOverlay(
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
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12.r),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.heart_fill,
                                        color: Colors.white,
                                        size: 14.sp,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ReelVideoStats.formatCount(
                                          parseApiCount(video.likeCount),
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 4.h,
                                  right: 4.w,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      showMoreOptions(
                                        context,
                                        video.id,
                                        video.frontUserId,
                                        video.image,
                                        video,
                                      );
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.eye_fill,
                                        color: Colors.white,
                                        size: 14.sp,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ReelVideoStats.formatCount(
                                          parseApiCount(video.viewCount),
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (video.sponsorType != null)
                                  Positioned(
                                    top: 10,
                                    left: 0,
                                    child: InkWell(
                                      onTap: () {
                                        if (kDisableVideoPromotionTemporarily) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Video promotion is temporarily unavailable.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        showPackageDialog(context, videos: [video]);
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: video.sponsorType == 2
                                              ? const Color(0xFFFFD700)
                                              : const Color(0xFFC0C0C0),
                                        ),
                                        child: Icon(
                                          Icons.star_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        childCount: selectedVideos.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 70.h)),
              ],
            );
              }),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _openProfileReelFromGrid(
    UserVideos tapped,
    VideoTypes activeTab,
  ) async {
    if (_openingProfileReel) {
      return;
    }
    _openingProfileReel = true;
    try {
      // Sync silence + session claim only — no awaits. The pushed screen's
      // bootstrap does the full pool dispose. Keeps the tap instant (no ~2s
      // wait that made users tap repeatedly).
      silenceHomeForReelRoute();
      if (!mounted) {
        return;
      }
      await _openProfileReel(tapped, activeTab);
    } finally {
      _openingProfileReel = false;
    }
  }

  Future<void> _openProfileReel(UserVideos tapped, VideoTypes activeTab) async {
    final user = profileController.simpleUserDetails.value?.user;
    final userId = user?.id?.toString();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final gridVideos = activeTab.videos ?? <UserVideos>[];
    final seedVideos = gridVideos
        .map(
          (v) => WallVideos.fromSimpleUserVideo(
            v,
            ownerId: userId,
            ownerName: user?.name?.toString(),
            ownerImage: user?.image?.toString(),
          ),
        )
        .toList();
    final initialIndex = seedVideos.indexWhere(
      (v) => v.id == tapped.id?.toString(),
    );
    warmProfileReelTap(
      videoUrl: tapped.videoUrl,
      video: tapped.video,
      hlsUrl: tapped.hlsUrl,
      hlsPlaylistUrl: tapped.hlsPlaylistUrl,
      transcodeStatus: tapped.transcodeStatus,
      videoSources: tapped.videoSources,
    );
    // Fire-and-forget: awaiting Get.to holds the open-guard for the whole
    // screen lifetime, which left the grid permanently dead if the pop was
    // interrupted. Teardown serialization is handled by awaitPendingReelTeardown.
    unawaited(Get.to(
      () => ProfileReelScreen(
        userId: userId,
        videoTypeId: activeTab.id?.toString(),
        anchorId: tapped.id?.toString(),
        ownerDisplayName: user?.name?.toString(),
        ownerUserName: user?.userName?.toString(),
        ownerImage: user?.image?.toString(),
        seedVideos: seedVideos,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        initialPosterUrl: profileReelPosterFromGrid(
          processingStatus: tapped.processingStatus,
          transcodeStatus: tapped.transcodeStatus,
          thumbnailUrl: tapped.thumbnailUrl,
          imageUrl: tapped.imageUrl,
          image: tapped.image,
        ),
      ),
      preventDuplicates: false,
    ));
  }

  List<VideoTypes> _buildDisplayVideoTypes(List<VideoTypes>? sourceTypes) {
    final deduped =
        ProfileVideoTypeUtils.normalizeVideoTypeTabs<VideoTypes>(sourceTypes);
    if (!deduped.any(
      (t) => ProfileVideoTypeUtils.isOthersVideoTypeName(t.name?.toString()),
    )) {
      deduped.add(VideoTypes(name: 'Others', videos: <UserVideos>[]));
    }
    return deduped;
  }

  void showMoreOptions(BuildContext context,
      String videoId,
      String userId,
      String videoImage,
      UserVideos video,) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 40),
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

                if (video.sponsorType == null &&
                    !kDisableVideoPromotionTemporarily)
                  ListTile(
                    leading: Icon(Icons.campaign_rounded),
                    trailing: Icon(Icons.chevron_right_rounded),
                    title: Text(
                      'promote_post'.tr,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    onTap: () async {
                      // Close the bottom sheet first
                      Navigator.pop(bottomSheetContext);
                      // Pass the single video as a List<Videos>
                      Get.to(
                            () =>
                            PromoteVideoView(
                              videos: [
                                video,
                              ], // Pass the current video as a single-item list
                            ),
                      )?.then((value) async {
                        await profileController.getUserDetails();
                      });
                      ;
                    },
                  ),

                ListTile(
                  leading: Icon(Icons.edit),
                  trailing: Icon(Icons.chevron_right_rounded),
                  title: Text(
                    'Edit Video'.tr,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    Get.to(() => EditVideoView(videos: [video]))?.then((
                        value,) async {
                      await profileController.getUserDetails();
                    });
                    ;
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.redAccent),
                  title: Text(
                    'Delete Video'.tr,
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.sp),
                  ),
                  onTap: () async {
                    // Close the bottom sheet first
                    Navigator.pop(bottomSheetContext);
                    // Call deleteVideo with the original context
                    final bool isDeleted = await profileController.deleteVideo(
                      context,
                      videoId,
                      userId,
                    );
                    if (isDeleted) {
                      print("===============");
                      print(isDeleted);
                      // Ensure navigation happens after successful deletion
                      // Get.back();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
