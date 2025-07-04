import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../chatModel/chatModel.dart';

class ChatController extends GetxController with WidgetsBindingObserver {
  final ChatModel _model = ChatModel();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode messageFocusNode = FocusNode();

  var unreadCount = 0.obs;
  var isBlocked = false.obs;
  var isSendingMessage = false.obs;
  var isInChat = true.obs;
  var receiverData = <String, dynamic>{}.obs;

  late String chatId;
  final String senderId;
  final String receiverId;

  ChatController({required this.senderId, required this.receiverId}) {
    chatId = _model.getChatId(senderId, receiverId);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupMessageListener();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      markMessagesAsRead();
    }
  }

  Future<void> _initializeChat() async {
    try {
      final futures = await Future.wait([
        _model.fetchReceiverData(receiverId),
        _model.getUnreadCount(chatId, senderId),
        _model.fetchRecipientToken(receiverId),
      ]);
      receiverData.value = futures[0] as Map<String, dynamic>;
      unreadCount.value = futures[1] as int;
      if (unreadCount.value > 0 && !isBlocked.value) {
        markMessagesAsRead();
      }
    } catch (e) {
      print('🚨 Error initializing chat: $e');
      receiverData.value = {'name': receiverId, 'image': ''};
    }
  }

  void sendMessage() {
    if (messageController.text.trim().isEmpty ||
        isBlocked.value ||
        isSendingMessage.value) {
      return;
    }

    isSendingMessage.value = true;
    final messageText = messageController.text.trim();
    messageController.clear();

    _model
        .sendMessage(
          chatId: chatId,
          senderId: senderId,
          receiverId: receiverId,
          messageText: messageText,
        )
        .then((_) {
          _handleNotificationAsync(messageText);
          scrollToBottom();
          isSendingMessage.value = false;
          messageFocusNode.requestFocus();
        })
        .catchError((e) {
          print('🚨 Error sending message: $e');
          messageController.text = messageText;
          isSendingMessage.value = false;
          Get.snackbar(
            'Error',
            'Failed to send message',
            backgroundColor: Colors.red,
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 2),
          );
        });
  }

  void _handleNotificationAsync(String messageText) async {
    try {
      final futures = await Future.wait([
        _model.fetchSenderName(senderId),
        _model.fetchRecipientToken(receiverId),
      ]);
      final senderName = futures[0] as String;
      final recipientToken = futures[1] as String;
      if (recipientToken.isNotEmpty) {
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

  void scrollToBottom({bool animated = true}) {
    if (scrollController.hasClients) {
      if (animated) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    }
  }

  void markMessagesAsRead() {
    if (isBlocked.value || !isInChat.value) return;
    _model
        .markMessagesAsRead(chatId, senderId)
        .then((_) {
          unreadCount.value = 0;
        })
        .catchError((e) {
          print('🚨 Error marking messages as read: $e');
        });
  }

  void _setupMessageListener() {
    _model.getMessagesStream(chatId).listen((snapshot) {
      if (snapshot.docs.isNotEmpty && isInChat.value) {
        final latestMessage =
            snapshot.docs.first.data() as Map<String, dynamic>?;
        if (latestMessage == null) return;
        final receiverId = latestMessage['receiverId'] as String?;
        final isRead = latestMessage['read'] as bool? ?? false;
        if (receiverId == senderId && !isRead) {
          snapshot.docs.first.reference.update({'read': true});
          unreadCount.value = 0;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        isInChat.value = true;
        markMessagesAsRead();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        isInChat.value = false;
        break;
    }
  }

  Stream<QuerySnapshot> getMessagesStream() {
    return _model.getMessagesStream(chatId);
  }

  Stream<DocumentSnapshot> getChatStream() {
    return _model.getChatStream(chatId);
  }

  @override
  void onClose() {
    isInChat.value = false;
    WidgetsBinding.instance.removeObserver(this);
    messageController.dispose();
    messageFocusNode.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
