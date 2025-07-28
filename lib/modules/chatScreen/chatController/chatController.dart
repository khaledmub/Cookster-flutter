import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../chatModel/chatModel.dart';

class ChatController extends GetxController with WidgetsBindingObserver {
  final ChatModel _model = ChatModel();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode messageFocusNode = FocusNode();

  // Reactive variables
  var unreadCount = 0.obs;
  var isBlocked = false.obs;
  var isSendingMessage = false.obs;
  var isInChat = true.obs;
  var receiverData = <String, dynamic>{}.obs;
  var isTyping = false.obs;
  var receiverTyping = false.obs;
  var isOnline = false.obs;
  var lastSeen = Rxn<DateTime>();
  var connectionState = 'connecting'.obs;

  // Private variables
  late String chatId;
  final String senderId;
  final String receiverId;

  Timer? _typingTimer;
  Timer? _scrollTimer;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  StreamSubscription<DocumentSnapshot>? _receiverStatusSubscription;

  bool _isScrolling = false;
  bool _shouldAutoScroll = true;
  int _lastMessageCount = 0;

  ChatController({required this.senderId, required this.receiverId}) {
    chatId = _model.getChatId(senderId, receiverId);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupListeners();
    _setupTextFieldListener();
    _updateUserPresence(true);
  }

