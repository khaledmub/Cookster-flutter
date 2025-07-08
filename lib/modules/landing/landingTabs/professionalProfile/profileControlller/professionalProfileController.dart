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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../../../../../services/apiClient.dart';
import '../../add/videoUploadSettingsModel/videoUploadSettingsModel.dart';
import '../../profile/profileModel/profileModel.dart';
import '../../profile/profileModel/simpleUserProfileModel.dart';

class ProfessionalProfileController extends GetxController {
  var selectedIndex = 0.obs;
  var simpleUserDetails = Rxn<SimpleUserDetails>();
  var userDetails = Rxn<UserDetails>();
  var isLoading = false.obs;
  var isProfileUpdating = false.obs;
  var selectedImage = Rxn<File>();
  var selectCountryId = "".obs;
  var selectedCityId = "".obs;

  final isB2B = false.obs;

  // Toggle function
  void toggleB2B(bool value) {
    isB2B.value = value;
    userDetails.value!.additionalData!.isB2B = value ? 1 : 0;
    changeB2BStatus(value);
  }

  // API function to change B2B status using ApiClient
  Future<bool> changeB2BStatus(bool isB2BStatus) async {
    try {
      final response = await ApiClient.postRequest(EndPoints.b2bStatus, {
        'is_b2b': isB2BStatus ? 1 : 0,
      });

      print(response.body);

      if (response.statusCode == 200) {
        // Update the local state on success
        isB2B.value = isB2BStatus;
        return true;
      } else {
        print('Failed to change B2B status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error changing B2B status: $e');
      return false;
    }
  }

  // Observable lists for followers and following with user details
  RxList<String> followersList = <String>[].obs;
  RxList<String> followingList = <String>[].obs;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController contactEmailController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  var latitude = "";
  var longitude = "";

  // var stateId = -1;
  var countryId = -1;
  var cityId = -1;
  var menuId = -1;
  var videoUploadSettings = Rxn<VideoUploadSettings>();

  var profileLikesCount = 0.obs;

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

  String? validateWebsite(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final websiteRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)(\.[a-zA-Z]{2,})+(\/\S*)?$',
    );

    if (!websiteRegex.hasMatch(value)) {
      return 'website_invalid_error'.tr;
    }

