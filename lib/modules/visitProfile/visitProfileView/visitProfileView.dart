import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/visitProfile/visitProfileModel/visitProfileModel.dart';
import 'package:cookster/modules/visitProfile/visitProfileController/visitProfileController.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../appRoutes/appRoutes.dart';
import 'package:cookster/core/firestore/reel_video_stats.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/widgets/profile_grid_thumbnail.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../appUtils/openToWork.dart';
import '../../../loaders/pulseLoader.dart';
import '../../popup_like/popup_like_dialog.dart';
import '../../viewReview/viewReviewView/viewReviewView.dart';
import '../../chatScreen/chatScreenView.dart';
import '../../followersFollowing/followersFollowingView/followersFollowingView.dart';
import '../../landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../../landing/landingTabs/professionalProfile/profileWidgets/professsionalProfileWidgets.dart';
import '../../landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/core/video/profile_reel_prefetch.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/modules/visitProfile/profile_reel_screen.dart';
import 'package:cookster/core/media/profile_video_visibility.dart';
import 'package:cookster/core/media/media_url_resolver.dart';

class VisitProfileView extends StatefulWidget {
  final String userId;

  const VisitProfileView({super.key, required this.userId});

  @override
  State<VisitProfileView> createState() => _VisitProfileViewState();
}

