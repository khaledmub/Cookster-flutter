import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/modules/singleVideoVisit/singleVideoController/singleVisitVideoController.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/colorUtils.dart';
import '../../loaders/pulseLoader.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingTabs/home/homeView/commentScreen.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import '../search/searchView/searchView.dart';
import '../visitProfile/visitProfileView/visitProfileView.dart';

class SingleVideoVisit extends StatefulWidget {
  const SingleVideoVisit({super.key});

  @override
  State<SingleVideoVisit> createState() => _SingleVideoVisitState();
}

class _SingleVideoVisitState extends State<SingleVideoVisit> {
  final AppLinks appLinks = AppLinks();
  String? videoId;
  final SingleVisitVideoController singleVisitVideoController = Get.put(
    SingleVisitVideoController(),
  );
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showIcon = false; // To control visibility of play/pause icon
  bool _isBuffering = false; // To track buffering state

  final VideoCommentsController videoCommentsController = Get.put(
    VideoCommentsController(),
  );

  String? userId;
  String? userImage;

  @override
  void initState() {
    super.initState();

    if (Get.arguments != null && Get.arguments is Map<String, dynamic>) {
      final Map<String, dynamic> args = Get.arguments;
      videoId = args['videoId'];
      print("Received Video ID in SingleVideoVisit from arguments: $videoId");
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(''))
      ..addListener(() {
        setState(() {
          _isBuffering =
              _videoController.value.isBuffering; // Update buffering state
        });
      });

    _parseInitialDeepLink();
    _listenForDeepLinks();
    _fetchUserIdFromStorage();

    if (videoId != null) {
      singleVisitVideoController.fetchSingleVideo(videoId!);
    }
  }

  Future<void> _fetchUserIdFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storeUserId = prefs.getString('user_id');
    String? storeUserImage = prefs.getString('user_image');

    if (storeUserId != null) {
      setState(() {
        userId = storeUserId;
        userImage = storeUserImage;
      });
      print("Fetched User ID from SharedPreferences: $userId");
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _parseInitialDeepLink() async {
    try {
      final Uri? initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _processDeepLink(initialUri);
      }
    } catch (e) {
      print("Error parsing initial deep link: $e");
    }
  }

