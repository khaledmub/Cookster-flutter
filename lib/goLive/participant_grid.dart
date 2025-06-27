import 'package:cookster/goLive/participant_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

class ParticipantGrid extends StatefulWidget {
  final Room room;

  const ParticipantGrid({Key? key, required this.room}) : super(key: key);

  @override
  State<ParticipantGrid> createState() => _ParticipantGridState();
}

class _ParticipantGridState extends State<ParticipantGrid> {
  late Participant localParticipant;

  // Removed numberOfColumns and numberOfMaxOnScreenParticipants since we don't need grid

  Map<String, Participant> participants = {};
  Map<String, Participant> onScreenParticipants = {};

  @override
  void initState() {
    localParticipant = widget.room.localParticipant;
    participants.putIfAbsent(localParticipant.id, () => localParticipant);
    participants.addAll(widget.room.participants);
    updateOnScreenParticipants();

    // Setting livestream event listeners
    setLivestreamEventListener(widget.room);

    // Disable mirroring for local participant's front camera
    _configureCameraMirror();

    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  // Configure camera to disable mirroring
  void _configureCameraMirror() {
    localParticipant.streams.forEach((streamId, stream) {
      if (stream.kind == 'video') {
        // Handle mirroring configuration here
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Since we're only showing one participant, no need for GridView
    if (onScreenParticipants.isEmpty) {
      return const Center(child: Text('No active participants'));
    }

    final participant = onScreenParticipants.values.first;
    return ParticipantTile(
      key: Key(participant.id),
      participant: participant,
      isLocalParticipant: participant.id == localParticipant.id,
    );
  }

  void setLivestreamEventListener(Room livestream) {
    // Called when participant joined livestream
    livestream.on(Events.participantJoined, (Participant participant) {
      final newParticipants = participants;
      newParticipants[participant.id] = participant;
      setState(() {
        participants = newParticipants;
        updateOnScreenParticipants();
      });
    });

    // Called when participant left livestream
    livestream.on(Events.participantLeft, (participantId) {
      final newParticipants = participants;
      newParticipants.remove(participantId);
      setState(() {
        participants = newParticipants;
        updateOnScreenParticipants();
      });
    });

    livestream.on(Events.participantModeChanged, (data) {
      Map<String, Participant> _participants = {};
      Participant _localParticipant = widget.room.localParticipant;
      _participants.putIfAbsent(_localParticipant.id, () => _localParticipant);
      _participants.addAll(livestream.participants);

      setState(() {
        localParticipant = _localParticipant;
        participants = _participants;
        updateOnScreenParticipants();
      });
    });

    // Screen sharing events removed since we only want host view
  }

  void updateOnScreenParticipants() {
    Map<String, Participant> newScreenParticipants = <String, Participant>{};

    // Find the host participant (usually the one with presenter mode or first active participant)
    List<Participant> activeParticipants =
        participants.values
            .where((element) => element.mode == Mode.SEND_AND_RECV)
            .toList();

    // Show only the first active participant (assumed to be host)
    // You can modify this logic based on how you identify the host in your app
    if (activeParticipants.isNotEmpty) {
      Participant hostParticipant = activeParticipants.first;
      newScreenParticipants.putIfAbsent(
        hostParticipant.id,
        () => hostParticipant,
      );
    }

    if (!listEquals(
      newScreenParticipants.keys.toList(),
      onScreenParticipants.keys.toList(),
    )) {
      setState(() {
        onScreenParticipants = newScreenParticipants;
      });
    }

    // Always keep single column since we're only showing host
    // setState(() {
    //   numberOfColumns = 1;
    // });
  }
}
