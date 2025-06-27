import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_call.dart';

class CommentWidget extends StatefulWidget {
  final String liveStreamId;

  const CommentWidget({super.key, required this.liveStreamId});

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;
  bool _isLiked = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Check if the user has already liked the livestream
    _checkIfLiked();
  }

  void _checkIfLiked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');
    if (userId == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('liveVideos')
              .doc(widget.liveStreamId)
              .get();

      if (doc.exists && mounted) {
        List<dynamic> likedBy = doc.get('likedBy') ?? [];
        setState(() {
          _isLiked = likedBy.contains(userId);
        });
      }
    } catch (e) {
      if (mounted) {
        // Handle error silently or log it
        print('Error checking like status: $e');
      }
    }
  }

  void _toggleLike() async {
    if (_isProcessing || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    _heartAnimationController.forward().then(
      (_) => _heartAnimationController.reverse(),
    );

    try {
      bool newLikeStatus = await toggleLikeLivestream(widget.liveStreamId);

      if (mounted) {
        setState(() {
          _isLiked = newLikeStatus;
        });
      }
    } catch (e) {
      if (mounted && !e.toString().contains('operation already in progress')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || !mounted) return;

    try {
      await addComment(widget.liveStreamId, _commentController.text.trim());
      if (mounted) {
        setState(() {
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          // Comments Header with Likes Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'live_comments'.tr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('liveVideos')
                          .doc(widget.liveStreamId)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.hasError) {
                      return const SizedBox.shrink();
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final likes = data?['likes'] ?? 0;
                    return Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.red.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child:  Text(
                            'livec'.tr,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('liveVideos')
                      .doc(widget.liveStreamId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading comments',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final List<dynamic> comments = data?['comments'] ?? [];

                // Reverse the comments list to show latest comments at the top
                final reversedComments = comments.reversed.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: reversedComments.length,
                  itemBuilder: (context, index) {
                    final comment =
                        reversedComments[index] as Map<String, dynamic>;
                    return _buildCommentTile(
                      comment['userId'] ?? 'unknown',
                      comment['name'] ?? 'Anonymous',
                      comment['comment'] ?? '',
                      comment['profilePicture'] ??
                          'https://via.placeholder.com/40/FF6B6B/FFFFFF?text=U',
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'write_a_comment'.tr,
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          suffixIcon:
                              _commentController.text.isNotEmpty
                                  ? IconButton(
                                    onPressed: _addComment,
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.blue,
                                    ),
                                  )
                                  : null,
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ScaleTransition(
                    scale: _heartAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            _isLiked
                                ? Colors.red.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color:
                              _isLiked
                                  ? Colors.red.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon:
                            _isProcessing
                                ? const SizedBox()
                                : Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color:
                                      _isLiked
                                          ? Colors.red
                                          : Colors.white.withOpacity(0.8),
                                  size: 24,
                                ),
                        onPressed: _isProcessing ? null : _toggleLike,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(
    String username,
    String displayName,
    String comment,
    String avatarUrl,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 40, // 2 * radius
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[700], // Background color
                  image:
                      avatarUrl.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {
                              // This will not directly render an icon, so we handle it in the child
                            },
                          )
                          : null,
                ),
                child:
                    avatarUrl.isEmpty
                        ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        )
                        : ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              );
                            },
                          ),
                        ),
              ),
              // Positioned(
              //   bottom: 0,
              //   right: 0,
              //   child: Container(
              //     width: 12,
              //     height: 12,
              //     decoration: BoxDecoration(
              //       color: Colors.green,
              //       border: Border.all(color: Colors.black, width: 2),
              //       borderRadius: BorderRadius.circular(6),
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName.isNotEmpty ? displayName : username,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
