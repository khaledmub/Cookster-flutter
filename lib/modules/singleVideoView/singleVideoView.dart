import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/hashTagReels.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:cookster/modules/search/searchView/searchView.dart';
import 'package:cookster/modules/singleVideoView/singleVideoController.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../loaders/pulseLoader.dart';
import '../../services/apiClient.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingTabs/home/homeController/saveController.dart';
import '../landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import '../landing/landingTabs/home/homeView/commentScreen.dart';
import '../landing/landingTabs/home/homeWidgets/contactNowDialog.dart';
import '../landing/landingTabs/home/homeWidgets/reviewSheet.dart';
import '../landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../landing/landingTabs/profile/profileControlller/profileController.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';

class SingleVideoScreen extends StatefulWidget {
  final String? followers;
  final String? frondUserId;
  final String? userImage;
  final String? videoId;
  final String? videoUrl;
  final String? title;
  final String? description;
  final String? tags;
  final String? image;
  final String? userName;
  final String? createdAt;
  final int? allowComments;
  final String? takeOrder;
  final String? contactPhone;
  final String? contactEmail;
  final String? website;
  final String? latitude;
  final String? longitude;
  final String? isImage;
  final String? userEmail;

  SingleVideoScreen({
    this.followers,
    this.frondUserId,
    this.userImage,
    this.videoId,
    this.videoUrl,
    this.title,
    this.description,
    this.tags,
    this.image,
    this.userName,
    this.createdAt,
    this.allowComments,
    this.takeOrder,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.latitude,
    this.longitude,
    this.isImage,
    this.userEmail,
  });

  @override
  _SingleVideoScreenState createState() => _SingleVideoScreenState();
}

