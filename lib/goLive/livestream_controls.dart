import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

class LivestreamControls extends StatefulWidget {
  final Mode mode;
  final bool micEnabled; // Add micEnabled parameter
  final void Function()? onToggleMicButtonPressed;
  final void Function()? onToggleCameraButtonPressed;
  final void Function()? onChangeModeButtonPressed;

  const LivestreamControls({
    super.key,
    required this.mode,
    required this.micEnabled, // Require micEnabled
    this.onToggleMicButtonPressed,
    this.onToggleCameraButtonPressed,
    this.onChangeModeButtonPressed,
  });

  @override
  State<LivestreamControls> createState() => _LivestreamControlsState();
}

class _LivestreamControlsState extends State<LivestreamControls> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.mode == Mode.SEND_AND_RECV) ...[
          InkWell(
            onTap: widget.onToggleMicButtonPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                widget.micEnabled ? Icons.mic : Icons.mic_off_rounded, // Conditional icon
                color: Colors.white,
              ),
            ),
          ),
          // Uncomment if you need these buttons
          // const SizedBox(width: 10),
          // ElevatedButton(
          //   onPressed: widget.onToggleCameraButtonPressed,
          //   child: const Text('Toggle Cam'),
          // ),
          // ElevatedButton(
          //   onPressed: widget.onChangeModeButtonPressed,
          //   child: const Text('Audience'),
          // ),
        ],
      ],
    );
  }
}