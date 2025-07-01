import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:videosdk/videosdk.dart';
import 'api_call.dart';
import 'ils_view.dart';
import 'join_screen.dart';
import 'dart:async';

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
  bool hasIncrementedCount = false;
  Mode? localParticipantMode;
  bool isHost = false;
  bool isDisposed = false;
  bool isCleaningUp = false; // Prevent multiple cleanup calls
  Timer? _streamTimer; // Timer for 15-minute limit

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

    // Start 15-minute timer for host
    if (isHost) {
      _startStreamTimer();
    }
  }

  void _startStreamTimer() {
    const streamDuration = Duration(minutes: 15);
    _streamTimer = Timer(streamDuration, () {
      if (!isDisposed && !isCleaningUp && isHost) {
        _endStreamDueToTimeout();
      }
    });
  }

  void _endStreamDueToTimeout() {
    if (isCleaningUp || isDisposed) return;

    isCleaningUp = true;

    try {
      if (isHost) {
        _room.end();
        endLivestream(widget.liveStreamId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('live_stream_end_message'.tr),
            backgroundColor: Colors.blue,
          ),
        );
      }
      if (!isDisposed) {
        Get.back();
      }
    } catch (e) {
      debugPrint('Error ending stream due to timeout: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle different app lifecycle states
    switch (state) {
      case AppLifecycleState.detached:
        // App is being terminated
        _handleAppTermination();
        break;
      case AppLifecycleState.paused:
        // App is in background - you might want to pause video/audio here
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App is back in foreground
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is inactive (like when receiving a call)
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  void _handleAppPaused() {
    if (isCleaningUp || isDisposed) return;

    isCleaningUp = true;

    if (isJoined) {
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
    // Cancel timer when app is paused
    _streamTimer?.cancel();
  }

  void _handleAppResumed() {
    // Optional: Resume video/audio when app comes back to foreground
    if (isJoined && !isDisposed) {
      try {
        // Uncomment if you disabled cam/mic in _handleAppPaused
        // _room.localParticipant.enableCam();
        // _room.localParticipant.unmuteMic();
      } catch (e) {
        debugPrint('Error handling app resume: $e');
      }
    }
  }

  void _handleAppTermination() {
    if (isCleaningUp || isDisposed) return;

    isCleaningUp = true;

    if (isJoined) {
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
    // Cancel timer when app is terminated
    _streamTimer?.cancel();
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
      if (hasIncrementedCount && !isCleaningUp) {
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

    // Handle HLS state changes
    _room.on(Events.hlsStateChanged, (data) {
      debugPrint('HLS state changed: $data');
    });
  }

  void _handleRoomError(dynamic error) {
    // Handle various room errors
    if (!isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

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
    if (isDisposed) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isHost ? 'end_live_stream_title'.tr : 'leave_live_stream_title'.tr,
          ),
          content: Text(
            isHost
                ? 'end_live_stream_message'.tr
                : 'leave_live_stream_message'.tr,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancel_button'.tr),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _leaveRoom();
              },
              child: Text(isHost ? 'end_stream_button'.tr : 'leave_button'.tr),
            ),
          ],
        );
      },
    );
  }

  void _leaveRoom() {
    if (isCleaningUp || isDisposed) return;

    isCleaningUp = true;

    try {
      if (isHost) {
        _room.end();
        endLivestream(widget.liveStreamId);
      } else {
        _room.leave();
      }
      // Cancel timer when leaving room
      _streamTimer?.cancel();
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
    if (isDisposed) return;

    isDisposed = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel timer
    _streamTimer?.cancel();

    // Cleanup if not already done
    if (!isCleaningUp) {
      isCleaningUp = true;

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
