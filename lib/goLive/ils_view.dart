import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videosdk/videosdk.dart';
import '../appUtils/apiEndPoints.dart';
import 'api_call.dart';
import 'commentWIdget.dart';
import 'livestream_controls.dart';
import 'participant_grid.dart';

import 'dart:async';

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
  Timer? _timer;
  Duration _remainingTime = const Duration(minutes: 15);
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    localMode = widget.mode;

    // Check if current user is host
    isHost = _checkIfUserIsHost();

    // Start timer for host
    if (isHost) {
      _startTimer();
    }

    // Setting up the event listeners and initializing the participants and hls state
    setlivestreamEventListener();
    participants.putIfAbsent(
      widget.room.localParticipant.id,
      () => widget.room.localParticipant,
    );
    // Filtering the CONFERENCE participants to be shown in the grid
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

  void _startTimer() {
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _isTimerRunning = false;
        return;
      }
      setState(() {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                // Top section for End/Leave button, timer, and user count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
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
                          final int count = data?['likes'] ?? 0;
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

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
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
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.grey[700],
                                              image:
                                                  userImage.isNotEmpty
                                                      ? DecorationImage(
                                                        image: NetworkImage(
                                                          '${Common.profileImage}/${userImage}',
                                                        ),
                                                        fit: BoxFit.cover,
                                                        onError: (
                                                          exception,
                                                          stackTrace,
                                                        ) {
                                                          print(
                                                            'Image load error: $exception',
                                                          );
                                                        },
                                                      )
                                                      : null,
                                            ),
                                            child:
                                                ClipOval(
                                                      child: Image.network(
                                                        '${Common.profileImage}/${userImage}',
                                                        fit: BoxFit.cover,
                                                        width: 40,
                                                        height: 40,
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
                                                    '${"Likes".tr} $count',
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
                                    ),
                                    SizedBox(height: 8),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream:
                                          FirebaseFirestore.instance
                                              .collection('liveVideos')
                                              .doc(widget.roomId)
                                              .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData ||
                                            snapshot.data == null) {
                                          return const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text(
                                              'Loading count...',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        }
                                        int count =
                                            snapshot.data!['joinedUsersCount'] ??
                                            0;
                                        return Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(
                                                  18,
                                                ),
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
                                            ),

                                            SizedBox(width: 8,),

                                            _buildLivestreamControls()

                                          ],
                                        );
                                      },
                                    ),



                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const Spacer(),

                      // Timer display for host
                      if (isHost) const SizedBox(width: 8),
                      // Host gets "End" button, others get "Leave" button
                      Column(
                        children: [
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
                              isHost ? "end".tr : "leave".tr,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(height: 4),
                          if (isHost)
                            Container(
                              width: 60,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${_formatDuration(_remainingTime)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
          title: Text("end_livestream".tr),
          content: Text("are_you_sure_end_livestream".tr),
          actions: [
            TextButton(
              child: Text("cancel".tr),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("end".tr),
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



  Widget _buildLivestreamControls() {
    if (localMode == Mode.SEND_AND_RECV) {
      return LivestreamControls(
        mode: Mode.SEND_AND_RECV,
        micEnabled: micEnabled, // Pass micEnabled
        onToggleMicButtonPressed: () {
          micEnabled ? widget.room.muteMic() : widget.room.unmuteMic();
          setState(() {
            micEnabled = !micEnabled; // Update state to trigger rebuild
          });
        },
        onToggleCameraButtonPressed: () {
          camEnabled ? widget.room.disableCam() : widget.room.enableCam();
          setState(() {
            camEnabled = !camEnabled;
          });
        },
        onChangeModeButtonPressed: () {
          widget.room.changeMode(Mode.RECV_ONLY);
          setState(() {
            localMode = Mode.RECV_ONLY;
          });
        },
      );
    } else if (localMode == Mode.RECV_ONLY) {
      return Column(
        children: [
          LivestreamControls(
            mode: Mode.RECV_ONLY,
            micEnabled: micEnabled, // Pass micEnabled
            onToggleMicButtonPressed: () {
              micEnabled ? widget.room.muteMic() : widget.room.unmuteMic();
              setState(() {
                micEnabled = !micEnabled;
              });
            },
            onToggleCameraButtonPressed: () {
              camEnabled ? widget.room.disableCam() : widget.room.enableCam();
              setState(() {
                camEnabled = !camEnabled;
              });
            },
            onChangeModeButtonPressed: () {
              widget.room.changeMode(Mode.SEND_AND_RECV);
              setState(() {
                localMode = Mode.SEND_AND_RECV;
              });
            },
          ),
        ],
      );
    } else {
      return LivestreamControls(
        mode: Mode.RECV_ONLY,
        micEnabled: micEnabled, // Pass micEnabled
        onToggleMicButtonPressed: () {
          micEnabled ? widget.room.muteMic() : widget.room.unmuteMic();
          setState(() {
            micEnabled = !micEnabled;
          });
        },
        onToggleCameraButtonPressed: () {
          camEnabled ? widget.room.disableCam() : widget.room.enableCam();
          setState(() {
            camEnabled = !camEnabled;
          });
        },
        onChangeModeButtonPressed: () {
          widget.room.changeMode(Mode.RECV_ONLY);
        },
      );
    }
  }
}
