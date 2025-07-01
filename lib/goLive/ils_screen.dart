import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:videosdk/videosdk.dart';
import 'api_call.dart';
import 'ils_view.dart';
import 'join_screen.dart';

class ILSScreen extends StatefulWidget {
  final String liveStreamId;
  final String token;
  final Mode mode;

  const ILSScreen({
    super.key,
    required this.liveStreamId,
    required this.token,
    required this.mode,
  });

  @override
  State<ILSScreen> createState() => _ILSScreenState();
}

class _ILSScreenState extends State<ILSScreen> with WidgetsBindingObserver {
  late Room _room;
  bool isJoined = false;
  bool hasIncrementedCount = false; // Track if we've incremented count
  Mode? localParticipantMode;
  bool isHost = false;
  bool isDisposed = false;

  bool _checkIfUserIsHost() {
    return widget.mode == Mode.SEND_AND_RECV;
  }

  @override
  void initState() {
    super.initState();

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    print(widget.liveStreamId);
    // Create room when widget loads
    _room = VideoSDK.createRoom(
      roomId: widget.liveStreamId,
      token: widget.token,
      displayName: "widget.name",
      micEnabled: true,
      camEnabled: true,
      defaultCameraIndex: 1,
      mode: widget.mode,
    );
    localParticipantMode = widget.mode;
    // Setting the event listener for join and leave events
    setLivestreamEventListener();

    // Joining room
    _room.join();
    isHost = _checkIfUserIsHost();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app being terminated or going to background
    if (state == AppLifecycleState.detached) {
      _handleAppTermination();
    }
  }

  void _handleAppTermination() {
    if (!isDisposed && isJoined) {
      try {
        if (isHost) {
          _room.end();
          endLivestream(widget.liveStreamId);
        } else {
          _room.leave();
        }

        // Manually decrement count if we had incremented it
        if (hasIncrementedCount) {
          _decrementUserCount();
        }
      } catch (e) {
        debugPrint('Error during app termination cleanup: $e');
      }
    }
  }

  void _decrementUserCount() {
    FirebaseFirestore.instance
        .collection('liveVideos')
        .doc(widget.liveStreamId)
        .update({'joinedUsersCount': FieldValue.increment(-1)})
        .catchError((e) {
          debugPrint('Error decrementing count: $e');
        });
  }

  // Listening to room events
  void setLivestreamEventListener() {
    _room.on(Events.roomJoined, () {
      if (widget.mode == Mode.SEND_AND_RECV) {
        _room.localParticipant.pin();
      }

      // Increment count only once for local participant
      if (!hasIncrementedCount) {
        FirebaseFirestore.instance
            .collection('liveVideos')
            .doc(widget.liveStreamId)
            .update({'joinedUsersCount': FieldValue.increment(1)})
            .then((_) {
              hasIncrementedCount = true;
            })
            .catchError((e) {
              debugPrint('Error updating joinedUsersCount on local join: $e');
            });
      }

      setState(() {
        localParticipantMode = _room.localParticipant.mode;
        isJoined = true;
      });
    });

    _room.on(Events.participantJoined, (Participant participant) {
      // Only count remote participants (not local)
      if (participant.id != _room.localParticipant.id) {
        FirebaseFirestore.instance
            .collection('liveVideos')
            .doc(widget.liveStreamId)
            .update({'joinedUsersCount': FieldValue.increment(1)})
            .catchError((e) {
              debugPrint(
                'Error updating joinedUsersCount on participant join: $e',
              );
            });
      }
    });

    _room.on(Events.participantLeft, (String participantId) {
      // Only decrement for remote participants
      if (participantId != _room.localParticipant.id) {
        FirebaseFirestore.instance
            .collection('liveVideos')
            .doc(widget.liveStreamId)
            .update({'joinedUsersCount': FieldValue.increment(-1)})
            .catchError((e) {
              debugPrint(
                'Error updating joinedUsersCount on participant leave: $e',
              );
            });
      }
    });

    _room.on(Events.roomLeft, () {
      // Decrement count for local participant when leaving
      if (hasIncrementedCount) {
        _decrementUserCount();
        hasIncrementedCount = false;
      }

      if (!isDisposed) {
        Get.back();
      }
    });

    // Handle room errors
    _room.on(Events.error, (error) {
      debugPrint('Room error: $error');
      _handleRoomError(error);
    });
  }

  void _handleRoomError(dynamic error) {
    // Handle various room errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection error: ${error.toString()}'),
        backgroundColor: Colors.red,
      ),
    );

    // Optionally leave room on error
    _leaveRoom();
  }

  // Handle back navigation with PopScope
  void _onPopInvoked(bool didPop) {
    if (!didPop) {
      _showExitConfirmation();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isHost ? 'End Live Stream?' : 'Leave Live Stream?'),
          content: Text(
            isHost
                ? 'Are you sure you want to end this live stream? All participants will be disconnected.'
                : 'Are you sure you want to leave this live stream?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _leaveRoom();
              },
              child: Text(isHost ? 'End Stream' : 'Leave'),
            ),
          ],
        );
      },
    );
  }

  void _leaveRoom() {
    try {
      if (isHost) {
        _room.end();
        endLivestream(widget.liveStreamId);
      } else {
        _room.leave();
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
      // Force navigation even if leave fails
      if (!isDisposed) {
        Get.back();
      }
    }
  }

  @override
  void dispose() {
    isDisposed = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    try {
      // Ensure room is left when widget is disposed
      if (isJoined) {
        if (isHost) {
          _room.end();
          endLivestream(widget.liveStreamId);
        } else {
          _room.leave();
        }

        // Manually decrement if needed
        if (hasIncrementedCount) {
          _decrementUserCount();
        }
      }
    } catch (e) {
      debugPrint('Error in dispose: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: _onPopInvoked,
      child: Scaffold(
        backgroundColor: Colors.black,
        body:
            isJoined
                ? Column(
                  children: [
                    Expanded(
                      child: ILSView(
                        room: _room,
                        liveStreamId: widget.liveStreamId,
                        bar: false,
                        mode: widget.mode,
                        roomId: widget.liveStreamId,
                      ),
                    ),
                    // You can add a real-time user count widget here if needed
                  ],
                )
                : const Center(
                  child: PulseLogoLoader(logoPath: "assets/images/appLogo.png"),
                ),
      ),
    );
  }
}
