import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chatScreenView.dart';

class ChatListScreen extends StatelessWidget {
  final String userId;

  const ChatListScreen({Key? key, required this.userId}) : super(key: key);

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return userDoc.exists
          ? {
        'name': userDoc.data()?['name'] ?? userId,
        'image': userDoc.data()?['image'] ?? '',
      }
          : {'name': userId, 'image': ''};
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
      final snapshot = await FirebaseFirestore.instance
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

  Stream<List<String>> _fetchChatUsers(String currentUserId) {
    print('🔍 Fetching chats for user: $currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      print('📥 Received snapshot with ${snapshot.docs.length} documents');

      List<String> chatUsers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        print('👥 Participants in ${doc.id}: $participants');

        final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty && !chatUsers.contains(otherUserId)) {
          chatUsers.add(otherUserId);
          print('➕ Added $otherUserId to chatUsers list');
        }
      }

      print('📤 Final chatUsers list: $chatUsers');
      return chatUsers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId;
    print('🔑 Current User ID: $currentUserId');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: TextStyle(color: Colors.grey[800], fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey[200],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
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
      body: StreamBuilder<List<String>>(
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            );
          }

          final chatPartners = snapshot.data ?? [];
          print('👥 Chat partners: $chatPartners');

          if (chatPartners.isEmpty) {
            return Center(
              child: Text(
                'No chats found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            itemCount: chatPartners.length,
            itemBuilder: (context, index) {
              final partnerId = chatPartners[index];
              final chatId = _getChatId(currentUserId, partnerId);
              print('📬 Building ListTile for partnerId: $partnerId, chatId: $chatId');

              return FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  _fetchUserData(partnerId),
                  _getUnreadCount(chatId, currentUserId),
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get()
                      .then(
                        (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null,
                  ),
                ]).then(
                      (results) => {
                    'userData': results[0],
                    'unreadCount': results[1],
                    'lastMessage': results[2],
                  },
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                      ),
                      title: Text('Loading...'),
                    );
                  }

                  final data = snapshot.data as Map<String, dynamic>;
                  final userData = data['userData'] as Map<String, dynamic>;
                  final unreadCount = data['unreadCount'] as int;
                  final lastMessage = data['lastMessage'] as Map<String, dynamic>?;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: userData['image'].isNotEmpty
                          ? CachedNetworkImageProvider(userData['image'])
                          : null,
                      child: userData['image'].isEmpty
                          ? Icon(Icons.person, color: Colors.grey[600])
                          : null,
                    ),
                    title: Text(
                      userData['name'],
                      style: TextStyle(
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
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
                          : 'No messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unreadCount > 0
                        ? CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue,
                      child: Text(
                        '$unreadCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            senderId: currentUserId,
                            receiverId: partnerId,
                          ),
                        ),
                      );
                    },
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