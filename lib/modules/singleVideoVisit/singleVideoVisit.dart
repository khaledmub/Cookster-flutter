import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/modules/singleVideoVisit/singleVideoController/singleVisitVideoController.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../appUtils/apiEndPoints.dart';
import '../../appUtils/colorUtils.dart';
import '../../loaders/pulseLoader.dart';
import '../landing/landingTabs/home/homeController/addCommentControllr.dart';
import '../landing/landingTabs/home/homeView/commentScreen.dart';
import '../landing/landingTabs/reportContent/reportContentView/reportContentView.dart';
import '../search/searchView/searchView.dart';
import '../visitProfile/visitProfileView/visitProfileView.dart';

class SingleVisitVideo extends StatefulWidget {
  const SingleVisitVideo({super.key});

  @override
  State<SingleVisitVideo> createState() => _SingleVideoVisitState();
}

class _SingleVideoVisitState extends State<SingleVisitVideo> {
  final AppLinks _appLinks = AppLinks();
  String? _currentVideoId;
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

  @override
  void initState() {
    super.initState();

    // Reset videoId and controller state
    _resetState();

    // Initialize empty video controller to avoid errors
    _videoController = VideoPlayerController.networkUrl(Uri.parse(''))
      ..addListener(() {
        setState(() {
          _isBuffering = _videoController.value.isBuffering;
        });
      });

    _fetchUserIdFromStorage();

    // Handle deep link initialization
    _handleDeepLinkInitialization();
  }

  void _resetState() {
    setState(() {
      _currentVideoId = null;
      _initializedVideoUrl = null;
      _isVideoInitialized = false;
      _showIcon = false;
      _isBuffering = false;
    });
    _singleVisitVideoController.resetVideoContent(); // Reset controller state
  }

  Future<void> _handleDeepLinkInitialization() async {
    // Parse initial deep link
    await _parseInitialDeepLink();

    // Set up listener for future deep links
    _listenForDeepLinks();

    // If videoId is set from initial deep link, fetch the video
    if (_currentVideoId != null) {
      _singleVisitVideoController.fetchSingleVideo(_currentVideoId!);
    }
  }

  Future<void> _fetchUserIdFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storeUserId = prefs.getString('user_id');
    String? storeUserImage = prefs.getString('user_image');

    if (storeUserId != null) {
      setState(() {
        _userId = storeUserId;
        _userImage = storeUserImage;
      });
      print("Fetched User ID from SharedPreferences: $_userId");
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _parseInitialDeepLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print("Initial deep link found: $initialUri");
        // Schedule deep link processing after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processDeepLink(initialUri);
        });
      } else {
        print("No initial deep link found");
      }
    } catch (e) {
      print("Error parsing initial deep link: $e");
    }
  }

  void _listenForDeepLinks() {
    _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) {
          print("New deep link received: $uri");
          // Schedule deep link processing after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resetState(); // Reset state before processing new deep link
            _processDeepLink(uri);
          });
        }
      },
      onError: (error) {
        print("Deep link stream error: $error");
      },
    );
  }

  void _processDeepLink(Uri uri) {
    print("Processing Deep Link: $uri");
    print("URI Path: ${uri.path}");
    print("URI Query Parameters: ${uri.queryParameters}");

    // Check if this is the correct path for single video
    if (uri.path == '/visitSingleVideo' ||
        uri.path.contains('visitSingleVideo')) {
      String? urlVideoId = uri.queryParameters['id'];
      print("Extracted video ID from URL: $urlVideoId");

      if (urlVideoId != null && urlVideoId.isNotEmpty) {
        if (urlVideoId != _currentVideoId) {
          setState(() {
            _currentVideoId = urlVideoId;
            _initializedVideoUrl = null; // Reset to force re-initialization
          });
          print("Updated Video ID from deep link: $_currentVideoId");
          _singleVisitVideoController.fetchSingleVideo(_currentVideoId!);
        } else {
          print("Video ID is same as current, no need to reload");
        }
      } else {
        print("No video ID found in deep link query parameters");
      }
    } else {
      print("Deep link path doesn't match visitSingleVideo: ${uri.path}");
    }
  }

  void _initializeVideoIfNeeded(String videoUrl) {
    // Only initialize if the video URL has changed
    if (_initializedVideoUrl == videoUrl) {
      return; // Video is already initialized with this URL
    }

    // Schedule the initialization after the current build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo(videoUrl);
    });
  }

  void _initializeVideo(String videoUrl) {
    if (_videoController.value.isInitialized &&
        _videoController.dataSource == videoUrl) {
      return; // Avoid reinitializing if URL doesn't change
    }

    _videoController.dispose();
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
                  _videoController.setLooping(true); // Set video to loop
                  _videoController.play(); // Auto-play the video
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
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
      _showIcon = true; // Show icon on tap
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showIcon = false; // Hide icon after 1 second
          });
        }
      });
    });
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
          // Schedule video initialization instead of calling it directly
          final videoUrl = "${Common.videoUrl}/${data.video!}";
          _initializeVideoIfNeeded(videoUrl);

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause, // Toggle play/pause on tap
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
                        ), // Show buffering indicator
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
