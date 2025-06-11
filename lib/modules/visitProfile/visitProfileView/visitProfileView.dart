import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/visitProfile/visitProfileController/visitProfileController.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../loaders/pulseLoader.dart';
import '../../landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../../landing/landingTabs/professionalProfile/profileWidgets/professsionalProfileWidgets.dart';
import '../../landing/landingTabs/profile/profileControlller/profileController.dart';
import '../../singleVideoView/singleVideoView.dart';

class VisitProfileView extends StatefulWidget {
  final String userId;

  const VisitProfileView({super.key, required this.userId});

  @override
  State<VisitProfileView> createState() => _VisitProfileViewState();
}

class _VisitProfileViewState extends State<VisitProfileView>
    with SingleTickerProviderStateMixin {
  final VisitProfileController visitProfileController = Get.put(
    VisitProfileController(),
  );
  final HomeController homeController = Get.find();

  TabController? _tabController;
  int _currentTabIndex = 0;

  // Add an RxInt to track followers count locally
  RxInt localFollowersCount = 0.obs;
  bool isLocalCountInitialized = false;

  @override
  void initState() {
    super.initState();
    visitProfileController.fetchUserProfile(widget.userId);
    // Tab controller will be initialized after data is loaded
  }

  final ProfileController profileController = Get.find();
  final ProfessionalProfileController professionalProfileController =
      Get.find();

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var currentUserDetails = profileController.simpleUserDetails.value?.user;

    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id!;
    if (userId == null) {
      userId = currentUserDetails?.id!;
    }

    visitProfileController.checkProfileLikeStatus(
      widget.userId.toString(),
      userId.toString(),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Profile".tr,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            offset: Offset(0, 50),
            color: Colors.white,
            onSelected: (value) async {
              if (value == 'block') {
                final user = visitProfileController.visitProfile.value?.user;
                if (user != null) {
                  // Prepare the image provider
                  ImageProvider imageProvider =
                      user.image != null && user.image!.isNotEmpty
                          ? CachedNetworkImageProvider(
                            '${Common.profileImage}/${user.image!}',
                          )
                          : AssetImage('assets/images/sd.png') as ImageProvider;

                  // Show the block confirmation dialog
                  showBlockConfirmationBottomSheet(
                    context: context,
                    name: user.name ?? 'Unknown', // Provide the user's name
                    image: imageProvider, // Provide the image provider
                    onBlock: () async {
                      // Implement the block action here
                      try {
                        // Example: Call a method in visitProfileController to block the user
                        await homeController.blockUser(widget.userId);

                        // Optionally navigate back or update UI
                        Get.back();
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
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text(
                      'block'.tr,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
          ),
        ],
      ),

      body: Obx(() {
        final user = visitProfileController.visitProfile.value;
        final userDetails = visitProfileController.visitProfile.value?.user;
        // Use getFirstAdditionalData to safely access additionalData
        final professionalAdditionalData =
            visitProfileController.visitProfile.value?.getFirstAdditionalData();
        final videoTypes =
            visitProfileController.visitProfile.value?.videoTypes;

        if (userDetails == null) {
          return Center(
            child: PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
          );
        }

        // Initialize the local followers count when data is first loaded
        if (!isLocalCountInitialized && user != null) {
          localFollowersCount.value = user.followers!;
          isLocalCountInitialized = true;
        }

        // Initialize TabController when data is loaded
        if (_tabController == null &&
            videoTypes != null &&
            videoTypes.isNotEmpty) {
          _tabController = TabController(
            length: videoTypes.length,
            vsync: this,
          );

          _tabController!.addListener(() {
            if (_tabController!.indexIsChanging) {
              setState(() {
                _currentTabIndex = _tabController!.index;
              });
            }
          });
        }

        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SizedBox(height: 16.h),
              if (userDetails.coverImage != null &&
                  userDetails.coverImage!.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
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
                                      '${Common.profileImage}/${userDetails.coverImage!}',
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
                        right: 0, // Add this to ensure horizontal centering
                        child: Center(
                          // Wrap the Container in a Center widget for horizontal alignment
                          child: Container(
                            height: 60.h,
                            width: 60.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child:
                                  userDetails.image == null
                                      ? Image.asset(
                                        "assets/images/sd.png",
                                        fit: BoxFit.cover,
                                      )
                                      : CachedNetworkImage(
                                        imageUrl:
                                            '${Common.profileImage}/${userDetails.image!}',
                                        fit: BoxFit.cover,
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (userDetails.coverImage == null)
                // Profile Image
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
                            child:
                                userDetails.image == null
                                    ? Image.asset(
                                      "assets/images/sd.png",
                                      fit: BoxFit.cover,
                                    )
                                    : CachedNetworkImage(
                                      imageUrl:
                                          '${Common.profileImage}/${userDetails.image!}',
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget:
                                          (context, url, error) =>
                                              Icon(Icons.person),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              SizedBox(height: 8.h),
              // Username
              Text(
                "@${userDetails.name}",
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
              // Stats Row - Now using localFollowersCount for followers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ProfileStat(
                    number: "${user!.following}",
                    label: "Following".tr,
                  ),
                  // Use local followers count to show immediate updates
                  Obx(
                    () => ProfileStat(
                      number: "${localFollowersCount.value}",
                      label: "Followers".tr,
                    ),
                  ),
                  ProfileStat(
                    number: "${visitProfileController.profileLikesCount.value}",
                    label: "Likes".tr,
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Only show contact icons if professionalAdditionalData exists
              if (professionalAdditionalData != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 45.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (professionalAdditionalData.contactPhone != null &&
                          professionalAdditionalData.contactPhone!.isNotEmpty)
                        IconButtonWidget(
                          icon: "assets/icons/phone.svg",
                          onTap:
                              () => _launchPhone(
                                professionalAdditionalData.contactPhone,
                              ),
                        ),
                      if (professionalAdditionalData.contactEmail != null &&
                          professionalAdditionalData.contactEmail!.isNotEmpty)
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
                // Custom Buttons
                Obx(() {
                  var currentUserDetails =
                      profileController.simpleUserDetails.value?.user;

                  var currentUser =
                      professionalProfileController.userDetails.value?.user;
                  bool isProfileNull = currentUser == null;

                  // Fixed: Using widget.userId consistently
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
                                profileController.isFollowingProcess.value ||
                                professionalProfileController
                                    .isFollowingProcess
                                    .value,
                            color:
                                isFollowing
                                    ? ColorUtils.greyTextFieldBorderColor
                                    : ColorUtils.primaryColor,
                            text: isFollowing ? "Following".tr : "follow".tr,
                            onTap: () {
                              // Update local followers count immediately when button is pressed
                              if (isFollowing) {
                                // Unfollow action - decrement followers count
                                localFollowersCount.value--;
                              } else {
                                // Follow action - increment followers count
                                localFollowersCount.value++;
                              }

                              print(widget.userId);

                              // Then perform the actual follow/unfollow action
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
                        SizedBox(width: 8),
                        ProfileLikeButton(
                          profileId: widget.userId,
                          currentUserId: userId.toString(),
                          controller: visitProfileController,
                        ),
                      ],
                    ),
                  );
                }),
              SizedBox(height: 16.h),

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
                        color: Color(0xFFFFF8D6), // Light Yellow Background
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(videoTypes.length, (index) {
                          bool isSelected = _tabController!.index == index;
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
                                borderRadius: BorderRadius.circular(50.r),
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

                    // Video List based on selected tab
                    if (videoTypes.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8, // Horizontal spacing between items
                          runSpacing: 8, // Vertical spacing between rows
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
                                    width: 100.w,
                                    height: 133.h,
                                  ),
                                ),
                              ];
                            }

                            return selectedVideoType.videos!.map((video) {
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
                                        videoUrl: video.video,
                                        title: video.title,
                                        image: video.image,
                                        allowComments: video.allowComments,
                                        description: video.description,
                                        tags: video.tags,
                                        userName: video.userName,
                                        createdAt: video.createdAt,
                                        isImage: video.isImage.toString(),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          image: DecorationImage(
                                            image:
                                                video.image != null &&
                                                        video.image!.isNotEmpty
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
                                            SizedBox(width: 4),
                                            StreamBuilder<DocumentSnapshot>(
                                              stream:
                                                  FirebaseFirestore.instance
                                                      .collection('videos')
                                                      .doc(video.id)
                                                      .snapshots(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return Text(
                                                    "...",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                }
                                                if (!snapshot.hasData ||
                                                    !snapshot.data!.exists) {
                                                  return Text(
                                                    "0",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                }
                                                final data =
                                                    snapshot.data!.data()
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
                                                String formattedLikeCount =
                                                    likeCount > 1000
                                                        ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                                                        : likeCount.toString();

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

              SizedBox(height: 24.h),
            ],
          ),
        );
      }),
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

  Future<void> _launchWhatsApp(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      // Remove any non-digit characters from the phone number
      String cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      // Ensure the phone number starts with '+' for international format
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
      final Uri mapsUri = Uri.parse('geo:$latitude,$longitude');
      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch maps');
      }
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
    // Allows dynamic height
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder:
        (context) => SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            constraints: BoxConstraints(
              maxWidth: 500, // Limits width on larger screens
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Avatar with subtle shadow
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
                // Title with dynamic font scaling
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
                // Description with better readability
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
                // Block Button with animation and haptic feedback
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
                // Cancel Button with subtle animation
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

// Custom widget for animated button scaling
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