  Future<void> _initializeChat() async {
    try {
      connectionState.value = 'connecting';

      // Run initialization tasks in parallel
      final futures = await Future.wait([
        _model.fetchReceiverData(receiverId),
        _model.getUnreadCount(chatId, senderId),
        _model.fetchRecipientToken(receiverId),
      ]);

      receiverData.value = futures[0] as Map<String, dynamic>;
      unreadCount.value = futures[1] as int;

      connectionState.value = 'connected';

      // Mark messages as read if there are unread messages
      if (unreadCount.value > 0 && !isBlocked.value) {
        await markMessagesAsRead();
      }

      // Auto-scroll to bottom after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomSmooth(delay: 500);
      });
    } catch (e) {
      print('🚨 Error initializing chat: $e');
      connectionState.value = 'error';
      receiverData.value = {'name': receiverId, 'image': '', 'isOnline': false};
      _showError('Failed to load chat');
    }
  }

  void _setupListeners() {
    _setupScrollListener();
    _setupMessageListener();
    _setupChatListener();
    _setupReceiverStatusListener();
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      final position = scrollController.position;
      _isScrolling = true;

      // Cancel any pending scroll timer
      _scrollTimer?.cancel();

      // Set a timer to detect when scrolling stops
      _scrollTimer = Timer(Duration(milliseconds: 150), () {
        _isScrolling = false;
      });

      // Update auto-scroll preference based on scroll position
      final distanceFromBottom = position.maxScrollExtent - position.pixels;
      _shouldAutoScroll = distanceFromBottom < 100;

      // Mark messages as read when scrolled to bottom
      if (distanceFromBottom < 50 && unreadCount.value > 0) {
        markMessagesAsRead();
      }
    });
  }

  void _setupMessageListener() {
    _messagesSubscription = _model
        .getMessagesStream(chatId)
        .listen(
          (snapshot) {
            if (snapshot.docs.isEmpty) return;

            final currentMessageCount = snapshot.docs.length;
            final isNewMessage = currentMessageCount > _lastMessageCount;
            _lastMessageCount = currentMessageCount;

            // Auto-scroll for new messages if conditions are met
            if (isNewMessage && _shouldAutoScroll && !_isScrolling) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottomSmooth(delay: 100);
              });
            }

            // Handle message read status
            if (isInChat.value) {
              _handleMessageReadStatus(snapshot.docs);
            }
          },
          onError: (error) {
            print('🚨 Error in message stream: $error');
            connectionState.value = 'error';
          },
        );
  }

  void _setupChatListener() {
    _chatSubscription = _model
        .getChatStream(chatId)
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>?;
              if (data != null) {
                final blockedBy = List<String>.from(data['blockedBy'] ?? []);
                isBlocked.value = blockedBy.contains(senderId);

                // Handle typing indicators
                final typingUsers = Map<String, dynamic>.from(
                  data['typing'] ?? {},
                );
                receiverTyping.value = typingUsers[receiverId] == true;
              }
            }
          },
          onError: (error) {
            print('🚨 Error in chat stream: $error');
          },
        );
  }

  void _setupReceiverStatusListener() {
    _receiverStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data != null) {
                isOnline.value = data['isOnline'] ?? false;
                if (data['lastSeen'] != null) {
                  lastSeen.value = (data['lastSeen'] as Timestamp).toDate();
                }
              }
            }
          },
          onError: (error) {
            print('🚨 Error in receiver status stream: $error');
          },
        );
  }

  void _setupTextFieldListener() {
    messageController.addListener(() {
      final hasText = messageController.text.trim().isNotEmpty;

      if (hasText && !isTyping.value) {
        _startTyping();
      } else if (!hasText && isTyping.value) {
        _stopTyping();
      }
    });
  }

  void _handleMessageReadStatus(List<QueryDocumentSnapshot> docs) {
    for (final doc in docs) {
      final message = doc.data() as Map<String, dynamic>?;
      if (message == null) continue;

      final messageReceiverId = message['receiverId'] as String?;
      final isRead = message['read'] as bool? ?? false;

      // Mark message as read if it's for current user and not already read
      if (messageReceiverId == senderId && !isRead) {
        doc.reference.update({'read': true}).catchError((e) {
          print('🚨 Error updating read status: $e');
        });
      }
    }
  }

  Future<void> sendMessage() async {
    final messageText = messageController.text.trim();

    if (messageText.isEmpty || isBlocked.value || isSendingMessage.value) {
      return;
    }

    try {
      isSendingMessage.value = true;
      messageController.clear();
      _stopTyping();

      // Send message with optimistic UI update
      await _model.sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        messageText: messageText,
      );

      // Handle post-send actions
      await Future.wait([
        _handleNotificationAsync(messageText),
        Future.delayed(Duration(milliseconds: 100)),
        // Small delay for smooth UX
      ]);

      // Auto-scroll and focus
      _shouldAutoScroll = true;
      _scrollToBottomSmooth();

      // Request focus back to input field
      if (!messageFocusNode.hasFocus) {
        messageFocusNode.requestFocus();
      }
    } catch (e) {
      print('🚨 Error sending message: $e');
      // Restore message text on error
      messageController.text = messageText;
      _showError('Failed to send message');
    } finally {
      isSendingMessage.value = false;
    }
  }

  Future<void> _handleNotificationAsync(String messageText) async {
    try {
      final futures = await Future.wait([
        _model.fetchSenderName(senderId),
        _model.fetchRecipientToken(receiverId),
      ]);

      final senderName = futures[0];
      final recipientToken = futures[1];

      if (recipientToken.isNotEmpty && !isOnline.value) {
        await _model.sendNotification(
          recipientToken: recipientToken,
          title: senderName,
          body: messageText,
          senderId: senderId,
          receiverId: receiverId,
        );
      }
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  void _startTyping() {
    isTyping.value = true;
    _updateTypingStatus(true);

    // Cancel existing timer
    _typingTimer?.cancel();

    // Stop typing after 3 seconds of inactivity
    _typingTimer = Timer(Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    isTyping.value = false;
    _updateTypingStatus(false);
    _typingTimer?.cancel();
  }

  Future<void> _updateTypingStatus(bool typing) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'typing.$senderId': typing,
      });
    } catch (e) {
      print('🚨 Error updating typing status: $e');
    }
  }

  void scrollToBottom({bool animated = true, int delay = 0}) {
    if (delay > 0) {
      Future.delayed(Duration(milliseconds: delay), () {
        _performScroll(animated);
      });
    } else {
      _performScroll(animated);
    }
  }

  void _scrollToBottomSmooth({int delay = 0}) {
    scrollToBottom(animated: true, delay: delay);
  }

  void _performScroll(bool animated) {
    if (!scrollController.hasClients) return;

    final maxScrollExtent = scrollController.position.maxScrollExtent;

    if (animated) {
      scrollController
          .animateTo(
            maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          .catchError((e) {
            print('🚨 Error during animated scroll: $e');
          });
    } else {
      scrollController.jumpTo(maxScrollExtent);
    }
  }

  Future<void> markMessagesAsRead() async {
    if (isBlocked.value || !isInChat.value || unreadCount.value == 0) return;

    try {
      await _model.markMessagesAsRead(chatId, senderId);
      unreadCount.value = 0;
    } catch (e) {
      print('🚨 Error marking messages as read: $e');
    }
  }

  Future<void> _updateUserPresence(bool isOnline) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(senderId).update(
        {'isOnline': isOnline, 'lastSeen': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      print('🚨 Error updating user presence: $e');
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 3),
      margin: EdgeInsets.all(16),
      borderRadius: 8,
      isDismissible: true,
    );
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 2),
      margin: EdgeInsets.all(16),
      borderRadius: 8,
      isDismissible: true,
    );
  }

  // Public methods for UI interactions
  void onMessageInputTap() {
    _shouldAutoScroll = true;
    _scrollToBottomSmooth(delay: 300);
  }

  void onMessageInputSubmit() {
    sendMessage();
  }

  void retryConnection() {
    connectionState.value = 'connecting';
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        isInChat.value = true;
        _updateUserPresence(true);
        markMessagesAsRead();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        isInChat.value = false;
        _updateUserPresence(false);
        _stopTyping();
        break;
    }
  }

  // Stream getters
  Stream<QuerySnapshot> getMessagesStream() {
    return _model.getMessagesStream(chatId);
  }

  Stream<DocumentSnapshot> getChatStream() {
    return _model.getChatStream(chatId);
  }

  // Cleanup
  void _cancelSubscriptions() {
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _receiverStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _scrollTimer?.cancel();
  }

  @override
  void onClose() {
    isInChat.value = false;
    _updateUserPresence(false);
    _stopTyping();

    // Remove observers and cancel subscriptions
    WidgetsBinding.instance.removeObserver(this);
    _cancelSubscriptions();

    // Dispose controllers
    messageController.dispose();
    messageFocusNode.dispose();
    scrollController.dispose();

    super.onClose();
  }
}
