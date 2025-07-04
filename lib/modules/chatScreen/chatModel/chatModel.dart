import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/notificationService.dart';

class ChatModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedRecipientToken;
  String? _cachedAccessToken;
  DateTime? _tokenCacheTime;
  static const Duration TOKEN_CACHE_DURATION = Duration(hours: 1);

  String getChatId(String senderId, String receiverId) {
    List<String> ids = [senderId, receiverId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<int> getUnreadCount(String chatId, String senderId) async {
    try {
      final snapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: senderId)
              .where('read', isEqualTo: false)
              .get();
      return snapshot.docs.length;
    } catch (e) {
      print('🚨 Error fetching unread count: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> fetchReceiverData(String receiverId) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(receiverId).get();
      return userDoc.exists
          ? {
            'name': userDoc.data()?['name'] ?? receiverId,
            'image': userDoc.data()?['image'] ?? '',
          }
          : {'name': receiverId, 'image': ''};
    } catch (e) {
      print('🚨 Error fetching receiver data: $e');
      return {'name': receiverId, 'image': ''};
    }
  }

  Future<String> fetchRecipientToken(String receiverId) async {
    if (_cachedRecipientToken != null) {
      return _cachedRecipientToken!;
    }
    try {
      final userDoc =
          await _firestore.collection('users').doc(receiverId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final token = userDoc.data()!['uuid'] ?? '';
        _cachedRecipientToken = token;
        return token;
      }
      return '';
    } catch (e) {
      print('🚨 Error fetching recipient uuid: $e');
      return '';
    }
  }

  Future<String> fetchSenderName(String senderId) async {
    try {
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      return senderDoc.exists && senderDoc.data() != null
          ? senderDoc.data()!['name'] ?? 'User'
          : 'User';
    } catch (e) {
      print('🚨 Error fetching sender name: $e');
      return 'User';
    }
  }

  Future<void> sendNotification({
    required String recipientToken,
    required String title,
    required String body,
    required String senderId,
    required String receiverId,
  }) async {
    if (recipientToken.isEmpty) return;

    const String fcmUrl =
        'https://fcm.googleapis.com/v1/projects/cockster-e477a/messages:send';

    try {
      String accessToken;
      if (_cachedAccessToken != null &&
          _tokenCacheTime != null &&
          DateTime.now().difference(_tokenCacheTime!) < TOKEN_CACHE_DURATION) {
        accessToken = _cachedAccessToken!;
      } else {
        accessToken = await PushNotificationService.getAccessToken();
        _cachedAccessToken = accessToken;
        _tokenCacheTime = DateTime.now();
      }

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': recipientToken,
            'notification': {'title': title, 'body': body},
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'type': 'chat',
              'senderId': senderId,
              'receiverId': receiverId,
            },
          },
        }),
      );

      if (response.statusCode == 401) {
        _cachedAccessToken = null;
        _tokenCacheTime = null;
      }
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String messageText,
  }) async {
    try {
      final message = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(chatRef, {
        'participants': [senderId, receiverId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, message);
      await batch.commit();
    } catch (e) {
      print('🚨 Error sending message: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  Future<void> markMessagesAsRead(String chatId, String senderId) async {
    try {
      final snapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: senderId)
              .where('read', isEqualTo: false)
              .get();
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print('🚨 Error marking messages as read: $e');
    }
  }
}
