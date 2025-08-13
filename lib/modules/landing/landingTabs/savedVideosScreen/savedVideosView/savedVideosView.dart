import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../appUtils/apiEndPoints.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../singleVideoView/singleVideoView.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import '../../profile/profileControlller/profileController.dart';

class SavedVideosView extends StatefulWidget {
  const SavedVideosView({super.key});

  @override
  State<SavedVideosView> createState() => _SavedVideosViewState();
}

class _SavedVideosViewState extends State<SavedVideosView> {
  final SaveController saveController = Get.find();
  final ProfileController profileController = Get.find();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      saveController.getSavedVideos();
    });
  }

  Future<void> _onRefresh() async {
    await saveController.getSavedVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          padding: EdgeInsets.only(top: 20.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: LinearGradient(
              colors: [Color(0XFFFFD700), Color(0XFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  "Saved Reels".tr,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                left: Directionality.of(context) == TextDirection.rtl ? null : 16,
                right: Directionality.of(context) == TextDirection.rtl ? 16 : null,
                top: 25,
                child: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFE6BE00),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_back
                            : Icons.arrow_back,
                        color: ColorUtils.darkBrown,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Color(0XFFFFD700),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            // Ensure the content takes up at least the full screen height
            height: MediaQuery.of(context).size.height,
            child: Obx(() {
              if (saveController.isLoading.value) {
                return const Center(
                  child: PulseLogoLoader(
                    logoPath: "assets/images/appLogo.png",
                  ),
                );
              }

              final videos = saveController.savedVideos;

              if (videos.isEmpty) {
                return Center(
                  child: Image.asset(
                    "assets/images/notfound.png",
                    fit: BoxFit.cover,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: videos.map((video) {
                    return SizedBox(
                      width: 100.w,
                      height: 133.h,
                      child: GestureDetector(
                        // Use onTap to avoid gesture conflicts
                        onTap: () {
                          Get.to(
                            SingleVideoScreen(
                              followers: video.followersCount.toString(),
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
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                image: DecorationImage(
                                  image: (video.image != null &&
                                      video.image!.isNotEmpty)
                                      ? CachedNetworkImageProvider(
                                    '${Common.videoUrl}/${video.image}',
                                  )
                                      : const AssetImage(
                                    "assets/images/food1.jpg",
                                  ) as ImageProvider,
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
                                  gradient: const LinearGradient(
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
                                    stream: FirebaseFirestore.instance
                                        .collection('videos')
                                        .doc(video.id)
                                        .snapshots(),
                                    builder: (context, snapshot) {

                                      if (!snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return Text(
                                          "0",
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                      final data = snapshot.data!.data()
                                      as Map<String, dynamic>? ??
                                          {};
                                      List<dynamic> likes = data['likes'] ?? [];
                                      int likeCount = likes.length;
                                      String formattedLikeCount = likeCount > 1000
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
                  }).toList(),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}