import 'dart:io';
import 'dart:math';
import 'package:cookster/basicVideoEditor/videoEditorControllers/audioSelectorController.dart';
import 'package:cookster/basicVideoEditor/videoEditorControllers/videoFilterController.dart';
import 'package:cookster/basicVideoEditor/videoFilterUi.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart' show FFmpegKit;
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../appUtils/colorUtils.dart';
import '../loaders/pulseLoader.dart';
import '../modules/landing/landingTabs/add/videoAddView/videoAddView.dart';
import 'audioSelector.dart';

enum EditingTool { text, font, color, sticker, crop, fontSize }

enum StickerType { text, image }

enum ResizeDirection {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class TextOverlay {
  String? text;
  String? imageUrl; // Optional GIF URL
  double x;
  double y;
  Color color;
  double fontSize;
  bool hasBorder;
  String fontFamily;
  StickerType type;
  File? localImageFile; // To store downloaded GIF
  double? width; // Added width for image/sticker overlays
  double? height; // Added height for image/sticker overlays

  TextOverlay({
    this.text, // Optional text
    this.imageUrl, // Optional image URL
    required this.x,
    required this.y,
    this.color = Colors.white,
    this.fontSize = 72,
    this.hasBorder = true,
    this.fontFamily = 'Arial',
    this.type = StickerType.text,
    this.localImageFile,
    this.width, // Optional width parameter
    this.height, // Optional height parameter
  }) {
    // Auto-set dimensions for image overlays if not provided
    if ((type == StickerType.image) && (width == null || height == null)) {
      width ??=
          100; // Default width (changed from 10 to 100 for better visibility)
      height ??=
          100; // Default height (changed from 10 to 100 for better visibility)
    }
  }

  String get colorHex {
    return color.value.toRadixString(16).padLeft(8, '0').substring(2);
  }

  // Added copyWith method
  TextOverlay copyWith({
    String? text,
    String? imageUrl,
    double? x,
    double? y,
    Color? color,
    double? fontSize,
    bool? hasBorder,
    String? fontFamily,
    StickerType? type,
    File? localImageFile,
    double? width,
    double? height,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      hasBorder: hasBorder ?? this.hasBorder,
      fontFamily: fontFamily ?? this.fontFamily,
      type: type ?? this.type,
      localImageFile: localImageFile ?? this.localImageFile,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class CropSettings {
  double x;
  double y;
  double width;
  double height;

  CropSettings({this.x = 0, this.y = 0, this.width = 1.0, this.height = 1.0});
}

class VideoTextEditor extends StatefulWidget {
  final File videoFile;

  const VideoTextEditor({Key? key, required this.videoFile}) : super(key: key);

  @override
  _VideoTextEditorState createState() => _VideoTextEditorState();
}

class _VideoTextEditorState extends State<VideoTextEditor> {
  File? _selectedVideo;
  File? _processedVideo;
  VideoPlayerController? _videoController;
  VideoPlayerController? _processedVideoController;
  TextEditingController _textController = TextEditingController();
  List<TextOverlay> _textOverlays = [];
  bool _isDragging = false;
  int _selectedOverlayIndex = -1;
  double _videoWidth = 0.0;
  double _videoHeight = 0.0;
  bool _isProcessing = false;
  double _processingProgress = 0;
  bool _isEditing = false;
  final AudioSelectorController controller = Get.put(AudioSelectorController());
  final VideoFilterController videoFilterController = Get.put(
    VideoFilterController(),
  );

  final GlobalKey _videoKey = GlobalKey();
  EditingTool _currentTool = EditingTool.text;

  // Crop settings
  CropSettings _cropSettings = CropSettings();
  bool _isCropping = false;

  // Available fonts
  final List<String> _fontOptions = [
    // 'Arial',
    // 'Courier',
    'Times New Roman',
    // 'Comic Sans MS',
    // 'Aref Ruqa',
    'Amiri',
    'Noto',
    'Cairo',
  ];

  bool _isTypingText = false;
  FocusNode _textFocusNode = FocusNode();

  // Sticker options
  final List<GiphyGif> _stickerOptions = [];

  void _fetchStickers() async {
    final gif = await GiphyGet.getGif(
      context: context,
      apiKey: 'XdA5gt5kKyXr35erM4UyICj8iYSlPQR0',
      lang: GiphyLanguage.english,
      showStickers: true,
    );

    if (gif != null) {
      _addStickerOverlay(gif);
      // setState(() {
      //   // Add to sticker options if not already present
      //   if (!_stickerOptions.any((element) => element.id == gif.id)) {
      //     _stickerOptions.add(gif);
      //     _addStickerOverlay(gif);
      //   }
      // });
    }
  }

  VideoPlayerController? _filteredVideoController;
  bool _showFilteredPreview = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _selectedVideo = widget.videoFile;
    _textOverlays = [];
    _processedVideo = null;
    _processingProgress = 0;
    _isEditing = true;
    _cropSettings = CropSettings();

    _videoController?.dispose();
    _processedVideoController?.dispose();

    _videoController = VideoPlayerController.file(_selectedVideo!)
      ..initialize()
          .then((_) {
            setState(() {
              _videoWidth = _videoController!.value.size.width;
              _videoHeight = _videoController!.value.size.height;

              double currentAspectRatio = _videoWidth / _videoHeight;
              const targetAspectRatio = 0.5623529411764706; // 9:16

              print('Original Aspect Ratio: $currentAspectRatio');
              print('Video Name: ${_selectedVideo!.path.split('/').last}');

              // Check if current aspect ratio is greater than target
              if (currentAspectRatio > targetAspectRatio) {
                // Calculate new dimensions to match target aspect ratio
                double newWidth = _videoHeight * targetAspectRatio;
                double newHeight =
                    _videoHeight; // Keep height same, adjust width

                // Update crop settings or video dimensions
                _cropSettings = CropSettings(
                  width: newWidth,
                  height: newHeight,
                  x: (_videoWidth - newWidth) / 2, // Center crop
                  y: 0,
                );

                print('Adjusted to Target Aspect Ratio: $targetAspectRatio');
                print('New Dimensions: ${newWidth}x$newHeight');
              }

              _videoController!.play();
              _videoController!.setLooping(true);
            });
          })
          .catchError((error) {
            print("Error initializing video controller: $error");
          });

    _textFocusNode.addListener(() {
      setState(() {
        _isTypingText = _textFocusNode.hasFocus;
      });
    });

    _initializeFilterController();
  }

  void _initializeFilterController() {
    // Listen to changes in filtered video file
    ever(videoFilterController.filteredVideoFile, (File? filteredFile) {
      if (filteredFile != null) {
        _filteredVideoController?.dispose();
        _filteredVideoController = VideoPlayerController.file(filteredFile)
          ..initialize()
              .then((_) {
                setState(() {
                  _showFilteredPreview = true;
                });
                _filteredVideoController!.play();
                _filteredVideoController!.setLooping(true);
              })
              .catchError((error) {
                print("Error initializing filtered video controller: $error");
              });
      } else {
        setState(() {
          _showFilteredPreview = false;
        });
        _filteredVideoController?.dispose();
        _filteredVideoController = null;
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [Permission.storage, Permission.mediaLibrary].request();
    }
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
        _textOverlays = [];
        _processedVideo = null;
        _processingProgress = 0;
        _isEditing = true;
        _cropSettings = CropSettings();

        // Dispose old controller if exists
        _videoController?.dispose();
        _processedVideoController?.dispose();

        // Initialize new controller
        _videoController = VideoPlayerController.file(_selectedVideo!)
          ..initialize().then((_) {
            setState(() {
              _videoWidth = _videoController!.value.size.width;
              _videoHeight = _videoController!.value.size.height;
            });
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      });
    }
  }

  void _addTextOverlay() {
    if (_textController.text.isEmpty || _selectedVideo == null) return;

    setState(() {
      _textOverlays.add(
        TextOverlay(
          text: _textController.text,
          x: 0.5,
          // Center of screen horizontally
          y: 0.5,
          // Center of screen vertically
          color: Colors.white,
          fontSize: 36,
          hasBorder: true,
          fontFamily: 'Amiri',
        ),
      );
      _textController.clear();
      _selectedOverlayIndex = _textOverlays.length - 1;
      _isTypingText = false;
      _textFocusNode.unfocus();
    });
  }

  // Download the GIF to a local file
  Future<File?> _downloadGif(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final gifName = 'gif_${DateTime.now().millisecondsSinceEpoch}.gif';
        final gifFile = File('${tempDir.path}/$gifName');
        await gifFile.writeAsBytes(response.bodyBytes);
        return gifFile;
      }
    } catch (e) {
      print("Error downloading GIF: $e");
    }
    return null;
  }

  Future<void> _addStickerOverlay(GiphyGif gif) async {
    if (_selectedVideo == null || gif.images?.original?.url == null) return;

    final gifUrl = gif.images!.original!.url;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Download the GIF to a local file first
      final localGifFile = await _downloadGif(gifUrl);

      if (localGifFile != null) {
        // Calculate standard sticker size
        double standardStickerSize =
            min(_videoWidth, _videoHeight) * 0.2; // 20% of smaller dimension

        setState(() {
          _textOverlays.add(
            TextOverlay(
              imageUrl: gifUrl,
              x: 0.5,
              // Center horizontally
              y: 0.5,
              // Center vertically
              type: StickerType.image,
              localImageFile: localGifFile,
              width: standardStickerSize,
              // Add width
              height: standardStickerSize, // Add height
            ),
          );
          _selectedOverlayIndex = _textOverlays.length - 1;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download sticker")),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error adding sticker: $e")));
    }
  }

