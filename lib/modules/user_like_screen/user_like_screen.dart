import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../appUtils/apiEndPoints.dart';
import '../visitProfile/visitProfileView/visitProfileView.dart';
import 'package:cookster/core/media/media_url_resolver.dart';

class LikesScreen extends StatelessWidget {
  final String currentUserId;

  const LikesScreen({Key? key, required this.currentUserId}) : super(key: key);

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
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('profileLikes')
                .where('profileId', isEqualTo: currentUserId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: const PulseLogoLoader(
                logoPath: "assets/images/appIcon.png",
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          // Collect all likedByIds from the documents
          List<String> likedByIds = [];
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            var likedBy = data['likedBy'];
            if (likedBy is List) {
              likedByIds.addAll(likedBy.cast<String>());
            } else if (likedBy is String) {
              likedByIds.add(likedBy);
            }
          }

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

          // Remove duplicates
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
                                      ? CachedNetworkImage(
                                        imageUrl:
                                            MediaUrlResolver.profileImageUrl(image) ?? '',
                                        fit: BoxFit.cover,
                                        memCacheWidth:
                                            gridThumbnailMemCacheSize(48),
                                        memCacheHeight:
                                            gridThumbnailMemCacheSize(48),
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(
                                            color: const Color(0xFFFFD700),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) {
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
