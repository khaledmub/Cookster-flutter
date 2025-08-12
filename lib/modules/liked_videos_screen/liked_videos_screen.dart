import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LikedVideosScreen extends StatefulWidget {
  final String userId;

  const LikedVideosScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _LikedVideosScreenState createState() => _LikedVideosScreenState();
}

class _LikedVideosScreenState extends State<LikedVideosScreen> {
  // Stream to get total likes count
  Stream<int> checkLikedVideos(String userId) {
    return FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
      int totalLikes = 0;
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        List<String> likes = List<String>.from(data['likes'] ?? []);
        totalLikes += likes.length;
      }
      return totalLikes;
    });
  }

  // Stream to get video IDs liked by the user
  Stream<List<String>> getLikedVideoIds(String userId) {
    return FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
      return querySnapshot.docs.map((doc) => doc.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Liked Videos'),
      ),
      body: Column(
        children: [
          // Total likes
          StreamBuilder<int>(
            stream: checkLikedVideos(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Error loading total likes'),
                );
              }
              final totalLikes = snapshot.data ?? 0;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Total Likes Across Videos: $totalLikes',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          // Liked videos list
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: getLikedVideoIds(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading liked videos'));
                }
                final videoIds = snapshot.data ?? [];

                // Create comma-separated string
                final commaSeparatedIds = videoIds.join(",");

                if (videoIds.isEmpty) {
                  return const Center(child: Text('No liked videos found'));
                }


                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display comma separated list
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Comma-separated IDs:\n$commaSeparatedIds',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: videoIds.length,
                        itemBuilder: (context, index) {
                          final videoId = videoIds[index];
                          return ListTile(
                            title: Text('Video ID: $videoId'),
                            leading: const Icon(Icons.video_library),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Tapped Video ID: $videoId')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}