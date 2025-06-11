import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../../services/apiClient.dart';
import '../../add/videoUploadSettingsModel/videoUploadSettingsModel.dart';
import '../profileModel/profileModel.dart';
import '../profileModel/simpleUserProfileModel.dart';

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
  var countryId = -1.obs;
  var selectCountryId = "".obs;
  var selectedCityId = "".obs;
  var selectedAccountType = "".obs;

  var cityId = -1.obs;
  var profileLikesCount = 0.obs;


  Future<void> checkReceivedLikes(String currentUserId) async {
    try {
      print("Step 1: Function called with currentUserId: $currentUserId");

      // Query the document where profileId matches currentUserId
      print("Step 2: Querying Firestore for received likes...");
      final QuerySnapshot receivedLikes =
          await FirebaseFirestore.instance
              .collection('profileLikes')
              .where('profileId', isEqualTo: currentUserId)
              .get();

      if (receivedLikes.docs.isNotEmpty) {
        // Fetch the likeCount from the first document
        int likeCount = receivedLikes.docs.first['likeCount'] ?? 0;
        profileLikesCount.value = likeCount;
        print("Step 3: Updated profileLikesCount to $likeCount");
      } else {
        profileLikesCount.value = 0;
        print("Step 3: No likes found. profileLikesCount set to 0.");
      }
    } catch (e) {
      print("Error checking received like status: $e");
    }
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
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
      var response = await ApiClient.getRequest(EndPoints.videoTypes).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Get.offAllNamed('/noInternet');
          throw TimeoutException("The connection has timed out!");
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        videoUploadSettings.value = VideoUploadSettings.fromJson(data);
      } else {
        print("Error fetching video settings: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching video upload settings: $e");
    }
  }

  Future<File?> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  Future<void> getUserDetails() async {
    try {
      print("Step 1: Starting getUserDetails method.");

      isLoading.value = true;
      print("Step 2: isLoading set to true.");

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
        var data = jsonDecode(response.body);

        print("Step 7: Raw JSON response: $data");
        print("Step 7: Response type: ${data.runtimeType}");

        if (data is Map<String, dynamic>) {
          print("Check Simple Details fetched");
          simpleUserDetails.value = SimpleUserDetails.fromJson(data);
          print("Check Followers list fetched");
          followersList.value = simpleUserDetails.value!.followers ?? [];
          print("Check Following list fetched");
          followingList.value = simpleUserDetails.value!.following ?? [];
        } else {
          print(
            "Step 8: Invalid response format. Expected Map, got ${data.runtimeType}",
          );
          throw Exception(
            "Invalid response format: Expected Map<String, dynamic>",
          );
        }
      } else {
        print(
          "Step 9: Failed to fetch user details. Status code: ${response.statusCode}",
        );
      }
    } catch (e, stackTrace) {
      print("Step 10: Error occurred while fetching user details: $e");
      print("Stack trace: $stackTrace");
    } finally {
      isLoading.value = false;
      print(
        "Step 11: isLoading set to false. getUserDetails method completed.",
      );
    }
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'password_required_error'.tr;
    } else if (password.length < 8) {
      return 'password_length_error'.tr;
    } else if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'password_uppercase_error'.tr;
    } else if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'password_special_char_error'.tr;
    }
    return null; // Password is valid
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

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Common.baseUrl}${EndPoints.editUserProfile}'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept-Language'] = language; // Add Accept-Language header


      // Add only non-null fields
      if (name?.isNotEmpty ?? false) request.fields['name'] = name!;
      if (dob?.isNotEmpty ?? false) request.fields['dob'] = dob!;
      if (password?.isNotEmpty ?? false) request.fields['password'] = password!;
      if (phoneNumber?.isNotEmpty ?? false)
        request.fields['phone'] = phoneNumber!;
      if (countryId != -1) request.fields['country'] = countryId.toString();
      if (cityId != -1) request.fields['city'] = cityId.toString();
      if (selectedAccountType != -1)
        request.fields['type_of_account'] = selectedAccountType.toString();

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = jsonDecode(responseData);
        print("API Response: $data"); // Debugging log

        String userId = data['user']['id'];

        String updatedName = data['user']['name'];
        String? updatedImage = data['user']['image']; // Can be null
        String successMessage = data['message'] ?? 'Profile updated successfully.';



        print("PRINTING SUCCESS MESSAGE: ${successMessage}");

        // Update Firestore with new name & image
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'name': updatedName,
            'image': updatedImage, // If null, Firestore keeps it null
          },
        );

        // Refresh user details in app
        getUserDetails();

        Get.back();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage), // Display API message
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        var errorData = jsonDecode(responseData);
        String errorMessage = "Profile update failed"; // Default error message

        if (errorData is Map<String, dynamic>) {
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
          if (errorData.containsKey('errors')) {
            var errors = errorData['errors'] as Map<String, dynamic>;
            if (errors.isNotEmpty) {
              String detailedErrors = errors.entries
                  .map((e) {
                    var errorList = List<String>.from(
                      e.value,
                    ); // Ensure it's a list
                    return "${e.key.replaceAll('_', ' ').capitalizeFirst}: ${errorList.join(", ")}";
                  })
                  .join("\n");
              errorMessage += "\n$detailedErrors";
            }
          }
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
  void onInit() {
    super.onInit();
    getUserDetails();
    getVideoUploadSettings();
  }

  // @override
  // void onClose() {
  //   nameController.dispose();
  //   emailController.dispose();
  //   birthdayController.dispose();
  //   phoneNumberController.dispose();
  //   passwordController.dispose();
  //   super.onClose();
  // }
}
