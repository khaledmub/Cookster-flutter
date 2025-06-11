import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:path_provider/path_provider.dart';
import '../../landing/landingTabs/add/videoAddView/videoAddView.dart';
import '../latestEditorView/videoRecorder.dart';
import 'package:giphy_get/giphy_get.dart';

class VideoTrimScreen extends StatefulWidget {
  final File videoFile;

  const VideoTrimScreen({Key? key, required this.videoFile}) : super(key: key);

  @override
  _VideoTrimScreenState createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  late VideoPlayerController _videoController;
  double _startValue = 0.0;
  double _endValue = 30.0;
  bool _isPlaying = false;
  double _rotationAngle = 0.0;
  String _aspectRatio = 'original';
  double _speed = 1.0;
  double _actualAspectRatio = 0.0;
  double _videoDuration = 0.0;

  String _overlayText = '';
  Offset _textPosition = Offset(50, 50);
  Color _textColor = Colors.white;
  String? _stickerUrl;
  Offset _stickerPosition = Offset(150, 150);

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            final size = _videoController.value.size;
            _actualAspectRatio = size.width / size.height;
            print('Input video dimensions: ${size.width}x${size.height}');
            print('Input video aspect ratio: $_actualAspectRatio');

            _videoDuration =
                _videoController.value.duration.inSeconds.toDouble();
            _endValue = _videoDuration > 30 ? 30 : _videoDuration;
          });
        }
      });
  }

  Future<void> _cropAndRotate() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final editor = VideoEditorBuilder(videoPath: widget.videoFile.path)
          .trim(
            startTimeMs: (_startValue * 1000).toInt(),
            endTimeMs: (_endValue * 1000).toInt(),
          )
          .speed(speed: _speed != 1.0 ? _speed : 1.0);

      if (_aspectRatio != 'original') {
        editor.crop(
          aspectRatio:
              _aspectRatio == '16:9'
                  ? VideoAspectRatio.ratio16x9
                  : _aspectRatio == '4:3'
                  ? VideoAspectRatio.ratio4x3
                  : VideoAspectRatio.ratio1x1,
        );
      }

      if (_rotationAngle != 0) {
        double normalizedAngle = _rotationAngle % 360;
        if (normalizedAngle < 0) normalizedAngle += 360;
        editor.rotate(
          degree:
              normalizedAngle == 90
                  ? RotationDegree.degree90
                  : normalizedAngle == 180
                  ? RotationDegree.degree180
                  : normalizedAngle == 270
                  ? RotationDegree.degree270
                  : RotationDegree.values[0],
        );
      }

      final result = await editor.export(outputPath: outputPath);
      Get.back();
      Get.to(() => VideoPreviewScreen(videoFile: File(result!)));
    } catch (e) {
      Get.back();
      print('Error processing video: $e');
    }
  }

  Rect _getCropRect() {
    final size = MediaQuery.of(context).size;
    double width = size.width;
    double height = width / _actualAspectRatio; // Respect native aspect ratio

    if (_rotationAngle == 90 || _rotationAngle == 270) {
      final temp = width;
      width = height;
      height = temp;
    }

    if (_aspectRatio == 'original') {
      return Rect.fromLTWH(0, 0, width, height);
    }

    double cropWidth = width;
    double cropHeight = height;

    if (_aspectRatio == '16:9') {
      cropHeight = width * 9 / 16;
    } else if (_aspectRatio == '4:3') {
      cropHeight = width * 3 / 4;
    } else if (_aspectRatio == '1:1') {
      cropHeight = width;
    }

    return Rect.fromLTWH(
      (width - cropWidth) / 2,
      (height - cropHeight) / 2,
      cropWidth,
      cropHeight,
    );
  }

  void _showTextInputDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Add Text',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter text',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              onSubmitted: (value) {
                if (mounted) {
                  setState(() {
                    _overlayText = value;
                    _textPosition = Offset(50, 50);
                  });
                }
                Navigator.pop(context);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showStickerPicker() async {
    final gif = await GiphyGet.getGif(
      context: context,
      apiKey: 'XdA5gt5kKyXr35erM4UyICj8iYSlPQR0',
      lang: GiphyLanguage.english,
      showStickers: true,
    );
    if (gif != null && gif.images?.original?.url != null) {
      if (mounted) {
        setState(() {
          _stickerUrl = gif.images!.original!.url;
          _stickerPosition = Offset(150, 150);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("PRINTING THE ACTUAL RATIO ${_actualAspectRatio}");
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: const Text('Edit Video', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _startValue < _endValue ? _cropAndRotate : null,
          ),
        ],
      ),
      body:
          _videoController.value.isInitialized
              ? Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video Player with native aspect ratio
                        Center(
                          child: Transform.rotate(
                            angle: -(_rotationAngle * 3.14159 / 180),
                            child: ClipRect(
                              clipper: _CropClipper(_getCropRect()),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width,
                                  maxHeight:
                                      MediaQuery.of(context).size.height *
                                      0.6, // Limit height to avoid overflow
                                ),
                                child: AspectRatio(
                                  aspectRatio: _actualAspectRatio,
                                  // Use native aspect ratio
                                  child: VideoPlayer(_videoController),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_overlayText.isNotEmpty)
                          Positioned(
                            left: _textPosition.dx,
                            top: _textPosition.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  double newX =
                                      _textPosition.dx + details.delta.dx;
                                  double newY =
                                      _textPosition.dy + details.delta.dy;
                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  final screenHeight =
                                      MediaQuery.of(context).size.height;
                                  const textWidth = 100.0;
                                  const textHeight = 40.0;
                                  newX = newX.clamp(
                                    0.0,
                                    screenWidth - textWidth,
                                  );
                                  newY = newY.clamp(
                                    0.0,
                                    screenHeight - textHeight,
                                  );
                                  _textPosition = Offset(newX, newY);
                                });
                              },
                              child: Text(
                                _overlayText,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 10.0,
                                      color: Colors.black,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_stickerUrl != null)
                          Positioned(
                            left: _stickerPosition.dx,
                            top: _stickerPosition.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  double newX =
                                      _stickerPosition.dx + details.delta.dx;
                                  double newY =
                                      _stickerPosition.dy + details.delta.dy;
                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  final screenHeight =
                                      MediaQuery.of(context).size.height;
                                  const stickerWidth = 100.0;
                                  const stickerHeight = 100.0;
                                  newX = newX.clamp(
                                    0.0,
                                    screenWidth - stickerWidth,
                                  );
                                  newY = newY.clamp(
                                    0.0,
                                    screenHeight - stickerHeight,
                                  );
                                  _stickerPosition = Offset(newX, newY);
                                });
                              },
                              child: Image.network(
                                _stickerUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white.withOpacity(0.7),
                            size: 50,
                          ),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _isPlaying = !_isPlaying;
                                if (_isPlaying) {
                                  _videoController.seekTo(
                                    Duration(seconds: _startValue.toInt()),
                                  );
                                  _videoController.play();
                                } else {
                                  _videoController.pause();
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RangeSlider(
                                values: RangeValues(_startValue, _endValue),
                                min: 0,
                                max: _videoDuration,
                                divisions: _videoDuration.toInt(),
                                activeColor: Colors.redAccent,
                                inactiveColor: Colors.grey,
                                labels: RangeLabels(
                                  '${_startValue.round()}s',
                                  '${_endValue.round()}s',
                                ),
                                onChanged: (RangeValues values) {
                                  if (mounted) {
                                    setState(() {
                                      double newStart = values.start;
                                      double newEnd = values.end;
                                      if (newEnd - newStart > 30) {
                                        if (newStart == _startValue) {
                                          newEnd = newStart + 30;
                                        } else {
                                          newEnd = newStart + 30;
                                        }
                                      }
                                      if (newEnd > _videoDuration) {
                                        newEnd = _videoDuration;
                                        newStart = newEnd - 30;
                                        if (newStart < 0) newStart = 0;
                                      }
                                      _startValue = newStart;
                                      _endValue = newEnd;
                                      _videoController.seekTo(
                                        Duration(seconds: _startValue.toInt()),
                                      );
                                      if (_isPlaying) {
                                        _videoController.pause();
                                        _isPlaying = false;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Max duration: 30s',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 100,
                    color: Colors.black87,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      children: [
                        _buildEditOption(
                          icon: Icons.rotate_left,
                          label: 'Rotate Left',
                          onTap: () => setState(() => _rotationAngle -= 90),
                        ),
                        const SizedBox(width: 16),
                        _buildEditOption(
                          icon: Icons.rotate_right,
                          label: 'Rotate Right',
                          onTap: () => setState(() => _rotationAngle += 90),
                        ),
                        const SizedBox(width: 16),
                        _buildEditOption(
                          icon: Icons.crop,
                          label: 'Crop',
                          onTap: () => _showCropDialog(context),
                        ),
                        const SizedBox(width: 16),
                        _buildEditOption(
                          icon: Icons.text_fields_rounded,
                          label: 'Add Text',
                          onTap: _showTextInputDialog,
                        ),
                        const SizedBox(width: 16),
                        _buildEditOption(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Add Sticker',
                          onTap: _showStickerPicker,
                        ),
                        const SizedBox(width: 16),
                        _buildEditOption(
                          icon: Icons.speed,
                          label: 'Speed',
                          onTap: () => _showSpeedDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEditOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.3),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showCropDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.black87,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -(_rotationAngle * 3.14159 / 180),
                      child: ClipRect(
                        clipper: _CropClipper(_getCropRect()),
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width,
                            maxHeight: MediaQuery.of(context).size.height * 0.6,
                          ),
                          child: AspectRatio(
                            aspectRatio: _actualAspectRatio,
                            child: VideoPlayer(_videoController),
                          ),
                        ),
                      ),
                    ),
                    GridPaper(
                      color: Colors.white.withOpacity(0.3),
                      divisions: 4,
                      subdivisions: 1,
                      interval: 100,
                      child: Container(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                        ['Original', '16:9', '4:3', '1:1']
                            .map(
                              (ratio) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _aspectRatio == ratio.toLowerCase()
                                            ? Colors.redAccent
                                            : Colors.grey,
                                  ),
                                  onPressed: () {
                                    if (mounted)
                                      setState(
                                        () =>
                                            _aspectRatio = ratio.toLowerCase(),
                                      );
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    ratio,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Select Speed',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [0.5, 1.0, 1.5, 2.0]
                      .map(
                        (speed) => ListTile(
                          title: Text(
                            '${speed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _speed = speed;
                                _videoController.setPlaybackSpeed(speed);
                              });
                            }
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _videoController.pause();
    _videoController.dispose();
    super.dispose();
  }
}

class _CropClipper extends CustomClipper<Rect> {
  final Rect rect;

  _CropClipper(this.rect);

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => true;
}
