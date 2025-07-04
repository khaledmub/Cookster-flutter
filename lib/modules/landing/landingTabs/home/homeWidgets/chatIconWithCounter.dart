import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      int unreadChatCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
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
            .limit(1) // We only need to know if there's at least one unread message
            .get();

        if (unreadSnapshot.docs.isNotEmpty) {
          unreadChatCount++;
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
                      stream: _getUnreadChatCount(userId),
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
                                // borderRadius: BorderRadius.circular(10),
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