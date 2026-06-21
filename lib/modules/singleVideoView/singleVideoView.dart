import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/text/hashtag_text.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/hashtagReelScreen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import '../../appBindings/app_bindings.dart';
import '../../appRoutes/appRoutes.dart';
import '../../services/apiClient.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingController/landingController.dart';
import '../landing/landingTabs/home/homeController/homeController.dart';
import '../landing/landingTabs/home/homeController/saveController.dart';
import '../landing/landingTabs/home/homeModel/userSaveUnsave.dart';
import '../landing/landingTabs/home/homeView/commentScreen.dart';
import '../landing/landingTabs/home/homeWidgets/contactNowDialog.dart';
import '../landing/landingTabs/home/homeWidgets/reviewSheet.dart';
import '../landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../landing/landingTabs/profile/profileControlller/profileController.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import '../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../video_likes_screen/video_likes_screen.dart';

class SingleVideoScreen extends StatefulWidget {
  final String? followers;
  final String? frondUserId;
  final String? userImage;
  final String? videoId;
  final String? videoUrl;
  final String? hlsUrl;
  final List<String> qualityMp4Urls;
  final String? thumbnailUrl;
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
    this.hlsUrl,
    this.qualityMp4Urls = const [],
    this.thumbnailUrl,
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
  String? _resolvedVideoUrl;
  String? _playerKey;
  bool _isPlaying = true;
  bool _isInitializing = true;
  bool _isMuted = false;
  bool _showPlayPauseIcon = false;
  bool _isImageMode = false;
  RxInt localFollowersCount = 0.obs;

  String? _resolveMediaUrl({String? primary, String? fallback}) {
    return MediaUrlResolver.playbackUrl(videoUrl: primary, video: fallback);
  }

  String? _resolveThumbnailUrl({String? thumbnail, String? image}) {
    return MediaUrlResolver.thumbnailUrl(
      thumbnailUrl: thumbnail,
      imageUrl: image,
      image: image,
    );
  }


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

  bool isAuthenticated = false;
  Timer? _viewTrackDebounce;
  final Set<String> _trackedVideoIds = <String>{};

  late final VideoCommentsController _videoCommentsController;
  Worker? _navTabWorker;

