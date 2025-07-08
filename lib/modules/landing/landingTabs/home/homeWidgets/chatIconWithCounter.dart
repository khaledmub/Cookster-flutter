import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:async';

class ChatIconWithCounter extends StatelessWidget {
  final String userId;
  final bool isAuthenticated;
  final VoidCallback onTap;

  const ChatIconWithCounter({
    Key? key,
    required this.userId,
    required this.isAuthenticated,
    required this.onTap,
  }) : super(key: key);

  // Method to get count of chats with unread messages
  Stream<int> _getUnreadChatCount(String currentUserId) {
    // Create a stream controller to manage the combined stream
    final StreamController<int> controller = StreamController<int>();

    // Keep track of active subscriptions
    final Map<String, StreamSubscription> messageSubscriptions = {};
    StreamSubscription? chatSubscription;

    void updateUnreadCount() async {
      try {
        // Get all chats for current user
        final chatsSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .get();

        int unreadChatCount = 0;

        for (var doc in chatsSnapshot.docs) {
          final data = doc.data();
          final blockedBy = List<String>.from(data['blockedBy'] ?? []);

          // Skip if current user is blocked
          if (blockedBy.contains(currentUserId)) {
            continue;
          }

          // Check if this chat has any unread messages for current user
          final unreadSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .where('receiverId', isEqualTo: currentUserId)
              .where('read', isEqualTo: false)
              .limit(1)
              .get();

          if (unreadSnapshot.docs.isNotEmpty) {
            unreadChatCount++;
          }
        }

        if (!controller.isClosed) {
          controller.add(unreadChatCount);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Listen to changes in chats collection
    chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      // Cancel previous message subscriptions
      for (var sub in messageSubscriptions.values) {
        sub.cancel();
      }
      messageSubscriptions.clear();

      // Set up new message subscriptions for each chat
      for (var doc in snapshot.docs) {
        final chatId = doc.id;
        final data = doc.data();
        final blockedBy = List<String>.from(data['blockedBy'] ?? []);

        // Skip if current user is blocked
        if (blockedBy.contains(currentUserId)) {
          continue;
        }

        // Listen to messages in this chat
        messageSubscriptions[chatId] = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .snapshots()
            .listen((_) {
          // When any message changes, update the count
          updateUnreadCount();
        });
      }

      // Initial count update
      updateUnreadCount();
    });

    // Clean up subscriptions when stream is closed
    controller.onCancel = () {
      chatSubscription?.cancel();
      for (var sub in messageSubscriptions.values) {
        sub.cancel();
      }
      messageSubscriptions.clear();
    };

    return controller.stream;
  }

  // Alternative simpler approach - listen to all messages globally
  Stream<int> _getUnreadChatCountAlternative(String currentUserId) {
    return FirebaseFirestore.instance
        .collectionGroup('messages') // Listen to all messages across all chats
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return 0;

      // Get unique chat IDs from unread messages
      Set<String> chatIds = {};
      for (var doc in snapshot.docs) {
        // Extract chat ID from document path
        final pathSegments = doc.reference.path.split('/');
        if (pathSegments.length >= 2) {
          chatIds.add(pathSegments[1]); // chats/{chatId}/messages/{messageId}
        }
      }

      // Filter out blocked chats
      int unreadChatCount = 0;
      for (String chatId in chatIds) {
        try {
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();

          if (chatDoc.exists) {
            final data = chatDoc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final blockedBy = List<String>.from(data['blockedBy'] ?? []);

            // Only count if user is participant and not blocked
            if (participants.contains(currentUserId) && !blockedBy.contains(currentUserId)) {
              unreadChatCount++;
            }
          }
        } catch (e) {
          // Skip this chat if there's an error
          continue;
        }
      }

      return unreadChatCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset(
                    "assets/icons/chatIcon.svg",
                    color: Colors.white,
                  ),
                  // Only show counter if user is authenticated
                  if (isAuthenticated)
                    StreamBuilder<int>(
                      stream: _getUnreadChatCountAlternative(userId), // Using the alternative approach
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data! > 0) {
                          final count = snapshot.data!;
                          return Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: count > 9
                                  ? const Text(
                                '9+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              )
                                  : Text(
                                count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}