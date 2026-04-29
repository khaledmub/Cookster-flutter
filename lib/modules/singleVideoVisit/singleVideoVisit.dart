import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chewie/chewie.dart';
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
import 'package:video_player/video_player.dart';
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

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = true;
  bool _isInitializing = true;
  bool _isMuted = false;
  bool _showPlayPauseIcon = false;
  String? _frontUserId; // Store the user ID from SharedPreferences
  String? _frontUserImage; // Store the user ID from SharedPreferences
  String _language = 'en'; // Default to English
  bool _hasInitializedPlayer = false;

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
    ever(singleVideoController.isLoading, (isLoading) {
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

    final video = singleVideoController.singleVideoContent.value.video;
    if (video?.video == null) {
      print("Video data not available for initialization");
      return;
    }

    _hasInitializedPlayer = true;

    final videoUrl = video!.videoUrl?.isNotEmpty == true ? video!.videoUrl! : '${Common.videoUrl}/${video!.video}';
    print("PRINTING VIDEO URL: $videoUrl");

    try {
      _videoPlayerController = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        showControls: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
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
    if (_videoPlayerController?.value.isPlaying == true) {
      _videoPlayerController!.pause();
      setState(() {
        _isPlaying = false;
        _showPlayPauseIcon = true;
      });
    }
  }

  void _resumeVideo() {
    if (_videoPlayerController?.value.isPlaying == false) {
      _videoPlayerController!.play();
      setState(() {
        _isPlaying = true;
        _showPlayPauseIcon = true;
      });
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;

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
    if (_videoPlayerController == null) return;

    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_videoPlayerController?.value.isInitialized == true) {
        _resumeVideo();
      }
    } else if (state == AppLifecycleState.paused) {
      if (_videoPlayerController?.value.isInitialized == true) {
        _videoPlayerController!.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseVideo();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
              return Image.network("${Common.videoUrl}/${video.image}");
            }

            _trackVideoView(
              video.id.toString(),
              _frontUserId!,
              _frontUserId != null ? true : false,
            );

            return Stack(
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
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 10,
                  child:
                      _isInitializing || _videoPlayerController == null
                          ? SizedBox.shrink()
                          : video.isImage == 1
                          ? SizedBox.shrink()
                          : EnhancedSeekBar(
                            controller: _videoPlayerController!,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
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
          Get.offAll(() => Landing());
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
