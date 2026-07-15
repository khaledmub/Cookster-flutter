import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/services/username_availability_service.dart';
import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../../services/apiClient.dart';
import '../../../../../services/video_settings_service.dart';
import '../../add/videoUploadSettingsModel/videoUploadSettingsModel.dart'
    hide VideoTypes;
import '../profileModel/profileModel.dart' hide VideoTypes;
import '../profileModel/simpleUserProfileModel.dart';
import 'package:cookster/core/media/media_url_resolver.dart';
import 'package:cookster/core/media/wall_video_media.dart';
import 'package:cookster/services/video_processing_service.dart';

class ProfileController extends GetxController {
  var selectedIndex = 0.obs;
  var simpleUserDetails = Rxn<SimpleUserDetails>();
  var userDetails = Rxn<UserDetails>();

  // Observable lists for followers and following with user details
  RxList<String> followersList = <String>[].obs;
  RxList<String> followingList = <String>[].obs;

  var isLoading = false.obs;
  var isFollowingProcess = false.obs;
  var isProfileUpdating = false.obs;
  var isFollowersLoading = false.obs;
  var isFollowingLoading = false.obs;
  var selectedImage = Rxn<File>();
  final profileImageRefreshToken = 0.obs;
  int countryId = -1;
  var selectCountryId = "".obs;
  var selectedCityId = "".obs;
  var selectedCountryName = ''.obs;
  var selectedCityName = ''.obs;
  var selectedAccountType = "".obs;
  var isSettingsLoading = false.obs;

  int cityId = -1;
  var profileLikesCount = 0.obs;

  Stream<int> checkReceivedLikes(String currentUserId) {
    print("Step 1: Stream initialized for currentUserId: $currentUserId");

    return FirebaseFirestore.instance
        .collection('profileLikes')
        .where('profileId', isEqualTo: currentUserId)
        .snapshots()
        .map((QuerySnapshot snapshot) {
          print("Step 2: Received snapshot for profileLikes");
          if (snapshot.docs.isNotEmpty) {
            int likeCount = snapshot.docs.first['likeCount'] ?? 0;
            print("Step 3: Updating profileLikesCount to $likeCount");
            profileLikesCount.value = likeCount;
            return likeCount;
          } else {
            print("Step 3: No likes found. profileLikesCount set to 0.");
            profileLikesCount.value = 0;
            return 0;
          }
        })
        .handleError((e) {
          print("Error in stream: $e");
          return 0;
        });
  }

