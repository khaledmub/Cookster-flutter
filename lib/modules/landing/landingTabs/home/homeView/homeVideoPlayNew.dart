import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPlaceholder extends StatefulWidget {
  final String videoUrl;
  final dynamic isImage;

  const VideoPlayerPlaceholder({super.key, required this.videoUrl, required this.isImage});

  @override
  VideoPlayerPlaceholderState createState() => VideoPlayerPlaceholderState();
}

class VideoPlayerPlaceholderState extends State<VideoPlayerPlaceholder> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          _duration = _controller!.value.duration;
        });
        _controller!.setLooping(true);
        _controller!.play();
      }).catchError((error) {
        print('Error initializing video: $error');
      });

    // _controller?.addListener(() {
    //   setState(() {
    //     _position = _controller!.value.position;
    //   });
    // });
  }

  // @override
  // void dispose() {
  //   _controller?.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Stack(
      children: [
        Center(
          child: VideoPlayer(_controller!),
        ),
        if (widget.isImage == 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const ZeroSizeSliderThumbShape(), // Removes the thumb
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0.0), // Removes overlay
                trackHeight: 4.0, // Thin seek bar
                activeTrackColor: ColorUtils.primaryColor.withOpacity(0.8),
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _controller!.seekTo(Duration(seconds: value.toInt()));
                  });
                },
              ),
            ),
          ),
      ],
    )
        : Container();
  }
}

// Custom SliderThumbShape to remove the thumb completely
class ZeroSizeSliderThumbShape extends SliderComponentShape {
  const ZeroSizeSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.zero;
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    // No painting needed since we want no thumb
  }
}