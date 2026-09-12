import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:camera/camera.dart';
import 'package:cookster/modules/landing/landingTabs/notification/notificationView/notificationView.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/changePlan/changePlanView/changePlanView.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileView/profileView.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cookster/appBindings/app_bindings.dart';
import '../../../appRoutes/appRoutes.dart';
import '../../../appUtils/colorUtils.dart';
import '../../../basicVideoEditor/basicVideoEditor.dart';
import '../../../cameraScreen.dart';
import '../../../captuteImage.dart';
import '../../../core/navigation/upload_form_route.dart';
import '../../../services/imageEditScreen.dart';
import '../landingTabs/add/videoAddController/videoAddController.dart';
import '../landingTabs/add/videoAddView/videoAddView.dart';
import '../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../search/searchController/searchController.dart';
import '../../singleVideoVisit/singleVideoVisit.dart';
import '../landingController/landingController.dart';
import '../../../core/video/media_kit_player_pool.dart';
import '../../../core/video/video_player_pool.dart';
import '../landingTabs/home/homeController/homeController.dart';
import '../landingTabs/home/homeController/saveController.dart';
import '../landingTabs/home/homeView/reelsVideoScreen.dart';
import '../landingTabs/nearBusiness/nearBusinessController/nearBusinessController.dart';
import '../landingTabs/nearBusiness/newBusinessView/nearBusinessView.dart';
import '../landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../landingTabs/professionalProfile/profileView/professionalProfileView.dart';
import '../../../loaders/pulseLoader.dart';

class Landing extends StatefulWidget {
  final int initialIndex;

  Landing({super.key, this.initialIndex = 0});

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  NavBarController get navBarController => Get.find<NavBarController>();
  final Widget _homeScreen = VideoReelScreen();
  Future<List<Widget>>? _screensFuture;
  StreamSubscription<Uri>? _deepLinkSubscription;
  Worker? _subscriptionExpiryWorker;
  bool _deepLinksInitialized = false;
  final RxBool _isSubscriptionExpired = false.obs;
  SaveController get saveController => ensureSaveController();
  PromoteVideoController get promoteVideoController =>
      Get.find<PromoteVideoController>();
  HomeController get controller => Get.find<HomeController>();
  VideoAddController get videoAddController => Get.find<VideoAddController>();

  final AppLinks appLinks = AppLinks();

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  Future<void> fetchUserDetails() async {
    bool isAuthenticated = await _isUserAuthenticated();
    if (isAuthenticated) {
      int entity = await getEntity();

      subscribeUserToTopics(entity.toString());

      if (entity == 2) {
        await professionalProfileController.getUserDetails();
      } else {
        await profileController.getUserDetails();
      }
    }
  }

  Future<void> subscribeUserToTopics(String entity) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      // Fixed topic
      await messaging.subscribeToTopic("cookster");
      print("✅ Subscribed to cookster");