  Stream<int> checkLikedVideos(String userId) {
    return FirebaseFirestore.instance
        .collection('videos')
        .where('likes', arrayContains: userId)
        .snapshots()
        .map((QuerySnapshot querySnapshot) {
          int totalLikes = 0;
          for (var doc in querySnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;
            List<String> likes = List<String>.from(data['likes'] ?? []);
            totalLikes += likes.length; // Count likes for each video
          }
          return totalLikes;
        });
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  var isCheckingUsername = false.obs;
  var isUsernameAvailable = RxnBool();
  String? initialUsername;
  var videoUploadSettings = Rxn<VideoUploadSettings>();

  // Check if current user is following a specific user
  bool isFollowing(String userId) {
    if (simpleUserDetails.value == null ||
        simpleUserDetails.value!.following == null) {
      return false;
    }
    return simpleUserDetails.value!.following!.contains(userId);
  }

  // Toggle follow/unfollow status
  Future<void> toggleFollowStatus(String userId) async {
    print('PRINTING THE USER ID FOR FOLLOWERS: ${userId}');

    // Set loading state to true
    isFollowingProcess.value = true;

    try {
      final endpoint =
          isFollowing(userId) ? '${EndPoints.unfollow}' : '${EndPoints.follow}';

      final response = await ApiClient.postRequest(endpoint, {
        'following_id': userId,
      });

      if (response.statusCode == 200) {
        // Update local following list
        if (isFollowing(userId)) {
          simpleUserDetails.value!.following!.remove(userId);
          followingList.removeWhere((id) => id.toString() == userId);
        } else {
          simpleUserDetails.value!.following!.add(userId);
          // Fetch user details and add to followingList
        }

        // Update UI
        simpleUserDetails.refresh();
        followingList.refresh();

        // Show toast message instead of snackbar
        String message = isFollowing(userId) ? "Following".tr : "unfollowed".tr;

        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black.withOpacity(0.7),
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        print("Failed to toggle follow status: ${response.body}");

        // Show error as toast
        Fluttertoast.showToast(
          msg: "Couldn't update follow status",
          backgroundColor: Colors.black.withOpacity(0.7),
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print("Error toggling follow status: $e");

      // Show error as toast
      Fluttertoast.showToast(
        msg: "Something went wrong",
        backgroundColor: Colors.black.withOpacity(0.7),
        textColor: Colors.white,
      );
    } finally {
      // Set loading state back to false regardless of success or failure
      isFollowingProcess.value = false;
    }
  }

  // Fetch user details by ID
  Future<Map<String, dynamic>?> fetchUserDetails() async {
    try {
      isLoading.value = true; // Start loading

      final response = await ApiClient.getRequest(
        '${EndPoints.getUserProfile}',
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        User? user = User.fromJson(data['user']);
        List<String>? followers = data['followers']?.cast<String>();
        List<String>? following = data['following']?.cast<String>();

        return {'user': user, 'followers': followers, 'following': following};
      } else {
        print("Failed to fetch user details: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching user details: $e");
      return null;
    } finally {
      isLoading.value = false; // Stop loading
    }
  }

  Future<void> showLogoutDialog(BuildContext context) async {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: "Logout Confirmation".tr,
      desc: "confirm_logout".tr,
      btnCancelText: "No".tr,
      btnCancelOnPress: () {},
      // No action on cancel
      btnCancelColor: Colors.grey,
      // Set Cancel button color to grey
      btnOkText: "Yes".tr,
      btnOkOnPress: () {
        Get.offAllNamed(AppRoutes.signIn); // Navigate to sign-in screen
        // await showLoadingDialog(context); // Show loading indicator (commented out)
        logoutUser(); // Call logout API
        Get.back(); // Close the loading dialog
      },
      btnOkColor: ColorUtils.primaryColor, // Set OK button to primary color
    ).show();
  }

  String? nameValidator(String? value) {
    // Check if the value is null or empty after trimming
    if (value == null || value.trim().isEmpty) {
      return "name_required_error".tr;
    }

    // Get the trimmed value to work with
    String trimmedValue = value.trim();

    // Check minimum length after trimming
    if (trimmedValue.length < 3) {
      return "name_length_error".tr;
    }

    return null; // Valid name
  }

  String? usernameValidator(String? value) {
    return PublicUserIdentity.validateUsernameFormat(value);
  }

  Future<void> checkUsernameAvailability() async {
    final normalized =
        PublicUserIdentity.normalizeUsername(usernameController.text);
    if (normalized == (initialUsername ?? '')) {
      isUsernameAvailable.value = true;
      return;
    }
    final formatError = usernameValidator(normalized);
    if (formatError != null) {
      isUsernameAvailable.value = null;
      return;
    }

    isCheckingUsername.value = true;
    try {
      isUsernameAvailable.value =
          await UsernameAvailabilityService.checkAvailability(normalized);
    } finally {
      isCheckingUsername.value = false;
    }
  }

  String? dobValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // No error if empty (optional field)
    }
    return null; // Valid DOB (no format validation)
  }

  Future<void> showLoadingDialog() async {
    Get.dialog(
      Center(
        child: PulseLogoLoader(logoPath: "assets/images/appIcon.png", size: 80),
      ),
      barrierDismissible: false, // Prevent closing while loading
    );
  }

  Future<void> logoutUser() async {
    try {
      final response = await ApiClient.postRequest('${EndPoints.logout}', {});

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        // Store the onboarding_completed, language, and selectedLanguage values before clearing
        bool onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;
        String language =
            prefs.getString('language') ??
            'en'; // Default to 'en' as per ApiClient
        String selectedLanguage =
            prefs.getString('selectedLanguage') ??
            'English'; // Default to 'English' as per LanguageController
        bool initLanguage = prefs.getBool('initLanguage') ?? false;

        // Clear all preferences
        await prefs.clear();

        // Restore the onboarding_completed, language, and selectedLanguage values
        await prefs.setBool('onboarding_completed', onboardingCompleted);
        await prefs.setString('language', language);
        await prefs.setString('selectedLanguage', selectedLanguage);
        await prefs.setBool('initLanguage', initLanguage);

        // Clear in-memory user data
        userDetails.value = null; // Assuming this is defined elsewhere
        simpleUserDetails.value = null; // Assuming this is defined elsewhere
        followersList.clear(); // Assuming this is defined elsewhere
        followingList.clear(); // Assuming this is defined elsewhere

        // Reinitialize ApiClient language
        await ApiClient.initLanguage();

        print(
          "User logged out, preferences cleared except onboarding status, language, and selectedLanguage",
        );
        // Get.offAllNamed(AppRoutes.signIn); // Navigate to sign-in screen
      } else {
        print("Logout failed: ${response.body}");
      }
    } catch (e) {
      print("Error logging out: $e");
    }
  }

