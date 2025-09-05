import 'dart:developer';
import 'dart:io';
import 'dart:ui';

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
import '../landingTabs/home/homeController/homeController.dart';
import '../landingTabs/home/homeController/saveController.dart';
import '../landingTabs/home/homeView/reelsVideoScreen.dart';
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
  final NavBarController navBarController = Get.put(NavBarController());
  final SaveController saveController = Get.put(SaveController());
  final PromoteVideoController promoteVideoController = Get.put(
    PromoteVideoController(),
  );

  final HomeController controller = Get.put(HomeController());

  final VideoAddController videoAddController = Get.put(VideoAddController());

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

  Future<void> _handleAuthRequiredAction(VoidCallback action) async {
    bool isAuthenticated = await _isUserAuthenticated();
    if (isAuthenticated) {
      action();
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
    Get.to(CameraCaptureScreen(cameras: cameras))?.then((_) {
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

  final ProfileController profileController = Get.put(ProfileController());
  final ProfessionalProfileController professionalProfileController = Get.put(
    ProfessionalProfileController(),
  );
  final UserSearchController searchController = Get.put(UserSearchController());

  Future<List<Widget>> _screens(BuildContext context) async {
    int entity = await getEntity();
    return [
      VideoReelScreen(),
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
                  // controller.pauseCurrentVideo();
                  try {
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
                    // controller.restoreVideoState();
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
                  // controller.pauseCurrentVideo();
                  final cameras = await availableCameras();
                  Get.to(CameraScreen(cameras: cameras))?.then((_) {
                    // controller.restoreVideoState();
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

  @override
  void initState() {
    super.initState();
    navBarController.selectedIndex.value = widget.initialIndex;
    fetchUserDetails();
    navBarController.checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    appLinks.getInitialLink().then((uri) async {
      bool isAuthenticated = await _isUserAuthenticated();
      if (uri != null) {
        final videoId = uri.queryParameters['id'];
        if (videoId != null) {
          log('Initial deep link with video ID: $videoId');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            isAuthenticated
                ? Get.to(
                  () => SingleVisitVideo(
                    videoId: videoId,
                    key: UniqueKey(), // ✅ Important
                  ),
                  arguments: videoId,
                )
                : Get.to(AppRoutes.signIn);
          });
        }
      }
    });

    // Handle deep links while app is running
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appLinks.uriLinkStream.listen((uri) async {
        final videoId = uri.queryParameters['id'];
        if (videoId != null && videoId.isNotEmpty) {
          bool isAuthenticated = await _isUserAuthenticated();

          log('Stream deep link with video ID: $videoId');
          isAuthenticated
              ? Get.to(
                () => SingleVisitVideo(
                  key: UniqueKey(), // ✅ Important
                  videoId: videoId,
                ),
                arguments: videoId,
              )
              : Get.toNamed(AppRoutes.signIn);
        } else {
          log('Invalid or missing video ID');
          Get.snackbar(
            'Error',
            'Invalid video ID in deep link',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });
    });

    return Obx(() {
      RxBool isExpired = RxBool(false);
      final subscriptionEndDate =
          professionalProfileController
              .userDetails
              .value
              ?.subscription
              ?.endDate;
      if (subscriptionEndDate != null) {
        try {
          isExpired.value = DateTime.now().isAfter(
            DateTime.parse(subscriptionEndDate),
          );
        } catch (e) {
          isExpired.value = false;
        }
      }
      if (isExpired.value) {
        Future.delayed(Duration.zero, () {
          showExpiredPackageDialog(context);
        });
      }
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          if (navBarController.selectedIndex.value != 0) {
            navBarController.changeTab(0);
            // controller.restoreVideoState();
          } else {
            final shouldPop = await _showExitConfirmationDialog(context);
            if (shouldPop) {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: SafeArea(child: _buildBottomNavBar(context)),
          body: FutureBuilder<List<Widget>>(
            future: _screens(context),
            builder: (context, snapshot) {
              return Obx(() {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    snapshot.data![navBarController.selectedIndex.value],
                  ],
                );
              });
            },
          ),
        ),
      );
    });
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: Get.width,
          height: 60.h,
          decoration: BoxDecoration(
            color:
                navBarController.selectedIndex.value == 0
                    ? Colors.black
                    : Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5),
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
        ),
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
    final isHomeTab = navBarController.selectedIndex.value == 0;

    return InkWell(
      onTap: () async {
        if (index == 2 || index == 3) {
          await _handleAuthRequiredAction(() {
            _performTabNavigation(index);
          });
        } else {
          _performTabNavigation(index);
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
                _getIconColor(isSelected, isHomeTab),
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label.tr,
            style: TextStyle(
              fontSize: 12.sp,
              color: _getTextColor(isSelected, isHomeTab),
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  void _performTabNavigation(int index) {
    navBarController.changeTab(index);
  }

  Color _getIconColor(bool isSelected, bool isHomeTab) {
    if (isHomeTab) {
      return isSelected ? ColorUtils.primaryColor : Colors.white;
    } else {
      return isSelected ? ColorUtils.primaryColor : ColorUtils.grey;
    }
  }

  Color _getTextColor(bool isSelected, bool isHomeTab) {
    if (isHomeTab) {
      return Colors.white;
    } else {
      return isSelected ? ColorUtils.primaryColor : ColorUtils.grey;
    }
  }

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        await _handleAuthRequiredAction(() {
          _handleAddButtonLogic(context);
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

  void _handleAddButtonLogic(BuildContext context) {
    if (professionalProfileController.userDetails.value != null &&
        professionalProfileController.userDetails.value!.subscription != null &&
        professionalProfileController
                .userDetails
                .value!
                .subscription!
                .endDate !=
            null) {
      try {
        DateTime endDate = DateTime.parse(
          professionalProfileController
              .userDetails
              .value!
              .subscription!
              .endDate!,
        );
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
