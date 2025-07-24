import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../followersFollowing/followersFollowingView/followersFollowingView.dart';
import '../../../../promoteVideo/promoteVideoView/promoteVideoView.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import '../../add/editVideo/editVideoView.dart';
import '../../packagePopupDialog/packagePopupDialog.dart';
import '../../savedVideosScreen/savedVideosView/savedVideosView.dart';
import '../profileModel/simpleUserProfileModel.dart';
import '../profileWidgets/profileWidgets.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  final ProfileController profileController = Get.find();

  int? entity;

  TabController? _tabController;
  int _currentTabIndex = 0;

  Future<void> _loadEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      entity = prefs.getInt('entity'); // Entity ki value set kar rahe hain
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadEntity();
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
    return Obx(() {
      final userDetails = profileController.simpleUserDetails.value?.user;
      // : profileController.userDetails.value?.user;

      final videoTypes = profileController.simpleUserDetails.value?.videoTypes;

      if (_tabController == null &&
          videoTypes != null &&
          videoTypes.isNotEmpty) {
        _tabController = TabController(length: videoTypes.length, vsync: this);

        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) {
            setState(() {
              _currentTabIndex = _tabController!.index;
            });
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
            automaticallyImplyLeading: false,
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

          body: Obx(
            () =>
                profileController.isLoading.value
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
                        spacing: 16.h,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 16.h),
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
                                      border: Border.all(
                                        color: ColorUtils.primaryColor,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child:
                                          userDetails!.image == null
                                              ? Image.asset(
                                                "assets/images/sd.png",
                                                fit: BoxFit.cover,
                                              )
                                              : CachedNetworkImage(
                                                imageUrl:
                                                    '${Common.profileImage}/${userDetails.image!}',
                                                fit:
                                                    BoxFit
                                                        .cover, // Network image ko bhi adjust karne ke liye
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            "@${userDetails.name}",
                            style: TextStyle(
                              color: ColorUtils.darkBrown,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
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

                                StreamBuilder<int>(
                                  stream: profileController.checkReceivedLikes(
                                    userDetails.id,
                                  ),
                                  builder: (
                                    context,
                                    AsyncSnapshot<int> snapshot,
                                  ) {
                                    if (snapshot.hasError) {
                                      return ProfileStat(
                                        number: "Error",
                                        label: "Likes".tr,
                                      );
                                    }
                                    return ProfileStat(
                                      number: "${snapshot.data ?? 0}",
                                      label: "Likes".tr,
                                    );
                                  },
                                ),
                              ],
                            );
                          }),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40.0,
                            ),
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
                                SizedBox(width: 16),
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
                                // Custom Tab Bar
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 16),
                                  width: double.infinity,
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      0xFFFFF8D6,
                                    ), // Light Yellow Background
                                    borderRadius: BorderRadius.circular(50.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(videoTypes.length, (
                                      index,
                                    ) {
                                      bool isSelected =
                                          _tabController!.index == index;
                                      return GestureDetector(
                                        onTap: () {
                                          _tabController!.animateTo(index);
                                          setState(
                                            () {},
                                          ); // Trigger rebuild to update video list
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
                                              videoTypes[index].name ??
                                                  "Unknown",
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

                                // Video List based on selected tab
                                if (videoTypes.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Wrap(
                                      spacing:
                                          8, // Horizontal spacing between items
                                      runSpacing:
                                          8, // Vertical spacing between rows
                                      children: () {
                                        final selectedVideoType =
                                            videoTypes[_tabController!.index];
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
                                                    frondUserId:
                                                        video.frontUserId,
                                                    userImage: video.userImage,
                                                    videoId: video.id,
                                                    videoUrl: video.video,
                                                    title: video.title,
                                                    image: video.image,
                                                    allowComments:
                                                        video.allowComments,
                                                    description:
                                                        video.description,
                                                    tags: video.tags,
                                                    userName: video.userName,

                                                    createdAt: video.createdAt,
                                                    isImage:
                                                        video.isImage
                                                            .toString(),
                                                  ),
                                                );
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
                                                            video.image !=
                                                                        null &&
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
                                                          end:
                                                              Alignment
                                                                  .topCenter,
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
                                                          CupertinoIcons
                                                              .heart_fill,
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
                                                                      Colors
                                                                          .white,
                                                                ),
                                                              );
                                                            }
                                                            if (!snapshot
                                                                    .hasData ||
                                                                !snapshot
                                                                    .data!
                                                                    .exists) {
                                                              return Text(
                                                                "0",
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
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
                                                            List<dynamic>
                                                            likes =
                                                                data['likes'] ??
                                                                [];
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
                                                                color:
                                                                    Colors
                                                                        .white,
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
                                                          shape:
                                                              BoxShape.circle,
                                                          // Circular shape
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                    0.2,
                                                                  ),
                                                              // Subtle shadow for depth
                                                              blurRadius: 4,
                                                              offset: Offset(
                                                                0,
                                                                2,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Icon(
                                                          Icons.more_vert,
                                                          color:
                                                              Colors
                                                                  .white, // Keep white color for icon
                                                        ),
                                                      ),
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
                                                          margin:
                                                              EdgeInsets.only(
                                                                left: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
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
                    ),
          ),
        ),
      );
    });
  }

  void showMoreOptions(
    BuildContext context,
    String videoId,
    String userId,
    String videoImage,
    UserVideos video,
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

                if (video.sponsorType == null)
                  ListTile(
                    leading: Icon(Icons.campaign_rounded),
                    trailing: Icon(Icons.chevron_right_rounded),
                    title: Text(
                      'promote_video'.tr,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    onTap: () async {
                      // Close the bottom sheet first
                      Navigator.pop(bottomSheetContext);
                      // Pass the single video as a List<Videos>
                      Get.to(
                        () => PromoteVideoView(
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