  void _removeSelectedOverlay() {
    if (_selectedOverlayIndex >= 0) {
      setState(() {
        _textOverlays.removeAt(_selectedOverlayIndex);
        _selectedOverlayIndex = -1;
      });
    }
  }

  var activeFeature = ''.obs; // '' = none, 'filters', 'stickers', 'text'

  // Calculate the actual video dimensions within the display container
  Size _getActualVideoSize(BoxConstraints constraints) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }

    final aspectRatio = _videoController!.value.aspectRatio;
    double videoWidth, videoHeight;

    if (constraints.maxWidth / constraints.maxHeight > aspectRatio) {
      // Video is constrained by height
      videoHeight = constraints.maxHeight;
      videoWidth = videoHeight * aspectRatio;
    } else {
      // Video is constrained by width
      videoWidth = constraints.maxWidth;
      videoHeight = videoWidth / aspectRatio;
    }

    return Size(videoWidth, videoHeight);
  }

  // Update text overlay position during dragging
  // Add these variables to your class
  Offset? _initialTouchOffset;
  Offset? _initialTextPosition;

  // Updated dragging variables
  Offset? _dragStartPosition;
  int _draggingIndex = -1;

  // Updated drag start method
  void _startDrag(
    DragStartDetails details,
    int index,
    BoxConstraints constraints,
  ) {
    if (index < 0 || index >= _textOverlays.length) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      _draggingIndex = index;
      _selectedOverlayIndex = index;
      _dragStartPosition = localPosition;
    });
  }

  //
  // // Updated position update method
  //   void _updateTextOverlayPosition(
  //       DragUpdateDetails details, BoxConstraints constraints, int index)
  //   {
  //     if (_draggingIndex != index || _dragStartPosition == null) return;
  //
  //     final RenderBox box = context.findRenderObject() as RenderBox;
  //     final Offset localPosition = box.globalToLocal(details.globalPosition);
  //
  //     // Calculate the delta movement
  //     final deltaX = localPosition.dx - _dragStartPosition!.dx;
  //     final deltaY = localPosition.dy - _dragStartPosition!.dy;
  //
  //     // Get the actual video dimensions within the display container
  //     final videoSize = _getActualVideoSize(constraints);
  //     final videoWidth = videoSize.width;
  //     final videoHeight = videoSize.height;
  //
  //     // Calculate the video's position within the container
  //     final videoX = (constraints.maxWidth - videoWidth) / 2;
  //     final videoY = (constraints.maxHeight - videoHeight) / 2;
  //
  //     // Only update if the position is within the video bounds
  //     if (index >= 0 && index < _textOverlays.length) {
  //       // Convert from screen coordinates to video percentage
  //       final newX = _textOverlays[index].x + (deltaX / videoWidth);
  //       final newY = _textOverlays[index].y + (deltaY / videoHeight);
  //
  //       // Clamp values to ensure they stay within the video
  //       final clampedX = newX.clamp(0.0, 1.0);
  //       final clampedY = newY.clamp(0.0, 1.0);
  //
  //       setState(() {
  //         _textOverlays[index].x = clampedX;
  //         _textOverlays[index].y = clampedY;
  //         _dragStartPosition = localPosition;
  //       });
  //     }
  //   }

  // Updated end drag method
  void _endDrag() {
    setState(() {
      _draggingIndex = -1;
      _dragStartPosition = null;
    });
  }

  // Update crop area during dragging
  void _updateCropArea(DragUpdateDetails details, BoxConstraints constraints) {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);

    // Get the actual video dimensions within the display container
    final videoSize = _getActualVideoSize(constraints);
    final videoWidth = videoSize.width;
    final videoHeight = videoSize.height;

    // Calculate the video's position within the container
    final videoX = (constraints.maxWidth - videoWidth) / 2;
    final videoY = (constraints.maxHeight - videoHeight) / 2;

    // Calculate position as percentage of video dimensions
    final newX = (localPosition.dx - videoX) / videoWidth;
    final newY = (localPosition.dy - videoY) / videoHeight;

    // Clamp values to stay within video bounds
    final clampedX = newX.clamp(0.0, 1.0);
    final clampedY = newY.clamp(0.0, 1.0);

    setState(() {
      // Update crop settings based on drag direction
      _cropSettings.width = (clampedX - _cropSettings.x).clamp(
        0.1,
        1.0 - _cropSettings.x,
      );
      _cropSettings.height = (clampedY - _cropSettings.y).clamp(
        0.1,
        1.0 - _cropSettings.y,
      );
    });
  }

  void _startCropping() {
    setState(() {
      _isCropping = true;
      _cropSettings = CropSettings();
    });
  }

  // Add these new variables to your _VideoTextEditorState class
  VideoPlayerController? _croppedPreviewController;
  bool _showCroppedPreview = false;

  // Replace the _applyCrop method
  Future<void> _applyCrop() async {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final previewPath =
          "${tempDir.path}/cropped_preview_${DateTime.now().millisecondsSinceEpoch}.mp4";

      // Calculate crop parameters in pixels
      final cropX = (_cropSettings.x * _videoWidth).round();
      final cropY = (_cropSettings.y * _videoHeight).round();
      final cropW = (_cropSettings.width * _videoWidth).round();
      final cropH = (_cropSettings.height * _videoHeight).round();

      // Create a cropped preview using FFmpeg
      final String command =
          "-i ${_selectedVideo!.path} -vf \"crop=$cropW:$cropH:$cropX:$cropY\" -c:v libx264 -preset ultrafast -crf 23 -c:a copy $previewPath";

      print("Creating cropped preview with command: $command");

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Dispose old preview controller if it exists
        _croppedPreviewController?.dispose();

        // Initialize the preview controller
        _croppedPreviewController = VideoPlayerController.file(
            File(previewPath),
          )
          ..initialize().then((_) {
            setState(() {
              _showCroppedPreview = true;
              _isProcessing = false;
              _isCropping = false;
            });
            _croppedPreviewController!.play();
            _croppedPreviewController!.setLooping(true);
          });
      } else {
        print("Failed to create cropped preview");
        setState(() {
          _isProcessing = false;
          _isCropping = false;
        });
      }
    } catch (e) {
      print("Error creating cropped preview: $e");
      setState(() {
        _isProcessing = false;
        _isCropping = false;
      });
    }
  }

  // Replace the _getPositionInVideoCoordinates method with this improved version
  Offset _getPositionInVideoCoordinates(
    double normalizedX,
    double normalizedY,
  ) {
    // For FFmpeg processing, we need to convert from normalized coordinates (0-1)
    // to actual video pixel coordinates based on the original video dimensions
    return Offset(normalizedX * _videoWidth, normalizedY * _videoHeight);
  }

  // Replace the _processVideo method with this corrected version
  Future<void> _processVideo() async {
    if (_croppedPreviewController != null) {
      await _croppedPreviewController!.dispose();
      _croppedPreviewController = null;
      _showCroppedPreview = false;
    }

    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video first")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      File inputFile = _selectedVideo!;

      // Use filtered video if available
      if (videoFilterController.filteredVideoFile.value != null) {
        inputFile = videoFilterController.filteredVideoFile.value!;
      }

      // Check file size (in bytes)
      final fileSize = await inputFile.length();
      const maxSize = 72 * 1024 * 1024; // 72MB in bytes

      // Compress if file size exceeds 72MB
      if (fileSize > maxSize) {
        final compressedPath =
            "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4";
        String compressionCommand =
            "-i '${inputFile.path.replaceAll("'", "\\'")}' -c:v libx264 -b:v 8M -preset fast -c:a aac -b:a 128k '${compressedPath.replaceAll("'", "\\'")}'";
        final compressionSession = await FFmpegKit.executeAsync(
          compressionCommand,
          (session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              inputFile = File(compressedPath);
            } else {
              throw Exception("Compression failed");
            }
          },
          (log) => print("Compression Log: ${log.getMessage()}"),
          (statistics) {},
        );
        await compressionSession.getReturnCode();
        final compressedSize = await inputFile.length();
        print("Compressed size: ${compressedSize / (1024 * 1024)} MB");
      }

      final outputPath =
          "${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final duration = _videoController!.value.duration.inSeconds.toDouble();

      // Update video dimensions from controller
      _videoWidth = _videoController!.value.size.width;
      _videoHeight = _videoController!.value.size.height;

      // Define target aspect ratio (9:16)
      const targetAspectRatio = 9 / 16;
      final originalWidth = _videoWidth;
      final originalHeight = _videoHeight;
      final originalAspectRatio = originalWidth / originalHeight;

      // Calculate target dimensions for 9:16
      double targetWidth, targetHeight;
      if (originalAspectRatio > targetAspectRatio) {
        targetHeight = originalHeight;
        targetWidth = targetHeight * targetAspectRatio;
      } else {
        targetWidth = originalWidth;
        targetHeight = targetWidth / targetAspectRatio;
      }

      // Round to even integers for FFmpeg
      int finalWidth = targetWidth.round();
      int finalHeight = targetHeight.round();
      finalWidth = finalWidth % 2 == 0 ? finalWidth : finalWidth + 1;
      finalHeight = finalHeight % 2 == 0 ? finalHeight : finalHeight + 1;

      // Calculate scaling factor for font size adjustment
      double fontScalingFactor = finalHeight / _videoHeight;

      List<String> inputFiles = [inputFile.path];
      String filterComplex = "";
      String inputLabel = "[0:v]";
      String outputLabel = "[scaled]";

      // Scale video to fit 9:16 aspect ratio
      filterComplex +=
          "$inputLabel scale=$finalWidth:$finalHeight:force_original_aspect_ratio=decrease,pad=$finalWidth:$finalHeight:(ow-iw)/2:(oh-ih)/2:black";

      // Add selected filter if available
      if (videoFilterController.selectedFilter.value != null) {
        final selectedFilter = videoFilterController.selectedFilter.value!;
        final commandTemplate = selectedFilter['commandTemplate'] as String;

        if (commandTemplate.contains('{value}')) {
          String defaultValueFormatted =
              (selectedFilter['defaultValue'] as double).toStringAsFixed(2);
          String filterCommand = commandTemplate.replaceAll(
            '{value}',
            defaultValueFormatted,
          );
          filterComplex += (filterComplex.isEmpty ? '' : ',') + filterCommand;
        } else {
          filterComplex += (filterComplex.isEmpty ? '' : ',') + commandTemplate;
        }
      }

      filterComplex += " $outputLabel;";
      inputLabel = outputLabel;

      // Prepare font directory
      Directory appDocDir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${appDocDir.path}/fonts');
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }

      // Map of font names to their asset paths
      final fontAssetMap = {
        'Arial': 'assets/fonts/Arial.ttf',
        'Courier': 'assets/fonts/Courier.ttf',
        'Times New Roman': 'assets/fonts/TimesNewRoman.ttf',
        'Comic Sans MS': 'assets/fonts/ComicSansMS.ttf',
        'Aref Ruqa': 'assets/fonts/ArefRuqaa-Regular.ttf',
        'Amiri': 'assets/fonts/Amiri-Regular.ttf',
        'Arabic 2': 'assets/fonts/ScheherazadeNew-Regular.ttf',
        'Noto': 'assets/fonts/noto.ttf',
        'Cairo': 'assets/fonts/cairo.ttf',
      };

      // Load all required fonts
      Map<String, File> fontFiles = {};
      for (var fontName in _fontOptions) {
        final fontAsset = fontAssetMap[fontName];
        if (fontAsset != null) {
          final fontFile = File('${fontDir.path}/$fontName.ttf');
          if (!await fontFile.exists()) {
            try {
              ByteData data = await rootBundle.load(fontAsset);
              List<int> bytes = data.buffer.asUint8List();
              await fontFile.writeAsBytes(bytes);
            } catch (e) {
              print("Error loading font $fontName: $e");
            }
          }
          fontFiles[fontName] = fontFile;
        }
      }

      int overlayCount = 0;

      for (int i = 0; i < _textOverlays.length; i++) {
        final overlay = _textOverlays[i];

        // Convert overlay positions to the target 9:16 coordinate system
        double xPos = overlay.x * finalWidth;
        double yPos = overlay.y * finalHeight;

        // Adjust font size based on scaling factor
        double adjustedFontSize = overlay.fontSize * fontScalingFactor;

        if (overlay.type == StickerType.text && overlay.text != null) {
          String textFilter = "$inputLabel drawtext=";
          final fontFile = fontFiles[overlay.fontFamily];
          if (fontFile != null && await fontFile.exists()) {
            // Properly escape font file path
            textFilter += "fontfile='${fontFile.path.replaceAll("'", "\\'")}'";
          } else {
            textFilter += "font='${overlay.fontFamily}'";
          }
          // Escape Arabic text and ensure UTF-8 encoding
          String escapedText = overlay.text!
              .replaceAll("'", "\\'")
              .replaceAll(':', '\\:');
          textFilter += ":text='$escapedText'";
          // Adjust x position for RTL text: align to the right side
          textFilter += ":x=$xPos-(text_w/2):y=$yPos-(text_h/2)";
          textFilter += ":fontsize=${adjustedFontSize.round()}";
          textFilter += ":fontcolor=#${overlay.colorHex}";
          // Enable RTL and complex text rendering (requires libass)
          textFilter += ":enable='if(gt(t,0),1,0)'";
          outputLabel = "[text$i]";
          textFilter += " $outputLabel";

          filterComplex += textFilter + ";";
          inputLabel = outputLabel;
          overlayCount++;
        } else if (overlay.type == StickerType.image &&
            overlay.localImageFile != null) {
          inputFiles.add(overlay.localImageFile!.path);
          int inputIndex = inputFiles.length - 1;

          String scaleFilter =
              "[$inputIndex:v]scale=150:150:force_original_aspect_ratio=decrease,pad=150:150:(ow-iw)/2:(oh-ih)/2[scaled$overlayCount];";

          double overlayX = xPos - 75;
          double overlayY = yPos - 75;
          overlayX = overlayX.clamp(0.0, finalWidth - 150);
          overlayY = overlayY.clamp(0.0, finalHeight - 150);

          String overlayFilter =
              "$inputLabel[scaled$overlayCount]overlay=$overlayX:$overlayY[overlay$overlayCount]";

          filterComplex += scaleFilter + overlayFilter + ";";
          inputLabel = "[overlay$overlayCount]";
          overlayCount++;
        }
      }

      // Get the audio file from AudioSelectorController
      final audioController = Get.find<AudioSelectorController>();
      String? audioPath;
      if (audioController.selectedFileName.isNotEmpty) {
        audioPath = audioController.selectedFilePath;
      }

      String command = "";
      int audioInputIndex = -1;

      // Add input files
      for (String file in inputFiles) {
        command += "-i '${file.replaceAll("'", "\\'")}' ";
      }

      // Add audio input if selected
      if (audioPath != null) {
        command += "-i '${audioPath.replaceAll("'", "\\'")}' ";
        audioInputIndex = inputFiles.length;
      }

      // Set video duration
      command += "-t $duration ";

      // Build filter complex
      if (filterComplex.isNotEmpty) {
        if (filterComplex.endsWith(";")) {
          filterComplex = filterComplex.substring(0, filterComplex.length - 1);
        }
        command += "-filter_complex \"$filterComplex\" ";
        command += "-map \"$inputLabel\" ";
      } else {
        command += "-map 0:v ";
      }

      // Audio mapping
      if (audioPath != null && audioInputIndex != -1) {
        command += "-map $audioInputIndex:a ";
        command += "-c:a aac -b:a 128k ";
      } else {
        command += "-map 0:a? ";
        command += "-c:a copy ";
      }

      // Video encoding settings
      command += "-c:v libx264 -preset medium -crf 23 ";
      command += "'${outputPath.replaceAll("'", "\\'")}'";

      print("Executing FFmpeg command: $command");

      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            setState(() {
              _processedVideo = File(outputPath);
              _isEditing = false;
              _processedVideoController?.dispose();
              _processedVideoController = VideoPlayerController.file(
                  _processedVideo!,
                )
                ..initialize().then((_) {
                  setState(() {
                    _isProcessing = false;
                  });
                  _processedVideoController!.play();
                  _processedVideoController!.setLooping(true);
                });
            });
          } else {
            session.getLogs().then((logs) {
              String logString = logs.map((log) => log.getMessage()).join("\n");
              print("FFmpeg Error: $logString");
            });
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error Processing Video"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (log) {
          print("FFmpeg Log: ${log.getMessage()}");
          String message = log.getMessage();
          if (message.contains("time=")) {
            try {
              final timeStr = message.split("time=")[1].split(" ")[0].trim();
              final List<String> timeParts = timeStr.split(':');
              final double hours = double.parse(timeParts[0]);
              final double minutes = double.parse(timeParts[1]);
              final double seconds = double.parse(timeParts[2]);
              final double currentTime = hours * 3600 + minutes * 60 + seconds;
              setState(() {
                _processingProgress = (currentTime / duration).clamp(0.0, 1.0);
              });
            } catch (e) {
              print("Error parsing progress: $e");
            }
          }
        },
        (statistics) {},
      );
    } catch (e) {
      print(videoFilterController.selectedFilter.value);
      print("Error: $e");
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Replace the _updateTextOverlayPosition method with this improved version
  void _updateTextOverlayPosition(
    DragUpdateDetails details,
    double videoWidth,
    double videoHeight,
    int index,
  ) {
    if (index < 0 || index >= _textOverlays.length) return;

    setState(() {
      final overlay = _textOverlays[index];

      // Get overlay dimensions
      final overlayWidth =
          overlay.type == StickerType.text
              ? overlay.fontSize *
                  overlay.text!.length *
                  0.6 // Approximate text width
              : (overlay.width ?? 100.0);
      final overlayHeight =
          overlay.type == StickerType.text
              ? overlay.fontSize *
                  1.2 // Approximate text height
              : (overlay.height ?? 100.0);

      // Calculate current position in pixel coordinates
      double currentPixelX = videoWidth * overlay.x;
      double currentPixelY = videoHeight * overlay.y;

      // Apply the drag delta
      double newPixelX = currentPixelX + details.delta.dx;
      double newPixelY = currentPixelY + details.delta.dy;

      // Calculate boundaries considering overlay size
      final minX = 0.0; // Left edge
      final maxX = 1.0; // Right edge
      final minY = 0.0; // Top edge
      final maxY = 1.0; // Bottom edge

      // Convert to normalized coordinates (0.0 to 1.0)
      double newX = newPixelX / videoWidth;
      double newY = newPixelY / videoHeight;

      // Clamp the position to keep overlay within video bounds
      newX = newX.clamp(minX, maxX);
      newY = newY.clamp(minY, maxY);

      // Ensure overlay stays fully visible
      if (newPixelX + overlayWidth / 2 > videoWidth) {
        newX = (videoWidth - overlayWidth / 2) / videoWidth;
      }
      if (newPixelX - overlayWidth / 2 < 0) {
        newX = (overlayWidth / 2) / videoWidth;
      }
      if (newPixelY + overlayHeight / 2 > videoHeight) {
        newY = (videoHeight - overlayHeight / 2) / videoHeight;
      }
      if (newPixelY - overlayHeight / 2 < 0) {
        newY = (overlayHeight / 2) / videoHeight;
      }

      // Update the overlay position
      _textOverlays[index] = overlay.copyWith(x: newX, y: newY);
    });
  }

  // Update the dispose method to include the preview controller
  @override
  void dispose() {
    _videoController?.dispose();
    _processedVideoController?.dispose();
    _croppedPreviewController?.dispose();
    _textController.dispose();
    _textFocusNode.dispose(); // Don't forget to dispose the focus node
    super.dispose();
  }

  void _startAddingText() {
    setState(() {
      _textController.clear();
      _isTypingText = true;
      _selectedOverlayIndex = -1;
    });

    // Request focus to show keyboard
    Future.delayed(Duration(milliseconds: 100), () {
      _textFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Your existing WillPopScope logic remains unchanged
        if (_isEditing) {
          bool shouldPop =
              await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: Text(
                        "discard_changes".tr,
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        "go_back_warning".tr,
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          child: Text("cancel".tr),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: Text("Discard".tr),
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _selectedVideo = null;
                              _videoController?.dispose();
                              _videoController = null;
                            });
                            Navigator.pop(context, true);
                          },
                        ),
                      ],
                    ),
              ) ??
              false;
          return shouldPop;
        }
        return true;
      },
      child: SafeArea(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          // Prevent resizing when keyboard opens
          backgroundColor: Colors.black,
          appBar:
              _isEditing
                  ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                backgroundColor: Colors.grey[900],
                                title: const Text(
                                  "Discard changes?",
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  "If you go back now, you'll lose your edits.",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  TextButton(
                                    child: const Text("Discard"),
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = false;
                                        _selectedVideo = null;
                                        _videoController?.dispose();
                                        _videoController = null;
                                      });
                                      Get.back();
                                      Get.back();
                                    },
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                    title: Text(
                      "Edit Video".tr,
                      style: TextStyle(color: Colors.white),
                    ),
                    actions: [
                      if (_selectedOverlayIndex >= 0 && !_isCropping)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _removeSelectedOverlay,
                          tooltip: "Delete Selected Item",
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton(
                          onPressed: _processVideo,
                          child: Row(
                            children: [
                              Icon(Icons.check),
                              SizedBox(width: 4),
                              Text("Save".tr),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                  : AppBar(
                    iconTheme: IconThemeData(color: Colors.white),
                    backgroundColor: Colors.black,
                    elevation: 0,
                    title: Text(
                      "video_editor".tr,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          body: Stack(
            children: [
              _processedVideo != null && !_isEditing
                  ? _buildProcessedVideoScreen()
                  : _buildVideoEditorScreen(),
              if (_isTypingText && _isEditing && !_isCropping)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      MediaQuery.of(
                        context,
                      ).viewInsets.bottom, // Adjust for keyboard
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _textFocusNode,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            decoration: InputDecoration(
                              hintText: "type_text".tr,
                              hintStyle: TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.black45,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _addTextOverlay();
                              } else {
                                setState(() {
                                  _isTypingText = false;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.white),
                          onPressed: _addTextOverlay,
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _textController.clear();
                              _isTypingText = false;
                              _textFocusNode.unfocus();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              // Other Positioned widgets (like font size slider) remain unchanged
              if (_isEditing)
                if (_selectedOverlayIndex >= 0 &&
                    _textOverlays[_selectedOverlayIndex].type ==
                        StickerType.text &&
                    _textOverlays[_selectedOverlayIndex].text !=
                        GiphyType.stickers)
                  Positioned(
                    left: 10,
                    top: 150,
                    bottom: 300,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        color: ColorUtils.darkBrown.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        // Force LTR direction for the slider
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value:
                                _textOverlays[_selectedOverlayIndex].fontSize,
                            min: 10,
                            max: 100,
                            divisions: 90,
                            label:
                                _textOverlays[_selectedOverlayIndex].fontSize
                                    .round()
                                    .toString(),
                            activeColor: ColorUtils.primaryColor,
                            inactiveColor: Colors.grey,
                            onChanged: (value) {
                              setState(() {
                                _textOverlays[_selectedOverlayIndex].fontSize =
                                    value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              if (_isEditing)
                if (_selectedOverlayIndex >= 0 &&
                    _textOverlays[_selectedOverlayIndex].type ==
                        StickerType.text &&
                    _textOverlays[_selectedOverlayIndex].text !=
                        GiphyType.stickers)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        MediaQuery.of(
                          context,
                        ).viewInsets.bottom, // Adjust for keyboard
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 60,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _colorOption(Colors.white),
                                _colorOption(Colors.yellow),
                                _colorOption(Colors.orange),
                                _colorOption(Colors.red),
                                _colorOption(Colors.pink),
                                _colorOption(Colors.purple),
                                _colorOption(Colors.blue),
                                _colorOption(Colors.cyan),
                                _colorOption(Colors.teal),
                                _colorOption(Colors.green),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              // scrollDirection: ScrollDirection.forward,
                              itemCount: _fontOptions.length,
                              itemBuilder: (context, index) {
                                final font = _fontOptions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_selectedOverlayIndex >= 0) {
                                          _textOverlays[_selectedOverlayIndex]
                                              .fontFamily = font;
                                        } else if (_textOverlays.isNotEmpty) {
                                          _textOverlays.last.fontFamily = font;
                                        }
                                      });
                                    },
                                    child: Chip(
                                      backgroundColor:
                                          _selectedOverlayIndex >= 0 &&
                                                  _textOverlays[_selectedOverlayIndex]
                                                          .fontFamily ==
                                                      font
                                              ? ColorUtils.primaryColor
                                              : Colors.grey[800],
                                      label: Text(
                                        font,
                                        style: TextStyle(
                                          fontFamily: font,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
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
      ),
    );
  }

  Widget _buildVideoEditorScreen() {
    // Ensure video loops
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.setLooping(true);
    }

    return _selectedVideo != null &&
            _videoController != null &&
            _videoController!.value.isInitialized
        ? Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isCropping) {
                    setState(() {
                      _selectedOverlayIndex = -1;
                    });
                  }
                },
                child: Stack(
                  children: [
                    // Video player with 9:16 aspect ratio
                    Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Obx(() {
                            // Get filter configuration
                            final filterConfig = videoFilterController
                                .getFilterConfig(
                                  filter:
                                      videoFilterController
                                          .selectedFilter
                                          .value,
                                  value:
                                      videoFilterController.sliderValue.value,
                                );

                            // Base video widget
                            Widget videoWidget = FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width:
                                    _showFilteredPreview &&
                                            _filteredVideoController != null &&
                                            _filteredVideoController!
                                                .value
                                                .isInitialized
                                        ? _filteredVideoController!
                                            .value
                                            .size
                                            .width
                                        : _videoController!.value.size.width,
                                height:
                                    _showFilteredPreview &&
                                            _filteredVideoController != null &&
                                            _filteredVideoController!
                                                .value
                                                .isInitialized
                                        ? _filteredVideoController!
                                            .value
                                            .size
                                            .height
                                        : _videoController!.value.size.height,
                                child:
                                    _showFilteredPreview &&
                                            _filteredVideoController != null &&
                                            _filteredVideoController!
                                                .value
                                                .isInitialized
                                        ? VideoPlayer(_filteredVideoController!)
                                        : VideoPlayer(_videoController!),
                              ),
                            );

                            // Apply filter based on type
                            Widget filteredWidget;
                            if (filterConfig['type'] == 'color' &&
                                filterConfig['colorFilter'] != null) {
                              filteredWidget = ColorFiltered(
                                colorFilter: filterConfig['colorFilter'],
                                child: videoWidget,
                              );
                            } else if (filterConfig['type'] == 'image' &&
                                filterConfig['imageFilter'] != null) {
                              filteredWidget = ClipRect(
                                child: BackdropFilter(
                                  filter: filterConfig['imageFilter'],
                                  child: videoWidget,
                                ),
                              );
                            } else {
                              filteredWidget = videoWidget; // No filter applied
                            }

                            // Wrap with GestureDetector for play/pause
                            return GestureDetector(
                              onTap: () async {
                                // Determine which controller to use
                                final activeController =
                                    _showFilteredPreview &&
                                            _filteredVideoController != null &&
                                            _filteredVideoController!
                                                .value
                                                .isInitialized
                                        ? _filteredVideoController
                                        : _videoController;

                                // Toggle play/pause
                                if (activeController != null) {
                                  if (activeController.value.isPlaying) {
                                    await controller.pauseAudio();

                                    print("AUDIO IS PAUSED");

                                    await activeController.pause();
                                    print("Video  IS PAUSED");
                                  } else {
                                    if (controller
                                        .selectedFilePathRx
                                        .value
                                        .isNotEmpty) {
                                      await activeController.setVolume(0);
                                      print("VOLUME IS SET TO 0");

                                      await activeController.play();
                                      print("VIDEO IS PLAYING");
                                    } else {
                                      await activeController.play();

                                      print("AUDIO IS PLAYING");
                                    }
                                  }
                                }
                              },
                              child: filteredWidget,
                            );
                          }),
                        ),
                      ),
                    ),
                    // Overlay rendering
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double videoWidth = constraints.maxWidth;
                        double videoHeight = constraints.maxHeight;

                        return Stack(
                          children: [
                            // Render all overlays (text and stickers)
                            ..._textOverlays.asMap().entries.map((entry) {
                              final index = entry.key;
                              final overlay = entry.value;
                              final bool isSelected =
                                  index == _selectedOverlayIndex;

                              double overlayWidth =
                                  overlay.type == StickerType.text
                                      ? 200
                                      : (overlay.width ?? 100);
                              double overlayHeight =
                                  overlay.type == StickerType.text
                                      ? 40
                                      : (overlay.height ?? 100);
                              double overlayX = videoWidth * overlay.x;
                              double overlayY = videoHeight * overlay.y;

                              return Positioned(
                                left: overlayX - (overlayWidth / 2),
                                top: overlayY - (overlayHeight / 2),
                                child: GestureDetector(
                                  onPanStart: (_) {
                                    setState(() {
                                      _selectedOverlayIndex = index;
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    _updateTextOverlayPosition(
                                      details,
                                      videoWidth,
                                      videoHeight,
                                      index,
                                    );
                                  },
                                  onTap: () {
                                    setState(() {
                                      _selectedOverlayIndex = index;
                                    });
                                  },
                                  onPanEnd: (_) {
                                    setState(() {
                                      _selectedOverlayIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration:
                                        isSelected
                                            ? BoxDecoration(
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            )
                                            : null,
                                    child:
                                        overlay.type == StickerType.text
                                            ? Center(
                                              child: Text(
                                                overlay.text!,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: overlay.fontSize,
                                                  color: overlay.color,
                                                  fontFamily:
                                                      overlay.fontFamily,
                                                  shadows:
                                                      overlay.hasBorder
                                                          ? [
                                                            const Shadow(
                                                              blurRadius: 3,
                                                              color:
                                                                  Colors.black,
                                                              offset: Offset(
                                                                1,
                                                                1,
                                                              ),
                                                            ),
                                                          ]
                                                          : null,
                                                ),
                                              ),
                                            )
                                            : overlay.localImageFile != null
                                            ? SizedBox(
                                              width: overlayWidth,
                                              height: overlayHeight,
                                              child: Image.file(
                                                overlay.localImageFile!,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                            : const SizedBox(),
                                  ),
                                ),
                              );
                            }).toList(),
                            // Show "Add Text" prompt only if no overlays exist
                            // if (!_isCropping && _textOverlays.isEmpty)
                            //   GestureDetector(
                            //     onTap: _startAddingText,
                            //     child: Container(
                            //       width: constraints.maxWidth,
                            //       height: constraints.maxHeight,
                            //       color: Colors.transparent,
                            //       child: Center(
                            //         child: Container(
                            //           padding: EdgeInsets.symmetric(
                            //             vertical: 12,
                            //             horizontal: 24,
                            //           ),
                            //           decoration: BoxDecoration(
                            //             color: Colors.black.withOpacity(0.5),
                            //             borderRadius: BorderRadius.circular(10),
                            //           ),
                            //           child: Text(
                            //             "Add Text",
                            //             style: TextStyle(
                            //               color: Colors.white,
                            //               fontSize: 24,
                            //               fontWeight: FontWeight.bold,
                            //             ),
                            //           ),
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                          ],
                        );
                      },
                    ),
                    // Sticker button (always visible unless cropping)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 30,
                          ),
                          height: 150,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Sticker button (hidden when cropping)
                                  if (!_isCropping)
                                    InkWell(
                                      onTap: _fetchStickers,
                                      child: SvgPicture.asset(
                                        height: 30,
                                        "assets/icons/sticker.svg",
                                        color: Colors.white,
                                      ),
                                    ),
                                  SizedBox(height: 20),

                                  // Text button (hidden when cropping)
                                  if (!_isCropping)
                                    InkWell(
                                      onTap: _startAddingText,
                                      child: SvgPicture.asset(
                                        height: 30,
                                        "assets/icons/text.svg",
                                        color: Colors.white,
                                      ),
                                    ),
                                  SizedBox(height: 20),

                                  // Filter button
                                  InkWell(
                                    onTap: () {
                                      videoFilterController.toggleFilterList();
                                    },
                                    child: SvgPicture.asset(
                                      height: 30,
                                      "assets/icons/filter.svg",
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Filter list and slider
                    VideoFilterUI(),

                    AudioSelector(),
                  ],
                ),
              ),
              // Processing overlay
              Obx(() {
                return (_isProcessing ||
                        videoFilterController.isProcessing.value)
                    ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PulseLogoLoader(
                              logoPath: "assets/images/appIconC.png",
                            ),
                            const SizedBox(height: 16),
                            Text(
                              videoFilterController.isProcessing.value
                                  ? ""
                                  : "${"processing_video".tr}.... ${(_processingProgress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    )
                    : SizedBox.shrink();
              }),
            ],
          ),
        )
        : const Center(
          child: PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
        );
  }

  ResizeDirection? _activeHandle;

  // Helper method to build resize handles
  Widget _buildResizeHandle(
    BoxConstraints constraints,
    double x,
    double y,
    ResizeDirection direction,
  ) {
    final bool isActive = _activeHandle == direction;

    return Positioned(
      left: constraints.maxWidth * x - 15,
      top: constraints.maxHeight * y - 15,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _activeHandle = direction;
          });
        },
        onPanUpdate:
            (details) => _resizeCropArea(details, constraints, direction),
        onPanEnd: (_) {
          setState(() {
            _activeHandle = null;
          });
        },
        child: Container(
          width: isActive ? 36 : 30, // Slightly larger when active
          height: isActive ? 36 : 30,
          decoration: BoxDecoration(
            color: isActive ? Colors.yellow : Colors.white,
            // Highlight when active
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to move the entire crop area
  void _moveCropArea(DragUpdateDetails details, BoxConstraints constraints) {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);

    // Get the actual video dimensions within the display container
    final videoSize = _getActualVideoSize(constraints);
    final videoWidth = videoSize.width;
    final videoHeight = videoSize.height;

    // Calculate the video's position within the container
    final videoX = (constraints.maxWidth - videoWidth) / 2;
    final videoY = (constraints.maxHeight - videoHeight) / 2;

    // Calculate position change as percentage of video dimensions
    final deltaX = details.delta.dx / videoWidth;
    final deltaY = details.delta.dy / videoHeight;

    setState(() {
      // Update position, ensuring crop area stays within video bounds
      _cropSettings.x = (_cropSettings.x + deltaX).clamp(
        0.0,
        1.0 - _cropSettings.width,
      );
      _cropSettings.y = (_cropSettings.y + deltaY).clamp(
        0.0,
        1.0 - _cropSettings.height,
      );
    });
  }

  // Method to resize the crop area from different corners/edges
  void _resizeCropArea(
    DragUpdateDetails details,
    BoxConstraints constraints,
    ResizeDirection direction,
  ) {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);

    // Get the actual video dimensions within the display container
    final videoSize = _getActualVideoSize(constraints);
    final videoWidth = videoSize.width;
    final videoHeight = videoSize.height;

    // Calculate the video's position within the container
    final videoX = (constraints.maxWidth - videoWidth) / 2;
    final videoY = (constraints.maxHeight - videoHeight) / 2;

    // Calculate position as percentage of video dimensions
    final newX = (localPosition.dx - videoX) / videoWidth;
    final newY = (localPosition.dy - videoY) / videoHeight;

    // Clamp values to stay within video bounds
    final clampedX = newX.clamp(0.0, 1.0);
    final clampedY = newY.clamp(0.0, 1.0);

    // Minimum size for the crop area (10% of each dimension)
    final minWidth = 0.1;
    final minHeight = 0.1;

    setState(() {
      switch (direction) {
        case ResizeDirection.topLeft:
          final newWidth = _cropSettings.width + (_cropSettings.x - clampedX);
          final newHeight = _cropSettings.height + (_cropSettings.y - clampedY);

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
            _cropSettings.x = clampedX;
          }

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
            _cropSettings.y = clampedY;
          }
          break;

        case ResizeDirection.top:
          final newHeight = _cropSettings.height + (_cropSettings.y - clampedY);

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
            _cropSettings.y = clampedY;
          }
          break;

        case ResizeDirection.topRight:
          final newWidth = clampedX - _cropSettings.x;
          final newHeight = _cropSettings.height + (_cropSettings.y - clampedY);

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
          }

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
            _cropSettings.y = clampedY;
          }
          break;

        case ResizeDirection.right:
          final newWidth = clampedX - _cropSettings.x;

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
          }
          break;

        case ResizeDirection.bottomRight:
          final newWidth = clampedX - _cropSettings.x;
          final newHeight = clampedY - _cropSettings.y;

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
          }

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
          }
          break;

        case ResizeDirection.bottom:
          final newHeight = clampedY - _cropSettings.y;

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
          }
          break;

        case ResizeDirection.bottomLeft:
          final newWidth = _cropSettings.width + (_cropSettings.x - clampedX);
          final newHeight = clampedY - _cropSettings.y;

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
            _cropSettings.x = clampedX;
          }

          if (newHeight >= minHeight) {
            _cropSettings.height = newHeight;
          }
          break;

        case ResizeDirection.left:
          final newWidth = _cropSettings.width + (_cropSettings.x - clampedX);

          if (newWidth >= minWidth) {
            _cropSettings.width = newWidth;
            _cropSettings.x = clampedX;
          }
          break;
      }
    });
  }

  Widget _buildProcessedVideoScreen() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child:
                _processedVideoController != null &&
                        _processedVideoController!.value.isInitialized
                    ? GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_processedVideoController!.value.isPlaying) {
                            _processedVideoController!.pause();
                          } else {
                            _processedVideoController!.play();
                          }
                        });
                      },
                      child: AspectRatio(
                        aspectRatio:
                            _processedVideoController!.value.aspectRatio,
                        child: VideoPlayer(_processedVideoController!),
                      ),
                    )
                    : const CircularProgressIndicator(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: Text("edit_again".tr),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _processedVideo = null;
                    _processedVideoController?.dispose();
                    _processedVideoController = null;
                  });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.next_plan_outlined),
                label: Text("Next".tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                ),
                onPressed: () {
                  _videoController?.pause();
                  _processedVideoController?.pause();
                  Get.to(VideoPreviewScreen(videoFile: _processedVideo!));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolButton(
    IconData icon,
    String label,
    bool isSelected,
    Function()? onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? ColorUtils.primaryColor : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? ColorUtils.primaryColor : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorOption(Color color) {
    final bool isSelected =
        _selectedOverlayIndex >= 0 &&
        _textOverlays[_selectedOverlayIndex].color.value == color.value;

    return GestureDetector(
      onTap: () {
        if (_selectedOverlayIndex >= 0) {
          setState(() {
            _textOverlays[_selectedOverlayIndex].color = color;
          });
        }
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
