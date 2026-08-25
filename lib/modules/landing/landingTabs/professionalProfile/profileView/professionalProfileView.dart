import 'dart:async';
import 'dart:io';

import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/core/widgets/profile_grid_thumbnail.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/core/widgets/profile_user_title.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/profile/profile_video_type_utils.dart';
import 'package:cookster/core/profile/profile_share.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/core/video/profile_reel_prefetch.dart';
import 'package:cookster/modules/visitProfile/profile_reel_screen.dart';
import 'package:cookster/appUtils/feature_flags.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../appUtils/openToWork.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../followersFollowing/followersFollowingView/followersFollowingView.dart';
import '../../../../liked_videos_screen/liked_videos_screen.dart';
import '../../../../popup_like/popup_like_dialog.dart';
import '../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../../../promoteVideo/promoteVideoView/promoteVideoView.dart';
import '../../add/editVideo/editVideoView.dart';
import '../../packagePopupDialog/packagePopupDialog.dart';
import '../../packagePopupDialog/statisticsPopup.dart';
import '../../profile/profileModel/profileModel.dart';
import '../../savedVideosScreen/savedVideosView/savedVideosView.dart';
import '../editProfile/editProfileView/professionalEditProfileView.dart';
import '../editProfile/editProfileView/subscribedPackage.dart';
import '../profileControlller/professionalProfileController.dart';
import '../profileWidgets/professsionalProfileWidgets.dart';
import 'package:cookster/core/media/media_url_resolver.dart';

class ProfessionalProfileView extends StatefulWidget {
  const ProfessionalProfileView({super.key});

  @override
  State<ProfessionalProfileView> createState() =>
      _ProfessionalProfileViewState();
}

