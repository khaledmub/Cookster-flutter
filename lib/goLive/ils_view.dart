import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:videosdk/videosdk.dart';
import 'api_call.dart';
import 'commentWIdget.dart';
import 'livestream_controls.dart';
import 'participant_grid.dart';

class ILSView extends StatefulWidget {
  final Room room;
  final Mode mode;
  final bool bar;
  final String roomId;
  final String liveStreamId;

  const ILSView({
    super.key,
    required this.room,
    required this.bar,
    required this.mode,
    required this.roomId,
    required this.liveStreamId,
  });

  @override
  State<ILSView> createState() => _ILSViewState();
}

class _ILSViewState extends State<ILSView> {
  var micEnabled = true;
  var camEnabled = true;

  Map<String, Participant> participants = {};
  Mode? localMode;
  bool isHost = false;

  @override
  void initState() {
    super.initState();
    localMode = widget.mode;

    // Check if current user is host (you can modify this logic based on your app's host identification)
    // For example, if host is the first participant or has a specific property
    isHost = _checkIfUserIsHost();

    //Setting up the event listeners and initializing the participants and hls state
    setlivestreamEventListener();
    participants.putIfAbsent(
      widget.room.localParticipant.id,
      () => widget.room.localParticipant,
    );
    //filtering the CONFERENCE participants to be shown in the grid
    widget.room.participants.values.forEach((participant) {
      if (participant.mode == Mode.SEND_AND_RECV) {
        participants.putIfAbsent(participant.id, () => participant);
      }
    });
  }

  // Method to check if current user is host
  bool _checkIfUserIsHost() {
    return widget.mode == Mode.SEND_AND_RECV;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          // ParticipantGrid should take full available space
          ParticipantGrid(room: widget.room),

          // SafeArea for controls
          SafeArea(
            child: Column(
              children: [
                // Top section for End/Leave button and user count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    // mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('liveVideos')
                                .doc(widget.roomId)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Loading...',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final int count = data?['joinedUsersCount'] ?? 0;
                          final String userId = data?['userId'] ?? '';

                          return FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Loading user...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              if (userSnapshot.hasError) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Error loading user',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final userName =
                                  userData?['name'] ?? 'Unknown User';
                              final userImage =
                                  userData?['image'] ??
                                  'https://via.placeholder.com/40/FF6B6B/FFFFFF?text=U';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // User Image
                                    Container(
                                      width: 24,
                                      // Smaller size for compact layout
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[700],
                                        image:
                                            userImage.isNotEmpty
                                                ? DecorationImage(
                                                  image: NetworkImage(
                                                    userImage,
                                                  ),
                                                  fit: BoxFit.cover,
                                                  onError: (
                                                    exception,
                                                    stackTrace,
                                                  ) {
                                                    // Optional: Log error
                                                    print(
                                                      'Image load error: $exception',
                                                    );
                                                  },
                                                )
                                                : null,
                                      ),
                                      child:
                                          userImage.isEmpty
                                              ? const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 24,
                                              )
                                              : ClipOval(
                                                child: Image.network(
                                                  userImage,
                                                  fit: BoxFit.cover,
                                                  width: 24,
                                                  height: 24,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return const Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 24,
                                                    );
                                                  },
                                                ),
                                              ),
                                    ),
                                    const SizedBox(width: 8),
                                    // User Name and Likes Count
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Likes $count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Spacer(),
                      // Host gets "End" button, others get "Leave" button
                      ElevatedButton(
                        onPressed: () {
                          if (isHost) {
                            _endLivestream();
                          } else {
                            widget.room.leave();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                        child: Text(
                          isHost ? "End" : "Leave",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),

                      SizedBox(width: 8),

                      StreamBuilder<DocumentSnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('liveVideos')
                                .doc(widget.roomId)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Loading count...',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }
                          int count = snapshot.data!['joinedUsersCount'] ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                Text(
                                  ' $count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Spacer to push comments to the bottom
                const Expanded(child: SizedBox.shrink()),
                // Bottom section for comments
                SizedBox(
                  height: 300, // Adjust height as needed
                  child: CommentWidget(liveStreamId: widget.liveStreamId),
                ),
              ],
            ),
          ),

          // Uncomment and implement if needed
          // _buildLivestreamControls(),
        ],
      ),
    );
  }

  // Method to end livestream for host
  void _endLivestream() {
    // Show confirmation dialog for host
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("End Livestream"),
          content: const Text(
            "Are you sure you want to end the livestream for everyone?",
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("End"),
              onPressed: () {
                Navigator.of(context).pop();
                // End the entire meeting/livestream
                widget.room.end();
                endLivestream(widget.roomId);
                // Or if you want to just leave: widget.room.leave();
              },
            ),
          ],
        );
      },
    );
  }

  // listening to room events for participants join, left and hls state changes
  void setlivestreamEventListener() {
    widget.room.on(Events.participantJoined, (Participant participant) {
      //Adding only Conference participant to show in grid
      if (participant.mode == Mode.SEND_AND_RECV) {
        setState(
          () => participants.putIfAbsent(participant.id, () => participant),
        );
      }
    });

    widget.room.on(Events.participantModeChanged, (data) {
      // Update host status when mode changes
      setState(() {
        isHost = _checkIfUserIsHost();
      });
    });

    widget.room.on(Events.participantLeft, (String participantId) {
      if (participants.containsKey(participantId)) {
        setState(() => participants.remove(participantId));
      }
    });
  }
}
