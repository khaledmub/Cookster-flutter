import 'dart:async';
import 'dart:ui';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/goLive/join_screen.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/commentScreen.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/hashTagReels.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/profileModel.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileModel/simpleUserProfileModel.dart';
import 'package:cookster/modules/landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import 'package:cookster/modules/search/searchView/searchView.dart';
import 'package:cookster/modules/visitProfile/visitProfileView/visitProfileView.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:like_button/like_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pro_image_editor/core/platform/io/io_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../auth/signUp/signUpController/cityController.dart';
import '../../../../chatScreen/userChatList.dart';
import '../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../../../search/searchController/searchController.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import '../../add/videoAddController/videoAddController.dart';
import '../homeController/addCommentControllr.dart';
import '../homeController/homeController.dart';
import '../homeWidgets/chatIconWithCounter.dart';
import '../homeWidgets/contactNowDialog.dart';
import '../homeWidgets/reviewSheet.dart';

class VideoReelScreen extends StatefulWidget {
  @override
  _VideoReelScreenState createState() => _VideoReelScreenState();
}

class _VideoReelScreenState extends State<VideoReelScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final HomeController controller = Get.find();
  final PromoteVideoController promoteVideoController = Get.find();
  final VideoCommentsController videoCommentsController = Get.put(
    VideoCommentsController(),
  );
  final ProfileController profileController = Get.find();
  final ProfessionalProfileController professionalProfileController =
      Get.find();

  final SaveController saveController = Get.find();

  @override
  bool get wantKeepAlive => true;

  // late SwiperController _swiperController;
  bool _showIcon = false;
  bool isAuthenticated = false;

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  Future<void> _checkAuthentication() async {
    try {
      bool authStatus = await _isUserAuthenticated();
      var currentUserDetails = profileController.simpleUserDetails.value?.user;
      var currentUser = professionalProfileController.userDetails.value?.user;
      String? id = currentUser?.id ?? currentUserDetails?.id;
      setState(() {
        isAuthenticated = authStatus;
      });
    } catch (e) {
      print('Error checking authentication: $e');
    }
  }

  String _language = 'en'; // Default to English
  String userIdFromStorage = ''; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
      userIdFromStorage = prefs.getString('user_id') ?? '';
    });
  }

  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _checkAuthentication();
    WakelockPlus.enable();
    pageController = PageController(initialPage: controller.currentIndex.value);

    // _swiperController = SwiperController();
    _restoreSwiperPosition();
  }

  void _restoreSwiperPosition() {
    // Set Swiper to the last viewed index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          controller.currentIndex.value >= 0 &&
          controller.currentIndex.value < controller.chewieControllers.length) {
        // _swiperController.move(controller.currentIndex.value, animation: false);
      }
    });
  }

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
    // _swiperController.dispose();

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

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light, // White icons
        statusBarColor: Colors.transparent, // Transparent status bar
      ),
    );

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

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Generate a new device ID (you could also use UUID package)
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique device ID for Android
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor; // Unique device ID for iOS
      } else {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString(); // Fallback
      }
      await prefs.setString('device_id', deviceId!);
    }
    return deviceId;
  }

  // Updated _trackVideoView function to handle both user and device views
  Future<void> _trackVideoView(
    String videoId,
    String? userId,
    bool isAuthenticated,
  ) async {
    try {
      final videoRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId);

      if (isAuthenticated && userId != null) {
        // Track view for authenticated user
        await videoRef.set({
          'views': FieldValue.arrayUnion([userId]),
        }, SetOptions(merge: true));
        print("PRINTING VIDEO ID: $videoId Printing USER ID: $userId");
      } else {
        // Track view for non-authenticated user using device ID
        String deviceId = await _getDeviceId();
        await videoRef.set({
          'views': FieldValue.arrayUnion([deviceId]),
        }, SetOptions(merge: true));
        print("PRINTING VIDEO ID: $videoId Printing DEVICE ID: $deviceId");
      }
    } catch (e) {
      print('Error tracking video view: $e');
      // Optionally handle the error (e.g., show a toast or log it)
    }
  }

  final PageController _pageController = PageController();

  void _scrollToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToPrevious() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    isAuthenticated = isAuthenticated;
    print("PRINTING IS AUTHENTICATED ${isAuthenticated}");
    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;
    bool isRtl = _language == 'ar';

    return WillPopScope(
      onWillPop: () async {
        _handleScreenExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),

        body: Obx(() {
          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  controller.isLoading.value ||
                          controller.isLocationFetching.value
                      ? Center(
                        child: PulseLogoLoader(
                          logoPath: "assets/images/appIcon.png",
                          size: 80,
                        ),
                      )
                      : controller.videoFeed.value.videos == null ||
                          controller.videoFeed.value.videos!.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              textAlign: TextAlign.center,
                              "${'no_video_for'.tr} ${controller.currentCity.value} ${'try_to_change'.tr}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (controller.selectedType.value == "Near Me")
                                  Expanded(
                                    child: AppButton(
                                      text: "Change Location",
                                      onTap: () {
                                        _showBottomSheet(context);
                                      },
                                    ),
                                  ),

                                SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Get.to(
                                      () => SearchView(
                                        isGeneral:
                                            controller.selectedType.value ==
                                                    "General"
                                                ? 1
                                                : 0,
                                      ),
                                    )?.then((_) {
                                      controller.fetchVideos(
                                        city: controller.currentCity.value,
                                        country:
                                            controller.currentCountry.value,
                                      );
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
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
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
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    controller.fetchVideos();
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
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.refresh,
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
                      )
                      : Expanded(
                        child: Listener(
                          child: GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity! > 300) {
                                _scrollToPrevious();
                              } else if (details.primaryVelocity! < -300) {
                                _scrollToNext();
                              }
                            },
                            onPanEnd: (details) {
                              if (details.velocity.pixelsPerSecond.dy > 500) {
                                _scrollToPrevious();
                              } else if (details.velocity.pixelsPerSecond.dy <
                                  -500) {
                                _scrollToNext();
                              }
                            },
                            child: PageView.custom(
                              scrollDirection: Axis.vertical,
                              controller: _pageController,
                              clipBehavior: Clip.none,
                              pageSnapping: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padEnds: true,
                              onPageChanged: (index) async {
                                controller.visiblePageIndex.value = index;
                                int actualIndex =
                                    controller.videoFeed.value.videos != null
                                        ? index %
                                            controller
                                                .videoFeed
                                                .value
                                                .videos!
                                                .length
                                        : 0;
                                controller.handlePageChange(actualIndex);

                                // Check if we're nearing the end of the list (3 videos left)
                                if (controller.videoFeed.value.videos != null &&
                                    actualIndex >=
                                        controller
                                                .videoFeed
                                                .value
                                                .videos!
                                                .length -
                                            3) {
                                  // Fetch more videos to append to the list
                                  await controller.fetchMoreVideos();
                                }

                                if (mounted) setState(() {});

                                // Track view in Firestore
                                String? videoId =
                                    controller.videoFeed.value.videos != null
                                        ? controller
                                            .videoFeed
                                            .value
                                            .videos![actualIndex]
                                            .id
                                        : null;
                                if (videoId != null) {
                                  await _trackVideoView(
                                    videoId,
                                    userId,
                                    isAuthenticated,
                                  );
                                } else {
                                  print(
                                    'Error: Video ID is null for index $actualIndex',
                                  );
                                }
                              },
                              childrenDelegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (controller.videoFeed.value.videos ==
                                          null ||
                                      controller
                                          .videoFeed
                                          .value
                                          .videos!
                                          .isEmpty) {
                                    return Container(
                                      width: MediaQuery.of(context).size.width,
                                      height:
                                          MediaQuery.of(context).size.height,
                                      color: Colors.black,
                                      child: const Center(
                                        child: Text(
                                          'No videos available',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  int actualIndex =
                                      index %
                                      controller.videoFeed.value.videos!.length;
                                  var videoDetail =
                                      controller
                                          .videoFeed
                                          .value
                                          .videos![actualIndex];
                                  var chewieController =
                                      controller.chewieControllers[actualIndex];

                                  bool isInitialized =
                                      chewieController != null &&
                                      chewieController
                                          .videoPlayerController
                                          .value
                                          .isInitialized;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.bottomLeft,
                                    children: [
                                      GestureDetector(
                                        onTap: _togglePlayPause,
                                        onDoubleTap: controller.toggleMute,
                                        child:
                                            isInitialized
                                                ? Chewie(
                                                  controller: chewieController,
                                                )
                                                : Center(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                        "${Common.videoUrl}/${videoDetail.image}",
                                                  ),
                                                ),
                                      ),
                                      VideoDescriptionWidget(
                                        title: videoDetail.title,
                                        description: videoDetail.description,
                                        tags: videoDetail.tags,
                                        controller: controller,
                                      ),
                                      videoUserDetails(
                                        profileController: profileController,
                                        professionalProfileController:
                                            professionalProfileController,
                                        videoDetail: videoDetail,
                                        controller: controller,
                                        userId: userId,
                                        isAuthenticated: isAuthenticated,
                                      ),
                                      videoActions(
                                        videoDetail,
                                        currentUserDetails,
                                        currentUser,
                                        context,
                                      ),
                                      if (_showIcon &&
                                          isInitialized &&
                                          actualIndex ==
                                              controller.currentIndex.value)
                                        Center(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              chewieController.isPlaying
                                                  ? Icons.pause_circle_filled
                                                  : Icons.play_circle_filled,
                                              size: 64.0,
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (videoDetail.isImage == 0 &&
                                          isInitialized)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 3,
                                          child: StatefulBuilder(
                                            builder: (context, setState) {
                                              bool isThumbTapped =
                                                  false; // Track thumb interaction state

                                              return StreamBuilder<Duration>(
                                                stream: Stream.periodic(
                                                  const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  (_) =>
                                                      chewieController
                                                          .videoPlayerController
                                                          .value
                                                          .position,
                                                ),
                                                builder: (context, snapshot) {
                                                  final position =
                                                      snapshot.data ??
                                                      Duration.zero;
                                                  final duration =
                                                      chewieController
                                                          .videoPlayerController
                                                          .value
                                                          .duration ??
                                                      Duration.zero;
                                                  final isInitialized =
                                                      chewieController
                                                          .videoPlayerController
                                                          .value
                                                          .isInitialized;

                                                  if (!isInitialized ||
                                                      duration ==
                                                          Duration.zero) {
                                                    return Slider(
                                                      value: 0,
                                                      max: 1,
                                                      onChanged: null,
                                                      thumbColor:
                                                          ColorUtils
                                                              .primaryColor,
                                                      activeColor:
                                                          ColorUtils
                                                              .primaryColor,
                                                      inactiveColor:
                                                          ColorUtils.darkBrown,
                                                    );
                                                  }

                                                  return SliderTheme(
                                                    data: SliderThemeData(
                                                      thumbShape:
                                                          RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                isThumbTapped
                                                                    ? 0.0
                                                                    : 6.0, // Change radius based on tap
                                                          ),
                                                      overlayShape:
                                                          const RoundSliderOverlayShape(
                                                            overlayRadius: 0,
                                                          ),
                                                      trackHeight: 2,
                                                    ),
                                                    child: Slider(
                                                      value:
                                                          position.inSeconds
                                                              .toDouble(),
                                                      max:
                                                          duration.inSeconds
                                                              .toDouble(),
                                                      onChanged: (value) {
                                                        chewieController.seekTo(
                                                          Duration(
                                                            seconds:
                                                                value.toInt(),
                                                          ),
                                                        );
                                                      },
                                                      onChangeStart: (_) {
                                                        setState(() {
                                                          isThumbTapped =
                                                              true; // Set to true when interaction starts
                                                        });
                                                        if (chewieController
                                                            .isPlaying) {
                                                          chewieController
                                                              .pause();
                                                        }
                                                      },
                                                      onChangeEnd: (_) {
                                                        setState(() {
                                                          isThumbTapped =
                                                              false; // Revert to false when interaction ends
                                                        });
                                                        if (!chewieController
                                                            .isPlaying) {
                                                          chewieController
                                                              .play();
                                                        }
                                                      },
                                                      thumbColor:
                                                          ColorUtils
                                                              .primaryColor,
                                                      activeColor:
                                                          ColorUtils
                                                              .primaryColor,
                                                      inactiveColor:
                                                          ColorUtils.darkBrown,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),

                                      Positioned(
                                        top: Get.height * 0.05,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            Get.to(
                                              () => SearchView(
                                                isGeneral:
                                                    controller
                                                                .selectedType
                                                                .value ==
                                                            "General"
                                                        ? 1
                                                        : 0,
                                              ),
                                            )!.then((_) {
                                              controller.disposeControllers();
                                              controller.fetchVideos(
                                                city:
                                                    controller
                                                        .currentCity
                                                        .value,
                                                country:
                                                    controller
                                                        .currentCountry
                                                        .value,
                                              );
                                            });
                                          },
                                          child: Container(
                                            margin: EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(100),

                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 10.0,
                                                  sigmaY: 10.0,
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.search,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                childCount:
                                    controller.videoFeed.value.videos != null
                                        ? controller
                                            .videoFeed
                                            .value
                                            .videos!
                                            .length
                                        : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),

              SafeArea(
                child: Obx(
                  () => Container(
                    margin: EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        SizedBox(width: 16),

                        InkWell(
                          onTap: () {
                            isAuthenticated
                                ? Get.to(JoinScreen())
                                : Get.toNamed(AppRoutes.signIn);
                          },
                          child: SvgPicture.asset(
                            "assets/icons/live.svg",
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        if ((promoteVideoController
                                    .siteSettings
                                    .value
                                    ?.settings
                                    ?.allowGeneralVideos ??
                                0) ==
                            1)
                          GestureDetector(
                            onTap: () async {
                              if (controller.isLoading.value ||
                                  controller.isLocationFetching.value) {
                              } else {
                                controller.disposeControllers();
                                controller.setSelectedType("General");
                                controller.fetchVideos();
                              }
                              ;
                            },
                            child: Text(
                              "General".tr,
                              style: TextStyle(
                                shadows: <Shadow>[
                                  // Subtle depth shadow
                                  Shadow(
                                    offset: Offset(0.0, 2.0),
                                    blurRadius: 4.0,
                                    color: Color.fromARGB(60, 0, 0, 0),
                                  ),
                                  // Soft outline for readability
                                  Shadow(
                                    offset: Offset(0.0, 0.0),
                                    blurRadius: 8.0,
                                    color: Color.fromARGB(80, 0, 0, 0),
                                  ),
                                  // Crisp edge definition
                                  Shadow(
                                    offset: Offset(0.5, 0.5),
                                    blurRadius: 1.0,
                                    color: Color.fromARGB(100, 0, 0, 0),
                                  ),
                                ],
                                color:
                                    controller.selectedType.value == "General"
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                fontWeight:
                                    controller.selectedType.value == "General"
                                        ? FontWeight.w500
                                        : FontWeight.w300,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        SizedBox(width: 20),
                        GestureDetector(
                          onTap: () {
                            if (controller.isLoading.value ||
                                controller.isLocationFetching.value) {
                            } else {
                              controller.disposeControllers();
                              controller.setSelectedType("Near Me");
                              controller.fetchVideos();
                            }
                            ;
                          },
                          child: Text(
                            "Near Me".tr,
                            style: TextStyle(
                              shadows: <Shadow>[
                                // Subtle depth shadow
                                Shadow(
                                  offset: Offset(0.0, 2.0),
                                  blurRadius: 4.0,
                                  color: Color.fromARGB(60, 0, 0, 0),
                                ),
                                // Soft outline for readability
                                Shadow(
                                  offset: Offset(0.0, 0.0),
                                  blurRadius: 8.0,
                                  color: Color.fromARGB(80, 0, 0, 0),
                                ),
                                // Crisp edge definition
                                Shadow(
                                  offset: Offset(0.5, 0.5),
                                  blurRadius: 1.0,
                                  color: Color.fromARGB(100, 0, 0, 0),
                                ),
                              ],
                              color:
                                  controller.selectedType.value == "Near Me"
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                              fontWeight:
                                  controller.selectedType.value == "Near Me"
                                      ? FontWeight.w500
                                      : FontWeight.w300,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        if ((promoteVideoController
                                    .siteSettings
                                    .value
                                    ?.settings
                                    ?.allowGeneralVideos ??
                                0) ==
                            1)
                          GestureDetector(
                            onTap: () async {
                              print(
                                "RINTING IS AUTHENTICAT ${isAuthenticated}",
                              );
                              if (isAuthenticated) {
                                if (controller.isLoading.value ||
                                    controller.isLocationFetching.value) {
                                } else {
                                  controller.disposeControllers();
                                  controller.setSelectedType("Following");
                                  controller.fetchVideos();
                                }
                                ;
                              } else {
                                Get.toNamed(AppRoutes.signIn);
                              }
                            },
                            child: Text(
                              "Following".tr,
                              style: TextStyle(
                                shadows: <Shadow>[
                                  // Subtle depth shadow
                                  Shadow(
                                    offset: Offset(0.0, 2.0),
                                    blurRadius: 4.0,
                                    color: Color.fromARGB(60, 0, 0, 0),
                                  ),
                                  // Soft outline for readability
                                  Shadow(
                                    offset: Offset(0.0, 0.0),
                                    blurRadius: 8.0,
                                    color: Color.fromARGB(80, 0, 0, 0),
                                  ),
                                  // Crisp edge definition
                                  Shadow(
                                    offset: Offset(0.5, 0.5),
                                    blurRadius: 1.0,
                                    color: Color.fromARGB(100, 0, 0, 0),
                                  ),
                                ],
                                color:
                                    controller.selectedType.value == "Following"
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                fontWeight:
                                    controller.selectedType.value == "Following"
                                        ? FontWeight.w500
                                        : FontWeight.w300,
                                fontSize: 18,
                              ),
                            ),
                          ),

                        SizedBox(width: 16),

                        ChatIconWithCounter(
                          userId: userId ?? '',
                          isAuthenticated: isAuthenticated,
                          onTap: () {
                            isAuthenticated
                                ? Get.to(
                                  ChatListScreen(userId: userIdFromStorage),
                                )?.then((_) {
                                  controller.restoreVideoState();
                                })
                                : Get.toNamed(AppRoutes.signIn);
                          },
                        ),
                        SizedBox(width: 16),
                      ],
                    ),
                  ),
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
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                color: Colors.white,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter'.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                                  ? 'Select Country'.tr
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
                        print(controller.currentCityId.value);
                        // Pass the initialCity ID to showCityDialog
                        showCityDialog(
                          context,
                          initialCity: int.parse(
                            controller.currentCityId.value,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined),
                          SizedBox(width: 10),
                          Obx(
                            () => ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              // Set your desired maximum width
                              child: Text(
                                controller.currentCity.value == ""
                                    ? 'Select City'.tr
                                    : controller.currentCity.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow:
                                    TextOverflow
                                        .ellipsis, // Show ellipsis if text exceeds maxWidth
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
                      text: "Submit".tr,
                      onTap: () {
                        Navigator.pop(context);
                        controller.currentCity.value == ""
                            ? null
                            : controller
                                .fetchVideos(
                                  city: controller.currentCity.value,
                                  country: controller.currentCountry.value,
                                )
                                .then((value) {
                                  controller.saveLocationData();
                                });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
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
    bool isAuthenticated = currentUserDetails != null || currentUser != null;
    return Positioned(
      right: 10,
      bottom: Platform.isAndroid ? Get.height * 0.02 : Get.height * 0.02,
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
                              commentSnapshot.data?.docs.length ?? 0;
                          String formattedCommentCount =
                              commentCount > 1000
                                  ? '${(commentCount / 1000).toStringAsFixed(1)}K'
                                  : commentCount.toString();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Simplified Like Button
                              InkWell(
                                onTap: () async {
                                  if (!isAuthenticated) {
                                    Get.toNamed(AppRoutes.signIn);
                                    return;
                                  }
                                  final String videoId = videoDetail.id!;
                                  String userId =
                                      currentUserDetails?.id ??
                                      currentUser!.id!;
                                  HapticFeedback.lightImpact();

                                  // Optimistic UI update
                                  final optimisticLikes = List<dynamic>.from(
                                    likes,
                                  );
                                  if (isLiked) {
                                    optimisticLikes.remove(userId);
                                  } else {
                                    optimisticLikes.add(userId);
                                  }
                                  await videoCommentsController.toggleVideoLike(
                                    videoId.toString(),
                                    userId.toString(),
                                  );
                                },
                                child: SizedBox(
                                  height: 20.h,
                                  width: 20.h,
                                  child: SvgPicture.asset(
                                    "assets/icons/heart.svg",
                                    fit: BoxFit.fill,
                                    color: isLiked ? Colors.red : Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                formattedLikeCount ?? "0",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                ),
                              ),
                              // Comment Button
                              if (videoDetail.allowComments == 1) ...[
                                SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    if (!isAuthenticated) {
                                      Get.toNamed(AppRoutes.signIn);
                                      return;
                                    }
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
                                  child: SizedBox(
                                    height: 20.h,
                                    width: 20.h,
                                    child: SvgPicture.asset(
                                      "assets/icons/comment.svg",
                                      fit: BoxFit.fill,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  formattedCommentCount,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                ),
                                SizedBox(height: 8),
                              ],
                              // Static Buttons (Share, Save, More)
                              _buildStaticButtons(
                                videoDetail,
                                currentUserDetails?.id ?? currentUser?.id ?? '',
                                context,
                              ),

                              if (videoDetail.takeOrder == 1 &&
                                  (videoDetail.contactPhone?.isNotEmpty ==
                                          true ||
                                      videoDetail.contactEmail?.isNotEmpty ==
                                          true ||
                                      videoDetail.latitude?.isNotEmpty == true))
                                Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      width: 40,
                                      height: 1,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        if (!isAuthenticated) {
                                          Get.toNamed(AppRoutes.signIn);
                                          return;
                                        }
                                        final businessId =
                                            videoDetail.frontUserId.toString();
                                        final firestore =
                                            FirebaseFirestore.instance;
                                        final docRef = firestore
                                            .collection('countContactClick')
                                            .doc(videoDetail.id);

                                        firestore.runTransaction((
                                          transaction,
                                        ) async {
                                          final docSnapshot = await transaction
                                              .get(docRef);
                                          if (!docSnapshot.exists) {
                                            transaction.set(docRef, {
                                              'businessId':
                                                  videoDetail.frontUserId,
                                              'videoId': videoDetail.id,
                                              'totalClicks': 1,
                                              'userIds': [
                                                currentUserDetails!.id,
                                              ],
                                            });
                                          } else {
                                            final data = docSnapshot.data()!;
                                            final userIds = List<String>.from(
                                              data['userIds'] ?? [],
                                            );
                                            if (!userIds.contains(
                                              currentUserDetails!.id,
                                            )) {
                                              transaction.update(docRef, {
                                                'totalClicks':
                                                    FieldValue.increment(1),
                                                'userIds':
                                                    FieldValue.arrayUnion([
                                                      currentUserDetails.id,
                                                    ]),
                                              });
                                            }
                                          }
                                        });

                                        controller.pauseCurrentVideo();
                                        showContactNowDialog(
                                          context,
                                          website: videoDetail.website ?? "",
                                          phoneNumber:
                                              videoDetail.contactPhone ?? "",
                                          latitude: videoDetail.latitude ?? "",
                                          longitude:
                                              videoDetail.longitude ?? "",
                                          email: videoDetail.contactEmail ?? "",
                                          videoId: videoDetail.id.toString(),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ColorUtils.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SvgPicture.asset(
                                          "assets/icons/contact.svg",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

          if (videoDetail.sponsorType == null)
            if (videoDetail.frontUserId != currentUserDetails?.id)
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: InkWell(
                        onTap: () {
                          if (!isAuthenticated) {
                            Get.toNamed(AppRoutes.signIn);
                            return;
                          }
                          controller.pauseCurrentVideo();
                          String? userId =
                              currentUserDetails?.id ?? currentUser!.id;
                          String? userImage =
                              currentUserDetails?.image ??
                              currentUser?.image ??
                              "";
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
  Widget _buildStaticButtons(
    WallVideos videoDetail,
    String loggedInUserId,
    BuildContext context,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share Button
        Column(
          children: [
            InkWell(
              onTap: () => _handleShare(videoDetail),
              child: SizedBox(
                height: 20.h,
                width: 20.h,
                child: SvgPicture.asset(
                  "assets/icons/share.svg",
                  fit: BoxFit.fill,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 2),
            Text(
              "share".tr,
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
            SizedBox(height: 8),
          ],
        ),

        // Save Button
        videoDetail.sponsorType == null
            ? Obx(() {
              // Check if video is already saved
              bool isSaved = saveController.savedVideos.any(
                (video) => video.id.toString() == videoDetail.id,
              );

              return Column(
                children: [
                  InkWell(
                    onTap: () async {
                      if (isAuthenticated) {
                        if (isSaved) {
                          // 1. Immediately remove from local list
                          saveController.savedVideos.removeWhere(
                            (video) =>
                                video.id.toString() ==
                                videoDetail.id.toString(),
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
                      } else {
                        Get.toNamed(AppRoutes.signIn);
                      }
                    },
                    child: SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: SvgPicture.asset(
                        "assets/icons/bookmark.svg",
                        fit: BoxFit.fill,
                        color: isSaved ? ColorUtils.primaryColor : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Save".tr,
                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                  ),
                  SizedBox(height: 8),
                ],
              );
            })
            : SizedBox.shrink(),

        // SizedBox(height: 16),
        // More Button
        if (videoDetail.frontUserId != loggedInUserId)
          Column(
            children: [
              InkWell(
                onTap: () {
                  controller.pauseCurrentVideo();
                  if (isAuthenticated) {
                    _showMoreOptions(
                      context,
                      videoDetail.id!,
                      videoDetail.frontUserId!,
                      loggedInUserId,
                    );

                    if (mounted) {
                      controller.restoreVideoState();
                    }
                  } else {
                    Get.toNamed(AppRoutes.signIn);
                  }
                },
                child: SizedBox(
                  height: 20.h,
                  width: 20.h,
                  child: SvgPicture.asset(
                    "assets/icons/more.svg",
                    fit: BoxFit.fill,
                    color: Colors.white,
                  ),
                ),
              ),
              // SizedBox(height: 2),
              Text(
                "more".tr,
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
      final String webUrl =
          "https://cookster.org/web/visitSingleVideo?id=$videoId";
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

  void _showMoreOptions(
    BuildContext context,
    String videoId,
    String frontUserId,
    String userId,
  ) {
    // _handleScreenExit();
    // controller.pauseCurrentVideo();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    controller.pauseCurrentVideo();
                    controller.blockUser(userId, frontUserId);
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
                    controller.pauseCurrentVideo();
                    Get.to(ReportContentView(videoId: videoId))?.then((_) {
                      controller.restoreVideoState();
                    });
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

class videoUserDetails extends StatelessWidget {
  const videoUserDetails({
    super.key,
    required this.profileController,
    required this.professionalProfileController,
    required this.videoDetail,
    required this.controller,
    required this.userId,
    required this.isAuthenticated,
  });

  final ProfileController profileController;
  final ProfessionalProfileController professionalProfileController;
  final WallVideos videoDetail;
  final HomeController controller;
  final String? userId;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Get.height * 0.05,
      left: 10,
      right: 10,
      child: SizedBox(
        width: Get.width * 1,
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth:
                    Get.width * 0.72, // Maximum width for the entire container
              ),
              decoration: BoxDecoration(
                color: Colors.transparent, // Transparent to show blur
                borderRadius: BorderRadius.circular(50),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  // Blur effect
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
                        mainAxisSize: MainAxisSize.min,
                        // Adjust width to content
                        children: [
                          InkWell(
                            onTap: () {
                              controller.pauseCurrentVideo();
                              Get.to(
                                VisitProfileView(
                                  userId: videoDetail.frontUserId!,
                                ),
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
                                                videoDetail
                                                    .userImage!
                                                    .isNotEmpty
                                            ? CachedNetworkImageProvider(
                                              '${Common.profileImage}/${videoDetail.userImage}',
                                            )
                                            : null,
                                    child:
                                        videoDetail.userImage == null ||
                                                videoDetail.userImage!.isEmpty
                                            ? Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            )
                                            : null,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            Get.width *
                                            0.3, // Max width for username
                                      ),
                                      child: Text(
                                        videoDetail.userName ?? 'Unknown User',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow:
                                            TextOverflow
                                                .ellipsis, // Ellipsis for overflow
                                      ),
                                    ),
                                    videoDetail.sponsorType != null
                                        ? Text(
                                          "Sponsored",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                        : Text(
                                          "${videoDetail.followersCount} ${"Followers".tr}",
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

                          if (userId != videoDetail.frontUserId &&
                              videoDetail.sponsorType == null)
                            InkWell(
                              onTap: () async {
                                // Store the current following status before the action
                                if (isAuthenticated) {
                                  bool wasFollowing = isFollowing;

                                  if (isProfileNull) {
                                    await profileController.toggleFollowStatus(
                                      videoDetail.frontUserId!,
                                    );
                                  } else {
                                    await professionalProfileController
                                        .toggleFollowStatus(
                                          videoDetail.frontUserId!,
                                        );
                                  }

                                  // Update the follower count based on the action
                                  if (wasFollowing) {
                                    // User unfollowed, decrease count
                                    videoDetail.followersCount =
                                        (videoDetail.followersCount ?? 1) - 1;
                                  } else {
                                    // User followed, increase count
                                    videoDetail.followersCount =
                                        (videoDetail.followersCount ?? 0) + 1;
                                  }
                                } else {
                                  Get.toNamed(AppRoutes.signIn);
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
                                  color:
                                      isFollowing ? Colors.white : Colors.black,
                                ),
                                child: Center(
                                  child: Text(
                                    isFollowing ? "Following".tr : "follow".tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isFollowing
                                              ? Colors.black
                                              : Colors.white,
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
          ],
        ),
      ),
    );
  }
}

void showLocationDialog(BuildContext context) {
  final HomeController homeController = Get.find();
  final VideoAddController controller = Get.find();
  final NavBarController profileController = Get.find();
  final UserSearchController searchUpdateController = Get.find();
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
  RxString selectedCountryName =
      (controller.selectedCountry.value.isNotEmpty
              ? controller.selectedCountry.value
              : '')
          .obs;

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
    Get.back();
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 360.w,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Header (Title + Close Button)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.black),
                    SizedBox(width: 8.w),
                    Text(
                      "select_country_dialog_label".tr,
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

            /// Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'search_country_placeholder'.tr,
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

            /// Scrollable Location List
            Container(
              height: 240.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCountryName.length,
                      (index) => Column(
                        children: [
                          InkWell(
                            onTap: () {
                              selectedCountryName.value =
                                  filteredCountryName[index];
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 260.w,
                                    ),
                                    child: Text(
                                      filteredCountryName[index],
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight:
                                            selectedCountryName.value ==
                                                    filteredCountryName[index]
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 20.w,
                                    height: 20.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ColorUtils.primaryColor,
                                        width: 2.r,
                                      ),
                                      color:
                                          selectedCountryName.value ==
                                                  filteredCountryName[index]
                                              ? ColorUtils.primaryColor
                                              : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < filteredCountryName.length - 1)
                            Divider(
                              height: 1.h,
                              thickness: 1.r,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            /// Submit Button
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCountryName.value.isNotEmpty
                        ? () async {
                          try {
                            String country = selectedCountryName.value;
                            controller.selectLocation(
                              country,
                              countryMap[country]!,
                            );
                            searchUpdateController.currentCountry.value =
                                country;
                            await cityController.fetchCities(
                              countryMap[country]!,
                            );
                            homeController.currentCountry.value = country;
                            Get.back(); // Close the country dialog
                            showCityDialog(context);
                          } catch (e) {
                            print('Error selecting country: $e');
                            Get.snackbar('Error', 'Failed to load cities');
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  "Submit".tr,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showCityDialog(BuildContext context, {int? initialCity}) {
  final VideoAddController controller = Get.find();
  final CityController cityController = Get.find<CityController>();
  final UserSearchController homeController = Get.find();
  final HomeController homeUpdateController = Get.find();

  // Assuming City model has id and name properties
  List<Map<String, dynamic>> cityList =
      cityController.cityList
          .map((city) => {'id': city.id, 'name': city.name})
          .toList();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<Map<String, dynamic>> filteredCityList = cityList.obs;
  Rx<Map<String, dynamic>> selectedCity = Rx<Map<String, dynamic>>(
    controller.selectedCity.value.isNotEmpty
        ? {
          'id':
              cityList.firstWhere(
                (city) => city['name'] == controller.selectedCity.value,
                orElse: () => {'id': -1, 'name': ''},
              )['id'],
          'name': controller.selectedCity.value,
        }
        : {'id': -1, 'name': ''},
  );

  // Pre-select city if initialCity is provided
  if (initialCity != null) {
    Map<String, dynamic> initialCityData = cityList.firstWhere(
      (city) => city['id'] == initialCity,
      orElse: () => {'id': -1, 'name': ''},
    );
    if (initialCityData['name'].isNotEmpty) {
      selectedCity.value = initialCityData;
    }
  }

  // Filter cities based on search input
  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityList.value = cityList;
    } else {
      filteredCityList.value =
          cityList
              .where(
                (city) =>
                    city['name'].toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Obx(
        () => Container(
          width: 350.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child:
              cityController.isLoading.value
                  ? Center(child: CircularProgressIndicator())
                  : Column(
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
                                "Select City".tr,
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
                          hintText: 'search_city_placeholder'.tr,
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(
                              color: ColorUtils.primaryColor,
                            ),
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
                              children: List.generate(filteredCityList.length, (
                                index,
                              ) {
                                var city = filteredCityList[index];
                                bool isSelected =
                                    selectedCity.value['id'] == city['id'] &&
                                    selectedCity.value['name'] == city['name'];

                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        selectedCity.value = city;
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: 200.w,
                                              ),
                                              child: Text(
                                                city['name'],
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 20.w,
                                              height: 20.w,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      ColorUtils.primaryColor,
                                                  width: 2,
                                                ),
                                                color:
                                                    isSelected
                                                        ? ColorUtils
                                                            .primaryColor
                                                        : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (index < filteredCityList.length - 1)
                                      Divider(
                                        height: 1.h,
                                        thickness: 1.r,
                                        color: Colors.grey.shade300,
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      /// **Submit Button**
                      Obx(
                        () => ElevatedButton(
                          onPressed:
                              selectedCity.value['name'].isNotEmpty
                                  ? () {
                                    try {
                                      int selectedId = selectedCity.value['id'];
                                      String selectedName =
                                          selectedCity.value['name'];
                                      print(
                                        "Selected City: $selectedName (ID: $selectedId)",
                                      );

                                      homeUpdateController.currentCityId.value =
                                          selectedId.toString();
                                      homeController.currentCity.value =
                                          selectedName;
                                      homeUpdateController.currentCity.value =
                                          selectedName;
                                      controller.selectedCity.value =
                                          selectedName;
                                      Get.back(); // Close the city dialog
                                    } catch (e) {
                                      print('Error selecting city: $e');
                                      Get.snackbar(
                                        'Error',
                                        'Failed to select city',
                                      );
                                    }
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            minimumSize: Size(double.infinity, 44.h),
                          ),
                          child: Text(
                            "Submit".tr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    ),
  );
}

class VideoDescriptionWidget extends StatefulWidget {
  final String? title;
  final String? description;
  final String? tags;
  final HomeController? controller;

  const VideoDescriptionWidget({
    this.title,
    this.description,
    this.tags,
    this.controller,
    super.key,
  });

  @override
  _VideoDescriptionWidgetState createState() => _VideoDescriptionWidgetState();
}

class _VideoDescriptionWidgetState extends State<VideoDescriptionWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _hasOverflow = false;
  bool _isTagExpanded = false;
  bool _hasTagOverflow = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light, // White icons ke liye
        statusBarColor:
            Colors.transparent, // Optional: Status bar background color
      ),
    );
    if (widget.description != null) {
      _textController.text = widget.description!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflowOnce();
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light, // White icons ke liye
            statusBarColor:
                Colors.transparent, // Optional: Status bar background color
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _checkOverflowOnce() {
    final descriptionStyle = TextStyle(color: Colors.white, fontSize: 14.sp);
    final tagStyle = TextStyle(color: ColorUtils.primaryColor, fontSize: 12.sp);

    const double maxDescriptionWidth = 250.0;
    const double maxTagWidth = 250.0;

    // Check description overflow
    final TextPainter descPainter = TextPainter(
      text: TextSpan(text: widget.description, style: descriptionStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxDescriptionWidth);

    // Check tag overflow
    final String tagLine =
        widget.tags?.split(',').map((t) => '#${t.trim()}').join(' ') ?? '';
    final TextPainter tagPainter = TextPainter(
      text: TextSpan(text: tagLine, style: tagStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTagWidth);

    if (mounted) {
      setState(() {
        _hasOverflow = descPainter.didExceedMaxLines;
        _hasTagOverflow = tagPainter.didExceedMaxLines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = TextStyle(color: Colors.white, fontSize: 14.sp);
    final tagStyle = TextStyle(color: ColorUtils.primaryColor, fontSize: 12.sp);

    return Positioned(
      bottom: Platform.isAndroid ? Get.height * 0.03 : Get.height * 0.03,
      left: 10,
      child: Container(
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            if (widget.title != null && widget.title!.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 150),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (widget.title != null && widget.title!.isNotEmpty)
              SizedBox(height: 4.h),

            // Description with expand/collapse
            if (widget.description != null && widget.description!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 250),
                      child: Text(
                        widget.description!,
                        style: descriptionStyle,
                        maxLines: _isExpanded ? null : 1,
                        overflow:
                            _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_hasOverflow)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isExpanded ? "show_less".tr : "show_more".tr,
                          style: TextStyle(
                            color: ColorUtils.primaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            if (widget.description != null && widget.description!.isNotEmpty)
              SizedBox(height: 4.h),

            // Tags with expand/collapse and tap functionality
            if (widget.tags != null && widget.tags!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 250),
                      child: RichText(
                        maxLines: _isTagExpanded ? null : 1,
                        overflow:
                            _isTagExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                        text: TextSpan(
                          children:
                              widget.tags!.split(',').map((tag) {
                                final trimmedTag = tag.trim();
                                return TextSpan(
                                  text: '#$trimmedTag ',
                                  style: tagStyle,
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          widget.controller
                                              ?.pauseCurrentVideo();

                                          Get.to(
                                            () => SearchView(
                                              tag: trimmedTag,
                                              // isFollowing: 1,
                                              isGeneral: 1,
                                            ),
                                          );
                                        },
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_hasTagOverflow)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isTagExpanded = !_isTagExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isTagExpanded ? "show_less".tr : "show_more".tr,
                          style: TextStyle(
                            color: ColorUtils.primaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              Text("#", style: tagStyle),
          ],
        ),
      ),
    );
  }
}
