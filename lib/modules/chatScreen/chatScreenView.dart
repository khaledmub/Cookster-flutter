import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/colorUtils.dart';
import '../../services/notificationService.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;

  const ChatScreen({required this.senderId, required this.receiverId, Key? key})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // Performance optimization variables
  int _unreadCount = 0;
  bool _isBlocked = false;
  bool _isSendingMessage = false;
  bool _isInChat = false; // Track if user is actively in chat
  Map<String, dynamic>? _receiverData;

  // Cache variables for performance
  String? _cachedRecipientToken;
  String? _cachedAccessToken;
  DateTime? _tokenCacheTime;

  // Keyboard visibility
  late KeyboardVisibilityController keyboardVisibilityController;
  bool _isKeyboardVisible = false;

  // Cache duration constants
  static const Duration TOKEN_CACHE_DURATION = Duration(hours: 1);

  String get chatId {
    List<String> ids = [widget.senderId, widget.receiverId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Optimized notification sending with caching
  Future<void> _sendNotification(
      String recipientToken, {
        required String title,
        required String body,
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
              'senderId': widget.senderId,
              'receiverId': widget.receiverId,
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

  Future<int> _getUnreadCount() async {
    try {
      final snapshot =
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: widget.senderId)
          .where('read', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('🚨 Error fetching unread count: $e');
      return 0;
    }
  }

  // Optimized recipient token fetching with caching
  Future<String> _fetchRecipientToken() async {
    if (_cachedRecipientToken != null) {
      return _cachedRecipientToken!;
    }

    try {
      final userDoc =
      await _firestore.collection('users').doc(widget.receiverId).get();
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

  // Improved message sending with better keyboard handling
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _isBlocked ||
        _isSendingMessage) {
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final message = {
      'senderId': widget.senderId,
      'receiverId': widget.receiverId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    try {
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(chatRef, {
        'participants': [widget.senderId, widget.receiverId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': widget.senderId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, message);

      await batch.commit();

      _handleNotificationAsync(messageText);

      // Auto-scroll after sending message
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      print('🚨 Error sending message: $e');
      _messageController.text = messageText;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  void _handleNotificationAsync(String messageText) async {
    try {
      final futures = await Future.wait([
        _fetchSenderName(),
        _fetchRecipientToken(),
      ]);

      final senderName = futures[0];
      final recipientToken = futures[1];

      if (recipientToken.isNotEmpty) {
        await _sendNotification(
          recipientToken,
          title: senderName,
          body: messageText,
        );
      }
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  Future<String> _fetchSenderName() async {
    try {
      final senderDoc =
      await _firestore.collection('users').doc(widget.senderId).get();
      return senderDoc.exists && senderDoc.data() != null
          ? senderDoc.data()!['name'] ?? 'User'
          : 'User';
    } catch (e) {
      return 'User';
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  // Enhanced message reading with real-time marking
  void _markMessagesAsRead() {
    if (_isBlocked || !_isInChat) return;

    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: widget.senderId)
        .where('read', isEqualTo: false)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        return batch.commit();
      }
    })
        .then((_) {
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    })
        .catchError((e) {
      print('🚨 Error marking messages as read: $e');
    });
  }

  // Listen to new messages and mark as read immediately if user is in chat
  void _setupMessageListener() {
    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && _isInChat) {
        final latestMessage = snapshot.docs.first.data() as Map<String, dynamic>;
        final receiverId = latestMessage['receiverId'] as String?;
        final isRead = latestMessage['read'] as bool? ?? false;

        // If the latest message is for current user and not read, mark it as read
        if (receiverId == widget.senderId && !isRead) {
          snapshot.docs.first.reference.update({'read': true});
        }
      }
    });
  }

  Future<void> _fetchReceiverData() async {
    try {
      final userDoc =
      await _firestore.collection('users').doc(widget.receiverId).get();
      final data =
      userDoc.exists
          ? {
        'name': userDoc.data()?['name'] ?? widget.receiverId,
        'image': userDoc.data()?['image'] ?? '',
      }
          : {'name': widget.receiverId, 'image': ''};

      if (mounted) {
        setState(() {
          _receiverData = data;
        });
      }
    } catch (e) {
      print('🚨 Error fetching receiver data: $e');
      if (mounted) {
        setState(() {
          _receiverData = {'name': widget.receiverId, 'image': ''};
        });
      }
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'today'.tr;
    if (messageDate == yesterday) return 'yesterday'.tr;
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  bool _shouldShowDateHeader(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    return DateTime(current.year, current.month, current.day) !=
        DateTime(previous.year, previous.month, previous.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isInChat = true;

    // Setup keyboard visibility listener
    keyboardVisibilityController = KeyboardVisibilityController();
    keyboardVisibilityController.onChange.listen((bool visible) {
      setState(() {
        _isKeyboardVisible = visible;
      });

      if (visible) {
        // Scroll to bottom when keyboard appears
        Future.delayed(Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });

    _initializeChat();
    _setupMessageListener();
  }

  void _initializeChat() async {
    try {
      await Future.wait([
        _fetchReceiverData(),
        _getUnreadCount().then((count) {
          if (mounted) {
            setState(() {
              _unreadCount = count;
            });
          }
          if (count > 0 && !_isBlocked) {
            _markMessagesAsRead();
          }
        }),
        _fetchRecipientToken(),
      ]);
    } catch (e) {
      print('🚨 Error initializing chat: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isInChat = true;
        _markMessagesAsRead();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isInChat = false;
        break;
      case AppLifecycleState.detached:
        _isInChat = false;
        break;
      case AppLifecycleState.hidden:
        _isInChat = false;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey[200],
        title:
        _receiverData == null
            ? Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorUtils.primaryColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'loading'.tr,
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ],
        )
            : StreamBuilder<DocumentSnapshot>(
          stream:
          _firestore.collection('chats').doc(chatId).snapshots(),
          builder: (context, snapshot) {
            bool isBlocked = false;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data =
              snapshot.data!.data() as Map<String, dynamic>?;
              final blockedBy = List<String>.from(
                data?['blockedBy'] ?? [],
              );
              isBlocked = blockedBy.contains(widget.senderId);
              _isBlocked = isBlocked;
            }

            final receiverName = _receiverData!['name'] as String;
            final receiverImage = _receiverData!['image'] as String;

            return Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ColorUtils.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                    receiverImage.isNotEmpty
                        ? CachedNetworkImageProvider(
                      '${Common.profileImage}/${receiverImage}',
                    )
                        : null,
                    child:
                    receiverImage.isEmpty
                        ? Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.grey[600],
                    )
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiverName,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: 12,
                            width: 80,
                            color: Colors.grey[300],
                          ),
                        ),
                      if (snapshot.connectionState ==
                          ConnectionState.active &&
                          isBlocked)
                        Text(
                          'blocked'.tr,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        )

                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
              _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'something_went_wrong'.tr,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                final messages = snapshot.data?.docs;
                if (messages == null || messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'no_messages_yet'.tr,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'start_conversation'.tr,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                List<Widget> messageWidgets = [];
                DateTime? previousDate;

                for (var messageDoc in messages) {
                  final message = messageDoc.data() as Map<String, dynamic>;
                  final timestamp = message['timestamp'] as Timestamp?;
                  if (timestamp == null) continue;

                  final messageDate = timestamp.toDate();
                  final isMe = message['senderId'] == widget.senderId;
                  final isRead = message['read'] as bool? ?? false;

                  if (_shouldShowDateHeader(messageDate, previousDate)) {
                    messageWidgets.add(
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _formatDateHeader(messageDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  messageWidgets.add(
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                      child: Row(
                        mainAxisAlignment:
                        isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // if (!isMe) ...[
                          //   CircleAvatar(
                          //     radius: 12,
                          //     backgroundColor: Colors.grey[300],
                          //     child: Icon(
                          //       Icons.person,
                          //       size: 16,
                          //       color: Colors.grey[600],
                          //     ),
                          //   ),
                          //   SizedBox(width: 8),
                          // ],
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient:
                                      isMe
                                          ? LinearGradient(
                                        colors: [
                                          ColorUtils.primaryColor,
                                          Color(0xFFFFE55C),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                          : null,
                                      color: isMe ? null : Colors.grey[200],
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(
                                          isMe ? 20 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 4 : 20,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      message['message'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color:
                                        isMe
                                            ? Colors.black87
                                            : Colors.grey[800],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(messageDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      // if (isMe) ...[
                                      //   SizedBox(width: 4),
                                      //   Icon(
                                      //     isRead ? Icons.done_all : Icons.done,
                                      //     size: 14,
                                      //     color:
                                      //     isRead
                                      //         ? Colors.blue
                                      //         : Colors.grey[500],
                                      //   ),
                                      // ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  previousDate = messageDate;
                }

                // Auto-scroll to bottom after messages load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollToBottom(animated: false);
                  }
                });

                return GestureDetector(
                  onTap: () {
                    // Hide keyboard when tapping on messages area
                    _messageFocusNode.unfocus();
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    children: messageWidgets,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  ),
                );
              },
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('chats').doc(chatId).snapshots(),
            builder: (context, snapshot) {
              bool isBlocked = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final blockedBy = List<String>.from(data?['blockedBy'] ?? []);
                isBlocked = blockedBy.contains(widget.senderId);
                _isBlocked = isBlocked;
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.grey[300],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          color: Colors.grey[300],
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 150,
                          height: 14,
                          color: Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (isBlocked) {
                return Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.redAccent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'you_blocked_user'.tr,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            style: TextStyle(color: Colors.grey[800]),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'type_message'.tr,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                            onTap: () {
                              // Scroll to bottom when text field is tapped
                              Future.delayed(Duration(milliseconds: 300), () {
                                _scrollToBottom();
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ColorUtils.primaryColor, Color(0xFFFFE55C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ColorUtils.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon:
                          _isSendingMessage
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black87,
                              ),
                            ),
                          )
                              : Icon(
                            Icons.send,
                            color: Colors.black87,
                            size: 20,
                          ),
                          onPressed: _isSendingMessage ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isInChat = false;
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}