class _VisitProfileViewState extends State<VisitProfileView>
    with SingleTickerProviderStateMixin {
  late final VisitProfileController visitProfileController;
  late final HomeController homeController;
  late final ProfileController profileController;
  late final ProfessionalProfileController professionalProfileController;

  TabController? _tabController;
  Worker? _videoTypesWorker;

  // Add an RxInt to track followers count locally

  bool isLocalCountInitialized = false;

  String? userId;

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
  }

  String _language = 'en'; // Default to English

  @override
  void initState() {
    super.initState();
    ensureVisitProfileDependencies();
    visitProfileController = Get.put(VisitProfileController());
    homeController = Get.find<HomeController>();
    profileController = Get.find<ProfileController>();
    professionalProfileController = Get.find<ProfessionalProfileController>();
    homeController.pauseReelsForRouteOverlay();
    _initializeProfile().then((_) => _syncTabController());
    _loadLanguage();
    fetchUserId();
    _videoTypesWorker = ever(visitProfileController.visitProfile, (_) {
      _syncTabController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeController.reinforceReelsPausedForOverlay();
    });
  }

  void _onTabChanged() {
    if (_tabController?.indexIsChanging ?? false) {
      setState(() {});
    }
  }

  void _syncTabController() {
    final videoTypes = visitProfileController.visitProfile.value?.videoTypes;
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
  void dispose() {
    _videoTypesWorker?.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    homeController.resumeReelsAfterRouteOverlay();
    if (Get.isRegistered<VisitProfileController>()) {
      Get.delete<VisitProfileController>(force: true);
    }
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    await visitProfileController.fetchUserProfile(widget.userId);

    // Then initialize like status
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;

    if (userId != null) {
      await visitProfileController.checkProfileLikeStatus(
        widget.userId,
        userId,
      );
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  bool _followerChanged = false; // Track if follow status changed

  void _openProfileReel(Videos tapped, VideoTypes activeTab) {
    final profile = visitProfileController.visitProfile.value;
    final owner = profile?.user;
    if (widget.userId.isEmpty) {
      return;
    }
    warmProfileReelTap(
      videoUrl: tapped.videoUrl,
      video: tapped.video,
      hlsUrl: tapped.hlsUrl,
      hlsPlaylistUrl: tapped.hlsPlaylistUrl,
      transcodeStatus: tapped.transcodeStatus,
      videoSources: tapped.videoSources,
    );
    Get.to(
      () => ProfileReelScreen(
        userId: widget.userId,
        videoTypeId: activeTab.id?.toString(),
        anchorId: tapped.id?.toString(),
        ownerName: owner?.name?.toString(),
        ownerImage: owner?.image?.toString(),
        ownerFollowers: visitProfileController.localFollowersCount.value,
        initialPosterUrl: profileReelPosterFromGrid(
          processingStatus: tapped.processingStatus,
          transcodeStatus: tapped.transcodeStatus,
          thumbnailUrl: tapped.thumbnailUrl,
          imageUrl: tapped.imageUrl,
          image: tapped.image,
        ),
      ),
    );
  }

  List<VideoTypes> _buildDisplayVideoTypes(List<VideoTypes>? sourceTypes) {
    final existing = List<VideoTypes>.from(sourceTypes ?? <VideoTypes>[]);
    for (final type in existing) {
      type.videos = (type.videos ?? <Videos>[])
          .where(
            (video) => ProfileVideoVisibility.shouldListOnProfileGrid(
              status: video.status,
              processingStatus: video.processingStatus,
              transcodeStatus: video.transcodeStatus,
              videoUrl: video.videoUrl,
              video: video.video,
              hlsUrl: video.hlsUrl,
              hlsPlaylistUrl: video.hlsPlaylistUrl,
              thumbnailUrl: video.thumbnailUrl,
              imageUrl: video.imageUrl,
              image: video.image,
              isImage: video.isImage,
              videoSources: video.videoSources,
            ),
          )
          .toList();
    }
    final hasOthers = existing.any(
      (type) => (type.name ?? '').toLowerCase() == 'others',
    );
    if (hasOthers) {
      return existing;
    }
    existing.add(VideoTypes(name: 'Others', videos: <Videos>[]));
    return existing;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigateBack({'followerChanged': _followerChanged});
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            kToolbarHeight + MediaQuery.paddingOf(context).top,
          ),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFFADC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            navigateBack({'followerChanged': _followerChanged});
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6BE00),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: ColorUtils.darkBrown,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Profile".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          color: ColorUtils.darkBrown,
                        ),
                        splashRadius: 20,
                        offset: const Offset(0, 40),
                        color: Colors.white,
                        onSelected: (value) async {
                          if (value == 'block') {
                            bool isAuthenticated = await _isUserAuthenticated();
                            if (!isAuthenticated) {
                              Get.toNamed(AppRoutes.signIn);
                              return;
                            }
                            final user =
                                visitProfileController.visitProfile.value?.user;
                            if (user != null) {
                              ImageProvider imageProvider =
                                  user.image != null && user.image!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                        MediaUrlResolver.profileImageUrl(
                                              user.image!,
                                            ) ??
                                            '',
                                        maxWidth: gridThumbnailMemCacheSize(48),
                                        maxHeight: gridThumbnailMemCacheSize(48),
                                      )
                                      : const AssetImage('assets/images/sd.png')
                                          as ImageProvider;

                              showBlockConfirmationBottomSheet(
                                context: context,
                                name: user.name ?? 'Unknown',
                                image: imageProvider,
                                onBlock: () async {
                                  try {
                                    await homeController.blockUser(
                                      userId,
                                      widget.userId,
                                    );
                                    Get.back(
                                      result: {
                                        'followerChanged': _followerChanged,
                                      },
                                    );
                                  } catch (e) {
                                    Fluttertoast.showToast(
                                      msg: "Failed to block user",
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                    );
                                  }
                                },
                              );
                            } else {
                              Fluttertoast.showToast(
                                msg: "User data not available",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                              );
                            }
                          } else if (value == 'message_label'.tr) {
                            Get.to(
                              ChatView(
                                senderId: userId!,
                                receiverId: widget.userId,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'message_label'.tr,
                            child: Text(
                              'message_label'.tr,
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Text(
                              'block'.tr,
                              style: const TextStyle(color: Colors.red),
                            ),
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

        body: Obx(() {
          var user = visitProfileController.visitProfile.value;
          final userDetails = visitProfileController.visitProfile.value?.user;
          final professionalAdditionalData =
              visitProfileController.visitProfile.value
                  ?.getFirstAdditionalData();
          final videoTypes =
              visitProfileController.visitProfile.value?.videoTypes;
          final displayVideoTypes = _buildDisplayVideoTypes(videoTypes);

          if (userDetails == null) {
            return Center(
              child: PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await visitProfileController.fetchUserProfile(widget.userId);
            },
            child: CustomScrollView(
              cacheExtent: 400,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 16),

                  if (user!.user!.entity == 2)
                    SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            width: Get.width,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(14),
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image:
                                    (userDetails.coverImage != null &&
                                            userDetails.coverImage!.isNotEmpty)
                                        ? CachedNetworkImageProvider(
                                          MediaUrlResolver.profileImageUrl(userDetails.coverImage!) ?? '',
                                        )
                                        : const AssetImage(
                                              'assets/images/placeholder.jpg',
                                            )
                                            as ImageProvider,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Center(
                                child: OpenToWorkBadge(
                                  size: 65.h,
                                  showOpenToWork:
                                      professionalAdditionalData!.isB2B == 0
                                          ? false
                                          : true,

                                  imageUrl:
                                      MediaUrlResolver.profileImageUrl(userDetails.image) ?? '',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (user.user!.entity != 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Center(
                            child: OpenToWorkBadge(
                              size: 70.h,
                              showOpenToWork: false,
                              imageUrl:
                                  MediaUrlResolver.profileImageUrl(userDetails.image) ?? '',
                            ),
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: 8.h),
                  user.user!.entity == 2
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            /// LEFT SIDE → show only if country is not empty
                            if ((userDetails.countryName ?? '').isNotEmpty)
                              Expanded(
                                flex: 2,
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
                              const Spacer(flex: 2), // keeps alignment
                            /// CENTER → always centered
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: Text(
                                  PublicUserIdentity.formatAtHandle(
                                    userDetails.userName?.toString(),
                                  ).isNotEmpty
                                      ? PublicUserIdentity.formatAtHandle(
                                          userDetails.userName?.toString(),
                                        )
                                      : userDetails.name?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ColorUtils.darkBrown,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            /// RIGHT SIDE → show only if city is not empty
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
                              const Spacer(flex: 2), // keeps alignment
                          ],
                        ),
                      )
                      : Text(
                        PublicUserIdentity.formatAtHandle(
                          userDetails.userName?.toString(),
                        ).isNotEmpty
                            ? PublicUserIdentity.formatAtHandle(
                                userDetails.userName?.toString(),
                              )
                            : userDetails.name?.toString() ?? '',
                        style: TextStyle(
                          color: ColorUtils.darkBrown,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                  if (professionalAdditionalData != null &&
                      professionalAdditionalData.businessTypeName != null &&
                      professionalAdditionalData.businessTypeName!.isNotEmpty)
                    Text(
                      "${professionalAdditionalData.businessTypeName}",
                      style: TextStyle(
                        color: ColorUtils.darkBrown,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () {
                          Get.to(
                            SocialListsScreen(
                              initialTab: SocialTab.following,
                              userName: user.user!.name,
                              userId: user.user!.id,
                            ),
                          );
                        },
                        child: ProfileStat(
                          number:
                              "${visitProfileController.localFollowingCount}",
                          label: "Following".tr,
                        ),
                      ),
                      Obx(
                        () => InkWell(
                          onTap: () {
                            Get.to(
                              SocialListsScreen(
                                initialTab: SocialTab.followers,
                                userName: user.user!.name,
                                userId: user.user!.id,
                              ),
                            );
                          },
                          child: ProfileStat(
                            number:
                                "${visitProfileController.localFollowersCount}",
                            label: "Followers".tr,
                          ),
                        ),
                      ),
                      Obx(() {
                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return LikePopup(
                                  username: userDetails.name,
                                  likeCount:
                                      visitProfileController.totalLikes.value,
                                );
                              },
                            );
                          },
                          child: ProfileStat(
                            number:
                                "${visitProfileController.totalLikes.value}",
                            label: "Likes".tr,
                          ),
                        );
                      }),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  if (user.user!.entity == 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 45.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (professionalAdditionalData!.contactPhone !=
                                  null &&
                              professionalAdditionalData
                                  .contactPhone!
                                  .isNotEmpty)
                            IconButtonWidget(
                              icon: "assets/icons/phone.svg",
                              onTap:
                                  () => _launchPhone(
                                    professionalAdditionalData.contactPhone,
                                  ),
                            ),
                          if (professionalAdditionalData.contactEmail != null &&
                              professionalAdditionalData
                                  .contactEmail!
                                  .isNotEmpty)
                            IconButtonWidget(
                              icon: "assets/icons/whatsapp.svg",
                              onTap:
                                  () => _launchWhatsApp(
                                    professionalAdditionalData.contactPhone,
                                  ),
                            ),
                          if (professionalAdditionalData.website != null &&
                              professionalAdditionalData.website!.isNotEmpty)
                            IconButtonWidget(
                              icon: "assets/icons/website.svg",
                              onTap:
                                  () => _launchWebsite(
                                    professionalAdditionalData.website,
                                  ),
                            ),
                          if (professionalAdditionalData.latitude != null &&
                              professionalAdditionalData.longitude != null &&
                              professionalAdditionalData.latitude!.isNotEmpty &&
                              professionalAdditionalData.longitude!.isNotEmpty)
                            IconButtonWidget(
                              icon: "assets/icons/location.svg",
                              onTap:
                                  () => _launchMaps(
                                    double.tryParse(
                                      professionalAdditionalData.latitude!,
                                    ),
                                    double.tryParse(
                                      professionalAdditionalData.longitude!,
                                    ),
                                  ),
                            ),
                        ],
                      ),
                    ),

                  if (widget.userId != userId) SizedBox(height: 16.h),
                  if (widget.userId != userId)
                    Obx(() {
                      var currentUser =
                          professionalProfileController.userDetails.value?.user;
                      bool isProfileNull = currentUser == null;
                      bool isFollowing =
                          isProfileNull
                              ? profileController.isFollowing(widget.userId)
                              : professionalProfileController.isFollowing(
                                widget.userId,
                              );

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                isLoading:
                                    profileController
                                        .isFollowingProcess
                                        .value ||
                                    professionalProfileController
                                        .isFollowingProcess
                                        .value,
                                color:
                                    isFollowing
                                        ? ColorUtils.greyTextFieldBorderColor
                                        : ColorUtils.primaryColor,
                                text:
                                    isFollowing ? "Following".tr : "follow".tr,
                                onTap: () async {
                                  bool isAuthenticated =
                                      await _isUserAuthenticated();
                                  _followerChanged = true;
                                  if (!isAuthenticated) {
                                    Get.toNamed(AppRoutes.signIn);
                                    return;
                                  }
                                  if (isFollowing) {
                                    visitProfileController
                                        .localFollowersCount
                                        .value--;
                                  } else {
                                    visitProfileController
                                        .localFollowersCount
                                        .value++;
                                  }
                                  if (isProfileNull) {
                                    profileController.toggleFollowStatus(
                                      widget.userId,
                                    );
                                  } else {
                                    professionalProfileController
                                        .toggleFollowStatus(widget.userId);
                                  }
                                },
                              ),
                            ),

                            // const SizedBox(width: 8),
                            // InkWell(
                            //   child: ProfileLikeButton(
                            //     profileId: widget.userId,
                            //     currentUserId: userId.toString(),
                            //     controller: visitProfileController,
                            //   ),
                            // ),
                            if (user.user!.entity == 2) ...[
                              const SizedBox(width: 8),

                              InkWell(
                                onTap: () async {
                                  bool isAuthenticated =
                                      await _isUserAuthenticated();
                                  if (isAuthenticated) {
                                    Get.to(
                                      ViewReviews(
                                        professionalId: widget.userId,
                                      ),
                                    );
                                  } else {
                                    Get.toNamed(AppRoutes.signIn);
                                    return;
                                  }
                                  ;
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ColorUtils.primaryColor,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 30,
                                      color: ColorUtils.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  SizedBox(height: 16.h),

                  if (displayVideoTypes.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8D6),
                            borderRadius: BorderRadius.circular(50.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(displayVideoTypes.length, (index) {
                              bool isSelected = _tabController!.index == index;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    _tabController!.animateTo(index);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? ColorUtils.primaryColor
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(50.r),
                                    ),
                                    child: Center(
                                      child: Text(
                                        ((displayVideoTypes[index].name ??
                                                            "Unknown")
                                                        .toString()
                                                        .toLowerCase() ==
                                                    'others'
                                                ? 'Others'.tr
                                                : (displayVideoTypes[index].name ??
                                                    "Unknown")
                                                    .toString()),
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
                        SizedBox(height: 16.h),
                      ],
                    ),

                  SizedBox(height: 16.h),
                ],
              ),
                ),
                if (displayVideoTypes.isNotEmpty)
                  ..._visitProfileVideoSlivers(displayVideoTypes),
                SliverToBoxAdapter(child: SizedBox(height: 40.h)),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _visitProfileVideoSlivers(List<VideoTypes> displayVideoTypes) {
    if (_tabController == null) {
      return const [];
    }
    final selectedVideoType = displayVideoTypes[_tabController!.index];
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
              return GestureDetector(
                onTap: () => _openProfileReel(
                  video,
                  displayVideoTypes[_tabController!.index],
                ),
                child: Stack(
                  children: [
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
                    Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white.withOpacity(0.7),
                        size: 30.sp,
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
                          SizedBox(width: 4),
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

  Future<void> _launchWhatsApp(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      String cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (!cleanedPhone.startsWith('+')) {
        cleanedPhone = '+$cleanedPhone';
      }
      final Uri whatsAppUri = Uri.parse('https://wa.me/$cleanedPhone');
      if (await canLaunchUrl(whatsAppUri)) {
        await launchUrl(whatsAppUri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(
          msg: "Could not launch WhatsApp",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        debugPrint('Could not launch WhatsApp');
      }
    } else {
      Fluttertoast.showToast(
        msg: "No WhatsApp number available",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
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
}

void showBlockConfirmationBottomSheet({
  required BuildContext context,
  required String name,
  required ImageProvider image,
  required VoidCallback onBlock,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder:
        (context) => SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            constraints: BoxConstraints(
              maxWidth: 500,
              minHeight: 200,
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: image,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${"block".tr} $name?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "block_user_description".tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AnimatedScaleButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    onBlock();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.redAccent, Colors.redAccent.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'block'.tr,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedScaleButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'cancel'.tr,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({
    Key? key,
    required this.onPressed,
    required this.child,
  }) : super(key: key);

  @override
  _AnimatedScaleButtonState createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
