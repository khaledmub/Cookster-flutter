import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../appUtils/colorUtils.dart';

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;

  const ChatScreen({required this.senderId, required this.receiverId, Key? key})
    : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  int _unreadCount = 0;
  bool _isBlocked = false;
  bool _isLoadingBlockedStatus = true;

  String get chatId {
    List<String> ids = [widget.senderId, widget.receiverId]..sort();
    return '${ids[0]}_${ids[1]}';
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
      print('📬 Unread count for chatId $chatId: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e) {
      print('🚨 Error fetching unread count: $e');
      return 0;
    }
  }

  Future<bool> _checkBlockedStatus() async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final blockedBy = List<String>.from(chatDoc.data()?['blockedBy'] ?? []);
      print('🔒 BlockedBy for chat $chatId: $blockedBy');
      return blockedBy.contains(widget.senderId);
    } catch (e) {
      print('🚨 Error checking blocked status: $e');
      return false;
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _isBlocked) return;

    final messageText = _messageController.text.trim();
    final message = {
      'senderId': widget.senderId,
      'receiverId': widget.receiverId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    try {
      // Update the parent chat document
      _firestore.collection('chats').doc(chatId).set({
        'participants': [widget.senderId, widget.receiverId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': widget.senderId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add the message to the messages subcollection
      _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message);

      _messageController.clear();

      // Scroll to bottom
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      print('✅ Message sent successfully to chatId: $chatId');
    } catch (e) {
      print('🚨 Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markMessagesAsRead() {
    if (_isBlocked) return;
    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: widget.senderId)
        .where('read', isEqualTo: false)
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'read': true});
          }
          setState(() {
            _unreadCount = 0;
          });
        })
        .catchError((e) {
          print('🚨 Error marking messages as read: $e');
        });
  }

  Future<Map<String, dynamic>> _fetchReceiverData() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(widget.receiverId).get();
      return userDoc.exists
          ? {
            'name': userDoc.data()?['name'] ?? widget.receiverId,
            'image': userDoc.data()?['image'] ?? '',
          }
          : {'name': widget.receiverId, 'image': ''};
    } catch (e) {
      print('🚨 Error fetching receiver data: $e');
      return {'name': widget.receiverId, 'image': ''};
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
    // Fetch initial unread count and blocked status
    _getUnreadCount().then((count) {
      setState(() {
        _unreadCount = count;
      });
      if (count > 0 && !_isBlocked) {
        _markMessagesAsRead();
      }
    });
    _checkBlockedStatus().then((isBlocked) {
      setState(() {
        _isBlocked = isBlocked;
        _isLoadingBlockedStatus = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey[200],
        title: FutureBuilder<Map<String, dynamic>>(
          future: _fetchReceiverData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
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
              );
            }

            final receiverData =
                snapshot.data ?? {'name': widget.receiverId, 'image': ''};
            final receiverName = receiverData['name'] as String;
            final receiverImage = receiverData['image'] as String;

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
                            ? CachedNetworkImageProvider(receiverImage)
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
                      if (_isLoadingBlockedStatus)
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: 12,
                            width: 80,
                            color: Colors.grey[300],
                          ),
                        ),
                      if (!_isLoadingBlockedStatus &&
                          _unreadCount > 0 &&
                          !_isBlocked)
                        Text(
                          '$_unreadCount ${'new_messages'.tr}',
                          style: TextStyle(
                            color: Colors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (!_isLoadingBlockedStatus && _isBlocked)
                        Text(
                          'blocked'.tr,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColorUtils.primaryColor,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
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
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
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
                                      if (isMe) ...[
                                        SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all : Icons.done,
                                          size: 14,
                                          color:
                                              isRead
                                                  ? Colors.blue
                                                  : Colors.grey[500],
                                        ),
                                      ],
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

                return ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  children: messageWidgets,
                );
              },
            ),
          ),
          if (_isLoadingBlockedStatus)
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.grey[300],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 20, height: 20, color: Colors.grey[300]),
                    SizedBox(width: 8),
                    Container(width: 150, height: 14, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
          if (!_isLoadingBlockedStatus && _isBlocked)
            Container(
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
                  // SizedBox(width: 16),
                  // TextButton(
                  //   onPressed: _unblockUser,
                  //   child: Text(
                  //     'Unblock',
                  //     style: TextStyle(
                  //       color: Colors.teal,
                  //       fontSize: 14,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          if (!_isLoadingBlockedStatus && !_isBlocked)
            Container(
              padding: EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: Colors.grey[800]),
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
                      icon: Icon(Icons.send, color: Colors.black87, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
