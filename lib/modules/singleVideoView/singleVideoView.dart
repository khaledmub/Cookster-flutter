import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/text/hashtag_text.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/core/widgets/reel_action_rail.dart';
import 'package:cookster/core/widgets/reel_content_chrome.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/reel_video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart'
    show VideoDescriptionWidget;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:like_button/like_button.dart';
import 'package:cookster/core/share/cookster_share_links.dart';
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
    // Search/API may send is_image as 1, "1", true, or "true" — not only "1".
    // Also treat static-image URLs as photos when the flag is wrong/missing.
    final isPhoto = isReelGridPhotoPost(
      isImage: widget.isImage,
      videoUrl: widget.videoUrl,
      thumbnailUrl: widget.thumbnailUrl,
      imageUrl: widget.image,
      image: widget.image,
    );
    if (isPhoto) {
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

  /// Full-res photo URL for image posts (prefer cover/image_url over CDN thumb).
  String? get _photoDisplayUrl => MediaUrlResolver.photoDisplayUrl(
        videoUrl: widget.videoUrl,
        video: null,
        imageUrl: widget.image,
        image: widget.image,
        thumbnailUrl: widget.thumbnailUrl,
      ) ??
      _resolveMediaUrl(primary: widget.image, fallback: widget.thumbnailUrl) ??
      _resolveMediaUrl(primary: widget.thumbnailUrl, fallback: widget.videoUrl);

  void _pauseVideo() {
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      final player = MediaKitPlayerPool.instance.playerForKey(key);
      if (player != null) {
        try {
          unawaited(player.pause());
        } catch (_) {}
      }
    }
  }

  void _resumeVideo() {
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.unmuteAndPlay(key));
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
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      final player = MediaKitPlayerPool.instance.playerForKey(key);
      if (player != null) {
        setState(() {
          _isMuted = !_isMuted;
        });
        try {
          unawaited(player.setVolume(_isMuted ? 0 : 100));
        } catch (_) {}
      }
    }
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
                          final imageUrl = _photoDisplayUrl;
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
                userName: widget.userName,
                isPhotoPost: _isImageMode,
                tiktokStyle: true,
                bottomBarClearance: Get.height * 0.13,
              ),
              FutureBuilder<bool>(
                future: _isUserAuthenticated(),
                builder: (context, authSnap) {
                  final authed = authSnap.data ?? false;
                  return ReelActionRail(
                    video: wallVideoForReelActions(
                      id: widget.videoId,
                      frontUserId: widget.frondUserId,
                      takeOrder: widget.takeOrder == '1' ? 1 : 0,
                      allowComments: widget.allowComments,
                      userName: widget.userName,
                      userImage: widget.userImage,
                      contactPhone: widget.contactPhone,
                      contactEmail: widget.contactEmail,
                      website: widget.website,
                      latitude: widget.latitude,
                      longitude: widget.longitude,
                    ),
                    isAuthenticated: authed,
                    layout: ReelActionRailLayout.standalone,
                    onBeforeNavigation: _pauseVideo,
                  );
                },
              ),            ],
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
      final String shareMessage =
          CooksterShareLinks.videoShareMessage(videoId);
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
  final String? videoOwnerId;

  final dynamic isAuthenticated;

  const VideoCommentsWidget({
    required this.videoId,
    required this.userId,
    required this.userImage,
    this.videoOwnerId,
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
                      videoOwnerId: videoOwnerId,
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