      // Dynamic topic based on entity
      String topicName = "type_$entity";
      await messaging.subscribeToTopic(topicName);
      print("✅ Subscribed to $topicName");
    } catch (e) {
      print("❌ Error subscribing to topics: $e");
    }
  }

  Future<void> _handleAuthRequiredAction(Future<void> Function() action) async {
    bool isAuthenticated = await _isUserAuthenticated();
    if (isAuthenticated) {
      await action();
    } else {
      Get.toNamed(AppRoutes.signIn);
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    // controller.pauseCurrentVideo();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      Get.snackbar(
        'Error',
        'No cameras available on this device.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.to(
      () => CameraCaptureScreen(cameras: cameras),
      binding: CameraCaptureBinding(),
    )?.then((_) {
      // controller.restoreVideoState();
    });
  }

  Future<int> getEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(
      'Getting entity from shared preferences: ${prefs.getInt('entity') ?? 0}',
    );
    return prefs.getInt('entity') ?? 0;
  }

  ProfileController get profileController {
    ensureLandingProfileControllers();
    return Get.find<ProfileController>();
  }

  ProfessionalProfileController get professionalProfileController {
    ensureLandingProfileControllers();
    return Get.find<ProfessionalProfileController>();
  }
  UserSearchController get searchController => Get.find<UserSearchController>();

  Future<List<Widget>> _screens(BuildContext context) async {
    // Must never throw / hang — upload navigates to profile (index 3), and a
    // null snapshot previously rendered blank SizedBox.shrink() (gray screen).
    int entity = 0;
    try {
      entity = await getEntity().timeout(
        const Duration(seconds: 2),
        onTimeout: () => 0,
      );
    } catch (_) {
      entity = 0;
    }
    return [
      NearestBusinessScreen(),
      Notifications(),
      entity == 2 ? ProfessionalProfileView() : ProfileView(),
    ];
  }

  void showAwesomeMaintenanceDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: "Maintenance Mode",
      desc: "Our app is currently under maintenance. We'll be back soon!",
      btnOkText: "Got it!",
      btnOkOnPress: () {},
      btnOkColor: Colors.orange,
    ).show();
  }

  void _showVideoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  "video_options".tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: Colors.black87),
                title: Text(
                  "Select Video or Image".tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _prepareForMediaCapture();
                    final XFile? pickedFile = await ImagePicker().pickMedia(
                      imageQuality: 80,
                      maxWidth: 1920,
                      maxHeight: 1080,
                    );
                    if (pickedFile != null) {
                      final fileType = pickedFile.path.toLowerCase();
                      if (fileType.endsWith('.jpg') ||
                          fileType.endsWith('.jpeg') ||
                          fileType.endsWith('.png') ||
                          fileType.endsWith('.webp')) {
                        // ImageEdit only prepares media and Get.back(result).
                        // Opening the form here (after editor is gone) avoids
                        // ProImageEditor teardown popping the form.
                        final prepared =
                            await Get.to<PreparedUploadMedia?>(
                          () => ImageEditScreen(imagePath: pickedFile.path),
                        );
                        if (prepared != null) {
                          await _openUploadForm(prepared);
                        }
                      } else if (fileType.endsWith('.mp4') ||
                          fileType.endsWith('.avi') ||
                          fileType.endsWith('.mov')) {
                        await Get.to(
                              () =>
                              VideoTextEditor(videoFile: File(pickedFile.path)),
                        );
                      } else {
                        Get.snackbar(
                          'Error'.tr,
                          'Unsupported file type'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Error'.tr,
                      'Failed to pick file'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  } finally {
                    await _restoreAfterMediaCapture();
                  }
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.camera, color: Colors.black87),
                title: Text(
                  "Capture Video".tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _prepareForMediaCapture();
                    final cameras = await availableCameras();
                    await Get.to(() => CameraScreen(cameras: cameras));
                  } finally {
                    await _restoreAfterMediaCapture();
                  }
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.photo, color: Colors.black87),
                title: Text(
                  "Capture an Image".tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.camera).then((_) {
                    // controller.restoreVideoState();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    bool shouldExit = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: "exit_app".tr,
      desc: "are_you_sure_you_want_to_exit_the_app".tr,
      btnOkText: "Yes".tr,
      btnCancelText: "No".tr,
      btnOkColor: ColorUtils.primaryColor,
      btnCancelColor: Colors.grey,
      btnOkOnPress: () {
        shouldExit = true;
      },
      btnCancelOnPress: () {
        shouldExit = false;
      },
      dismissOnTouchOutside: false,
    ).show();
    return shouldExit;
  }

  void _initDeepLinks() {
    if (_deepLinksInitialized) return;
    _deepLinksInitialized = true;

    appLinks.getInitialLink().then((uri) async {
      if (uri == null) return;
      final videoId = uri.queryParameters['id'];
      if (videoId == null || videoId.isEmpty) return;
      final isAuthenticated = await _isUserAuthenticated();
      if (!mounted) return;
      if (isAuthenticated) {
        Get.to(
          () => SingleVisitVideo(videoId: videoId, key: UniqueKey()),
          arguments: videoId,
        );
      } else {
        Get.to(AppRoutes.signIn);
      }
    });

    _deepLinkSubscription = appLinks.uriLinkStream.listen((uri) async {
      final videoId = uri.queryParameters['id'];
      if (videoId == null || videoId.isEmpty) return;
      final isAuthenticated = await _isUserAuthenticated();
      if (isAuthenticated) {
        Get.to(
          () => SingleVisitVideo(key: UniqueKey(), videoId: videoId),
          arguments: videoId,
        );
      } else {
        Get.toNamed(AppRoutes.signIn);
      }
    });
  }

  void _checkSubscriptionExpiry() {
    final subscriptionEndDate =
        professionalProfileController.userDetails.value?.subscription?.endDate;
    if (subscriptionEndDate == null) return;
    try {
      final expired = DateTime.now().isAfter(DateTime.parse(subscriptionEndDate));
      if (expired && !_isSubscriptionExpired.value) {
        _isSubscriptionExpired.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showExpiredPackageDialog(context);
        });
      }
    } catch (_) {}
  }

  /// [NavBarController] outlives this route, so a previous Landing's [Obx] can
  /// still be mounted (and already built this frame) when a replacement Landing
  /// is inflated — e.g. the locale switch rebuilds the whole root stack. Writing
  /// the shared Rx mid-build would mark that stale Obx dirty and trip the
  /// "setState() called during build" assertion, so defer until the frame ends.
  void _applyInitialTabIndex() {
    if (navBarController.selectedIndex.value == widget.initialIndex) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      navBarController.selectedIndex.value = widget.initialIndex;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navBarController.selectedIndex.value = widget.initialIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    LandingBinding().dependencies();
    _applyInitialTabIndex();
    fetchUserDetails();
    navBarController.checkForUpdate();
    _initDeepLinks();
    // Bottom-nav mute/restore is handled in [_performTabNavigation] only.
    // A listener here caused double [enterMutedPlaybackContext] (depth stuck > 0).
    // Start loading secondary tabs immediately; home tab mounts above without
    // waiting for this future.
    _screensFuture = _screens(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final entity = await getEntity();
      if (entity == 2) {
        ensureLandingProfileControllers();
        _subscriptionExpiryWorker = ever(
          Get.find<ProfessionalProfileController>().userDetails,
          (_) => _checkSubscriptionExpiry(),
        );
      }
      if (mounted) setState(() {});
      if (widget.initialIndex == 0 && Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().onReturnedToHomeTab();
      }
    });
  }

  @override
  void dispose() {
    _subscriptionExpiryWorker?.dispose();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          if (navBarController.selectedIndex.value != 0) {
            await _performTabNavigation(0);
          } else {
            final shouldPop = await _showExitConfirmationDialog(context);
            if (shouldPop) {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: Obx(() => _buildBottomNavBar(context)),
          body: FutureBuilder<List<Widget>>(
            future: _screensFuture,
            builder: (context, snapshot) {
              final otherScreens = snapshot.data;
              final tabLoadingPlaceholder = ColoredBox(
                color: Colors.white,
                child: Center(
                  child: PulseLogoLoader(
                    logoPath: 'assets/images/appIcon.png',
                    size: 72,
                  ),
                ),
              );
                  return Obx(
                () {
                  final selected = navBarController.selectedIndex.value;
                  final capturing = Get.isRegistered<HomeController>() &&
                      Get.find<HomeController>().isInMediaCaptureFlow;
                  return IndexedStack(
                    index: selected,
                    sizing: StackFit.expand,
                    children: [
                      TickerMode(
                        // Freeze Home completely under camera/upload — keeps
                        // PageView/players from rebuilding under the form.
                        enabled: selected == 0 && !capturing,
                        child: _homeScreen,
                      ),
                      if (otherScreens != null) ...[
                        otherScreens[0],
                        otherScreens[1],
                        otherScreens[2],
                      ] else ...[
                        // Never use empty shrink at profile/discover indexes —
                        // post-upload lands on index 3 before this future finishes.
                        tabLoadingPlaceholder,
                        tabLoadingPlaceholder,
                        tabLoadingPlaceholder,
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
    );
  }

  static const double _navBarContentHeight = 49;

  Widget _buildBottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
          width: Get.width,
          height: _navBarContentHeight + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                svgIcon: 'assets/icons/home.svg',
                selectedSvgIcon: 'assets/icons/homeFilled.svg',
                label: 'Home',
                index: 0,
                context: context,
              ),
              _buildNavItem(
                svgIcon: 'assets/icons/chat.svg',
                selectedSvgIcon: 'assets/icons/chatFilled.svg',
                label: 'Discover'.tr,
                index: 1,
                context: context,
              ),
              _buildAddButton(context),
              _buildNavItem(
                svgIcon: 'assets/icons/notificaion.svg',
                selectedSvgIcon: 'assets/icons/notificationFilled.svg',
                label: 'Notifications',
                index: 2,
                context: context,
              ),
              _buildNavItem(
                svgIcon: 'assets/icons/profile.svg',
                selectedSvgIcon: 'assets/icons/userFilled.svg',
                label: 'Profile',
                index: 3,
                context: context,
              ),
            ],
          ),
    );
  }

  Widget _buildNavItem({
    required String svgIcon,
    required String selectedSvgIcon,
    required String label,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = navBarController.selectedIndex.value == index;

    return InkWell(
      onTap: () async {
        if (index == 2 || index == 3) {
          await _handleAuthRequiredAction(() async {
            await _performTabNavigation(index);
          });
        } else {
          await _performTabNavigation(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            isSelected ? selectedSvgIcon : svgIcon,
            height: 22,
            colorFilter: ColorFilter.mode(
              _getIconColor(isSelected),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.tr,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: _getTextColor(isSelected),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stopAllVideoAudio() async {
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().enterBottomNavMute();
    } else {
      MediaKitPlayerPool.instance.silenceAllSync();
      await MediaKitPlayerPool.instance.pauseAllAwait();
      await VideoPlayerPool.instance.pauseAll();
    }
  }

  Future<void> _performTabNavigation(int index) async {
    final wasOnHome = navBarController.selectedIndex.value == 0;

    if (index != 0) {
      await _stopAllVideoAudio();
      navBarController.changeTab(index);
      if (index == 1 && Get.isRegistered<LocationController>()) {
        unawaited(Get.find<LocationController>().ensureDiscoverLoaded());
      }
      return;
    }

    navBarController.changeTab(0);

    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      final hasRouteOverlay = Get.key.currentState?.canPop() ?? false;
      if (hasRouteOverlay && wasOnHome) {
        // Already on Home with an overlay (e.g. comment sheet) — stay silenced.
        home.isNavigating.value = true;
        home.setReelsTabVisible(false);
        MediaKitPlayerPool.instance.silenceAllSync();
      } else if (wasOnHome) {
        // Re-tap on Home reloads unseen-first and opens at index 0.
        // Do NOT call onReturnedToHomeTab first — it restores the saved scroll
        // index (~N) and wins the race before refreshHomeFeed resets to 0.
        unawaited(home.refreshHomeFeed());
      } else if (home.needsColdRestoreAfterCapture ||
          home.feedResumePendingWhenHomeTab) {
        // Coming from another tab after upload — restore playback, don't
        // race a feed reload against the cold attach.
        home.onReturnedToHomeTab();
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (!Get.isRegistered<HomeController>()) {
            return;
          }
          final h = Get.find<HomeController>();
          if (!h.feedResumePendingWhenHomeTab &&
              !h.needsColdRestoreAfterCapture &&
              !h.coldRestoreInFlight) {
            return;
          }
          if (navBarController.selectedIndex.value != 0) {
            return;
          }
          debugPrint('[FeedRestore] tabNav post-upload nudge');
          h.onReturnedToHomeTab();
        });
      } else {
        // Returning to Home from another tab: unseen-first, not the last reel.
        unawaited(home.refreshHomeFeed());
      }
    }
  }

  Future<void> _prepareForMediaCapture() async {
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().beginMediaCaptureFlow();
    }
  }

  bool _captureOverlayStillOpen() {
    final route = Get.currentRoute.toLowerCase();
    if (route.contains('videopreview') ||
        route.contains('imageedit') ||
        route.contains('videotext') ||
        route.contains('camera')) {
      return true;
    }
    return Get.key.currentState?.canPop() ?? false;
  }

  Future<void> _openUploadForm(PreparedUploadMedia prepared) async {
    if (!Get.isRegistered<VideoAddController>()) {
      Get.put(VideoAddController());
    }
    // Short yield for editor overlay teardown — the real defense is
    // UploadFormPageRoute.didPop refusing forced Navigator.pop while absorbing.
    await WidgetsBinding.instance.endOfFrame;

    // First-open after install often gets a stale pop ~170ms after push.
    // Refuse it via didPop; if it still closes the route, reopen (same as
    // the working "second try").
    for (var attempt = 0; attempt < 4; attempt++) {
      final guard = UploadFormPopGuard();
      final nav = Get.key.currentState ?? Navigator.of(Get.context!);
      await nav.push<void>(
        UploadFormPageRoute(
          guard: guard,
          builder: (_) => VideoPreviewScreen(
            videoFile: prepared.file,
            isImage: prepared.isImage,
            popGuard: guard,
          ),
        ),
      );
      final reopen = guard.closedByStalePop;
      guard.dispose();
      if (!reopen) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _restoreAfterMediaCapture() async {
    if (!Get.isRegistered<HomeController>()) {
      return;
    }
    final home = Get.find<HomeController>();
    // Wait until editor/form overlays are gone. Prefer route checks over bare
    // canPop — GetX can briefly report canPop=false mid-transition.
    while (mounted && _captureOverlayStillOpen()) {
      home.reinforceMediaCaptureSilence();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted || !Get.isRegistered<HomeController>()) {
      return;
    }
    // Always end the capture gate — even if the user is on Profile after upload.
    // Previously we no-op'd when selectedIndex != 0, which could leave a leaked
    // capture depth until process kill if end wasn't paired on offAll.
    if (navBarController.selectedIndex.value != 0) {
      home.clearMediaCaptureGatesAfterLandingReset();
      return;
    }
    await home.endMediaCaptureFlow();
  }

  Color _getIconColor(bool isSelected) {
    return isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55);
  }

  Color _getTextColor(bool isSelected) {
    return isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55);
  }

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        await _handleAuthRequiredAction(() async {
          await _handleAddButtonLogic(context);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorUtils.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.add,
          color: ColorUtils.darkBrown,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _handleAddButtonLogic(BuildContext context) async {
    final entity = await getEntity();
    if (entity != 2) {
      _showVideoOptions(context);
      return;
    }

    final details = professionalProfileController.userDetails.value;
    final subscription = details?.subscription;
    final endDateStr = subscription?.endDate;
    if (details != null && subscription != null && endDateStr != null) {
      try {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(DateTime.now())) {
          _showVideoOptions(context);
        } else {
          showExpiredPackageDialog(context);
        }
      } catch (e) {
        print("Invalid date format: $e");
        showExpiredPackageDialog(context);
      }
    } else {
      _showVideoOptions(context);
    }
  }

  void showExpiredPackageDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'package_expired'.tr,
      desc: 'your_package_has_been_expired'.tr,
      btnOkText: 'renew'.tr,
      btnOkColor: ColorUtils.primaryColor,
      btnOkOnPress: () {
        Get.to(ChangePlanView());
      },
      dismissOnTouchOutside: false,
    ).show();
  }
}
