import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/singleVideoView/singleVideoController.dart';
import 'package:cookster/modules/singleVideoVisit/singleVideoController/singleVisitVideoController.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:http/src/response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../services/apiClient.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingTabs/home/homeView/reelsVideoScreen.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import '../landing/landingView/landingView.dart';
import '../singleVideoView/singleVideoView.dart' hide VideoDescriptionWidget;

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

    final videoUrl = '${Common.videoUrl}/${video!.video}';
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
    super.build(context);
    bool isRtl = _language == 'ar';

    return WillPopScope(
      onWillPop: () async {
        _pauseVideo();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0),
        body: Obx(() {
          if (singleVideoController.isLoading.value) {
            return Center(
              child: PulseLogoLoader(logoPath: "assets/icons/appLogo.png"),
            );
          }

          final video = singleVideoController.singleVideoContent.value.video;
          if (video == null) {
            return Center(
              child: Text(
                'Video not found',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
            );
          }

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
                        : EnhancedSeekBar(controller: _videoPlayerController!),
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

              VideoDescriptionWidget(
                title: video.title,
                description: video.description,
                tags: video.tags,
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
                          ),
                          SizedBox(height: 8),

                          if (video.allowComments == 1)
                            VideoCommentsWidget(
                              videoId: widget.videoId ?? '',
                              userId: _frontUserId ?? '',
                              userImage: _frontUserImage ?? '',
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
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.sp),
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
            ],
          ),
        );
      },
    );
  }
}

// Reused from SingleVideoScreen
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
    log("SingleVisitVideo key: ${widget.key}");

    return SizedBox(
      width: Get.width,
      height: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
          _animationController.forward();
          // if (widget.controller.is) {
          //   widget.controller.pause();
          // }
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          _animationController.reverse();
          // if (widget.controller.isInitialized) {
          //   widget.controller.play();
          // }
        },
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          _updateProgress(localPosition.dx! / box.size.width);
        },
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          _updateProgress(localPosition.dx! / box.size.width);
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
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: Get.width,
                    height: _isDragging ? 12 : 8,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isDragging ? 12 : 8,
                    width: Get.width * _bufferedProgress,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isDragging ? 12 : 8,
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
                Positioned(
                  left: (Get.width * _progress),
                  top: 15,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final thumbSize =
                          16.0 + (_animationController.value * 12);
                      return Transform.translate(
                        offset: Offset(-thumbSize / 2, -thumbSize / 2),
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
                if (_isDragging)
                  Positioned(
                    left: (Get.width * _progress),
                    top: -15,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(-20, 0),
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
