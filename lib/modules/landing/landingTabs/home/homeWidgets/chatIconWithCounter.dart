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

  Stream<int> _getUnreadChatCount(String currentUserId) {
    final controller = StreamController<int>.broadcast();
    StreamSubscription? messagesSub;
    Timer? debounce;

    Future<void> emitCount() async {
      try {
        final chatsSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .get();

        final allowedChatIds = <String>{};
        for (final doc in chatsSnapshot.docs) {
          final blockedBy = List<String>.from(doc.data()['blockedBy'] ?? []);
          if (!blockedBy.contains(currentUserId)) {
            allowedChatIds.add(doc.id);
          }
        }

        if (allowedChatIds.isEmpty) {
          if (!controller.isClosed) controller.add(0);
          return;
        }

        final unreadSnapshot = await FirebaseFirestore.instance
            .collectionGroup('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .where('read', isEqualTo: false)
            .get();

        final chatIds = <String>{};
        for (final doc in unreadSnapshot.docs) {
          final segments = doc.reference.path.split('/');
          if (segments.length >= 2 &&
              allowedChatIds.contains(segments[1])) {
            chatIds.add(segments[1]);
          }
        }

        if (!controller.isClosed) {
          controller.add(chatIds.length);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    void scheduleCountUpdate() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), emitCount);
    }

    messagesSub = FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((_) => scheduleCountUpdate());

    scheduleCountUpdate();

    controller.onCancel = () {
      debounce?.cancel();
      messagesSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            "assets/icons/chatIcon.svg",
            color: Colors.white,
          ),
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
    );
  }
}
