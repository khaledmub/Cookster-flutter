import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
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
import '../../../../singleVideoView/singleVideoView.dart';
import '../../add/editVideo/editVideoView.dart';
import '../../packagePopupDialog/packagePopupDialog.dart';
import '../../packagePopupDialog/statisticsPopup.dart';
import '../../profile/profileModel/profileModel.dart';
import '../../savedVideosScreen/savedVideosView/savedVideosView.dart';
import '../editProfile/editProfileView/professionalEditProfileView.dart';
import '../editProfile/editProfileView/subscribedPackage.dart';
import '../profileControlller/professionalProfileController.dart';
import '../profileWidgets/professsionalProfileWidgets.dart';

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

  Future<void> _loadEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      entity = prefs.getInt('entity');
    });
  }

  File? _selectedImage;
  bool _isEditMode = true;

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
    _loadEntity();
    _loadLanguage();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark, // White icons ke liye
        statusBarColor:
            Colors.transparent, // Optional: Status bar background color
      ),
    );
    bool isRtl = _language == 'ar';

    return Obx(() {
      final userDetails = profileController.userDetails.value?.user;
      final videoTypes = profileController.userDetails.value?.videoTypes;
      final subscribed = profileController.userDetails.value?.subscription;
      // if (userDetails?.id != null) {
      //   profileController.checkReceivedLikes(userDetails!.id.toString());
      // } else {
      //   print("Skipping checkReceivedLikes: userDetails or ID is null");
      // }
      final professionalAdditionalData =
          profileController.userDetails.value?.additionalData;

      profileController.isB2B.value =
          profileController.userDetails.value?.additionalData?.isB2B == 0
              ? false
              : true;

      // Initialize TabController only once
      if (_tabController == null &&
          videoTypes != null &&
          videoTypes.isNotEmpty) {
        _tabController = TabController(length: videoTypes.length, vsync: this);
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging) {
            currentTabIndex = _tabController!.index;
          }
        });
      }

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
                        Get.to(() => EditProfessionalProfileView());
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
                : SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    spacing: 16,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              width: Get.width,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image:
                                      _selectedImage != null
                                          ? FileImage(_selectedImage!)
                                          : (userDetails!.coverImage != null &&
                                              userDetails
                                                  .coverImage!
                                                  .isNotEmpty)
                                          ? CachedNetworkImageProvider(
                                            '${Common.profileImage}/${userDetails.coverImage!}',
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
                                        profileController.updateCoverImage(
                                          coverImage: _selectedImage!,
                                          context: context,
                                        );
                                        _isEditMode = true;
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
                                    showOpenToWork:
                                        profileController.isB2B.value,

                                    imageUrl:
                                        '${Common.profileImage}/${userDetails!.image}',
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
                            if ((userDetails!.countryName ?? '').isNotEmpty)
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
                                child: Text(
                                  "@${userDetails.name}",
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 45.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (professionalAdditionalData?.contactPhone !=
                                    null &&
                                professionalAdditionalData!
                                    .contactPhone!
                                    .isNotEmpty)
                              IconButtonWidget(
                                icon: "assets/icons/phone.svg",
                                onTap:
                                    () => _launchPhone(
                                      professionalAdditionalData.contactPhone,
                                    ),
                              ),
                            if (professionalAdditionalData?.contactEmail !=
                                    null &&
                                professionalAdditionalData!
                                    .contactEmail!
                                    .isNotEmpty)
                              IconButtonWidget(
                                icon: "assets/icons/email.svg",
                                onTap:
                                    () => _launchEmail(
                                      professionalAdditionalData.contactEmail,
                                    ),
                              ),
                            if (professionalAdditionalData?.website != null &&
                                professionalAdditionalData!.website!.isNotEmpty)
                              IconButtonWidget(
                                icon: "assets/icons/website.svg",
                                onTap:
                                    () => _launchWebsite(
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Get.to(SavedVideosView());
                                },
                                child: CustomButtonWidget(
                                  icon: "assets/icons/bookmark.svg",
                                  label: "Saved Reels".tr,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Get.to(
                                    LikedVideosScreen(userId: userDetails.id),
                                  );
                                },
                                child: CustomButtonWidget(
                                  icon: "assets/icons/heart.svg",
                                  label: "liked_videos".tr,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),

                            InkWell(
                              onTap: () {
                                showMoreOptionsProfile(
                                  context,
                                  userDetails.name,
                                  userDetails.email,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.darkBrown,
                                  ),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    color: ColorUtils.darkBrown,
                                    "assets/icons/chevron-down.svg",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (videoTypes != null && videoTypes.isNotEmpty)
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
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(videoTypes.length, (
                                  index,
                                ) {
                                  bool isSelected = currentTabIndex == index;
                                  return GestureDetector(
                                    onTap: () {
                                      _tabController!.animateTo(index);
                                      setState(() {
                                        currentTabIndex = index;
                                      });
                                    },
                                    child: Container(
                                      width: Get.width * 0.25,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
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
                                          videoTypes[index].name ?? "Unknown",
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            if (videoTypes.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: () {
                                    final selectedVideoType =
                                        videoTypes[currentTabIndex];
                                    if (selectedVideoType.videos == null ||
                                        selectedVideoType.videos!.isEmpty) {
                                      return [
                                        Center(
                                          child: Image.asset(
                                            "assets/images/notfound.png",
                                            fit: BoxFit.cover,
                                            // width: 100.w,
                                            height: 150.h,
                                          ),
                                        ),
                                      ];
                                    }

                                    return selectedVideoType.videos!.map((
                                      video,
                                    ) {
                                      return SizedBox(
                                        width: 100.w,
                                        height: 133.h,
                                        child: GestureDetector(
                                          onTap: () {
                                            Get.to(
                                              SingleVideoScreen(
                                                followers:
                                                    '${profileController.followersList.length}',
                                                frondUserId: video.frontUserId,
                                                userImage: video.userImage,
                                                videoId: video.id,
                                                videoUrl: video.videoUrl?.toString().isNotEmpty == true
                                                    ? video.videoUrl
                                                    : video.video,
                                                title: video.title,
                                                image: video.image,
                                                allowComments:
                                                    video.allowComments,
                                                description: video.description,
                                                tags: video.tags,
                                                userName: video.userName,
                                                createdAt: video.createdAt,
                                                isImage:
                                                    video.isImage.toString(),
                                                userEmail: video.userEmail,
                                              ),
                                            )!.then((_) {
                                              profileController
                                                  .getUserDetails();
                                            });
                                          },
                                          child: Stack(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  image: DecorationImage(
                                                    image:
                                                        video.image != null &&
                                                                video
                                                                    .image!
                                                                    .isNotEmpty
                                                            ? CachedNetworkImageProvider(
                                                                  '${Common.videoUrl}/${video.image}',
                                                                )
                                                                as ImageProvider
                                                            : AssetImage(
                                                              "assets/images/food1.jpg",
                                                            ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: Icon(
                                                  Icons.play_circle_outline,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
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
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                          bottom:
                                                              Radius.circular(
                                                                12.r,
                                                              ),
                                                        ),
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment
                                                              .bottomCenter,
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
                                                    SizedBox(width: 4),
                                                    StreamBuilder<
                                                      DocumentSnapshot
                                                    >(
                                                      stream:
                                                          FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'videos',
                                                              )
                                                              .doc(video.id)
                                                              .snapshots(),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return Text(
                                                            "...",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          );
                                                        }
                                                        if (!snapshot.hasData ||
                                                            !snapshot
                                                                .data!
                                                                .exists) {
                                                          return Text(
                                                            "0",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          );
                                                        }
                                                        final data =
                                                            snapshot.data!
                                                                    .data()
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >? ??
                                                            {};
                                                        List<dynamic> likes =
                                                            data['likes'] ?? [];
                                                        int likeCount =
                                                            likes
                                                                .length; // Count likes from array length
                                                        String
                                                        formattedLikeCount =
                                                            likeCount > 1000
                                                                ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                                                                : likeCount
                                                                    .toString();

                                                        return Text(
                                                          formattedLikeCount,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10.sp,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Positioned(
                                                top: 8.h,
                                                // Adjusted for better spacing, using flutter_screenutil for responsiveness
                                                right: 8.w,
                                                // Adjusted for better spacing
                                                child: InkWell(
                                                  onTap: () {
                                                    showMoreOptions(
                                                      context,
                                                      video.id,
                                                      video.frontUserId,
                                                      video.image,
                                                      video,
                                                    );
                                                  },
                                                  splashColor: Colors.grey
                                                      .withOpacity(0.3),
                                                  // Add subtle splash effect for feedback
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10.r,
                                                      ),
                                                  // Rounded touch area
                                                  child: Container(
                                                    // padding: EdgeInsets.all(6.w), // Larger touch area
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                      // Semi-transparent dark background for contrast
                                                      shape: BoxShape.circle,
                                                      // Circular shape
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          // Subtle shadow for depth
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.more_vert,
                                                      color:
                                                          Colors
                                                              .white, // Keep white color for icon
                                                      // size: 20.sp, // Slightly larger icon for visibility, responsive size
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
                                                    SizedBox(width: 4),
                                                    StreamBuilder<
                                                      DocumentSnapshot
                                                    >(
                                                      stream:
                                                          FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'videos',
                                                              )
                                                              .doc(video.id)
                                                              .snapshots(),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return Text(
                                                            "...",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          );
                                                        }
                                                        if (!snapshot.hasData ||
                                                            !snapshot
                                                                .data!
                                                                .exists) {
                                                          return Text(
                                                            "0",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          );
                                                        }
                                                        final data =
                                                            snapshot.data!
                                                                    .data()
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >? ??
                                                            {};
                                                        List<dynamic> views =
                                                            data['views'] ?? [];
                                                        int viewCount =
                                                            views
                                                                .length; // Count views from array length
                                                        String
                                                        formattedViewCount =
                                                            viewCount > 1000
                                                                ? '${(viewCount / 1000).toStringAsFixed(1)}K'
                                                                : viewCount
                                                                    .toString();

                                                        return Text(
                                                          formattedViewCount,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10.sp,
                                                          ),
                                                        );
                                                      },
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
                                                      showPackageDialog(
                                                        context,
                                                        videos: [video],
                                                      );
                                                    },
                                                    child: Container(
                                                      margin: EdgeInsets.only(
                                                        left: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color:
                                                            video.sponsorType ==
                                                                    2
                                                                ? Color(
                                                                  0xFFFFD700,
                                                                ) // Golden for Premium
                                                                : Color(
                                                                  0xFFC0C0C0,
                                                                ), // Silver for Basic
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
                                        ),
                                      );
                                    }).toList();
                                  }(),
                                ),
                              ),
                          ],
                        ),
                      SizedBox(height: 70.h),
                    ],
                  ),
                );
          }),
        ),
      );
    });
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
                if (video.sponsorType == null)
                  ListTile(
                    leading: Icon(Icons.campaign_rounded),
                    trailing: Icon(Icons.chevron_right_rounded),
                    title: Text(
                      'promote_video'.tr,
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
      final Uri mapsUri = Uri.parse('geo:$latitude,$longitude');
      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch maps');
      }
    }
  }
}
