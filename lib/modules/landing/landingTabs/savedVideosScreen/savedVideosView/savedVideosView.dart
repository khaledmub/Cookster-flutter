import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../appUtils/apiEndPoints.dart';
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
    // TODO: implement initState
    super.initState();
    saveController.getSavedVideos();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "saved_videos".tr,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: Obx(() {
        if (saveController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final videos = saveController.savedVideos;

        if (videos.isEmpty) {
          return Center(
            child: Image.asset("assets/images/notfound.png", fit: BoxFit.cover),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                videos.map((video) {
                  return SizedBox(
                    width: 100.w,
                    height: 133.h,
                    child: GestureDetector(
                      onTap: () {
                        Get.to(
                          SingleVideoScreen(
                            followers:
                                '${profileController.followersList.length}',
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
                                image:
                                    (video.image != null &&
                                            video.image!.isNotEmpty)
                                        ? CachedNetworkImageProvider(
                                          '${Common.videoUrl}/${video.image}',
                                        )
                                        : const AssetImage(
                                              "assets/images/food1.jpg",
                                            )
                                            as ImageProvider,
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
                                  colors: [Colors.black, Colors.transparent],
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
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('videos')
                                          .doc(video.id)
                                          .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Text(
                                        "...",
                                        style: TextStyle(color: Colors.white),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        !snapshot.data!.exists) {
                                      return Text(
                                        "0",
                                        style: TextStyle(color: Colors.white),
                                      );
                                    }
                                    final data =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>? ??
                                        {};
                                    List<dynamic> likes = data['likes'] ?? [];
                                    int likeCount =
                                        likes
                                            .length; // Count likes from array length
                                    String formattedLikeCount =
                                        likeCount > 1000
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
    );
  }
}
