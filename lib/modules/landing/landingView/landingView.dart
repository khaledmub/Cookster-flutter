import 'dart:io';
import 'dart:ui';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:camera/camera.dart';
import 'package:cookster/loaders/pulseLoader.dart';
import 'package:cookster/modules/landing/landingTabs/notification/notificationView/notificationView.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/changePlan/changePlanView/changePlanView.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileView/profileView.dart';
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

  Future<bool> _isUserAuthenticated() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('auth_token');
    return authToken != null && authToken.isNotEmpty;
  }

  Future<void> fetchUserDetails() async {
    bool isAuthenticated = await _isUserAuthenticated();
    if (isAuthenticated) {
      int entity = await getEntity();
      if (entity == 2) {
        // Fetch from ProfessionalProfileController
        await professionalProfileController.getUserDetails();
      } else {
        // Fetch from ProfileController
        await profileController.getUserDetails();
      }
    } else {
      // Handle unauthenticated user (e.g., redirect to sign-in)
      // Get.toNamed(AppRoutes.signIn);
    }
  }

  // Add this method to handle authentication required actions
  Future<void> _handleAuthRequiredAction(VoidCallback action) async {
    bool isAuthenticated = await _isUserAuthenticated();

    if (isAuthenticated) {
      action(); // Execute the action if authenticated
    } else {
      // Navigate to sign in page
      Get.toNamed(AppRoutes.signIn); // Make sure you have this route defined
    }
  }

  // Center vertically, adjust for widget height
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    // controller.handleNavigation();
    controller.pauseCurrentVideo(); // Pause any ongoing video

    // Get available cameras first
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
      controller.restoreVideoState(); // Restore video state after returning
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
      // VideoRecorderScreen(),
      // Container(),
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
                  controller.pauseCurrentVideo();

                  try {
                    // Pick a file from gallery
                    final XFile? pickedFile = await ImagePicker().pickMedia(
                      imageQuality: 80,
                      maxWidth: 1920,
                      maxHeight: 1080,
                    );

                    if (pickedFile != null) {
                      // Determine file type
                      final fileType = pickedFile.path.toLowerCase();

                      if (fileType.endsWith('.jpg') ||
                          fileType.endsWith('.jpeg') ||
                          fileType.endsWith('.png') ||
                          fileType.endsWith('.webp')) {
                        // Image selected
                        await Get.to(
                          () => ImageEditScreen(imagePath: pickedFile.path),
                        );
                      } else if (fileType.endsWith('.mp4') ||
                          fileType.endsWith('.avi') ||
                          fileType.endsWith('.mov')) {
                        // Video selected
                        await Get.to(
                          () =>
                              VideoTextEditor(videoFile: File(pickedFile.path)),
                        );
                      } else {
                        // Unsupported file type
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
                    // Handle any errors during file picking
                    Get.snackbar(
                      'Error'.tr,
                      'Failed to pick file'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  } finally {
                    // Restore video state
                    controller.restoreVideoState();
                  }
                },
              ),
              // SizedBox(height: 10),
              ListTile(
                leading: Icon(CupertinoIcons.camera, color: Colors.black87),
                title: Text(
                  "Capture Video".tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // controller.handleNavigation();
                  controller.pauseCurrentVideo();

                  // Get available cameras first
                  final cameras = await availableCameras();

                  Get.to(CameraScreen(cameras: cameras))?.then((_) {
                    controller.restoreVideoState();
                  });
                  // _pickVideo(context, ImageSource.camera);
                },
              ),
              // SizedBox(height: 10),
              ListTile(
                leading: Icon(CupertinoIcons.photo, color: Colors.black87),
                title: Text(
                  "Capture an Image".tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // controller.handleNavigation();
                  _pickImage(context, ImageSource.camera).then((_) {
                    controller.restoreVideoState();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    // If not on home screen (index 0), navigate to home
    if (navBarController.selectedIndex.value != 0) {
      navBarController.changeTab(0);
      controller.restoreVideoState();
      return false; // Don't exit the app
    } else {
      // Show exit confirmation dialog
      return await _showExitConfirmationDialog(context);
    }
  }

  // Show exit confirmation dialog
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
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Safely check if subscription is expired
      RxBool isExpired = RxBool(false); // Default to false

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
          // Handle parsing error, if any
          isExpired.value = false; // Assume not expired if parsing fails
        }
      }

      // Show dialog if expired, using Future.delayed to avoid build issues
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
            controller.restoreVideoState();
          } else {
            final shouldPop = await _showExitConfirmationDialog(context);
            if (shouldPop) {
              SystemNavigator.pop();
            }
          }
        },
        child:
            profileController.isLoading.value ||
                    professionalProfileController.isLoading.value
                ? Scaffold(
                  body: Center(
                    child: PulseLogoLoader(
                      logoPath: "assets/images/appIconC.png",
                    ),
                  ),
                )
                : Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: FutureBuilder<List<Widget>>(
                    future: _screens(context),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: PulseLogoLoader(
                            logoPath: "assets/images/appIcon.png",
                            size: 80,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(child: Text("Error loading screens"));
                      } else {
                        return Obx(() {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Main content
                              snapshot.data![navBarController
                                  .selectedIndex
                                  .value],

                              // Bottom Navigation Bar
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: SafeArea(
                                  child: _buildBottomNavBar(context),
                                ),
                              ),
                            ],
                          );
                        });
                      }
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
                    ? Colors.black.withOpacity(0.15)
                    : Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
        // Check if the tab requires authentication (Add=2, Notifications=2, Profile=3)
        // Note: Add button is handled separately in _buildAddButton
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

  // Extract the tab navigation logic into a separate method
  void _performTabNavigation(int index) {
    if (navBarController.selectedIndex.value == 0 && index != 0) {
      controller.handleNavigation();
    } else if (index == 0) {
      controller.restoreVideoState();
    }
    controller.pauseCurrentVideo();
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
      return Colors.white; // Always white on home tab
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

  // Extract the add button logic into a separate method
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
        // Add renewal logic here
      },
      dismissOnTouchOutside: false,
    ).show();
  }
}
