import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../visitProfile/visitProfileView/visitProfileView.dart';

class VideoLikesScreen extends StatelessWidget {
  final String videoId;

  const VideoLikesScreen({Key? key, required this.videoId}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchUsersData(
      List<String> userIds,
      ) async {
    if (userIds.isEmpty) return [];

    List<Map<String, dynamic>> usersData = [];

    // Batch fetch users data
    for (String userId in userIds) {
      try {
        DocumentSnapshot userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          var userData = userDoc.data() as Map<String, dynamic>;
          userData['userId'] = userId; // Add userId to the data
          usersData.add(userData);
        }
      } catch (e) {
        // Skip users that can't be fetched
        print('Error fetching user $userId: $e');
      }
    }

    return usersData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'likes'.tr,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
        FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: const PulseLogoLoader(
                logoPath: "assets/images/applogo.png",
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading likes',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no_likes_yet'.tr,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Get likes from the document
          var data = snapshot.data!.data() as Map<String, dynamic>;
          List<String> likedByIds = List<String>.from(data['likes'] ?? []);

          if (likedByIds.isEmpty) {
            return Center(
              child: Text(
                'No likes yet',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          // Remove duplicates if any
          likedByIds = likedByIds.toSet().toList();

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUsersData(likedByIds),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: PulseLogoLoader(logoPath: "assets/images/applogo.png"),
                );
              }

              if (usersSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading users',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              if (!usersSnapshot.hasData || usersSnapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'no_users_found'.tr,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }

              List<Map<String, dynamic>> usersData = usersSnapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: usersData.length,
                itemBuilder: (context, index) {
                  var userData = usersData[index];
                  String name = userData['name'] ?? 'Unknown';
                  String email = userData['email'] ?? '';
                  String image = userData['image'] ?? '';
                  String userId = userData['userId'] ?? '';

                  return InkWell(
                    onTap: () {
                      Get.off(() => VisitProfileView(userId: userId));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD700),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child:
                              image.isNotEmpty
                                  ? Image.network(
                                '${Common.profileImage}/$image',
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                    ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                      loadingProgress
                                          .expectedTotalBytes !=
                                          null
                                          ? loadingProgress
                                          .cumulativeBytesLoaded /
                                          loadingProgress
                                              .expectedTotalBytes!
                                          : null,
                                      color: const Color(0xFFFFD700),
                                    ),
                                  );
                                },
                                errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                    ) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.grey[600],
                                      size: 24,
                                    ),
                                  );
                                },
                              )
                                  : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.person,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (email.isNotEmpty)
                                  SizedBox(
                                    width: Get.width * 0.5,
                                    child: Text(
                                      email,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
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
                },
              );
            },
          );
        },
      ),
    );
  }
}