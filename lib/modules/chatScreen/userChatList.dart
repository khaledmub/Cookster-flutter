import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../appUtils/apiEndPoints.dart';
import 'chatScreenView.dart';

class ChatListScreen extends StatelessWidget {
  final String userId;

  const ChatListScreen({Key? key, required this.userId}) : super(key: key);

  // Cache for user data to avoid repeated Firestore calls
  static final Map<String, Map<String, dynamic>> _userDataCache = {};

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    if (_userDataCache.containsKey(userId)) {
      return _userDataCache[userId]!;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      final data =
          userDoc.exists
              ? {
                'name': userDoc.data()?['name'] ?? userId,
                'image': userDoc.data()?['image'] ?? '',
              }
              : {'name': userId, 'image': ''};
      _userDataCache[userId] = data;
      return data;
    } catch (e) {
      print('🚨 Error fetching user data for $userId: $e');
      return {'name': userId, 'image': ''};
    }
  }

  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<int> _getUnreadCount(String chatId, String currentUserId) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: currentUserId)
              .where('read', isEqualTo: false)
              .get();
      print('📬 Unread count for chatId $chatId: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e) {
      print('🚨 Error fetching unread count for $chatId: $e');
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchChatUsers(String currentUserId) {
    print('🔍 Fetching chats for user: $currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          print('📥 Received snapshot with ${snapshot.docs.length} documents');

          List<Map<String, dynamic>> chatData = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final blockedBy = List<String>.from(data['blockedBy'] ?? []);

            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              final lastMessageSnapshot =
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(doc.id)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get();

              final lastMessage =
                  lastMessageSnapshot.docs.isNotEmpty
                      ? lastMessageSnapshot.docs.first.data()
                      : null;

              chatData.add({
                'partnerId': otherUserId,
                'chatId': doc.id,
                'lastMessage': lastMessage,
                'timestamp':
                    lastMessage?['timestamp']?.toDate() ?? DateTime(1970),
                'blockedBy': blockedBy,
              });
            }
          }

          chatData.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          return chatData;
        });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'yesterday'.tr;
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'chats'.tr,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey[200],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black54),
            onPressed: () {
              _userDataCache.clear(); // Clear cache on refresh
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListScreen(userId: currentUserId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _fetchChatUsers(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('🚨 StreamBuilder error: ${snapshot.error}');
            return Center(
              child: Text(
                'Something went wrong: ${snapshot.error}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          }

          final chatData = snapshot.data ?? [];
          print(
            '👥 Chat data: ${chatData.map((e) => e['partnerId']).toList()}',
          );

          if (chatData.isEmpty) {
            return Center(
              child: Text(
                'no_chats_found'.tr,
                style: TextStyle(color: ColorUtils.primaryColor, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: chatData.length,
            itemBuilder: (context, index) {
              final chat = chatData[index];
              final partnerId = chat['partnerId'];
              final chatId = chat['chatId'];
              final lastMessage = chat['lastMessage'];
              final timestamp = chat['timestamp'] as DateTime;
              final blockedBy = List<String>.from(chat['blockedBy'] ?? []);
              final isBlocked = blockedBy.contains(currentUserId);

              // Use a unique key to prevent unnecessary rebuilds
              return FutureBuilder<Map<String, dynamic>>(
                key: ValueKey(chatId), // Unique key for each ListTile
                future: Future.wait([
                  _fetchUserData(partnerId),
                  _getUnreadCount(chatId, currentUserId),
                ]).then(
                  (results) => {
                    'userData': results[0],
                    'unreadCount': results[1],
                  },
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError || snapshot.data == null) {
                    return const SizedBox.shrink(); // or an error widget
                  }

                  final data = snapshot.data as Map<String, dynamic>;
                  final userData = data['userData'] as Map<String, dynamic>;
                  final unreadCount = data['unreadCount'] as int;

                  return data.isNotEmpty
                      ? ListTile(
                        key: ValueKey(chatId),
                        // Ensure stable identity
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              userData['image'].isNotEmpty
                                  ? CachedNetworkImageProvider(
                                    '${Common.profileImage}/${userData['image']}',
                                  )
                                  : null,
                          child:
                              userData['image'].isEmpty
                                  ? Icon(
                                    Icons.person,
                                    color: Colors.grey[600],
                                    size: 30,
                                  )
                                  : null,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    isBlocked
                                        ? "cookster_user".tr
                                        : userData['name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          unreadCount > 0 && !isBlocked
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                      color:
                                          isBlocked
                                              ? Colors.grey[600]
                                              : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        unreadCount > 0 && !isBlocked
                                            ? Colors.teal
                                            : Colors.grey[600],
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Text(
                          lastMessage != null
                              ? (lastMessage['message']?.substring(
                                    0,
                                    lastMessage['message'].length > 30
                                        ? 30
                                        : lastMessage['message'].length,
                                  ) ??
                                  '')
                              : 'no_messages'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                unreadCount > 0 && !isBlocked
                                    ? Colors.black87
                                    : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Get.to(
                            ChatView(
                              senderId: currentUserId,
                              receiverId: partnerId,
                            ),
                          );
                        },
                      )
                      : SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
}