class _ProfessionalProfileViewState extends State<ProfessionalProfileView>
    with SingleTickerProviderStateMixin {
  final ProfessionalProfileController profileController = Get.find();
  final PromoteVideoController promoteVideoController = Get.find();

  int? entity;
  TabController? _tabController;
  int currentTabIndex = 0;
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

  File? _selectedImage;
  bool _isEditMode = true;

  String? _buildCoverImageUrl(String? coverImage) {
    final base = MediaUrlResolver.profileImageUrl(coverImage);
    if (base == null || base.isEmpty) return null;
    return '$base?v=${profileController.coverImageRefreshToken.value}';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isEditMode = false;
      });
    }
  }

  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void initState() {
    super.initState();
    _applySystemUiStyle();
    _loadEntity();
    _loadLanguage();
    _videoTypesWorker = ever(profileController.userDetails, (_) {
      _syncFromUserDetails();
    });
    _syncFromUserDetails();
  }

  void _onTabChanged() {
    if (!(_tabController?.indexIsChanging ?? true)) {
      setState(() => currentTabIndex = _tabController!.index);
    }
  }

  Widget _savedLikedAppBarIcons(String? userId) {
    Widget circleIcon(String asset, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: ColorUtils.darkBrown),
          ),
          child: Center(
            child: SvgPicture.asset(
              asset,
              height: 20,
              color: ColorUtils.darkBrown,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circleIcon("assets/icons/bookmark.svg", () => Get.to(SavedVideosView())),
        SizedBox(width: 8.w),
        circleIcon("assets/icons/heart.svg", () {
          if (userId == null) {
            return;
          }
          Get.to(
            () => LikedVideosScreen(userId: userId),
            binding: LikedVideosBinding(userId),
          );
        }),
      ],
    );
  }

  void _syncFromUserDetails() {
    final details = profileController.userDetails.value;
    profileController.isB2B.value = details?.additionalData?.isB2B != 0;

    final displayVideoTypes = _buildDisplayVideoTypes(details?.videoTypes);
    if (displayVideoTypes.isEmpty) {
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = null;
      if (mounted) setState(() => currentTabIndex = 0);
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
  void dispose() {
    _videoTypesWorker?.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    return Obx(() {
      final userDetails = profileController.userDetails.value?.user;
      final videoTypes = profileController.userDetails.value?.videoTypes;
      final displayVideoTypes = _buildDisplayVideoTypes(videoTypes);
      final subscribed = profileController.userDetails.value?.subscription;
      // if (userDetails?.id != null) {
      //   profileController.checkReceivedLikes(userDetails!.id.toString());
      // } else {
      //   print("Skipping checkReceivedLikes: userDetails or ID is null");
      // }
      final professionalAdditionalData =
          profileController.userDetails.value?.additionalData;

      return RefreshIndicator(
        onRefresh: () async {
          await profileController.getUserDetails();
        },
        child: Scaffold(
          backgroundColor: Colors.white,

          appBar: AppBar(
            leadingWidth: 145,
            leading: InkWell(
              onTap: () {
                Get.to(SubscriptionPackageView(subscription: subscribed!));
              },
              child: Container(
                margin: EdgeInsets.only(
                  left: isRtl ? 0 : 16, // Fixed margin on the left
                  right: isRtl ? 16 : 0, // Fixed margin on the right
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 4), // Small gap between icon and text

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // Fixed left alignment
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "current_plan".tr,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: ColorUtils.grey,
                          ),
                        ),
                        Text(
                          subscribed?.title ?? 'No Plan',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.darkBrown,
                          ),
                        ),
                      ],
                    ),

                    Icon(
                      Icons.chevron_right, // Icon comes first
                      size: 24.sp,
                      color: ColorUtils.darkBrown,
                    ),
                  ],
                ),
              ),
            ),
            automaticallyImplyLeading: false,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            centerTitle: true,
            title: Text(
              "Profile".tr,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (!isRtl)
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: _savedLikedAppBarIcons(userDetails?.id?.toString()),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: isRtl ? 4.w : 16,
                ),
                child: Row(
                  children: [
                    if (isRtl)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: _savedLikedAppBarIcons(
                          userDetails?.id?.toString(),
                        ),
                      ),
                    ProfileAppBarCircleIcon(
                      onTap: () async {
                        final String? email = promoteVideoController
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

                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: email,
                          queryParameters: {'subject': ''},
                        );

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
                        color: ColorUtils.darkBrown,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ProfileAppBarCircleIcon(
                      onTap: () {
                        Get.to(() => EditProfessionalProfileView());
                      },
                      child: SvgPicture.asset(
                        "assets/icons/settings.svg",
                        height: 16.h,
                        colorFilter: const ColorFilter.mode(
                          ColorUtils.darkBrown,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ProfileAppBarCircleIcon(
                      onTap: () async {
                        await profileController.showLogoutDialog(context);
                      },
                      child: Directionality.of(context) == TextDirection.rtl
                          ? Transform.flip(
                              flipX: true,
                              child: SvgPicture.asset(
                                "assets/icons/logout.svg",
                                height: 15.h,
                                colorFilter: const ColorFilter.mode(
                                  ColorUtils.darkBrown,
                                  BlendMode.srcIn,
                                ),
                              ),
                            )
                          : SvgPicture.asset(
                              "assets/icons/logout.svg",
                              height: 15.h,
                              colorFilter: const ColorFilter.mode(
                                ColorUtils.darkBrown,
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Obx(() {
            return profileController.isLoading.value
                ? Column(
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
                )
                : CustomScrollView(
                  cacheExtent: 400,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 148.h,
                        child: Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              width: Get.width,
                              height: 110.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image:
                                      (userDetails!.coverImage != null &&
                                              userDetails
                                                  .coverImage!
                                                  .isNotEmpty)
                                          ? CachedNetworkImageProvider(
                                            _buildCoverImageUrl(
                                                  userDetails.coverImage,
                                                ) ??
                                                MediaUrlResolver.profileImageUrl(userDetails.coverImage!) ?? '',
                                          )
                                          : const AssetImage(
                                                'assets/images/placeholder.jpg',
                                              )
                                              as ImageProvider,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isEditMode) {
                                        _pickImage();
                                      } else {
                                        final pendingCover = _selectedImage;
                                        if (pendingCover == null) {
                                          setState(() {
                                            _isEditMode = true;
                                          });
                                          return;
                                        }
                                        profileController
                                            .updateCoverImage(
                                              coverImage: pendingCover,
                                              context: context,
                                            )
                                            .then((isSuccess) {
                                              if (!mounted) return;
                                              if (isSuccess) {
                                                setState(() {
                                                  _selectedImage = null;
                                                  _isEditMode = true;
                                                });
                                              }
                                            });
                                      }
                                    },
                                    child: Container(
                                      height: 30,
                                      width: 30,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: Icon(
                                        _isEditMode ? Icons.edit : Icons.save,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Obx(
                              () => Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: OpenToWorkBadge(
                                    size: 52.h,
                                    showOpenToWork:
                                        profileController.isB2B.value,

                                    imageUrl:
                                        '${MediaUrlResolver.profileImageUrl(userDetails.image) ?? ''}?v=${profileController.profileImageRefreshToken.value}',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            /// LEFT SIDE → country
                            if ((userDetails.countryName ?? '').isNotEmpty)
                              Expanded(
                                flex: 2, // give limited space
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "country".tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ColorUtils.darkBrown,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      userDetails.countryName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ColorUtils.darkBrown,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Spacer(flex: 2),

                            /// CENTER → name
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: ProfileUserTitle(
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
                              ),
                            ),

                            /// RIGHT SIDE → city
                            if ((userDetails.cityName ?? '').isNotEmpty)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "city".tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ColorUtils.darkBrown,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      userDetails.cityName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: ColorUtils.darkBrown,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Spacer(flex: 2),
                          ],
                        ),
                      ),
                      Obx(
                        () => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "b2b".tr,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                activeThumbColor: ColorUtils.primaryColor,
                                value: profileController.isB2B.value,
                                // Bind switch to isB2B value
                                onChanged:
                                    profileController
                                        .toggleB2B, // Call toggle function on change
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (professionalAdditionalData != null &&
                          professionalAdditionalData.businessTypeName != null &&
                          professionalAdditionalData
                              .businessTypeName!
                              .isNotEmpty)
                        Text(
                          "${professionalAdditionalData.businessTypeName}",
                          style: TextStyle(
                            color: ColorUtils.darkBrown,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                                number:
                                    "${profileController.followersList.length}",
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
                                number:
                                    "${profileController.followingList.length}",
                                label: "Following".tr,
                              ),
                            ),
                            // StreamBuilder<int>(
                            //   stream: profileController.checkLikedVideos(
                            //     userDetails.id,
                            //   ),
                            //   builder: (context, AsyncSnapshot<int> snapshot) {
                            //     if (snapshot.hasError) {
                            //       return ProfileStat(
                            //         number: "Error",
                            //         label: "Likes".tr,
                            //       );
                            //     }
                            //     return InkWell(
                            //       onTap: () {
                            //         Get.to(
                            //           LikesScreen(
                            //             currentUserId: userDetails.id,
                            //           ),
                            //         );
                            //       },
                            //       child: ProfileStat(
                            //         number: "${snapshot.data ?? 0}",
                            //         label: "Likes".tr,
                            //       ),
                            //     );
                            //   },
                            // ),
                            Obx(
                              () => InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return LikePopup(
                                        username: userDetails.name,
                                        likeCount:
                                            profileController.totalLikes.value,
                                      );
                                    },
                                  );
                                },
                                child: ProfileStat(
                                  number: "${profileController.totalLikes}",
                                  label: "likes".tr,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      ProfileActionCard(
                        contacts: [
                          if (professionalAdditionalData?.contactPhone !=
                                  null &&
                              professionalAdditionalData!
                                  .contactPhone!
                                  .isNotEmpty)
                            ProfileContactAction(
                              icon: "assets/icons/phone.svg",
                              label: 'Phone',
                              onTap: () => _launchPhone(
                                professionalAdditionalData.contactPhone,
                              ),
                            ),
                          if (professionalAdditionalData?.contactEmail !=
                                  null &&
                              professionalAdditionalData!
                                  .contactEmail!
                                  .isNotEmpty)
                            ProfileContactAction(
                              icon: "assets/icons/email.svg",
                              label: 'Email',
                              onTap: () => _launchEmail(
                                professionalAdditionalData.contactEmail,
                              ),
                            ),
                          if (professionalAdditionalData?.website != null &&
                              professionalAdditionalData!.website!.isNotEmpty)
                            ProfileContactAction(
                              icon: "assets/icons/website.svg",
                              label: 'Web',
                              onTap: () => _launchWebsite(
                                professionalAdditionalData.website,
                              ),
                            ),
                          if (professionalAdditionalData?.latitude != null &&
                              professionalAdditionalData?.longitude != null &&
                              professionalAdditionalData!
                                  .latitude!
                                  .isNotEmpty &&
                              professionalAdditionalData
                                  .longitude!
                                  .isNotEmpty)
                            ProfileContactAction(
                              icon: "assets/icons/location.svg",
                              label: 'Map',
                              onTap: () => _launchMaps(
                                double.tryParse(
                                  professionalAdditionalData.latitude!,
                                ),
                                double.tryParse(
                                  professionalAdditionalData.longitude!,
                                ),
                              ),
                            ),
                        ],
                        onShare: () {
                          shareProfile(
                            context: context,
                            email: userDetails.email?.toString(),
                            userId: userDetails.id?.toString(),
                            displayName: userDetails.name?.toString(),
                          );
                        },
                        onQr: () {
                          showProfileQrCodeDialog(
                            userEmail: userDetails.email?.toString(),
                            userId: userDetails.id?.toString(),
                          );
                        },
                        onMore: () {
                          showMoreOptionsProfile(
                            context,
                            userDetails.name,
                            userDetails.email,
                          );
                        },
                      ),

                      if (displayVideoTypes.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 16),
                              width: double.infinity,
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFF8D6),
                                borderRadius: BorderRadius.circular(50.r),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(displayVideoTypes.length, (
                                  index,
                                ) {
                                  bool isSelected = currentTabIndex == index;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        _tabController!.animateTo(index);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? ColorUtils.primaryColor
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            50.r,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            ProfileVideoTypeUtils.displayLabel(
                                              displayVideoTypes[index].name
                                                  ?.toString(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 12.sp,
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
                            SizedBox(height: 8.h),
                          ],
                        ),
                    ],
                  ),
                    ),
                if (displayVideoTypes.isNotEmpty)
                  ..._professionalProfileVideoSlivers(displayVideoTypes, currentTabIndex),
                SliverToBoxAdapter(child: SizedBox(height: 70.h)),
              ],
            );
          }),
        ),
      );
    });
  }

  List<Widget> _professionalProfileVideoSlivers(
    List<VideoTypes> displayVideoTypes,
    int tabIndex,
  ) {
    final selectedVideoType = displayVideoTypes[tabIndex];
    final videos = selectedVideoType.videos;
    if (videos == null || videos.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Image.asset(
                'assets/images/notfound.png',
                fit: BoxFit.cover,
                height: 150.h,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
              final video = videos[videoIndex];
              final isProcessing = isReelGridProcessing(
                isImage: video.isImage,
                videoUrl: video.videoUrl,
                video: video.video,
                thumbnailUrl: video.thumbnailUrl,
                imageUrl: video.imageUrl,
                image: video.image,
                transcodeStatus: video.transcodeStatus,
                processingStatus: video.processingStatus,
                playbackReady: video.playbackReady,
              );
              return GestureDetector(
                onTap: () {
                  if (isProcessing) {
                    _showStillProcessingMessage();
                    return;
                  }
                  unawaited(_openProfileReelFromGrid(
                    video,
                    displayVideoTypes[_tabController!.index],
                  ));
                },
                child: Stack(
                  children: [
                    if (isProcessing)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: const ColoredBox(
                          color: Color(0xFF121212),
                          child: SizedBox.expand(),
                        ),
                      )
                    else
                      ProfileGridThumbnail(
                        coverUrl: MediaUrlResolver.reelPosterUrl(
                          processingStatus: video.processingStatus?.toString(),
                          transcodeStatus: video.transcodeStatus?.toString(),
                          thumbnailUrl: video.thumbnailUrl?.toString(),
                          imageUrl: video.imageUrl?.toString(),
                          image: video.image?.toString(),
                        ),
                        borderRadius: 12.r,
                        logicalSize: 100,
                      ),
                    if (!isProcessing)
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
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black, Colors.transparent],
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
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: video.sponsorType == 2
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFC0C0C0),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (isProcessing)
                      ReelGridProcessingOverlay(borderRadius: 12.r),
                  ],
                ),
              );
            },
            childCount: videos.length,
          ),
        ),
      ),
    ];
  }

  void showMoreOptions(
    BuildContext context,
    String videoId,
    String userId,
    String? videoImage,
    ProfessionalVideos video,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20),
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
                      Navigator.pop(bottomSheetContext);
                      Get.to(() => PromoteVideoView(videos: [video]))?.then((
                        value,
                      ) async {
                        await profileController.getUserDetails();
                      });

                      ;
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.auto_graph_rounded),
                  trailing: Icon(Icons.chevron_right_rounded),
                  title: Text(
                    'view_statistics'.tr,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    showVideoStatsDialog(context, video: videoId);
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
                      value,
                    ) async {
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
                    Navigator.pop(bottomSheetContext);
                    final bool isDeleted = await profileController.deleteVideo(
                      context,
                      videoId,
                      userId,
                    );
                    if (isDeleted) {
                      print("===============");
                      print(isDeleted);
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

  Future<void> _launchPhone(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        debugPrint('Could not launch phone dialer');
      }
    }
  }

  Future<void> _launchEmail(String? email) async {
    if (email != null && email.isNotEmpty) {
      final Uri emailUri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        debugPrint('Could not launch email client');
      }
    }
  }

  Future<void> _launchWebsite(String? website) async {
    if (website != null && website.isNotEmpty) {
      final Uri websiteUri = Uri.parse(
        website.startsWith('http') ? website : 'https://$website',
      );
      if (await canLaunchUrl(websiteUri)) {
        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch website');
      }
    }
  }

  Future<void> _launchMaps(double? latitude, double? longitude) async {
    if (latitude != null && longitude != null) {
      final Uri geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
      final Uri webMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );

      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open location')),
      );
    }
  }

  void _showStillProcessingMessage() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('video_still_processing_message'.tr),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openProfileReelFromGrid(
    ProfessionalVideos tapped,
    VideoTypes activeTab,
  ) async {
    if (_openingProfileReel) {
      return;
    }
    _openingProfileReel = true;
    try {
      silenceHomeForReelRoute();
      if (!mounted) {
        return;
      }
      await _openProfileReel(tapped, activeTab);
    } finally {
      _openingProfileReel = false;
    }
  }

  Future<void> _openProfileReel(
    ProfessionalVideos tapped,
    VideoTypes activeTab,
  ) async {
    final user = profileController.userDetails.value?.user;
    final userId = user?.id?.toString();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final gridVideos = activeTab.videos ?? <ProfessionalVideos>[];
    final seedVideos = gridVideos
        .map(
          (v) => WallVideos.fromProfessionalVideo(
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
      deduped.add(
        VideoTypes(name: 'Others', videos: <ProfessionalVideos>[]),
      );
    }
    return deduped;
  }
}
