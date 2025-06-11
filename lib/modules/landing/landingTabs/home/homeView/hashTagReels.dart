import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/commentScreen.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/profileModel.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/simpleUserProfileModel.dart';
import 'package:cookster/modules/landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import 'package:cookster/modules/search/searchView/searchView.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swiper_plus/flutter_swiper_plus.dart';
import 'package:get/get.dart';
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../auth/signUp/signUpController/cityController.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import '../../add/videoAddController/videoAddController.dart';
import '../homeController/addCommentControllr.dart';
import '../homeController/hashTagController.dart';
import '../homeController/saveController.dart';
import '../homeWidgets/contactNowDialog.dart';
import '../homeWidgets/reviewSheet.dart';

class HashTagReels extends StatefulWidget {
  final String tag; // Required tag parameter

  const HashTagReels({key, required this.tag}) : super(key: key);

  @override
  _HashTagReelsState createState() => _HashTagReelsState();
}

class _HashTagReelsState extends State<HashTagReels>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final HashtagController controller = Get.put(HashtagController());
  final VideoCommentsController videoCommentsController = Get.put(
    VideoCommentsController(),
  );
  final ProfileController profileController = Get.find();
  final ProfessionalProfileController professionalProfileController =
      Get.find();

  final SaveController saveController = Get.find();

  @override
  bool get wantKeepAlive => true;

  late SwiperController _swiperController;
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    controller.fetchVideos(tag: widget.tag);
    WakelockPlus.enable();
    _swiperController = SwiperController();
    _restoreSwiperPosition();
  }

  void _restoreSwiperPosition() {
    // Set Swiper to the last viewed index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          controller.currentIndex.value >= 0 &&
          controller.currentIndex.value < controller.chewieControllers.length) {
        _swiperController.move(controller.currentIndex.value, animation: false);
      }
    });
  }

  @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   switch (state) {
  //     case AppLifecycleState.paused:
  //     case AppLifecycleState.inactive:
  //       controller.isAppInBackground.value = true;
  //       controller.pauseCurrentVideo();
  //       WakelockPlus.disable();
  //       break;
  //     case AppLifecycleState.resumed:
  //       controller.isAppInBackground.value = false;
  //       _restoreSwiperPosition(); // Restore Swiper position on resume
  //       controller.restoreVideoState(); // Restore video state
  //       if (mounted) setState(() {});
  //       WakelockPlus.enable();
  //       break;
  //     default:
  //       break;
  //   }
  // }
  void _togglePlayPause() {
    controller.togglePlayPause();
    setState(() {
      _showIcon = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showIcon = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swiperController.dispose();
    WakelockPlus.disable();
    // Do not dispose controllers here to preserve state
    super.dispose();
  }

  void _handleScreenExit() {
    controller.handleNavigation(); // Save state and pause
  }

  @override
  void deactivate() {
    // Save the current video's position and pause it
    if (controller.currentIndex.value >= 0 &&
        controller.currentIndex.value < controller.chewieControllers.length) {
      final currentChewieController =
          controller.chewieControllers[controller.currentIndex.value];
      if (currentChewieController != null &&
          currentChewieController.videoPlayerController.value.isInitialized) {
        // Save the current position
        controller.lastVideoPosition.value =
            currentChewieController.videoPlayerController.value.position;
        // Pause the video
        currentChewieController.videoPlayerController.pause();
      }
    }
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('didChangeDependencies called');

    // Step 1: Check if currentIndex is within valid range
    int index = controller.currentIndex.value;
    print('Current index: $index');
    if (index >= 0 && index < controller.chewieControllers.length) {
      print('Valid currentIndex. Proceeding to get ChewieController...');

      // Step 2: Get current ChewieController
      final currentChewieController = controller.chewieControllers[index];
      print('Got currentChewieController: $currentChewieController');

      // Step 3: Check if controller is not null and video is initialized
      if (currentChewieController != null) {
        bool isInitialized =
            currentChewieController.videoPlayerController.value.isInitialized;
        print('Video is initialized: $isInitialized');
        print('Last saved video position: ${controller.lastVideoPosition}');

        if (isInitialized) {
          print('Controller is valid and has a saved video position');

          if (!controller.isAppInBackground.value) {
            print('App is in foreground. Resuming video playback...');
            currentChewieController.videoPlayerController.play();
          } else {
            print('App is in background. Not playing video.');
          }
        } else {
          print('Video not initialized.');
        }
      } else {
        print('ChewieController is null.');
      }
    } else {
      print('Invalid currentIndex. Skipping video restoration.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;

    return WillPopScope(
      onWillPop: () async {
        _handleScreenExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0, elevation: 0),
        body: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: PulseLogoLoader(
                logoPath: "assets/images/appIcon.png",
                size: 80,
              ),
            );
          }

          if (controller.videoFeed.value.videos == null ||
              controller.videoFeed.value.videos!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textAlign: TextAlign.center,
                      "No videos available for ${controller.currentCity.value} Try to change the Location or Search for something else",
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: "Change Location",
                            onTap: () {
                              _showBottomSheet(context);
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            // controller.pauseCurrentVideo();
                            // _handleScreenExit();
                            Get.to(() => SearchView())?.then((_) {
                              controller.restoreVideoState();
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              // Transparent to show blur
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10.0,
                                  sigmaY: 10.0,
                                ), // Blur effect
                                child: Container(
                                  padding: EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.primaryColor,
                                    // Blue tint
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.black,
                                    size: 24.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              Swiper(
                physics: ScrollPhysics(),

                duration: 0,
                loop: false,
                controller: _swiperController,
                itemCount: controller.chewieControllers.length,
                scrollDirection: Axis.vertical,
                onIndexChanged: (index) {
                  controller.handlePageChange(index);
                  if (mounted) setState(() {});
                },
                itemBuilder: (context, index) {
                  var videoDetail = controller.videoFeed.value.videos![index];
                  var chewieController = controller.chewieControllers[index];

                  bool isInitialized =
                      chewieController != null &&
                      chewieController
                          .videoPlayerController
                          .value
                          .isInitialized;

                  return Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          onDoubleTap: controller.toggleMute,
                          child: Stack(
                            children: [
                              Center(
                                child:
                                    isInitialized
                                        ? Chewie(controller: chewieController)
                                        : Container(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Container(color: Colors.black),
                                              // CachedNetworkImage(
                                              //   fit: BoxFit.cover,
                                              //   width: double.infinity,
                                              //   height: double.infinity,
                                              //   imageUrl:
                                              //       '${Common.videoUrl}/${videoDetail.image}',
                                              //   placeholder:
                                              //       (context, url) => Container(
                                              //         color: Colors.black,
                                              //       ),
                                              // ),
                                              Center(
                                                child: PulseLogoLoader(
                                                  logoPath:
                                                      "assets/images/appIcon.png",
                                                  size: 80,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                              ),
                              if (_showIcon &&
                                  isInitialized &&
                                  index == controller.currentIndex.value)
                                Center(
                                  child: Icon(
                                    chewieController.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 64.0,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Obx(
                        () =>
                            controller.isMuted.value
                                ? Positioned(
                                  top: 100,
                                  right: 20,
                                  child: InkWell(
                                    onTap: controller.toggleMute,
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.volume_off,
                                        color: Colors.white,
                                        size: 24.sp,
                                      ),
                                    ),
                                  ),
                                )
                                : SizedBox(),
                      ),
                      VideoDescriptionWidget(
                        title: videoDetail.title,
                        description: videoDetail.description,
                        tags: videoDetail.tags,
                      ),

                      videoUserDetails(
                        profileController: profileController,
                        professionalProfileController:
                            professionalProfileController,
                        videoDetail: videoDetail,
                        controller: controller,
                        userId: userId,
                      ),

                      if (videoDetail.takeOrder == 1 &&
                          (videoDetail.contactPhone?.isNotEmpty == true ||
                              videoDetail.contactEmail?.isNotEmpty == true ||
                              videoDetail.latitude?.isNotEmpty ==
                                  true)) // Check if at least one is non-empty
                        Positioned(
                          top: Get.height * 0.08,
                          left: 16,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: InkWell(
                              onTap: () {
                                // Get current user ID

                                final businessId =
                                    videoDetail.frontUserId.toString();

                                final firestore = FirebaseFirestore.instance;
                                final docRef = firestore
                                    .collection('countContactClick')
                                    .doc(videoDetail.id);

                                // Run transaction to ensure atomic update
                                firestore.runTransaction((transaction) async {
                                  final docSnapshot = await transaction.get(
                                    docRef,
                                  );

                                  if (!docSnapshot.exists) {
                                    // If document doesn't exist, create it with initial data
                                    transaction.set(docRef, {
                                      'businessId': videoDetail.frontUserId,
                                      'videoId': videoDetail.id,
                                      'totalClicks': 1,
                                      'userIds': [userId],
                                    });
                                  } else {
                                    final data = docSnapshot.data()!;
                                    final userIds = List<String>.from(
                                      data['userIds'] ?? [],
                                    );

                                    if (!userIds.contains(userId)) {
                                      // User hasn't clicked before, increment count and add userId
                                      transaction.update(docRef, {
                                        'totalClicks': FieldValue.increment(1),
                                        'userIds': FieldValue.arrayUnion([
                                          userId,
                                        ]),
                                      });
                                    }
                                  }
                                });

                                print(videoDetail.id.toString());
                                controller.pauseCurrentVideo();
                                showContactNowDialog(
                                  context,
                                  website: videoDetail.website ?? "",
                                  phoneNumber: videoDetail.contactPhone ?? "",
                                  latitude: videoDetail.latitude ?? "",
                                  longitude: videoDetail.longitude ?? "",
                                  email: videoDetail.contactEmail ?? "",
                                  videoId: videoDetail.id.toString(),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorUtils.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Contact Us",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      videoActions(
                        videoDetail,
                        currentUserDetails,
                        currentUser,
                        context,
                      ),
                    ],
                  );
                },
              ),

              Positioned(
                top: Get.height * 0.01,
                right: 16,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        controller.pauseCurrentVideo();
                        // _handleScreenExit();
                        Get.to(() => SearchView())?.then((_) {
                          controller.restoreVideoState();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          // Transparent to show blur
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 10.0,
                              sigmaY: 10.0,
                            ), // Blur effect
                            child: Container(
                              padding: EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                // Blue tint
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        controller.pauseCurrentVideo();
                        _showBottomSheet(context);
                        // _handleScreenExit();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          // Transparent to show blur
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 10.0,
                              sigmaY: 10.0,
                            ), // Blur effect
                            child: Container(
                              padding: EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                // Blue tint
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String? selectedCountry;
  String? selectedCity;

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              color: Colors.white,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filter',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      showLocationDialog(context);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined),
                        SizedBox(width: 10),
                        Obx(
                          () => Text(
                            controller.currentCountry.value == ""
                                ? 'Select Country'
                                : controller.currentCountry.value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),

                  InkWell(
                    onTap: () {
                      showCityDialog(context);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined),
                        SizedBox(width: 10),
                        Obx(
                          () => Text(
                            controller.currentCity.value == ""
                                ? 'Select City'
                                : controller.currentCity.value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                  AppButton(
                    text: "Submit",
                    onTap: () {
                      Navigator.pop(context);
                      controller.currentCity.value == ""
                          ? null
                          : controller.fetchVideos(
                            city: controller.currentCity.value,
                            tag: widget.tag,
                          );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Stream<double> _getAverageRating(String videoId) {
    return FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('reviews')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return 0.0;
          double totalRating = 0.0;
          for (var doc in snapshot.docs) {
            totalRating += (doc['rating'] as num?)?.toDouble() ?? 0.0;
          }

          rateVideo(videoId, totalRating / snapshot.docs.length);
          return totalRating / snapshot.docs.length;
        });
  }

  /// Video widgets with details
  Positioned videoActions(
    WallVideos videoDetail,
    SimpleUser? currentUserDetails,
    User? currentUser,
    BuildContext context,
  ) {
    return Positioned(
      right: 10,
      bottom: Get.height * 0.1,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('videos')
                            .doc(videoDetail.id)
                            .snapshots(),
                    builder: (context, snapshot) {
                      final data =
                          snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      List<dynamic> likes = data['likes'] ?? [];
                      int likeCount =
                          likes.length; // Count likes from array length

                      String userId =
                          currentUserDetails?.id ?? currentUser?.id ?? '';
                      bool isLiked = likes.contains(userId);

                      String formattedLikeCount =
                          likeCount > 1000
                              ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                              : likeCount.toString();

                      // Fetch the comment count from the comments subcollection
                      return StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('videos')
                                .doc(videoDetail.id)
                                .collection('comments')
                                .snapshots(),
                        builder: (context, commentSnapshot) {
                          int commentCount =
                              commentSnapshot.data?.docs.length ??
                              0; // Count total comments
                          String formattedCommentCount =
                              commentCount > 1000
                                  ? '${(commentCount / 1000).toStringAsFixed(1)}K'
                                  : commentCount.toString();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Like Button
                              LikeButton(
                                size: 24.h,
                                isLiked: isLiked,
                                circleColor: CircleColor(
                                  start: Colors.red[200]!,
                                  end: Colors.red[400]!,
                                ),
                                bubblesColor: BubblesColor(
                                  dotPrimaryColor: Colors.red[300]!,
                                  dotSecondaryColor: Colors.red[200]!,
                                ),
                                likeBuilder:
                                    (bool isLiked) => SvgPicture.asset(
                                      "assets/icons/heart.svg",
                                      height: 24.h,
                                      color:
                                          isLiked ? Colors.red : Colors.white,
                                    ),
                                onTap: (currentIsLiked) async {
                                  final String videoId = videoDetail.id!;
                                  String userId =
                                      currentUserDetails?.id ??
                                      currentUser!.id!;
                                  HapticFeedback.lightImpact();

                                  // Optimistic UI update
                                  final optimisticLikes = List<dynamic>.from(
                                    likes,
                                  );
                                  if (currentIsLiked) {
                                    optimisticLikes.remove(userId);
                                  } else {
                                    optimisticLikes.add(userId);
                                  }
                                  await videoCommentsController.toggleVideoLike(
                                    videoId.toString(),
                                    userId.toString(),
                                  );

                                  return !currentIsLiked;
                                },
                              ),
                              SizedBox(height: 2),
                              Text(
                                formattedLikeCount ?? "0",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                ),
                              ),
                              SizedBox(height: 16),
                              // Comment Button
                              if (videoDetail.allowComments == 1) ...[
                                InkWell(
                                  onTap: () {
                                    controller.pauseCurrentVideo();
                                    String? userId =
                                        currentUserDetails?.id ??
                                        currentUser!.id;
                                    String? userImage =
                                        currentUserDetails?.image ??
                                        currentUser?.image ??
                                        "";
                                    showCommentsBottomSheetNew(
                                      context,
                                      videoDetail.id!,
                                      userId!,
                                      userImage!,
                                    );

                                    if (mounted) {
                                      controller.restoreVideoState();
                                    }
                                  },
                                  child: SvgPicture.asset(
                                    "assets/icons/comment.svg",
                                    height: 20.h,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  formattedCommentCount,
                                  // Display the comment count here
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              // Static Buttons (Share, Save, More)
                              _buildStaticButtons(videoDetail, context),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: InkWell(
                    onTap: () {
                      controller.pauseCurrentVideo();
                      String? userId =
                          currentUserDetails?.id ?? currentUser!.id;
                      String? userImage =
                          currentUserDetails?.image ?? currentUser?.image ?? "";
                      showReviewsBottomSheet(
                        context,
                        videoDetail.id!,
                        userId!,
                        userImage!,
                      );

                      if (mounted) {
                        controller.restoreVideoState();
                      }
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amberAccent,
                          size: 40,
                        ),
                        StreamBuilder<double>(
                          stream: _getAverageRating(videoDetail.id!),
                          builder: (context, snapshot) {
                            final averageRating =
                                snapshot.hasData && snapshot.data! > 0
                                    ? snapshot.data!.toStringAsFixed(1)
                                    : "0.0";
                            return Text(
                              averageRating,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for static buttons to avoid rebuilding
  Widget _buildStaticButtons(WallVideos videoDetail, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share Button
        Column(
          children: [
            InkWell(
              onTap: () => _handleShare(videoDetail),
              child: SvgPicture.asset(
                "assets/icons/share.svg",
                height: 20.h,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Share",
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Save Button
        Obx(() {
          // Check if video is already saved
          bool isSaved = saveController.savedVideos.any(
            (video) => video.id.toString() == videoDetail.id,
          );

          return Column(
            children: [
              InkWell(
                onTap: () async {
                  if (isSaved) {
                    // 1. Immediately remove from local list
                    saveController.savedVideos.removeWhere(
                      (video) =>
                          video.id.toString() == videoDetail.id.toString(),
                    );

                    // 2. Then hit API
                    await saveController.saveVideo(videoDetail.id!);
                  } else {
                    // 1. Immediately add to local list
                    saveController.savedVideos.add(
                      SavedVideos(
                        id: videoDetail.id,
                        title: videoDetail.title,
                        // Add other fields if needed, or just id is fine for now
                      ),
                    );

                    // 2. Then hit API
                    await saveController.saveVideo(videoDetail.id!);
                  }
                },
                child: SvgPicture.asset(
                  "assets/icons/bookmark.svg",
                  height: 20.h,
                  color: isSaved ? ColorUtils.primaryColor : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Save",
                style: TextStyle(color: Colors.white, fontSize: 10.sp),
              ),
            ],
          );
        }),
        SizedBox(height: 16),
        // More Button
        Column(
          children: [
            InkWell(
              onTap: () {
                controller.pauseCurrentVideo();
                _showMoreOptions(context, videoDetail.id!);

                if (mounted) {
                  controller.restoreVideoState();
                }
              },
              child: Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 30.h,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "More",
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
          ],
        ),
      ],
    );
  }

  void _handleShare(WallVideos videoDetail) async {
    _handleScreenExit();
    try {
      final String videoId = videoDetail.id!;
      final String webUrl = "https://cookster.com/visitSingleVideo?id=$videoId";
      final String shareMessage =
          'Check out this amazing video on Cookster!\n$webUrl';
      await Share.share(shareMessage, subject: 'Cookster Video');
    } catch (e) {
      print('Error sharing video: $e');
      Get.snackbar(
        'Error',
        'Could not share this video',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      controller.restoreVideoState();
    }
  }

  void _showMoreOptions(BuildContext context, String videoId) {
    // _handleScreenExit();
    // controller.pauseCurrentVideo();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
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

              ListTile(
                leading: Icon(Icons.flag_outlined, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'Report Content',
                  style: TextStyle(color: Colors.black, fontSize: 14.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Get.to(ReportContentView(videoId: videoId))?.then((_) {
                    controller.restoreVideoState();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class videoUserDetails extends StatelessWidget {
  const videoUserDetails({
    super.key,
    required this.profileController,
    required this.professionalProfileController,
    required this.videoDetail,
    required this.controller,
    required this.userId,
  });

  final ProfileController profileController;
  final ProfessionalProfileController professionalProfileController;
  final WallVideos videoDetail;
  final HashtagController controller;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Get.height * 0.01,
      left: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent, // Transparent to show blur
          borderRadius: BorderRadius.circular(50),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Blur effect
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), // Blue tint
                borderRadius: BorderRadius.circular(50),
              ),
              child: Obx(() {
                var currentUserDetails =
                    profileController.simpleUserDetails.value?.user;
                var currentUser =
                    professionalProfileController.userDetails.value?.user;
                bool isProfileNull = currentUser == null;
                bool isFollowing =
                    isProfileNull
                        ? profileController.isFollowing(
                          videoDetail.frontUserId!,
                        )
                        : professionalProfileController.isFollowing(
                          videoDetail.frontUserId!,
                        );

                return Row(
                  mainAxisSize: MainAxisSize.min, // Adjust width to content
                  children: [
                    InkWell(
                      onTap: () {
                        controller.pauseCurrentVideo();
                        Get.to(
                          VisitProfileView(userId: videoDetail.frontUserId!),
                        )?.then((_) {
                          controller.restoreVideoState();
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 16.r,
                              backgroundImage:
                                  videoDetail.userImage != null &&
                                          videoDetail.userImage!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                        '${Common.profileImage}/${videoDetail.userImage}',
                                      )
                                      : null,
                              child:
                                  videoDetail.userImage == null ||
                                          videoDetail.userImage!.isEmpty
                                      ? Icon(Icons.person, color: Colors.white)
                                      : null,
                            ),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                videoDetail.userName ?? 'Unknown User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${videoDetail.followersCount} followers",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    if (userId != videoDetail.frontUserId)
                      InkWell(
                        onTap: () {
                          if (isProfileNull) {
                            profileController.toggleFollowStatus(
                              videoDetail.frontUserId!,
                            );
                          } else {
                            professionalProfileController.toggleFollowStatus(
                              videoDetail.frontUserId!,

                            );
                          }
                        },
                        child: Container(
                          height: 25,

                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white),
                            color: isFollowing ? Colors.white : Colors.black,
                          ),
                          child: Center(
                            child: Text(
                              isFollowing ? "Following".tr : "Follow".tr,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color:
                                    isFollowing ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class videoTitleEtc extends StatelessWidget {
  const videoTitleEtc({super.key, required this.videoDetail});

  final WallVideos videoDetail;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: Get.height * 0.1,
      left: 10,
      child: Container(
        width: Get.width * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (videoDetail.title != null && videoDetail.title!.isNotEmpty)
              Text(
                videoDetail.title!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (videoDetail.description != null &&
                videoDetail.description!.isNotEmpty)
              Text(
                videoDetail.description!,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (videoDetail.tags != null && videoDetail.tags!.isNotEmpty)
              Text(
                videoDetail.tags!
                    .split(',')
                    .map((tag) => "#${tag.trim()}")
                    .join(' '),
                style: TextStyle(
                  color: ColorUtils.primaryColor,
                  fontSize: 12.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                "#",
                style: TextStyle(
                  color: ColorUtils.primaryColor,
                  fontSize: 12.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void showLocationDialog(BuildContext context) {
  final HashtagController hashtagController = Get.find();
  final VideoAddController controller = Get.find();
  final ProfileController profileController = Get.find();
  final CityController cityController = Get.put(CityController());

  Map<String, int> countryMap = {};
  List<String> countryName =
      profileController.videoUploadSettings.value!.countries!.map((country) {
        countryMap[country.name!] = country.id!;
        return country.name!;
      }).toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;

  // Filter countries based on search input
  void filterCountries(String query) {
    if (query.isEmpty) {
      filteredCountryName.value = countryName;
    } else {
      filteredCountryName.value =
          countryName
              .where(
                (country) =>
                    country.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 350.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// **Header (Title + Close Button)**
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.black),
                    SizedBox(width: 8.w),
                    Text(
                      "Select Country",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// **Search Field**
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: (value) => filterCountries(value),
            ),
            SizedBox(height: 16.h),

            /// **Scrollable Location List**
            Container(
              height: 240.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCountryName.length,
                      (index) => InkWell(
                        onTap: () async {
                          try {
                            controller.selectLocation(
                              filteredCountryName[index],
                              countryMap[filteredCountryName[index]]!,
                            );

                            await cityController.fetchCities(
                              countryMap[filteredCountryName[index]]!,
                            );
                            hashtagController.currentCountry.value =
                                filteredCountryName[index];
                            Get.back(); // Close the country dialog
                            showCityDialog(context);
                          } catch (e) {
                            print('Error selecting country: $e');
                            Get.snackbar('Error', 'Failed to load cities');
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                filteredCountryName[index],
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight:
                                      controller.selectedCountry.value ==
                                              filteredCountryName[index]
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                width: 20.w,
                                height: 20.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.primaryColor,
                                    width: 2,
                                  ),
                                  color:
                                      controller.selectedCountry.value ==
                                              filteredCountryName[index]
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    ),
  );
}

void showCityDialog(BuildContext context) {
  final VideoAddController controller = Get.find();
  final CityController cityController = Get.find();
  final HashtagController hashtagController = Get.find();

  Map<String, int> cityMap = {};
  List<String> cityName =
      cityController.cityList.map((city) {
        cityMap[city.name!] = city.id!;
        return city.name!;
      }).toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCityName = cityName.obs;

  // Filter cities based on search input
  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityName.value = cityName;
    } else {
      filteredCityName.value =
          cityName
              .where((city) => city.toLowerCase().contains(query.toLowerCase()))
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 350.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// **Header (Title + Close Button)**
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.black),
                    SizedBox(width: 8.w),
                    Text(
                      "Select City",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// **Search Field**
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search city...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: (value) => filterCities(value),
            ),
            SizedBox(height: 16.h),

            /// **Scrollable Location List**
            Container(
              height: 230.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCityName.length,
                      (index) => InkWell(
                        onTap: () async {
                          try {
                            print(
                              "Selected City: ${filteredCityName[index]} (ID: ${cityMap[filteredCityName[index]]})",
                            );

                            hashtagController.currentCity.value =
                                filteredCityName[index];

                            print(
                              "Current City: ${hashtagController.currentCity.value}",
                            );

                            // HashtagController.fetchVideos(
                            //   city: filteredCityName[index],
                            //   // cityMap[filteredCityName[index]]!,
                            // );
                            // await HashtagController.fetchVideos(
                            //   city: filteredCityName[index],
                            // );
                            Get.back(); // Close the city dialog
                          } catch (e) {
                            print('Error selecting city: $e');
                            Get.snackbar('Error', 'Failed to fetch videos');
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                filteredCityName[index],
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight:
                                      controller.selectedCity.value ==
                                              filteredCityName[index]
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                width: 20.w,
                                height: 20.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.primaryColor,
                                    width: 2,
                                  ),
                                  color:
                                      controller.selectedCity.value ==
                                              filteredCityName[index]
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    ),
  );
}
