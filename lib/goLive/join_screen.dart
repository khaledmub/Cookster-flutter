import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videosdk/videosdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../appRoutes/appRoutes.dart';
import '../appUtils/colorUtils.dart';
import 'api_call.dart';
import 'ils_screen.dart';

class JoinScreen extends StatefulWidget {
  JoinScreen({super.key});

  @override
  _JoinScreenState createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  bool _isCreating = false;

  void onCreateButtonPressed(BuildContext context) async {
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
    });

    await createLivestream().then((liveStreamId) {
      // if (!context.mounted) return;
      Get.off(
        () => ILSScreen(
          liveStreamId: liveStreamId,
          token: token,
          mode: Mode.SEND_AND_RECV,
        ),
      );
    });
  }

  void onJoinButtonPressed(BuildContext context, String liveStreamId) {
    Get.off(
      () => ILSScreen(
        liveStreamId: liveStreamId,
        token: token,
        mode: Mode.RECV_ONLY,
      ),
    );
  }

  int entity = 0;

  Future<int> getEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(
      'Getting entity from shared preferences: ${prefs.getInt('entity') ?? 0}',
    );
    return prefs.getInt('entity') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadEntity(); // Call async method
  }

  void _loadEntity() async {
    entity = await getEntity();
    setState(() {}); // If UI depends on `entity`
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.primaryColor,
                    ColorUtils.primaryColor.withOpacity(0.9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      Get.offAllNamed(AppRoutes.landing);
                    },
                    child: Icon(Icons.arrow_back),
                  ),
                  SizedBox(width: 16),

                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.live_tv,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'go_live'.tr,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'start_streaming_or_join_others'.tr,
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Start New Livestream Card
                    if (entity == 2)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ColorUtils.primaryColor,
                              ColorUtils.primaryColor.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: ColorUtils.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap:
                                _isCreating
                                    ? null
                                    : () => onCreateButtonPressed(context),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child:
                                        _isCreating
                                            ? CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    ColorUtils.primaryColor,
                                                  ),
                                            )
                                            : const Icon(
                                              Icons.video_call,
                                              color: Colors.black,
                                              size: 32,
                                            ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isCreating
                                              ? 'creating_livestream'.tr
                                              : 'start_new_livestream'.tr,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isCreating
                                              ? 'please_wait_while_we_set_up_your_stream'
                                                  .tr
                                              : 'go_live_and_share_your_moments'
                                                  .tr,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (entity == 2) const SizedBox(height: 30),

                    // Active Livestreams Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: ColorUtils.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'live_now'.tr,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: ColorUtils.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'live'.tr,
                                style: TextStyle(
                                  color: ColorUtils.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Active Livestreams List
                    Expanded(
                      child: FutureBuilder<String?>(
                        future: SharedPreferences.getInstance().then(
                          (prefs) => prefs.getString('user_id'),
                        ),
                        builder: (context, prefsSnapshot) {
                          if (!prefsSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ColorUtils.primaryColor,
                                ),
                              ),
                            );
                          }

                          final currentUserId = prefsSnapshot.data;

                          return StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('liveVideos')
                                    .where('status', isEqualTo: 'active')
                                    .snapshots(),
                            builder: (context, liveSnapshot) {
                              if (liveSnapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.grey[600],
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Error loading livestreams',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (!liveSnapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ColorUtils.primaryColor,
                                    ),
                                  ),
                                );
                              }

                              // Filter out the current user's live stream
                              final liveVideos =
                                  liveSnapshot.data!.docs
                                      .where(
                                        (doc) => doc['userId'] != currentUserId,
                                      )
                                      .toList();

                              print(
                                "PRINTING CURRENT USER ID ${currentUserId}",
                              );

                              if (liveVideos.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.videocam_off,
                                          color: Colors.grey[400],
                                          size: 48,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'no_live_stream'.tr,
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'be_the_first_to_go_live'.tr,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: liveVideos.length,
                                itemBuilder: (context, index) {
                                  final liveVideo = liveVideos[index];
                                  final liveStreamId =
                                      liveVideo['livestreamId'] ?? '';
                                  final userId = liveVideo['userId'] ?? '';

                                  return FutureBuilder<DocumentSnapshot>(
                                    future:
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(userId)
                                            .get(),
                                    builder: (context, userSnapshot) {
                                      if (!userSnapshot.hasData) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: _buildLoadingCard(),
                                        );
                                      }

                                      if (userSnapshot.hasError) {
                                        return const SizedBox.shrink();
                                      }

                                      final userData =
                                          userSnapshot.data!.data()
                                              as Map<String, dynamic>?;
                                      final userName =
                                          userData?['name'] ?? 'Unknown User';
                                      final userImage =
                                          userData?['image'] ?? '';

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: _buildLiveStreamCard(
                                          context,
                                          userName,
                                          userImage,
                                          liveStreamId,
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamCard(
    BuildContext context,
    String userName,
    String userImage,
    String liveStreamId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onJoinButtonPressed(context, liveStreamId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColorUtils.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            userImage.isNotEmpty
                                ? Image.network(
                                  userImage,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[700],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  color: Colors.grey[700],
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: ColorUtils.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1A1A1A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: ColorUtils.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'livec'.tr,
                                  style: TextStyle(
                                    color: ColorUtils.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            liveStreamId,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'join'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