    return null;
  }

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

  bool isFollowing(String userId) {
    if (userDetails.value == null || userDetails.value!.following == null) {
      return false;
    }
    return userDetails.value!.following!.contains(userId);
  }

  var isFollowingProcess = false.obs;

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
          userDetails.value!.following!.remove(userId);
          followingList.removeWhere((id) => id.toString() == userId);
        } else {
          userDetails.value!.following!.add(userId);
          // Fetch user details and add to followingList
        }

        // Update UI
        userDetails.refresh();
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

        {
          userDetails.value = UserDetails.fromJson(data);
          followersList.value = userDetails.value!.followers!;
          followingList.value = userDetails.value!.following!;
        }
      } else {
        print(
          "Step 9: Failed to fetch user details. Status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      print(
        "Step 10: Error occurred while fetching user details Are you Okay? Hope so: $e",
      );
    } finally {
      isLoading.value = false;
      print(
        "Step 11: isLoading set to false. getUserDetails method completed.",
      );
    }
  }

  String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // No error if empty (optional field)
    }
    RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );
    if (!emailRegex.hasMatch(value)) {
      return "email_invalid_error".tr;
    }
    return null; // Valid email
  }

  String? nameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // No error if empty (optional field)
    }
    if (value.trim().length < 3) {
      return "Name must be at least 3 characters long";
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value)) {
      return "Only alphabets and spaces are allowed";
    }
    return null; // Valid name
  }

  String? phoneValidator(String? value) {
    // Check if the value is null or empty
    if (value == null || value.isEmpty) {
      return 'phone_required_error'.tr;
    }

    // Define the regex:
    // - Optional leading '+' followed by digits only
    // - Total digits between 7 and 14
    final phoneRegex = RegExp(r'^\+?[0-9]{7,14}$');

    // Check if the input matches the regex
    if (!phoneRegex.hasMatch(value)) {
      return 'phone_invalid_error'.tr;
    }

    return null; // Valid phone number
  }

  String? locationValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // No error if empty (optional field)
    }
    if (value.trim().length < 3) {
      return "Location must be at least 3 characters long";
    }
    return null; // Valid location
  }

  String? usernameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // No error if empty (optional field)
    }
    if (value.length < 3) {
      return "name_length_error".tr;
    }
    return null; // Valid username
  }

  String? dobValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // No error if empty (optional field)
    }
    return null; // Valid DOB (no format validation)
  }

  Future<void> updateUserProfile({
    String? name,
    String? dob,
    String? password,
    File? imageFile,
    String? businessType,
    String? contactPhone,
    String? contactEmail,
    String? website,
    String? location,
    String? latitude,
    String? longitude,
    required BuildContext context,
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
      request.headers['Accept-Language'] =
          language; // Add Accept-Language header

      // Add only non-null fields
      if (name != null && name.isNotEmpty) request.fields['name'] = name;
      if (dob != null && dob.isNotEmpty) request.fields['dob'] = dob;
      if (password != null && password.isNotEmpty)
        request.fields['password'] = password;
      if (businessType != null && businessType.isNotEmpty)
        request.fields['business_type'] = businessType;
      if (countryId != -1) request.fields['country'] = countryId.toString();
      if (cityId != -1) request.fields['city'] = cityId.toString();
      if (menuId != -1) request.fields['business_type'] = menuId.toString();
      if (contactPhone != null && contactPhone.isNotEmpty)
        request.fields['contact_phone'] = contactPhone;
      if (contactEmail != null && contactEmail.isNotEmpty)
        request.fields['contact_email'] = contactEmail;
      if (website != null && website.isNotEmpty)
        request.fields['website'] = website;
      if (location != null && location.isNotEmpty)
        request.fields['location'] = location;
      if (latitude != null && latitude.isNotEmpty)
        request.fields['latitude'] = latitude;
      if (longitude != null && longitude.isNotEmpty)
        request.fields['longitude'] = longitude;
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
        String successMessage =
            data['message'] ?? 'Profile updated successfully.';

        // Update Firestore with new name & image
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'name': updatedName,
            'image': updatedImage, // If null, Firestore keeps it null
          },
        );
        getUserDetails();
        Get.back();
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(successMessage),
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
                  .map(
                    (e) =>
                        "${e.key.replaceAll('_', ' ').capitalizeFirst}: ${e.value.join(", ")}",
                  )
                  .join("\n");
              errorMessage += "\n$detailedErrors";
            }
          }
        }

        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        print("Profile update failed: $responseData");
      }
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10, // Status bar ke niche
            left: 10,
            right: 10,
          ),
          duration: Duration(seconds: 2), // Duration optional hai
        ),
      );
    } finally {
      isProfileUpdating.value = false; // Stop updating
    }
  }

  Future<void> updateCoverImage({
    required File coverImage,
    required BuildContext context,
  }) async {
    try {
      // Assuming isProfileUpdating is a RxBool defined elsewhere
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
      request.headers['Accept-Language'] =
          language; // Add Accept-Language header

      // Add cover image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'cover_image',
          coverImage.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = jsonDecode(responseData);
        print("API Response: $data"); // Debugging log

        String userId = data['user']['id'];
        String? updatedCoverImage = data['user']['cover_image']; // Can be null
        String successMessage =
            data['message'] ?? 'Profile updated successfully.';
        // Update Firestore with new cover image
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {
            'cover_image': updatedCoverImage,
            // If null, Firestore keeps it null
          },
        );

        // Assuming getUserDetails is defined elsewhere to refresh user data
        getUserDetails();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        var errorData = jsonDecode(responseData);
        String errorMessage =
            "Cover image update failed"; // Default error message

        if (errorData is Map<String, dynamic>) {
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
          if (errorData.containsKey('errors')) {
            var errors = errorData['errors'] as Map<String, dynamic>;
            if (errors.isNotEmpty) {
              String detailedErrors = errors.entries
                  .map(
                    (e) =>
                        "${e.key.replaceAll('_', ' ').capitalizeFirst}: ${e.value.join(", ")}",
                  )
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

        print("Cover image update failed: $responseData");
      }
    } catch (e) {
      print("Error updating cover image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10, // Below status bar
            left: 10,
            right: 10,
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      isProfileUpdating.value = false; // Stop updating
    }
  }

  @override
  void onInit() {
    super.onInit();
    // getUserDetails();
    getVideoUploadSettings();
  }
}
