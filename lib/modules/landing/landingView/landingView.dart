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
import '../../../services/imageEditScreen.dart';
import '../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../search/searchController/searchController.dart';
import '../../singleVideoVisit/singleVideoVisit.dart';
import '../landingController/landingController.dart';
import '../landingTabs/add/videoAddController/videoAddController.dart';
import '../../../core/video/media_kit_player_pool.dart';
import '../../../core/video/video_player_pool.dart';
import '../landingTabs/home/homeController/homeController.dart';
import '../landingTabs/home/homeController/saveController.dart';
import '../landingTabs/home/homeView/reelsVideoScreen.dart';
import '../landingTabs/nearBusiness/nearBusinessController/nearBusinessController.dart';
import '../landingTabs/nearBusiness/newBusinessView/nearBusinessView.dart';
import '../landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import '../landingTabs/professionalProfile/profileView/professionalProfileView.dart';

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
  SaveController get saveController => Get.find<SaveController>();
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
    int entity = await getEntity();
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
                        await Get.to(
                              () => ImageEditScreen(imagePath: pickedFile.path),
                        );
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
                  await _prepareForMediaCapture();
                  final cameras = await availableCameras();
                  Get.to(CameraScreen(cameras: cameras))?.then((_) async {
                    await _restoreAfterMediaCapture();
                  });
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

  @override
  void initState() {
    super.initState();
    LandingBinding().dependencies();
    navBarController.selectedIndex.value = widget.initialIndex;
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
              return Obx(
                () {
                  final selected = navBarController.selectedIndex.value;
                  return IndexedStack(
                    index: selected,
                    sizing: StackFit.expand,
                    children: [
                      TickerMode(
                        enabled: selected == 0,
                        child: _homeScreen,
                      ),
                      if (otherScreens != null) ...[
                        otherScreens[0],
                        otherScreens[1],
                        otherScreens[2],
                      ] else ...[
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
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

  Widget _buildBottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
          width: Get.width,
          height: 60.h + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
            ),
          ),
          child: Row(
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
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color:
              isSelected
                  ? ColorUtils.primaryColor.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              isSelected ? selectedSvgIcon : svgIcon,
              height: 16.h,
              colorFilter: ColorFilter.mode(
                _getIconColor(isSelected),
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label.tr,
            style: TextStyle(
              fontSize: 12.sp,
              color: _getTextColor(isSelected),
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
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
      if (hasRouteOverlay) {
        home.isNavigating.value = true;
        home.setReelsTabVisible(false);
        MediaKitPlayerPool.instance.silenceAllSync();
      } else if (wasOnHome) {
        // Re-tap on Home = TikTok-style refresh to the newest reel (index 0).
        // Do NOT call onReturnedToHomeTab first — it restores the saved scroll
        // index (~N) and wins the race before refreshHomeFeed resets to 0.
        unawaited(home.refreshHomeFeed());
      } else {
        home.onReturnedToHomeTab();
      }
    }
  }

  Future<void> _prepareForMediaCapture() async {
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().beginMediaCaptureFlow();
    }
  }

  Future<void> _restoreAfterMediaCapture() async {
    if (!Get.isRegistered<HomeController>()) {
      return;
    }
    if (navBarController.selectedIndex.value != 0) {
      return;
    }
    await Get.find<HomeController>().endMediaCaptureFlow();
  }

  Color _getIconColor(bool isSelected) {
    return isSelected ? ColorUtils.primaryColor : Colors.white;
  }

  Color _getTextColor(bool isSelected) {
    return isSelected ? ColorUtils.primaryColor : Colors.white;
  }

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        await _handleAuthRequiredAction(() async {
          await _handleAddButtonLogic(context);
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10, right: 0, left: 20),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ColorUtils.primaryColor,
          boxShadow: [
            BoxShadow(
              color: ColorUtils.primaryColor,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SvgPicture.asset(
          "assets/icons/add.svg",
          fit: BoxFit.contain,
          color: ColorUtils.darkBrown,
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