  @override
  void initState() {
    super.initState();
    ensureSingleVideoDependencies();
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().pauseReelsForRouteOverlay();
    } else {
      MediaKitPlayerPool.instance.silenceAllSync();
    }
    if (Get.isRegistered<NavBarController>()) {
      _navTabWorker = ever(
        Get.find<NavBarController>().selectedIndex,
        (_) {
          if (!mounted) return;
          setState(() => _isPlaying = false);
          _pauseVideo();
        },
      );
    }
    if (Get.isRegistered<VideoCommentsController>()) {
      _videoCommentsController = Get.find<VideoCommentsController>();
    } else {
      _videoCommentsController = Get.put(VideoCommentsController());
    }
    if (widget.followers != null) {
      localFollowersCount.value = int.tryParse(widget.followers!) ?? 0;
    }
    _loadLanguage();
    _scheduleViewTrack();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrapPlayer());
    unawaited(_checkAuthentication());
  }

  Future<void> _bootstrapPlayer() async {
    await prepareForFullscreenVideoPlayback();
    if (!mounted) {
      return;
    }
    await _resolvePlayback();
  }

  Future<void> _checkAuthentication() async {
    final bool authStatus = await _isUserAuthenticated(); // Await the Future
    setState(() {
      isAuthenticated = authStatus; // Update the state
    });
  }

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
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

  void _scheduleViewTrack() {
    final videoId = widget.videoId;
    if (videoId == null || videoId.isEmpty) return;
    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () {
      if (_trackedVideoIds.contains(videoId)) return;
      _trackedVideoIds.add(videoId);
      unawaited(_trackVideoView(videoId));
    });
  }

  Future<void> _trackVideoView(String videoId) async {
    try {
      final auth = await _isUserAuthenticated();
      await VideoViewTracker.trackUniqueView(
        videoId: videoId,
        userId: auth ? widget.frondUserId : null,
        isAuthenticated: auth,
      );
    } catch (e) {
      debugPrint('Error tracking video view: $e');
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

  Future<void> _resolvePlayback() async {
    if (widget.isImage == "1") {
      if (mounted) {
        setState(() {
          _isImageMode = true;
          _isInitializing = false;
        });
      }
      return;
    }

    final String? resolvedVideoUrl = _resolveMediaUrl(
          primary: widget.videoUrl,
          fallback: widget.image,
        ) ??
        widget.hlsUrl;

    if (resolvedVideoUrl == null) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'failed_to_load_video'.tr,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 20.0, left: 10.0, right: 10.0),
          ),
        );
      }
      return;
    }

    _resolvedVideoUrl = resolvedVideoUrl;
    _playerKey = widget.videoId?.isNotEmpty == true
        ? widget.videoId
        : resolvedVideoUrl;

    try {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'failed_to_load_video'.tr,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 20.0, left: 10.0, right: 10.0),
          ),
        );
      }
    }
  }

  void _pauseVideo() {
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.pause(key));
    }
  }

  void _resumeVideo() {
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.setActive(key));
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

  bool _isProcessing = false;

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  void dispose() {
    _navTabWorker?.dispose();
    _viewTrackDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final key = _playerKey;
    if (!_isImageMode && key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.release(key));
    }
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().resumeReelsAfterRouteOverlay();
    }
    super.dispose();
  }

  bool _followerChanged = false; // Track if follow status changed
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ProfileController profileController = Get.find<ProfileController>();
    final ProfessionalProfileController professionalProfileController =
        Get.find<ProfessionalProfileController>();
    final VideoCommentsController videoCommentsController =
        _videoCommentsController;
    bool isRtl = _language == 'ar';

    final SaveController saveController = Get.find<SaveController>();

    var currentUserDetails = profileController.simpleUserDetails.value?.user;
    var currentUser = professionalProfileController.userDetails.value?.user;
    String? userId = currentUser?.id ?? currentUserDetails?.id;

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: {'followerChanged': _followerChanged});
        return false; // Return false since we're handling navigation manually
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0),
        body: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,

            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (!_isInitializing && !_isImageMode) {
                      _togglePlayPause();
                    }
                  },
                  onDoubleTap: _isImageMode ? null : _toggleMute,
                  child: _isImageMode
                      ? (() {
                          final imageUrl = _resolveMediaUrl(
                            // For image posts, API may still send videoUrl;
                            // always prefer dedicated image field first.
                            primary: widget.image,
                            fallback: widget.videoUrl,
                          );
                          if (imageUrl == null) {
                            return Center(
                              child: Text(
                                'failed_to_load_video'.tr,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'failed_to_load_video'.tr,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })()
                      : _resolvedVideoUrl != null
                          ? ReelVideoPlayer(
                            key: ValueKey('single_${_playerKey}_ready'),
                            videoUrl: _resolvedVideoUrl!,
                            hlsUrl: widget.hlsUrl,
                            qualityMp4Urls: widget.qualityMp4Urls,
                            thumbnailUrl: _resolveThumbnailUrl(
                                  thumbnail: widget.thumbnailUrl ?? widget.image,
                                  image: widget.image,
                                ) ??
                                '',
                            posterFallbackUrl: widget.image,
                            videoId: _playerKey,
                            playerPoolKey: _playerKey,
                            releaseOnDispose: true,
                          )
                          : const SizedBox.shrink(),
                ),
              ),
              if (_isImageMode) const ReelPhotoBadge(),
              if (_showPlayPauseIcon && !_isInitializing && !_isImageMode)
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
                          color: Colors.black.withValues(alpha: 0.45),
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
                                Get.back(
                                  result: {'followerChanged': _followerChanged},
                                );
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
                                  ClipOval(
                                    child:
                                        widget.userImage != null &&
                                                widget.userImage!.isNotEmpty
                                            ? CachedNetworkImage(
                                              imageUrl:
                                                  MediaUrlResolver.profileImageUrl(widget.userImage) ?? '',
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              memCacheWidth: avatarMemCacheSize(
                                                40,
                                              ),
                                              memCacheHeight: avatarMemCacheSize(
                                                40,
                                              ),
                                              errorWidget:
                                                  (_, __, ___) => const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                  ),
                                            )
                                            : const CircleAvatar(
                                              radius: 20,
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      Obx(
                                        () => Text(
                                          "${localFollowersCount} ${"Followers".tr}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
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
                                    onTap: () async {
                                      bool isAuthenticated =
                                          await _isUserAuthenticated();

                                      if (isAuthenticated) {
                                        if (_isProcessing ||
                                            widget.frondUserId == null)
                                          return;

                                        _isProcessing = true;
                                        try {
                                          _followerChanged = true;
                                          if (isFollowing) {
                                            localFollowersCount.value--;
                                          } else {
                                            localFollowersCount.value++;
                                          }

                                          if (isProfileNull) {
                                            await profileController
                                                .toggleFollowStatus(
                                                  widget.frondUserId!,
                                                );
                                            debugPrint("User");
                                          } else {
                                            await professionalProfileController
                                                .toggleFollowStatus(
                                                  widget.frondUserId!,
                                                );
                                            debugPrint("Professional");
                                          }
                                        } finally {
                                          _isProcessing = false;
                                        }
                                      } else {
                                        Get.toNamed(AppRoutes.signIn);
                                        return;
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

              VideoDescriptionWidget(
                title: widget.title,
                description: widget.description,
                tags: widget.tags,
                pauseVideo: _pauseVideo,
              ),
              Positioned(
                right: 10,
                bottom: Get.height * 0.1,
                child: Column(
                  children: [
                    Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Column(
                            children: [
                              VideoLikesWidget(
                                videoId: widget.videoId ?? '',
                                userId: userId ?? '',
                                videoCommentsController:
                                    videoCommentsController,
                                isAuthenticated: isAuthenticated,
                              ),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: SvgPicture.asset(
                                  "assets/icons/eye.svg",
                                  fit: BoxFit.fill,
                                  color: Colors.white,
                                ),
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
                                    .doc(widget.videoId)
                                    .snapshots(),
                                builder: (context,
                                    snapshot,) {

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
                                      ? '${(viewCount / 1000)
                                      .toStringAsFixed(1)}K'
                                      : viewCount
                                      .toString();

                                  return Text(
                                    formattedViewCount,
                                    style:TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  );
                                },
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
                                  isAuthenticated: isAuthenticated,
                                ),
                              if (widget.allowComments == 1)
                                SizedBox(height: 8),
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
                                saveController.savedIdRevision.value;
                                final isSaved = saveController.isVideoSaved(
                                  widget.videoId.toString(),
                                );

                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        bool isAuthenticated =
                                            await _isUserAuthenticated();
                                        if (isAuthenticated) {
                                          if (isSaved) {
                                            // 1. Immediately remove from local list
                                            saveController.savedVideos
                                                .removeWhere(
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
                                        } else {
                                          Get.toNamed(AppRoutes.signIn);
                                          return;
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
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        bool isAuthenticated =
                                            await _isUserAuthenticated();
                                        if (isAuthenticated) {
                                          if (widget.videoId != null) {
                                            showMoreOptions(
                                              context,
                                              widget.videoId!,
                                              userId.toString(),
                                            );
                                          }
                                        } else {
                                          Get.toNamed(AppRoutes.signIn);
                                          return;
                                        }
                                      },
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 20.h,
                                              width: 20.h,
                                              child: SvgPicture.asset(
                                                "assets/icons/more.svg",
                                                fit: BoxFit.fill,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              "more".tr,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              userId != widget.frondUserId &&
                                      widget.takeOrder == "1" &&
                                      (widget.contactPhone?.isNotEmpty ==
                                              true ||
                                          widget.contactEmail?.isNotEmpty ==
                                              true ||
                                          widget.latitude?.isNotEmpty == true)
                                  ? Column(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        width: 40,
                                        height: 1,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          bool isAuthenticated =
                                              await _isUserAuthenticated();

                                          if (isAuthenticated) {
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
                                              final docSnapshot =
                                                  await transaction.get(docRef);

                                              if (!docSnapshot.exists) {
                                                // If document doesn't exist, create it with initial data
                                                transaction.set(docRef, {
                                                  'businessId':
                                                      widget.frondUserId,
                                                  'videoId': widget.videoId,
                                                  'totalClicks': 1,
                                                  'userIds': [userId],
                                                });
                                              } else {
                                                final data =
                                                    docSnapshot.data()!;
                                                final userIds =
                                                    List<String>.from(
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
                                              videoId:
                                                  widget.videoId.toString(),
                                            );
                                          } else {
                                            Get.toNamed(AppRoutes.signIn);
                                            return;
                                          }
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

                    SizedBox(height: 16.h),

                    if (widget.frondUserId != userId)
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  bool isAuthenticated =
                                      await _isUserAuthenticated();

                                  if (isAuthenticated) {
                                    _pauseVideo();
                                    String? userId =
                                        currentUserDetails?.id ??
                                        currentUser!.id;
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
                                  } else {
                                    Get.toNamed(AppRoutes.signIn);
                                    return;
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
                                      stream: _getAverageRating(
                                        widget.videoId!,
                                      ),
                                      builder: (context, snapshot) {
                                        final averageRating =
                                            snapshot.hasData &&
                                                    snapshot.data! > 0
                                                ? snapshot.data!
                                                    .toStringAsFixed(1)
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
                  ],
                ),
              ),
            ],
          ),
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
      final String appUrl = "cookster://open.cookster.app/video?id=$videoId";
      final String webUrl =
          "https://cookster.org/web/visitSingleVideo?id=$videoId";
      // Put the web app-link URL first because many messengers make only the
      // first URL richly clickable; keep custom scheme as direct fallback.
      final String shareMessage =
          'Check out this amazing video on Cookster!\n'
          '$webUrl\n\n'
          'Direct app link:\n$appUrl';
      await Share.share(shareMessage, subject: 'Cookster Video');
    } catch (e) {
      debugPrint('Error sharing video: $e');
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
    ensureSingleVideoDependencies();
    final PromoteVideoController promoteVideoController =
        Get.find<PromoteVideoController>();

    var infoEmail = promoteVideoController.siteSettings.value?.settings?.email;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: SafeArea(
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
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14.sp,
                      ),
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
                        debugPrint("===============");
                        debugPrint('$isDeleted');
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

                // ListTile(
                //   leading: Icon(Icons.headphones, color: ColorUtils.grey),
                //   trailing: Text(
                //     infoEmail!,
                //     style: TextStyle(color: Colors.black, fontSize: 14.sp),
                //   ),
                //   title: Text(
                //     'contact_us'.tr,
                //     style: TextStyle(color: Colors.black, fontSize: 14.sp),
                //   ),
                //   onTap: () async {
                //     final Uri emailUri = Uri(
                //       scheme: 'mailto',
                //       path: infoEmail,
                //       queryParameters: {
                //         'subject': 'Contact Us',
                //         // Optional: Pre-fill subject
                //         // 'body': 'Your message here', // Optional: Pre-fill body
                //       },
                //     );
                //
                //     // Launch the mail app
                //     if (await canLaunchUrl(emailUri)) {
                //       await launchUrl(emailUri);
                //     } else {
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(content: Text('No email app found')),
                //       );
                //     }
                //     Navigator.pop(context);
                //   },
                // ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VideoLikesWidget extends StatefulWidget {
  final String videoId;
  final String userId;
  final dynamic isAuthenticated;
  final VideoCommentsController videoCommentsController;

  const VideoLikesWidget({
    required this.videoId,
    required this.userId,
    required this.isAuthenticated,
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
                if (widget.isAuthenticated) {
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
                } else {
                  Get.toNamed(AppRoutes.signIn);
                }
                return null;
              },
            ),
            SizedBox(height: 2),
            InkWell(
              onTap: () {
                Get.to(VideoLikesScreen(videoId: widget.videoId));
              },
              child: Text(
                formattedLikeCount,
                style: TextStyle(color: Colors.white, fontSize: 10.sp),
              ),
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

  final dynamic isAuthenticated;

  const VideoCommentsWidget({
    required this.videoId,
    required this.userId,
    required this.userImage,
    required this.isAuthenticated,
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
        int commentCount = snapshot.data?.docs.length ?? 0;
        String formattedCount =
            commentCount > 1000
                ? '${(commentCount / 1000).toStringAsFixed(1)}K'
                : commentCount.toString();

        return Column(
          children: [
            InkWell(
              onTap: () {
                if (isAuthenticated) {
                  if (userId.isNotEmpty && videoId.isNotEmpty) {
                    showCommentsBottomSheetNew(
                      context,
                      videoId,
                      userId,
                      userImage,
                    );
                  }
                } else {
                  Get.toNamed(AppRoutes.signIn);
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
  Function? pauseVideo; // Add a callback to pause the video

  VideoDescriptionWidget({
    Key? key,
    this.title,
    this.description,
    this.tags,
    this.pauseVideo,
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
    final String tagLine = HashtagText.splitTags(widget.tags)
        .map(HashtagText.displayLabel)
        .join(' ');
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
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: HashtagText.splitTags(widget.tags).map((tag) {
                          final searchKey = HashtagText.searchKey(tag);
                          return InkWell(
                            onTap: () {
                              Get.off(
                                HashtagReelScreen(tag: searchKey),
                              );
                            },
                            child: Text(
                              HashtagText.displayLabel(tag),
                              style: tagStyle,
                            ),
                          );
                        }).toList(),
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
              ),
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
        debugPrint('Step 1: Initiating API call to delete video with ID: $videoId');
        // Step 1: Make API call to delete video
        final response = await ApiClient.deleteRequest(endpoint);

        debugPrint(
          'Step 2: API call completed. Status code: ${response.statusCode}',
        );
        debugPrint('API response body: ${response.body}');

        // Parse the API response
        final responseData = jsonDecode(response.body);
        debugPrint('Step 3: API response parsed successfully');

        // Assume the API returns a 'message' field in the JSON response
        final String apiMessage =
            responseData['message'] ?? 'No message provided by API';
        debugPrint('Step 4: Extracted API message: $apiMessage');

        if (response.statusCode == 201) {
          debugPrint(
            'Step 5: API call successful. Proceeding to delete Firestore document',
          );
          // Step 2: Delete video document from Firestore
          await FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .delete();
          debugPrint('Step 6: Firestore document deleted successfully');

          // Show success message from API at the top
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiMessage),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              duration: Duration(seconds: 3),
            ),
          );
          debugPrint('Step 7: Success SnackBar displayed');

          // Get.offAll(Landing());

          // Mark deletion as successful
          isDeleted = true;
          debugPrint('Step 8: Deletion marked as successful');
        } else {
          debugPrint(
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
          debugPrint('Step 6: Error SnackBar displayed for API failure');
        }
      } catch (e) {
        debugPrint('Error occurred during deletion: $e');
        // Show error message for any exception at the top
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
            duration: Duration(seconds: 3),
          ),
        );
        debugPrint('Error SnackBar displayed');
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
