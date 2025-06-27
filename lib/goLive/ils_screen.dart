import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';
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

class _ILSScreenState extends State<ILSScreen> {
  late Room _room;
  bool isJoined = false;
  Mode? localParticipantMode;

  @override
  void initState() {
    super.initState();

    print(widget.liveStreamId);
    // Create room when widget loads
    _room = VideoSDK.createRoom(
      roomId: widget.liveStreamId,
      token: widget.token,
      displayName: "widget.name",
      micEnabled: true,
      camEnabled: true,
      defaultCameraIndex: 1,
      // Index of MediaDevices will be used to set default camera
      mode: widget.mode,
    );
    localParticipantMode = widget.mode;
    // Setting the event listener for join and leave events
    setLivestreamEventListener();

    // Joining room
    _room.join();
  }

  // Listening to room events
  void setLivestreamEventListener() {
    _room.on(Events.roomJoined, () {
      if (widget.mode == Mode.SEND_AND_RECV) {
        _room.localParticipant.pin();
      }
      // Increment joined users count in Firestore for local participant
      FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(widget.liveStreamId)
          .update({'joinedUsersCount': FieldValue.increment(1)})
          .catchError((e) {
            debugPrint('Error updating joinedUsersCount on join: $e');
          });
      setState(() {
        localParticipantMode = _room.localParticipant.mode;
        isJoined = true;
      });
    });

    _room.on(Events.participantJoined, (Participant participant) {
      // Increment joined users count in Firestore for remote participant
      FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(widget.liveStreamId)
          .update({'joinedUsersCount': FieldValue.increment(1)})
          .catchError((e) {
            debugPrint(
              'Error updating joinedUsersCount on participant join: $e',
            );
          });
    });

    _room.on(Events.participantLeft, (String participantId) {
      // Decrement joined users count in Firestore for remote participant
      FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(widget.liveStreamId)
          .update({'joinedUsersCount': FieldValue.increment(-1)})
          .catchError((e) {
            debugPrint(
              'Error updating joinedUsersCount on participant leave: $e',
            );
          });
    });

    // Handling navigation when livestream is left
    _room.on(Events.roomLeft, () {
      // Decrement joined users count in Firestore for local participant
      FirebaseFirestore.instance
          .collection('liveVideos')
          .doc(widget.liveStreamId)
          .update({'joinedUsersCount': FieldValue.increment(-1)})
          .catchError((e) {
            debugPrint('Error updating joinedUsersCount on room leave: $e');
          });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => JoinScreen()),
        (route) => false, // Removes all previous routes
      );
    });
  }

  // On back button pressed, leave the room
  Future<bool> _onWillPop() async {
    _room.leave();
    return true;
  }

  @override
  void dispose() {
    // Ensure room is left when widget is disposed
    _room.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        // Showing the Host or Audience View based on the mode
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

                    // Display joined users count in real-time
                  ],
                )
                : const Center(
                  child: PulseLogoLoader(logoPath: "assets/images/appLogo.png"),
                ),
      ),
    );
  }
}
