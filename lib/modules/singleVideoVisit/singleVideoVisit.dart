import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/core/firestore/video_view_tracker.dart';
import 'package:cookster/core/video/fullscreen_video_playback.dart';
import 'package:cookster/core/video/media_kit_player_pool.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeWidgets/videoPlayerWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/singleVideoVisit/singleVideoController/singleVisitVideoController.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../appBindings/app_bindings.dart';
import '../../services/apiClient.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import '../landing/landingView/landingView.dart';
import '../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../singleVideoView/singleVideoView.dart';

class SingleVisitVideo extends StatefulWidget {
  final String videoId; // Required URL parameter

  const SingleVisitVideo({
    Key? key, // always support passing a key
    required this.videoId,
  }) : super(key: key);

  @override
  State<SingleVisitVideo> createState() => _SingleVideoVisitState();
}

class _SingleVideoVisitState extends State<SingleVisitVideo>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final SingleVisitVideoController singleVideoController = Get.put(
    SingleVisitVideoController(),
  );

  String? _resolvedVideoUrl;
  String? _playerKey;
  bool _isPlaying = true;
  bool _isInitializing = true;
  bool _isMuted = false;
  bool _showPlayPauseIcon = false;
  String? _frontUserId; // Store the user ID from SharedPreferences
  String? _frontUserImage; // Store the user ID from SharedPreferences
  String _language = 'en'; // Default to English
  bool _hasInitializedPlayer = false;
  Timer? _viewTrackDebounce;
  final Set<String> _trackedVideoIds = <String>{};
  Worker? _loadingWorker;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register lifecycle observer
    _loadLanguage();
    _initializeUserId();
    singleVideoController.fetchSingleVideo(widget.videoId);

    // Listen to the controller's loading state
    _loadingWorker = ever(singleVideoController.isLoading, (isLoading) {
      if (!isLoading && !_hasInitializedPlayer) {
        _initializePlayer();
      }
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

  void _scheduleViewTrack(String videoId) {
    if (videoId.isEmpty) return;
    _viewTrackDebounce?.cancel();
    _viewTrackDebounce = Timer(const Duration(seconds: 2), () {
      if (_trackedVideoIds.contains(videoId)) return;
      _trackedVideoIds.add(videoId);
      unawaited(
        VideoViewTracker.trackUniqueView(
          videoId: videoId,
          userId: _frontUserId,
          isAuthenticated: _frontUserId != null && _frontUserId!.isNotEmpty,
        ),
      );
    });
  }

  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
  }

  // Initialize user ID from SharedPreferences
  Future<void> _initializeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _frontUserId = prefs.getString('user_id');
      _frontUserImage = prefs.getString('user_image');
    });
  }

  static final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();
  final VideoCommentsController videoCommentsController = Get.put(
    VideoCommentsController(),
  );

  Future<void> _initializePlayer() async {
    if (_hasInitializedPlayer) return;

    await prepareForFullscreenVideoPlayback();

    final video = singleVideoController.singleVideoContent.value.video;
    if (video?.video == null) {
      print("Video data not available for initialization");
      return;
    }

    _hasInitializedPlayer = true;
    final videoId = video?.id?.toString();
    if (videoId != null && videoId.isNotEmpty) {
      _scheduleViewTrack(videoId);
    }

    if (video!.isImage.toString() == '1') {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      return;
    }

    _resolvedVideoUrl = video.videoUrl?.isNotEmpty == true
        ? video.videoUrl!
        : '${Common.videoUrl}/${video.video}';
    _playerKey = video.id?.isNotEmpty == true ? video.id : _resolvedVideoUrl;
    print("PRINTING VIDEO URL: $_resolvedVideoUrl");

    try {
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
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.pause(key));
      setState(() {
        _isPlaying = false;
        _showPlayPauseIcon = true;
      });
    }
  }

  void _resumeVideo() {
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.setActive(key));
      setState(() {
        _isPlaying = true;
        _showPlayPauseIcon = true;
      });
    }
  }

  void _togglePlayPause() {
    if (_resolvedVideoUrl == null) return;

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
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!_isInitializing && _resolvedVideoUrl != null) {
        _resumeVideo();
      }
    } else if (state == AppLifecycleState.paused) {
      _pauseVideo();
    }
  }

  @override
  void dispose() {
    _loadingWorker?.dispose();
    _viewTrackDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final key = _playerKey;
    if (key != null && key.isNotEmpty) {
      unawaited(MediaKitPlayerPool.instance.release(key));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("PRINTING THE VIDEO ID: ${widget.videoId}");
    super.build(context);
    bool isRtl = _language == 'ar';

    return WillPopScope(
      onWillPop: () async {
        _pauseVideo();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0),
        body: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Obx(() {
            final video = singleVideoController.singleVideoContent.value.video;
            if (video == null) {
              return Center(
                child: Text(
                  'Video not found',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                ),
              );
            }
            if (singleVideoController.isLoading.value) {
              return (video.image != null && video.image!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: "${Common.videoUrl}/${video.image}",
                      memCacheWidth: gridThumbnailMemCacheSize(120),
                      memCacheHeight: gridThumbnailMemCacheSize(120),
                      errorWidget: (context, url, error) => const SizedBox(),
                    )
                  : const SizedBox();
            }

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomLeft,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (!_isInitializing && video.isImage.toString() != '1') {
                        _togglePlayPause();
                      }
                    },
                    onDoubleTap: video.isImage.toString() == '1' ? null : _toggleMute,
                    child:
                        _isInitializing
                            ? Center(
                              child: PulseLogoLoader(
                                logoPath: "assets/images/appIcon.png",
                                size: 80,
                              ),
                            )
                            : video.isImage.toString() == '1'
                            ? Container(
                                color: Colors.black,
                                width: double.infinity,
                                height: double.infinity,
                                child: Center(
                                  child: CachedNetworkImage(
                                    imageUrl: (video.videoUrl?.isNotEmpty == true)
                                        ? video.videoUrl!
                                        : "${Common.videoUrl}/${video.video}",
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    memCacheWidth: gridThumbnailMemCacheSize(360),
                                    memCacheHeight: gridThumbnailMemCacheSize(640),
                                    errorWidget: (context, url, error) => const SizedBox(),
                                  ),
                                ),
                              )
                            : _resolvedVideoUrl != null
                            ? VideoPlayerWidget(
                              videoUrl: _resolvedVideoUrl!,
                              thumbnailUrl:
                                  "${Common.imageBaseUrl}/videos/${video.video ?? ''}",
                              isImage: video.isImage,
                              videoId: _playerKey,
                              autoPlay: true,
                              useMediaKit: true,
                              fillScreen: true,
                            )
                            : const SizedBox.shrink(),
                  ),
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
                  child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: InkWell(
                          onTap: () {
                            _pauseVideo();
                            Get.back();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 30,
                              ),
                              SizedBox(width: 8),
                              Text(
                                video.userName ?? 'Unknown User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                ),

                Positioned(
                  bottom: Get.height * 0.1,
                  child: VideoDescriptionWidget(
                    title: video.title,
                    description: video.description,
                    tags: video.tags,
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: Get.height * 0.1,
                  child: Container(
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
                              userId: _frontUserId ?? '',
                              videoCommentsController: videoCommentsController,
                              isAuthenticated: false,
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
                                  .doc(video.id)
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


                            if (video.allowComments == 1)
                              VideoCommentsWidget(
                                videoId: widget.videoId ?? '',
                                userId: _frontUserId ?? '',
                                userImage: _frontUserImage ?? '',
                                isAuthenticated: true,
                              ),

                            InkWell(
                              onTap: () {
                                if (widget.videoId.isNotEmpty) {
                                  _handleShare(widget.videoId);
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
                            if (_frontUserId != video.frontUserId)
                              Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (widget.videoId.isNotEmpty) {
                                        showMoreOptions(
                                          context,
                                          widget.videoId,
                                          _frontUserId ?? '',
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
                                  Text(
                                    "more".tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                ),
              ],
            );
          }),
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
          // rateVideo(videoId, totalRating / snapshot.docs.length);
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
    final PromoteVideoController promoteVideoController = Get.find();

    var infoEmail = promoteVideoController.siteSettings.value?.settings?.email;
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
                if (_frontUserId ==
                    singleVideoController
                        .singleVideoContent
                        .value
                        .video
                        ?.frontUserId)
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
                      Navigator.pop(bottomSheetContext);
                      _pauseVideo();
                      final bool isDeleted = await deleteVideo(
                        context,
                        videoId,
                        _frontUserId!,
                      );
                      if (isDeleted) {
                        print("Video deleted: $isDeleted");
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
                    Navigator.pop(bottomSheetContext);
                    Get.to(() => ReportContentView(videoId: videoId));
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

// Reused from SingleVideoScreen
Future<bool> deleteVideo(
  BuildContext context,
  String videoId,
  String frondUserId,
) async {
  final String endpoint = '${EndPoints.deleteVideo}?id=$videoId';
  bool isDeleted = false;

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

  await AwesomeDialog(
    context: context,
    dialogType: DialogType.warning,
    animType: AnimType.scale,
    title: 'delete_video'.tr,
    desc: 'sure_to_delete'.tr,
    btnCancelOnPress: () {
      isDeleted = false;
    },
    btnOkOnPress: () async {
      try {
        print('Step 1: Initiating API call to delete video with ID: $videoId');
        final response = await ApiClient.deleteRequest(endpoint);
        print(
          'Step 2: API call completed. Status code: ${response.statusCode}',
        );
        print('API response body: ${response.body}');
        final responseData = jsonDecode(response.body);
        print('Step 3: API response parsed successfully');
        final String apiMessage =
            responseData['message'] ?? 'No message provided by API';
        print('Step 4: Extracted API message: $apiMessage');

        if (response.statusCode == 201) {
          print(
            'Step 5: API call successful. Proceeding to delete Firestore document',
          );
          await FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .delete();
          print('Step 6: Firestore document deleted successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiMessage),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              duration: Duration(seconds: 3),
            ),
          );
          print('Step 7: Success SnackBar displayed');
          Get.offAll(
            () => Landing(),
            binding: LandingBinding(),
          );
          isDeleted = true;
          print('Step 8: Deletion marked as successful');
        } else {
          print(
            'Step 5: API call failed with status code: ${response.statusCode}',
          );
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

// Future<Response> rateVideo(String videoId, double averageRating) async {
//   final data = {"video_id": videoId, "average_rating": averageRating};
//   return await ApiClient.postRequest(
//     "${EndPoints.addVideoRating}",
//     data,
//   ); // Adjust endpoint as needed
// }