  Future<void> getVideoUploadSettings() async {
    try {
      final settings = await VideoSettingsService.instance.load();
      videoUploadSettings.value = settings;
    } catch (e) {
      print("Error fetching video upload settings: $e");
    }
  }

  Future<File?> pickImage() async {
    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Android 13+ uses READ_MEDIA_IMAGES (Permission.photos).
        // Older versions use storage permission.
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted || photosStatus.isLimited) {
          status = photosStatus;
        } else {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (!status.isGranted && !status.isLimited) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(
            content: Text('Please allow gallery access to select photos.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return null;
      }

      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Unable to access photos: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }

  Future<bool> deleteVideo(
    BuildContext context,
    String videoId,
    String frondUserId,
  ) async {
    final String endpoint = '${EndPoints.deleteVideo}?id=$videoId';
    bool isDeleted = false;

    // Check user authorization
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');
    if (userId == null || userId != frondUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are not authorized to delete this video'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    // Show confirmation dialog
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'delete_video'.tr,
      desc: 'sure_to_delete'.tr,
      btnCancelOnPress: () {
        // Return false if the user cancels
        isDeleted = false;
      },
      btnOkOnPress: () async {
        try {
          print(
            'Step 1: Initiating API call to delete video with ID: $videoId',
          );
          // Step 1: Make API call to delete video
          final response = await ApiClient.deleteRequest(endpoint);

          print(
            'Step 2: API call completed. Status code: ${response.statusCode}',
          );
          print('API response body: ${response.body}');

          // Parse the API response
          final responseData = jsonDecode(response.body);
          print('Step 3: API response parsed successfully');

          // Assume the API returns a 'message' field in the JSON response
          final String apiMessage =
              responseData['message'] ?? 'No message provided by API';
          print('Step 4: Extracted API message: $apiMessage');

          if (response.statusCode == 201) {
            print(
              'Step 5: API call successful. Proceeding to delete Firestore document',
            );
            // Step 2: Delete video document from Firestore
            await FirebaseFirestore.instance
                .collection('videos')
                .doc(videoId)
                .delete();
            print('Step 6: Firestore document deleted successfully');

            // Show success message from API at the top
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(apiMessage),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                duration: Duration(seconds: 3),
              ),
            );
            print('Step 7: Success SnackBar displayed');

            getUserDetails();

            // Get.offAll(Landing());

            // Mark deletion as successful
            isDeleted = true;
            print('Step 8: Deletion marked as successful');
          } else {
            print(
              'Step 5: API call failed with status code: ${response.statusCode}',
            );
            // API call failed, show the API's error message at the top
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(apiMessage),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                duration: Duration(seconds: 3),
              ),
            );
            print('Step 6: Error SnackBar displayed for API failure');
          }
        } catch (e) {
          print('Error occurred during deletion: $e');
          // Show error message for any exception at the top
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting video: $e'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              duration: Duration(seconds: 3),
            ),
          );
          print('Error SnackBar displayed');
        }
      },
      btnOkText: 'yes_delete'.tr,
      btnCancelText: 'cancel'.tr,
    ).show();

    return isDeleted;
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  RxList<String> videoIds = <String>[].obs;
  RxInt totalLikes = 0.obs;

  Future<void> getUserDetails() async {
    try {
      print("Step 1: Starting getUserDetails method.");

      // Soft refresh: keep the grid mounted when we already have profile data.
      // Flipping isLoading=true after upload unmounted tiles mid-tap (multi-tap
      // needed to open a just-uploaded photo).
      final hasCachedProfile = simpleUserDetails.value != null;
      if (!hasCachedProfile) {
        isLoading.value = true;
      }
      print("Step 2: isLoading set to ${isLoading.value} (soft=$hasCachedProfile).");

      print("Step 3: Sending GET request to fetch user details.");
      var response = await ApiClient.getRequest(
        EndPoints.getUserProfile,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("Step 4: Request timed out. Navigating to noInternet screen.");
          Get.offAllNamed('/noInternet');
          throw TimeoutException("The connection has timed out!");
        },
      );
      print(
        "Step 5: Response received with status code: ${response.statusCode}",
      );

      if (response.statusCode == 200) {
        print("Step 6: Successfully fetched user details. Parsing data.");
        final details = await compute(parseProfileDetails, response.body);
        simpleUserDetails.value = details;
        // Soft refresh (isLoading stays false) must still nudge Obx listeners so
        // grid badges/posters update after upload without a pull-to-refresh.
        simpleUserDetails.refresh();
        print("Check Followers list fetched");
        followersList.value = simpleUserDetails.value!.followers ?? [];
        print("Check Following list fetched");
        followingList.value = simpleUserDetails.value!.following ?? [];

        totalLikes.value = _sumVideoLikes(simpleUserDetails.value?.videoTypes);
        print("Step 9: Total likes on all videos: ${totalLikes.value}");
        ensureProcessingWatch();
      } else {
        print(
          "Step 11: Failed to fetch user details. Status code: ${response.statusCode}",
        );
      }
    } catch (e, stackTrace) {
      print("Step 12: Error occurred while fetching user details: $e");
      print("Stack trace: $stackTrace");
    } finally {
      isLoading.value = false;
      print(
        "Step 13: isLoading set to false. getUserDetails method completed.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Real-time upload processing watcher.
  //
  // After an upload lands the user back on the profile, the freshly uploaded
  // video appears as a "processing" grid tile (spinner overlay, not openable).
  // This watcher polls the server transcode status and soft-refreshes the grid
  // the moment a tile becomes watch-ready, so it flips to a playable poster in
  // place without a pull-to-refresh.
  Timer? _processingWatchTimer;
  DateTime? _processingWatchDeadline;
  final Set<String> _settledProcessingIds = <String>{};

  Set<String> _collectProcessingVideoIds() {
    final ids = <String>{};
    final types = simpleUserDetails.value?.videoTypes;
    if (types == null) return ids;
    for (final type in types) {
      for (final v in type.videos ?? const <UserVideos>[]) {
        final id = v.id?.toString();
        if (id == null || id.isEmpty) continue;
        final processing = isReelGridProcessing(
          isImage: v.isImage,
          videoUrl: v.videoUrl,
          video: v.video,
          thumbnailUrl: v.thumbnailUrl,
          imageUrl: v.imageUrl,
          image: v.image,
          transcodeStatus: v.transcodeStatus,
          processingStatus: v.processingStatus,
          playbackReady: v.playbackReady,
        );
        if (processing) ids.add(id);
      }
    }
    return ids;
  }

  void ensureProcessingWatch() {
    if (isClosed) return;
    if (_processingWatchTimer != null) return;
    if (_collectProcessingVideoIds().isEmpty) return;
    _processingWatchDeadline = DateTime.now().add(const Duration(minutes: 5));
    _processingWatchTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _onProcessingWatchTick(timer),
    );
  }

  Future<void> _onProcessingWatchTick(Timer timer) async {
    if (isClosed) {
      _stopProcessingWatch();
      return;
    }
    final deadline = _processingWatchDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _stopProcessingWatch();
      return;
    }
    final pending = _collectProcessingVideoIds();
    if (pending.isEmpty) {
      _stopProcessingWatch();
      return;
    }
    var anyNewlySettled = false;
    for (final id in pending) {
      final status = await VideoProcessingService.fetchStatus(id);
      if (status == null) continue;
      if (status.isWatchReady || status.transcodeFailed) {
        if (_settledProcessingIds.add(id)) {
          anyNewlySettled = true;
        }
      }
    }
    if (anyNewlySettled && !isClosed) {
      await getUserDetails();
    }
  }

  void _stopProcessingWatch() {
    _processingWatchTimer?.cancel();
    _processingWatchTimer = null;
    _processingWatchDeadline = null;
  }

  /// Lightweight refresh: only re-counts likes from Firestore
  /// without reloading the full profile (avoids UI flicker on back-navigation).
  Future<void> refreshLikesOnly() async {
    totalLikes.value = _sumVideoLikes(simpleUserDetails.value?.videoTypes);
  }

  int _sumVideoLikes(List<VideoTypes>? videoTypes) {
    if (videoTypes == null) return 0;
    var total = 0;
    for (final videoType in videoTypes) {
      for (final video in videoType.videos ?? const []) {
        total += parseApiCount(video.likeCount);
      }
    }
    return total;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'password_required_error'.tr;
    }
    return null;
  }

  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'phone_required_error'.tr;
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{7,14}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'phone_invalid_error'.tr;
    }
    return null;
  }

  Future<void> updateUserProfile({
    String? name,
    String? userName,
    String? dob,
    String? password,
    String? phoneNumber,

    File? imageFile,
    required BuildContext context, // Ensure valid context
  }) async {
    try {
      isProfileUpdating.value = true; // Start updating

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      String language = prefs.getString('language') ?? 'en';

      if (token == null) {
        isProfileUpdating.value = false;
        Get.snackbar("Error", "User is not logged in.");
        return;
      }

      final fields = <String, String>{};
      final files = <http.MultipartFile>[];

      if (name?.isNotEmpty ?? false) fields['name'] = name!;
      if (userName?.isNotEmpty ?? false) {
        fields['user_name'] = PublicUserIdentity.normalizeUsername(userName!);
      }
      if (dob?.isNotEmpty ?? false) fields['dob'] = dob!;
      if (password?.isNotEmpty ?? false) fields['password'] = password!;
      if (phoneNumber?.isNotEmpty ?? false) fields['phone'] = phoneNumber!;
      if (countryId != -1) fields['country'] = countryId.toString();
      if (cityId != -1) fields['city'] = cityId.toString();
      if (selectedAccountType.value.isNotEmpty &&
          selectedAccountType.value != '-1') {
        fields['type_of_account'] = selectedAccountType.value;
      }

      if (imageFile != null) {
        files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await ApiClient.multipartPost(
        EndPoints.editUserProfile,
        fields: fields,
        files: files,
      );
      final responseData = response.body;

      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(responseData) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Server returned an invalid response. Please try again later.');
        }
        print("API Response: $data");

        String userId = data['user']['id'];

        String updatedName = data['user']['name'];
        String? updatedImage = data['user']['image'];
        String successMessage =
            data['message'] ?? 'Profile updated successfully.';

        print("PRINTING SUCCESS MESSAGE: ${successMessage}");

        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'name': updatedName,
            'image': updatedImage,
          },
        );

        if (updatedImage != null && updatedImage.isNotEmpty) {
          await prefs.setString('user_image', updatedImage);
          await DefaultCacheManager().removeFile(
            MediaUrlResolver.profileImageUrl(updatedImage) ?? '',
          );
          profileImageRefreshToken.value = DateTime.now().millisecondsSinceEpoch;
        }

        getUserDetails();

        Get.back();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String errorMessage;
        try {
          var errorData = jsonDecode(responseData);
          errorMessage = "Profile update failed";

          if (errorData is Map<String, dynamic>) {
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'];
            }
            if (errorData.containsKey('errors')) {
              var errors = errorData['errors'] as Map<String, dynamic>;
              if (errors.isNotEmpty) {
                String detailedErrors = errors.entries
                    .map((e) {
                      var errorList = List<String>.from(e.value);
                      return "${e.key.replaceAll('_', ' ').capitalizeFirst}: ${errorList.join(", ")}";
                    })
                    .join("\n");
                errorMessage += "\n$detailedErrors";
              }
            }
          }
        } catch (_) {
          errorMessage = 'Server error (${response.statusCode}). Please try again later.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        print("Profile update failed with status code: ${response.statusCode}");
        print("Error response: $responseData");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      print("Exception during profile update: $e");
    } finally {
      isProfileUpdating.value = false; // End updating
    }
  }

  @override
  void onInit() async {
    super.onInit();
    // await getUserDetails();
  }

  // @override
  @override
  void onClose() {
    _stopProcessingWatch();
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    birthdayController.dispose();
    phoneNumberController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
