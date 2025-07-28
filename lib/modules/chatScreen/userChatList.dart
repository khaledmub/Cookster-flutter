import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/appCenterIcon.dart';
import 'chatScreenView.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({Key? key, required this.userId}) : super(key: key);

  // Cache for user data to avoid repeated Firestore calls
  static final Map<String, Map<String, dynamic>> _userDataCache = {};

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _language = 'en'; // Default to English
  Map<String, Future<Map<String, dynamic>>> _chatFutures = {};

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
    });
  }

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    if (ChatListScreen._userDataCache.containsKey(userId)) {
      return ChatListScreen._userDataCache[userId]!;
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
      ChatListScreen._userDataCache[userId] = data;
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

              // Update futures for this chat
              _chatFutures[doc.id] = Future.wait([
                _fetchUserData(otherUserId),
                _getUnreadCount(doc.id, currentUserId),
              ]).then(
                (results) => {
                  'userData': results[0],
                  'unreadCount': results[1],
                },
              );
            }
          }

          chatData.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          return chatData;
        });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    }
    if (messageDate == yesterday) {
      return 'Yesterday';
    }
    final daysDifference = today.difference(messageDate).inDays;
    if (daysDifference <= 7 && daysDifference > 1) {
      return DateFormat('EEEE').format(timestamp);
    }
    if (timestamp.year == now.year) {
      return DateFormat('dd MMMM').format(timestamp);
    }
    return DateFormat('dd MMMM, yy').format(timestamp);
  }

  void _refreshChatFutures(
    String chatId,
    String partnerId,
    String currentUserId,
  ) {
    setState(() {
      _chatFutures[chatId] = Future.wait([
        _fetchUserData(partnerId),
        _getUnreadCount(chatId, currentUserId),
      ]).then((results) => {'userData': results[0], 'unreadCount': results[1]});
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.userId;
    bool isRtl = _language == 'ar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90),
        child: Container(
          padding: EdgeInsets.only(top: 30),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFADC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Positioned(
                    left: isRtl ? null : 16,
                    right: isRtl ? 16 : null,
                    top: 10.h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        try {
                          Get.back();
                        } catch (e) {
                          print("Error navigating back: $e");
                        }
                      },
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6BE00),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isRtl ? Icons.arrow_back : Icons.arrow_back,
                            color: ColorUtils.darkBrown,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppCenterIcon(),
                ],
              ),
            ],
          ),
        ),
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
              child: PulseLogoLoader(logoPath: "assets/images/appIcon.png"),
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

          return Column(
            children: [
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      "chats".tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: chatData.length,
                  itemBuilder: (context, index) {
                    final chat = chatData[index];
                    final partnerId = chat['partnerId'];
                    final chatId = chat['chatId'];
                    final lastMessage = chat['lastMessage'];
                    final timestamp = chat['timestamp'] as DateTime;
                    final blockedBy = List<String>.from(
                      chat['blockedBy'] ?? [],
                    );
                    final isBlocked = blockedBy.contains(currentUserId);

                    return FutureBuilder<Map<String, dynamic>>(
                      key: ValueKey(chatId),
                      future:
                          _chatFutures[chatId] ??
                          Future.wait([
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
                          return const SizedBox.shrink();
                        }

                        final data = snapshot.data as Map<String, dynamic>;
                        final userData =
                            data['userData'] as Map<String, dynamic>;
                        var unreadCount = data['unreadCount'] as int;

                        return data.isNotEmpty
                            ? InkWell(
                              onTap: () {
                                Get.to(
                                  ChatView(
                                    senderId: currentUserId,
                                    receiverId: partnerId,
                                  ),
                                )!.then((_) {
                                  // Refresh the future for this specific chat
                                  _refreshChatFutures(
                                    chatId,
                                    partnerId,
                                    currentUserId,
                                  );
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.only(
                                  bottom: 20,
                                  left: 16,
                                  right: 16,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
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
                                                size: 26,
                                              )
                                              : null,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  isBlocked
                                                      ? "cookster_user".tr
                                                      : userData['name'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        unreadCount > 0 &&
                                                                !isBlocked
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                    color:
                                                        isBlocked
                                                            ? Colors.grey[600]
                                                            : Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTimestamp(timestamp),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          unreadCount > 0 &&
                                                                  !isBlocked
                                                              ? ColorUtils
                                                                  .primaryColor
                                                              : Colors
                                                                  .grey[600],
                                                    ),
                                                  ),
                                                  if (unreadCount > 0) ...[
                                                    SizedBox(width: 6),
                                                    Container(
                                                      constraints:
                                                          BoxConstraints(
                                                            minWidth: 18,
                                                            minHeight: 18,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            ColorUtils
                                                                .primaryColor,
                                                        shape:
                                                            unreadCount > 9
                                                                ? BoxShape
                                                                    .rectangle
                                                                : BoxShape
                                                                    .circle,
                                                        borderRadius:
                                                            unreadCount > 9
                                                                ? BorderRadius.circular(
                                                                  9,
                                                                )
                                                                : null,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          unreadCount > 99
                                                              ? '99+'
                                                              : '$unreadCount',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            lastMessage != null
                                                ? (lastMessage['message']
                                                        ?.substring(
                                                          0,
                                                          lastMessage['message']
                                                                      .length >
                                                                  30
                                                              ? 30
                                                              : lastMessage['message']
                                                                  .length,
                                                        ) ??
                                                    '')
                                                : 'no_messages'.tr,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  unreadCount > 0 && !isBlocked
                                                      ? Colors.black87
                                                      : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
