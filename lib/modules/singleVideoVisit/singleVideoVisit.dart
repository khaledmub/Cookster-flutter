import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cookster/modules/singleVideoVisit/singleVideoController/singleVisitVideoController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../appUtils/apiEndPoints.dart';
import '../../loaders/pulseLoader.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';

class SingleVisitVideo extends StatefulWidget {
  const SingleVisitVideo({super.key});

  @override
  State<SingleVisitVideo> createState() => _SingleVideoVisitState();
}

class _SingleVideoVisitState extends State<SingleVisitVideo> {
  final AppLinks _appLinks = AppLinks();
  String? _currentVideoId;
  String? _lastProcessedVideoId; // Track the last processed video ID
  String? _initializedVideoUrl; // Track which video URL is initialized
  final SingleVisitVideoController _singleVisitVideoController = Get.put(
    SingleVisitVideoController(),
  );
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showIcon = false; // To control visibility of play/pause icon
  bool _isBuffering = false; // To track buffering state

  final VideoCommentsController _videoCommentsController = Get.put(
    VideoCommentsController(),
  );

  String? _userId;
  String? _userImage;
  StreamSubscription<Uri>? _linkSubscription; // Store the stream subscription

  @override
  void initState() {
    super.initState();

    // Initialize empty video controller to avoid errors
    _videoController = VideoPlayerController.networkUrl(Uri.parse(''))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _isBuffering = _videoController.value.isBuffering;
          });
        }
      });

    // Reset state and fetch user ID
    _resetState();
    _fetchUserIdFromStorage();

    // Handle deep link initialization and fetch video
    _handleDeepLink();
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _currentVideoId = null;
        _initializedVideoUrl = null;
        _isVideoInitialized = false;
        _showIcon = false;
        _isBuffering = false;
      });
    }
    _singleVisitVideoController.resetVideoContent(); // Reset controller state
  }

  Future<void> _fetchUserIdFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storeUserId = prefs.getString('user_id');
    String? storeUserImage = prefs.getString('user_image');

    if (storeUserId != null && mounted) {
      setState(() {
        _userId = storeUserId;
        _userImage = storeUserImage;
      });
      print("Fetched user ID: $_userId");
    }
  }

  Future<void> _handleDeepLink() async {
    // Parse initial deep link
    await _parseInitialDeepLink();

    // Set up listener for future deep links
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Cancel the deep link stream subscription
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _parseInitialDeepLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print("Initial deep link found: $initialUri");
        _processDeepLink(initialUri);
      } else {
        print("No initial deep link found");
      }
    } catch (e) {
      print("Error parsing initial deep link: $e");
    }
  }

  void _listenForDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) {
          print("New deep link received: $uri");
          _processDeepLink(uri);
        }
      },
      onError: (error) {
        print("Deep link stream error: $error");
      },
    );
  }

  void _processDeepLink(Uri uri) {
    print("User entered screen with deep link Uri: $uri");
    print("URI Path: ${uri.path}");
    print("URI Query Parameters: ${uri.queryParameters}");

    if (uri.path == '/visitSingleVideo' ||
        uri.path.contains('visitSingleVideo')) {
      String? urlVideoId = uri.queryParameters['id'];
      print("Extracted video ID from Uri: $urlVideoId");

      if (urlVideoId != null && urlVideoId.isNotEmpty) {
        // Check if the video ID is different from the last processed one
        if (urlVideoId != _lastProcessedVideoId && mounted) {
          setState(() {
            _currentVideoId = urlVideoId;
            _lastProcessedVideoId = urlVideoId; // Update last processed ID
            _initializedVideoUrl = null; // Reset to force re-initialization
          });
          print("Updated Video ID from deep link: $_currentVideoId");
          _singleVisitVideoController.fetchSingleVideo(_currentVideoId!);
        } else {
          print("Ignoring duplicate deep link for video ID: $urlVideoId");
        }
      } else {
        print("No video ID found in deep link query parameters");
      }
    } else {
      print("Deep link path doesn't match visitSingleVideo: ${uri.path}");
    }
  }

  void _initializeVideoIfNeeded(String videoUrl) {
    if (_initializedVideoUrl == videoUrl && _isVideoInitialized) {
      return; // Video is already initialized with this URL
    }

    _initializeVideo(videoUrl);
  }

  void _initializeVideo(String videoUrl) {
    _videoController.dispose(); // Dispose previous controller
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(videoUrl))
          ..addListener(() {
            if (mounted) {
              setState(() {
                _isBuffering = _videoController.value.isBuffering;
              });
            }
          })
          ..initialize()
              .then((_) {
                if (mounted) {
                  setState(() {
                    _isVideoInitialized = true;
                    _initializedVideoUrl = videoUrl; // Track initialized URL
                  });
                  _videoController.setLooping(true);
                  _videoController.play();
                }
              })
              .catchError((error) {
                print("Error initializing video: $error");
                if (mounted) {
                  setState(() {
                    _isVideoInitialized = false;
                    _initializedVideoUrl = null;
                  });
                }
              });
  }

  void _togglePlayPause() {
    if (mounted) {
      setState(() {
        if (_videoController.value.isPlaying) {
          _videoController.pause();
        } else {
          _videoController.play();
        }
        _showIcon = true;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _showIcon = false;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final data = _singleVisitVideoController.singleVideoContent.value.video;

        if (_singleVisitVideoController.isLoading.value) {
          return Center(
            child: PulseLogoLoader(
              logoPath: "assets/images/appIcon.png",
              size: 80,
            ),
          );
        } else if (data == null ||
            data.video == null ||
            _currentVideoId == null) {
          return const Center(
            child: Text(
              "No video available",
              style: TextStyle(color: Colors.white),
            ),
          );
        } else {
          final videoUrl = "${Common.videoUrl}/${data.video!}";
          _initializeVideoIfNeeded(videoUrl);

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _isVideoInitialized
                          ? VideoPlayer(_videoController)
                          : Container(color: Colors.black),
                      if (!_isVideoInitialized || _isBuffering)
                        PulseLogoLoader(
                          logoPath: "assets/images/appIcon.png",
                          size: 80,
                        ),
                      if (_isVideoInitialized && _showIcon)
                        Icon(
                          _videoController.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 64.0,
                          color: Colors.white.withOpacity(0.7),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