  void _listenForDeepLinks() {
    appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) {
          _processDeepLink(uri);
        }
      },
      onError: (error) {
        print("Deep link stream error: $error");
      },
    );
  }

  void _processDeepLink(Uri uri) {
    print("Deep Link Received in SingleVideoVisit: $uri");
    String? urlVideoId = uri.queryParameters['id'];
    if (urlVideoId != null && urlVideoId != videoId) {
      setState(() {
        videoId = urlVideoId;
        print("Updated Video ID from deep link: $videoId");
        singleVisitVideoController.fetchSingleVideo(videoId!);
      });
    }
  }

  void _initializeVideo(String videoUrl) {
    if (_videoController.value.isInitialized &&
        _videoController.dataSource == videoUrl) {
      return; // Avoid reinitializing if URL hasn't changed
    }

    _videoController.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize()
          .then((_) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController.setLooping(true); // Set video to loop
            _videoController.play(); // Auto-play the video
          })
          .catchError((error) {
            print("Error initializing video: $error");
            setState(() {
              _isVideoInitialized = false;
            });
          });
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
      _showIcon = true; // Show icon on tap
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _showIcon = false; // Hide icon after 1 second
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        var data = singleVisitVideoController.singleVideoContent.value.video;

        if (singleVisitVideoController.isLoading.value) {
          return Center(
            child: PulseLogoLoader(
              logoPath: "assets/images/appIcon.png",
              size: 80,
            ),
          );
        } else if (data == null || data.video == null) {
          return Center(
            child: Text(
              "No video available",
              style: TextStyle(color: Colors.white),
            ),
          );
        } else {
          _initializeVideo("${Common.videoUrl}/${data.video!}");

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause, // Toggle play/pause on tap
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _isVideoInitialized
                          ? VideoPlayer(_videoController)
                          : Container(color: Colors.black),
                      if (!_isVideoInitialized || _isBuffering)
                        PulseLogoLoader(
                          logoPath: "assets/images/appIcon.png",
                          size: 80,
                        ), // Show buffering indicator
                      if (_isVideoInitialized && _showIcon)
                        Icon(
                          _videoController.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 64.0,
                          color: Colors.white.withOpacity(0.7),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: Get.height * 0.1,
                left: 10,
                child: Container(
                  width: Get.width * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.title != null && data.title!.isNotEmpty)
                        Text(
                          data.title!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (data.description != null &&
                          data.description!.isNotEmpty)
                        Text(
                          data.description!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (data.tags != null && data.tags!.isNotEmpty)
                        Text(
                          data.tags!
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
              ),
              Positioned(
                top: Get.height * 0.05,
                left: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        child: Icon(
                          Icons.arrow_back
,
                          color: Colors.white,
                          size: 30.sp,
                        ),
                      ),
                      InkWell(
                        onTap:
                            () => Get.to(
                              VisitProfileView(userId: data.frontUserId!),
                            ),
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
                                    data.userImage != null &&
                                            data.userImage!.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                          '${Common.profileImage}/${data.userImage}',
                                        )
                                        : null,
                                child:
                                    data.userImage == null ||
                                            data.userImage!.isEmpty
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
                                Text(
                                  data.userName ?? 'Unknown User',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${data.followersCount} followers",
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
                    ],
                  ),
                ),
              ),
              Positioned(
                top: Get.height * 0.05,
                right: 16,
                child: InkWell(
                  onTap: () => Get.to(SearchView()),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(Icons.search, color: Colors.white, size: 24.sp),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: Get.height * 0.1,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('videos')
                                    .doc(data.id)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return LikeButton(
                                  size: 24.h,
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
                                        color: Colors.white,
                                      ),
                                  onTap: (isLiked) async {
                                    await videoCommentsController
                                        .toggleVideoLike(
                                          videoId.toString(),
                                          userId.toString(),
                                        );
                                    return !isLiked;
                                  },
                                );
                              }
                              final data =
                                  snapshot.data?.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              List<dynamic> likes = data['likes'] ?? [];
                              bool isLiked = likes.contains(userId);
                              return LikeButton(
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
                                onTap: (isLiked) async {
                                  await videoCommentsController.toggleVideoLike(
                                    videoId.toString(),
                                    userId.toString(),
                                  );
                                  HapticFeedback.lightImpact();
                                  return !isLiked;
                                },
                              );
                            },
                          ),
                          SizedBox(height: 2),
                          StreamBuilder<DocumentSnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('videos')
                                    .doc(data.id)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                return Text(
                                  "...",
                                  style: TextStyle(color: Colors.white),
                                );
                              final data =
                                  snapshot.data?.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              int likeCount = data['likeCount'] ?? 0;
                              String formattedCount =
                                  likeCount > 1000
                                      ? '${(likeCount / 1000).toStringAsFixed(1)}K'
                                      : likeCount.toString();
                              return Text(
                                formattedCount,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (data.allowComments == 1)
                        Column(
                          children: [
                            InkWell(
                              onTap:
                                  () => showCommentsBottomSheetNew(
                                    context,
                                    data.id!,
                                    userId!,
                                    userImage!,
                                  ),
                              child: SvgPicture.asset(
                                "assets/icons/comment.svg",
                                height: 20.h,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('videos')
                                      .doc(data.id)
                                      .collection('comments')
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  return Text(
                                    "...",
                                    style: TextStyle(color: Colors.white),
                                  );
                                int commentCount =
                                    snapshot.data?.docs.length ?? 0;
                                String formattedCount =
                                    commentCount > 1000
                                        ? '${(commentCount / 1000).toStringAsFixed(1)}K'
                                        : commentCount.toString();
                                return Text(
                                  formattedCount,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      if (data.allowComments == 1) SizedBox(height: 16),
                      Column(
                        children: [
                          InkWell(
                            onTap: () => _handleShare(data.id.toString()),
                            child: SvgPicture.asset(
                              "assets/icons/share.svg",
                              height: 20.h,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Share",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Column(
                        children: [
                          InkWell(
                            onTap: () => _showMoreOptions(context, data.id!),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 30.h,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "More",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
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
        }
      }),
    );
  }

  void _showMoreOptions(BuildContext context, dynamic videoId) {
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
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.sell, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'Want to Promote this video?',
                  style: TextStyle(color: Colors.black, fontSize: 14.sp),
                ),
                onTap: () => Navigator.pop(context),
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
                  Get.to(ReportContentView(videoId: videoId));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleShare(String videoId) async {
    try {
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
    }
  }
}