class _SingleVideoScreenState extends State<SingleVideoScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = true;
  bool _isInitializing = true;
  bool _isMuted = false;
  bool _showPlayPauseIcon = false;

  // static final CustomCacheManager _cacheManager = CustomCacheManager._();

  @override
  bool get wantKeepAlive => true;

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
    _loadLanguage();
    _trackVideoView(
      widget.videoId ?? '',
      widget.frondUserId,
      widget.frondUserId != null ? true : false,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    } else if (state == AppLifecycleState.resumed) {
      if (_isPlaying) {
        _resumeVideo();
      }
    }
  }

  Future<void> _initializePlayer() async {
    final videoUrl = '${Common.videoUrl}/${widget.videoUrl}';
    print("PRINTING VIDEO URL: ${videoUrl}");

    try {
      // Check if the video is already cached
      // FileInfo? cachedFile = await _cacheManager.getFileFromCache(videoUrl);
      //
      // if (cachedFile == null || !cachedFile.file.existsSync()) {
      //   // If not cached or cache is invalid, download and cache the video
      //   cachedFile = await _cacheManager.downloadFile(videoUrl);
      // }

      // Use the cached file if available
      // if (cachedFile != null && cachedFile.file.existsSync()) {
      //   _videoPlayerController = VideoPlayerController.file(
      //     cachedFile.file,
      //     videoPlayerOptions: VideoPlayerOptions(
      //       mixWithOthers: false,
      //       allowBackgroundPlayback: false,
      //     ),
      //   );
      // } else {
      //   // Fallback to network if caching fails
      //
      // }

      _videoPlayerController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize the video player
      await _videoPlayerController.initialize();

      // Configure Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        showControls: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowPlaybackSpeedChanging: false,
        allowMuting: false,
        allowFullScreen: false,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        Get.snackbar(
          'Error',
          'Failed to load video',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _pauseVideo() {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    }
  }

  void _resumeVideo() {
    if (!_videoPlayerController.value.isPlaying) {
      _videoPlayerController.play();
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showPlayPauseIcon = true;
    });

    if (_isPlaying) {
      _resumeVideo();
    } else {
      _pauseVideo();
    }

    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  // Future<void> _clearCache() async {
  //   final videoUrl = '${Common.videoUrl}/${widget.videoUrl}';
  //   try {
  //     await _cacheManager.removeFile(videoUrl);
  //     print('Cache cleared for $videoUrl');
  //   } catch (e) {
  //     print('Error clearing cache: $e');
  //   }
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseVideo();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    // _clearCache(); // Clear cache when screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ProfileController profileController = Get.find();
    final ProfessionalProfileController professionalProfileController =
        Get.find();
    final VideoCommentsController videoCommentsController = Get.put(
      VideoCommentsController(),
    );
    bool isRtl = _language == 'ar';

    print("PRINTING VIDEO ID: ${widget.isImage}");

    final SaveController saveController = Get.find();

    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;

    return WillPopScope(
      onWillPop: () async {
        // _pauseVideo();
        // await _clearCache(); // Clear cache when user presses back
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0),
        body: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomLeft,

          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (!_isInitializing) {
                    _togglePlayPause();
                  }
                },
                onDoubleTap: _toggleMute,
                child:
                    _isInitializing
                        ? Center(
                          child: PulseLogoLoader(
                            logoPath: "assets/images/appIcon.png",
                            size: 80,
                          ),
                        )
                        : _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : SizedBox.shrink(),
              ),
            ),
            if (widget.isImage == "0")
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child:
                    _isInitializing
                        ? SizedBox.shrink()
                        : EnhancedSeekBar(controller: _videoPlayerController),
              ),
            if (_showPlayPauseIcon && !_isInitializing)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64.0,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            Positioned(
              top: Get.height * 0.05,
              left: isRtl ? null : 16,
              right: isRtl ? 16 : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          Get.width *
                          0.88, // Maximum width for the entire container
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        // Shrink Row to fit content
                        children: [
                          InkWell(
                            onTap: () {
                              // _pauseVideo();
                              // _clearCache(); // Clear cache when back arrow is tapped
                              Get.back();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              // Shrink inner Row
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                // SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 20, // Adjust size as needed
                                  backgroundImage:
                                      widget.userImage != null &&
                                              widget.userImage!.isNotEmpty
                                          ? NetworkImage(
                                            '${Common.profileImage}/${widget.userImage}',
                                          )
                                          : null,
                                  child:
                                      widget.userImage == null ||
                                              widget.userImage!.isEmpty
                                          ? Icon(
                                            Icons.person,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            Get.width *
                                            0.3, // Max width for username
                                      ),
                                      child: Text(
                                        widget.userName ?? 'Unknown User',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.sp,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "${widget.followers ?? ''} ${"Followers".tr}",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                          if (userId != widget.frondUserId)
                            Obx(() {
                              var isProfileNull =
                                  professionalProfileController
                                      .userDetails
                                      .value
                                      ?.user ==
                                  null;
                              bool isFollowing =
                                  isProfileNull && widget.frondUserId != null
                                      ? profileController.isFollowing(
                                        widget.frondUserId!,
                                      )
                                      : widget.frondUserId != null
                                      ? professionalProfileController
                                          .isFollowing(widget.frondUserId!)
                                      : false;

                              return Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: InkWell(
                                  onTap: () {
                                    if (widget.frondUserId == null) return;
                                    if (isProfileNull) {
                                      profileController.toggleFollowStatus(
                                        widget.frondUserId!,
                                      );
                                    } else {
                                      professionalProfileController
                                          .toggleFollowStatus(
                                            widget.frondUserId!,
                                          );
                                    }
                                  },
                                  child: Container(
                                    height: 30,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white),
                                      color:
                                          isFollowing
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                    child: Center(
                                      child: Text(
                                        isFollowing
                                            ? "Following".tr
                                            : "follow".tr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color:
                                              isFollowing
                                                  ? Colors.black
                                                  : Colors.white,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            VideoDescriptionWidget(
              title: widget.title,
              description: widget.description,
              tags: widget.tags,
            ),
            Positioned(
              right: 10,
              bottom: Get.height * 0.1,
              child: Column(
                children: [
                  ClipRRect(
                    // Use ClipRRect to confine the blur effect
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
                        child: Column(
                          children: [
                            VideoLikesWidget(
                              videoId: widget.videoId ?? '',
                              userId: userId ?? '',
                              videoCommentsController: videoCommentsController,
                            ),
                            SizedBox(height: 8),

                            // Comments Section (Extracted into a separate widget)
                            if (widget.allowComments == 1)
                              VideoCommentsWidget(
                                videoId: widget.videoId ?? '',
                                userId: userId ?? '',
                                userImage:
                                    currentUserDetails?.image ??
                                    currentUser?.image ??
                                    '',
                              ),
                            if (widget.allowComments == 1) SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                if (widget.videoId != null) {
                                  _handleShare(widget.videoId!);
                                }
                              },
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 20.h,
                                    width: 20.h,
                                    child: SvgPicture.asset(
                                      "assets/icons/share.svg",
                                      fit: BoxFit.fill,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    "share".tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),

                            Obx(() {
                              // Check if video is already saved
                              bool isSaved = saveController.savedVideos.any(
                                (video) =>
                                    video.id.toString() == widget.videoId,
                              );

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      if (isSaved) {
                                        // 1. Immediately remove from local list
                                        saveController.savedVideos.removeWhere(
                                          (video) =>
                                              video.id.toString() ==
                                              widget.videoId.toString(),
                                        );

                                        // 2. Then hit API
                                        await saveController.saveVideo(
                                          widget.videoId!,
                                        );
                                      } else {
                                        // 1. Immediately add to local list
                                        saveController.savedVideos.add(
                                          SavedVideos(
                                            id: widget.videoId,

                                            // Add other fields if needed, or just id is fine for now
                                          ),
                                        );

                                        // 2. Then hit API
                                        await saveController.saveVideo(
                                          widget.videoId!,
                                        );
                                      }
                                    },
                                    child: SizedBox(
                                      height: 20.h,
                                      width: 20.h,
                                      child: SvgPicture.asset(
                                        "assets/icons/bookmark.svg",
                                        fit: BoxFit.fill,
                                        color:
                                            isSaved
                                                ? ColorUtils.primaryColor
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Save".tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              );
                            }),
                            SizedBox(height: 8),
                            if (widget.frondUserId != userId)
                              Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (widget.videoId != null) {
                                        showMoreOptions(
                                          context,
                                          widget.videoId!,
                                          userId.toString(),
                                        );
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
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),

                            userId != widget.frondUserId &&
                                    widget.takeOrder == "1" &&
                                    (widget.contactPhone?.isNotEmpty == true ||
                                        widget.contactEmail?.isNotEmpty ==
                                            true ||
                                        widget.latitude?.isNotEmpty == true)
                                ? Column(
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
                                        final businessId =
                                            widget.frondUserId.toString();
                                        final firestore =
                                            FirebaseFirestore.instance;
                                        final docRef = firestore
                                            .collection('countContactClick')
                                            .doc(businessId);

                                        // Run transaction to ensure atomic update
                                        firestore.runTransaction((
                                          transaction,
                                        ) async {
                                          final docSnapshot = await transaction
                                              .get(docRef);

                                          if (!docSnapshot.exists) {
                                            // If document doesn't exist, create it with initial data
                                            transaction.set(docRef, {
                                              'businessId': widget.frondUserId,
                                              'videoId': widget.videoId,
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
                                                'totalClicks':
                                                    FieldValue.increment(1),
                                                'userIds':
                                                    FieldValue.arrayUnion([
                                                      userId,
                                                    ]),
                                              });
                                            }
                                          }
                                        });

                                        showContactNowDialog(
                                          context,
                                          website: widget.website ?? "",
                                          phoneNumber:
                                              widget.contactPhone ?? "",
                                          latitude: widget.latitude ?? "",
                                          longitude: widget.longitude ?? "",
                                          email: widget.contactEmail ?? "",
                                          videoId: widget.videoId.toString(),
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
                                )
                                : SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  if (widget.frondUserId != userId)
                    Container(
                      margin: EdgeInsets.only(top: 16),
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
                                _pauseVideo();
                                String? userId =
                                    currentUserDetails?.id ?? currentUser!.id;
                                String? userImage =
                                    currentUserDetails?.image ??
                                    currentUser?.image ??
                                    "";
                                showReviewsBottomSheet(
                                  context,
                                  widget.videoId!,
                                  userId!,
                                  userImage!,
                                );
                              },
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.amberAccent,
                                    size: 40,
                                  ),
                                  StreamBuilder<double>(
                                    stream: _getAverageRating(widget.videoId!),
                                    builder: (context, snapshot) {
                                      final averageRating =
                                          snapshot.hasData && snapshot.data! > 0
                                              ? snapshot.data!.toStringAsFixed(
                                                1,
                                              )
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
            ),
          ],
        ),
      ),
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

  void _handleShare(String videoId) async {
    _pauseVideo();
    try {
      final String webUrl = "https://cookster.org/visitSingleVideo?id=$videoId";
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
      if (_isPlaying) {
        _resumeVideo();
      }
    }
  }

  void showMoreOptions(BuildContext context, String videoId, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
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
              if (widget.frondUserId == userId)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.redAccent),
                  trailing: Icon(Icons.delete, color: Colors.redAccent),
                  title: Text(
                    'delete_video'.tr,
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.sp),
                  ),
                  onTap: () async {
                    // Close the bottom sheet first
                    Navigator.pop(bottomSheetContext);
                    // Pause the video to prevent it from playing during deletion
                    _pauseVideo();
                    // Call deleteVideo with the original context
                    final bool isDeleted = await deleteVideo(
                      context,
                      videoId,
                      userId,
                    );
                    if (isDeleted) {
                      print("===============");
                      print(isDeleted);
                      Navigator.pop(context); // Close the bottom sheet
                      // Ensure navigation happens after successful deletion
                      Get.back();
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
                  Navigator.pop(bottomSheetContext); // Close bottom sheet
                  Get.to(ReportContentView(videoId: videoId));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class EnhancedSeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Color primaryColor;
  final Color backgroundColor;

  const EnhancedSeekBar({
    required this.controller,
    this.primaryColor = ColorUtils.primaryColor,
    this.backgroundColor = ColorUtils.darkBrown,
  });

  @override
  _EnhancedSeekBarState createState() => _EnhancedSeekBarState();
}

class _EnhancedSeekBarState extends State<EnhancedSeekBar>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  double _bufferedProgress = 0.0;
  bool _isDragging = false;
  Timer? _updateTimer;
  late AnimationController _animationController;
  String _tooltipText = "0:00";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _updateTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      _updateProgressFromVideo();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateProgressFromVideo() {
    if (!_isDragging && widget.controller.value.isInitialized && mounted) {
      final duration = widget.controller.value.duration.inMilliseconds;
      if (duration > 0) {
        final currentPosition = widget.controller.value.position.inMilliseconds;
        double maxBufferedEnd = 0.0;
        if (widget.controller.value.buffered.isNotEmpty) {
          maxBufferedEnd = widget.controller.value.buffered
              .map((range) => range.end.inMilliseconds / duration)
              .reduce((max, buffered) => max > buffered ? max : buffered);
        }
        setState(() {
          _progress = currentPosition / duration;
          _bufferedProgress = maxBufferedEnd;
          _tooltipText = _formatDuration(
            Duration(milliseconds: currentPosition),
          );
        });
      }
    }
  }

  void _updateProgress(double newProgress) {
    final clampedProgress = newProgress.clamp(0.0, 1.0);
    setState(() {
      _progress = clampedProgress;
      _tooltipText = _formatDuration(
        widget.controller.value.duration * clampedProgress,
      );
    });
    final newPosition = widget.controller.value.duration * clampedProgress;
    widget.controller.seekTo(newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Get.width,
      height: 60, // Increased height for much better touch area
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Ensures the entire area is touch-sensitive
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
          _animationController.forward();
          if (widget.controller.value.isPlaying) {
            widget.controller.pause();
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          _animationController.reverse();
          if (widget.controller.value.isInitialized) {
            widget.controller.play();
          }
        },
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          _updateProgress(localPosition.dx / box.size.width);
        },
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          _updateProgress(localPosition.dx / box.size.width);
        },
        child: Center(
          child: Container(
            width: Get.width,
            height: 30,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background positioned in center
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: Get.width,
                    height: _isDragging ? 12 : 8,
                    // Increased height for better visibility
                    decoration: BoxDecoration(
                      color: widget.backgroundColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // Buffered progress
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isDragging ? 12 : 8, // Match the background height
                    width: Get.width * _bufferedProgress,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // Progress bar with gradient
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isDragging ? 12 : 8, // Match the background height
                    width: Get.width * _progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.7),
                          widget.primaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // Thumb precisely at the end of the progress bar
                Positioned(
                  left: (Get.width * _progress),
                  top: 15, // Center vertically in the container
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final thumbSize =
                          16.0 + (_animationController.value * 12);
                      return Transform.translate(
                        offset: Offset(-thumbSize / 2, -thumbSize / 2),
                        // Center the thumb on the progress point
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Tooltip
                if (_isDragging)
                  Positioned(
                    left: (Get.width * _progress),
                    top: -15, // Position above the progress bar
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(-20, 0),
                          // Center tooltip above the thumb
                          child: AnimatedOpacity(
                            opacity: _animationController.value,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _tooltipText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoLikesWidget extends StatefulWidget {
  final String videoId;
  final String userId;
  final VideoCommentsController videoCommentsController;

  const VideoLikesWidget({
    required this.videoId,
    required this.userId,
    required this.videoCommentsController,
    super.key,
  });

  @override
  _VideoLikesWidgetState createState() => _VideoLikesWidgetState();
}

class _VideoLikesWidgetState extends State<VideoLikesWidget> {
  bool? _localIsLiked; // Track local like state for optimistic updates
  int? _localLikeCount; // Track local like count

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('videos')
              .doc(widget.videoId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              LikeButton(
                size: 20.h,
                circleColor: CircleColor(
                  start: Colors.red[200]!,
                  end: Colors.red[400]!,
                ),
                bubblesColor: BubblesColor(
                  dotPrimaryColor: Colors.red[300]!,
                  dotSecondaryColor: Colors.red[200]!,
                ),
                likeBuilder:
                    (bool isLiked) => SizedBox(
                      height: 20.h,
                      width: 20.h,
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
              ),
              const SizedBox(height: 2),
              const Text("...", style: TextStyle(color: Colors.white)),
            ],
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        List<dynamic> likes = data['likes'] ?? [];
        int likeCount = likes.length; // Count likes from array length

        // Use local state if available, otherwise fall back to Firestore data
        bool isLiked = _localIsLiked ?? likes.contains(widget.userId);
        int displayLikeCount = _localLikeCount ?? likeCount;
        String formattedLikeCount =
            likeCount > 1000
                ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                : likeCount.toString();

        return Column(
          children: [
            LikeButton(
              size: 20.h,
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
                  (bool isLiked) => SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: SvgPicture.asset(
                      "assets/icons/heart.svg",
                      fit: BoxFit.fill,
                      color: isLiked ? Colors.red : Colors.white,
                    ),
                  ),
              onTap: (currentIsLiked) async {
                final String videoId = widget.videoId;
                String userId = widget.userId;
                HapticFeedback.lightImpact();

                // Optimistic UI update
                final optimisticLikes = List<dynamic>.from(likes);
                if (currentIsLiked) {
                  optimisticLikes.remove(userId);
                } else {
                  optimisticLikes.add(userId);
                }
                await widget.videoCommentsController.toggleVideoLike(
                  videoId.toString(),
                  userId.toString(),
                );

                return !currentIsLiked;
              },
            ),
            SizedBox(height: 2),
            Text(
              formattedLikeCount,
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
          ],
        );
      },
    );
  }
}

// Widget for Comments
class VideoCommentsWidget extends StatelessWidget {
  final String videoId;
  final String userId;
  final String userImage;

  const VideoCommentsWidget({
    required this.videoId,
    required this.userId,
    required this.userImage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .collection('comments')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              SvgPicture.asset(
                "assets/icons/comment.svg",
                fit: BoxFit.fill,
                color: Colors.white,
              ),
              SizedBox(height: 2),
              Text("...", style: TextStyle(color: Colors.white)),
            ],
          );
        }

        int commentCount = snapshot.data?.docs.length ?? 0;
        String formattedCount =
            commentCount > 1000
                ? '${(commentCount / 1000).toStringAsFixed(1)}K'
                : commentCount.toString();

        return Column(
          children: [
            InkWell(
              onTap: () {
                if (userId.isNotEmpty && videoId.isNotEmpty) {
                  showCommentsBottomSheetNew(
                    context,
                    videoId,
                    userId,
                    userImage,
                  );
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
              formattedCount,
              style: TextStyle(color: Colors.white, fontSize: 10.sp),
            ),
          ],
        );
      },
    );
  }
}

class VideoDescriptionWidget extends StatefulWidget {
  final String? title;
  final String? description;
  final String? tags;

  const VideoDescriptionWidget({
    Key? key,
    this.title,
    this.description,
    this.tags,
  }) : super(key: key);

  @override
  _VideoDescriptionWidgetState createState() => _VideoDescriptionWidgetState();
}

class _VideoDescriptionWidgetState extends State<VideoDescriptionWidget> {
  bool _isExpanded = false;
  bool _hasOverflow = false;
  bool _isTagExpanded = false;
  bool _hasTagOverflow = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.description != null) {
      _textController.text = widget.description!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflowOnce();
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
      bottom: Get.height * 0.13,
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
              Text(
                widget.title!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            if (widget.title != null && widget.title!.isNotEmpty)
              SizedBox(height: 4.h),

            // Description with Show More/Show Less
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

            // Tags with Show More/Show Less
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
                      child: InkWell(
                        onTap: () {
                          Get.to(SearchView(tag: widget.tags, isGeneral: 1));
                        },
                        child: Text(
                          widget.tags!
                              .split(',')
                              .map((t) => '#${t.trim()}')
                              .join(' '),
                          style: tagStyle,
                          maxLines: _isTagExpanded ? null : 1,
                          overflow:
                              _isTagExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
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

Future<bool> deleteVideo(
  BuildContext context,
  String videoId,
  String frondUserId,
) async {
  final String endpoint = '${EndPoints.deleteVideo}?id=$videoId';
  bool isDeleted = false;

  // Check user authorization
  final prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('user_id');
  if (userId == null || userId != frondUserId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You are not authorized to delete this video'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        duration: Duration(seconds: 3),
      ),
    );
    return false;
  }

  // Show confirmation dialog
  await AwesomeDialog(
    context: context,
    dialogType: DialogType.warning,
    animType: AnimType.scale,
    title: 'delete_video'.tr,
    desc: 'sure_to_delete'.tr,
    btnCancelOnPress: () {
      // Return false if the user cancels
      isDeleted = false;
    },
    btnOkOnPress: () async {
      try {
        print('Step 1: Initiating API call to delete video with ID: $videoId');
        // Step 1: Make API call to delete video
        final response = await ApiClient.deleteRequest(endpoint);

        print(
          'Step 2: API call completed. Status code: ${response.statusCode}',
        );
        print('API response body: ${response.body}');

        // Parse the API response
        final responseData = jsonDecode(response.body);
        print('Step 3: API response parsed successfully');

        // Assume the API returns a 'message' field in the JSON response
        final String apiMessage =
            responseData['message'] ?? 'No message provided by API';
        print('Step 4: Extracted API message: $apiMessage');

        if (response.statusCode == 201) {
          print(
            'Step 5: API call successful. Proceeding to delete Firestore document',
          );
          // Step 2: Delete video document from Firestore
          await FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .delete();
          print('Step 6: Firestore document deleted successfully');

          // Show success message from API at the top
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiMessage),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              duration: Duration(seconds: 3),
            ),
          );
          print('Step 7: Success SnackBar displayed');

          Get.offAll(Landing());

          // Mark deletion as successful
          isDeleted = true;
          print('Step 8: Deletion marked as successful');
        } else {
          print(
            'Step 5: API call failed with status code: ${response.statusCode}',
          );
          // API call failed, show the API's error message at the top
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiMessage),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              duration: Duration(seconds: 3),
            ),
          );
          print('Step 6: Error SnackBar displayed for API failure');
        }
      } catch (e) {
        print('Error occurred during deletion: $e');
        // Show error message for any exception at the top
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
            duration: Duration(seconds: 3),
          ),
        );
        print('Error SnackBar displayed');
      }
    },
    btnOkText: 'yes_delete'.tr,
    btnCancelText: 'cancel'.tr,
  ).show();

  return isDeleted;
}

Future<http.Response> rateVideo(String videoId, double averageRating) async {
  final data = {"video_id": videoId, "average_rating": averageRating};
  return await ApiClient.postRequest(
    "${EndPoints.addVideoRating}",
    data,
  ); // Adjust endpoint as needed
}
