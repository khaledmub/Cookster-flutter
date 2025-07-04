import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/colorUtils.dart';
import 'chatController/chatController.dart';

class ChatView extends StatelessWidget {
  final String senderId;
  final String receiverId;

  const ChatView({required this.senderId, required this.receiverId, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ChatController(senderId: senderId, receiverId: receiverId),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Obx(() => _buildAppBarContent(controller)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: StreamBuilder<QuerySnapshot>(
                stream: controller.getMessagesStream(),
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
                            color: ColorUtils.primaryColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'no_messages_yet'.tr,
                            style: TextStyle(
                              color: ColorUtils.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                    final isMe = message['senderId'] == senderId;

                    if (_shouldShowDateHeader(messageDate, previousDate)) {
                      messageWidgets.add(
                        Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 12),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
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
                      );
                    }

                    messageWidgets.add(
                      Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  message['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatTime(messageDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    previousDate = messageDate;
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.scrollToBottom(animated: false);
                  });

                  return ListView(
                    controller: controller.scrollController,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    children: messageWidgets,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                  );
                },
              ),
            ),
          ),
          _buildMessageInput(context, controller),
        ],
      ),
    );
  }

  Widget _buildAppBarContent(ChatController controller) {
    if (controller.receiverData.isEmpty) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: Colors.grey[300]),
            SizedBox(width: 12),
            Container(width: 100, height: 16, color: Colors.grey[300]),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: controller.getChatStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final blockedBy = List<String>.from(data?['blockedBy'] ?? []);
          controller.isBlocked.value = blockedBy.contains(senderId);
        }

        final receiverName = controller.receiverData['name'] as String;
        final receiverImage = controller.receiverData['image'] as String;

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  receiverImage.isNotEmpty
                      ? CachedNetworkImageProvider(
                        '${Common.profileImage}/$receiverImage',
                      )
                      : null,
              child:
                  receiverImage.isEmpty
                      ? Icon(Icons.person, color: Colors.grey[600])
                      : null,
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiverName,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (controller.isBlocked.value)
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
          ],
        );
      },
    );
  }

  Widget _buildMessageInput(BuildContext context, ChatController controller) {
    return StreamBuilder<DocumentSnapshot>(
      stream: controller.getChatStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final blockedBy = List<String>.from(data?['blockedBy'] ?? []);
          controller.isBlocked.value = blockedBy.contains(senderId);
        }

        if (controller.isBlocked.value) {
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
            top: 12,
            bottom: 12 + MediaQuery.of(context).viewPadding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.messageController,
                    focusNode: controller.messageFocusNode,
                    style: TextStyle(color: Colors.black87),
                    maxLines: 4,
                    minLines: 1,
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
                    onSubmitted: (_) => controller.sendMessage(),
                    textInputAction: TextInputAction.send,
                    onTap: () => controller.scrollToBottom(),
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
                      controller.isSendingMessage.value
                          ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(Icons.send, color: Colors.white, size: 24),
                  onPressed:
                      controller.isSendingMessage.value
                          ? null
                          : controller.sendMessage,
                ),
              ),
            ],
          ),
        );
      },
    );
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
}
