import 'dart:convert';
import 'dart:developer';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/core/i18n/api_message_localizer.dart';
import 'package:cookster/core/location/app_location_defaults.dart';
import 'package:cookster/core/user/public_user_identity.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/core/video/feed_disk_warm_service.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:cookster/services/notificationServices.dart';
import 'package:cookster/services/username_availability_service.dart';
import '../../../landing/landingView/landingView.dart';
import '../../../promoteVideo/promoteVideoModel/promoteVideoModel.dart';
import '../registrationSettingsModel/packagesModel.dart';
import '../registrationSettingsModel/registrationModel.dart';

class SignUpController extends GetxController {
  // TEMP: bypass subscription packages/payment flow until URWAY issue is fixed.
  static const bool bypassPackagesFlowTemporarily = true;

  var isLoading = false.obs;
  var registrationSettings = RegistrationSettings().obs;
  var packagesList = PackagesList().obs;
  final TextEditingController locationController = TextEditingController();
  // final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  var siteSettings = Rxn<SiteSettings>();

  var isPasswordVisible = true.obs;
  var isObscure = true.obs;
  var isSettingsLoading = false.obs;

  var selectedProfile = "".obs;
  var isProfileCreating = false.obs;
  final formKey = GlobalKey<FormState>();

  var selectedPackageId = ''.obs;

  void selectPackage(String packageId) {
    selectedPackageId.value = packageId;
  }

  var selectedProfileId = 1.obs;
  /// True when arriving from Google/Apple — hide password and treat email as social.
  final RxBool isSocialSignUp = false.obs;
  var isSubscriptionRequired = 0.obs;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();
  final TextEditingController contactEmailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  var businessType = "".obs;
  final RxBool isPaymentLoading = false.obs;
  var accountType = "".obs;
  var selectCountryId = "".obs;
  var selectedCityId = "".obs;
  RxDouble latitude = 0.0.obs;
  RxDouble longitude = 0.0.obs;

  var emailError = ''.obs;
  var accountTypeError = "".obs;

  var phoneError = ''.obs;
  var nameError = ''.obs;
  var usernameError = ''.obs;
  var isCheckingUsername = false.obs;
  var isUsernameAvailable = RxnBool();
  var isUsernameCheckFailed = false.obs;
  var passwordError = ''.obs;
  var dobError = ''.obs;
  var businessTypeError = ''.obs;
  var contactPhoneError = ''.obs;
  var contactEmailError = ''.obs;
  var websiteError = ''.obs;
  var locationError = ''.obs;
  var countryError = ''.obs;
  var cityError = ''.obs;

  void resetErrors() {
    emailError.value = '';
    phoneError.value = '';
    nameError.value = '';
    usernameError.value = '';
    isUsernameAvailable.value = null;
    isUsernameCheckFailed.value = false;
    passwordError.value = '';
    dobError.value = '';
    contactPhoneError.value = '';
    contactEmailError.value = '';
    websiteError.value = '';
    locationError.value = '';
    countryError.value = '';
    cityError.value = '';
  }

  // Future<void> signUpWithGoogle() async {
  //   isLoading.value = true;
  //   try {
  //     await _googleSignIn.signOut();
  //     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  //     if (googleUser == null) {
  //       isLoading.value = false;
  //       return;
  //     }
  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;
  //     final credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );
  //     final UserCredential userCredential = await FirebaseAuth.instance
  //         .signInWithCredential(credential);
  //     final String email = userCredential.user?.email ?? '';
  //     emailController.text = email;
  //     final String name = userCredential.user?.displayName ?? '';
  //     nameController.text = name;
  //   } catch (error) {
  //     print('Google sign-in error: $error');
  //     ScaffoldMessenger.of(
  //       Get.context!,
  //     ).showSnackBar(SnackBar(content: Text("google_signin_failed".tr)));
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

  String? locationValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "location_empty_error".tr;
    }
    return null;
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

  String? validateDOB(String? value) {
    // Allow empty or null values
    if (value == null || value.isEmpty) {
      return null;
    }

    // Validate format
    final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dobRegex.hasMatch(value)) {
      return 'dob_format_error'.tr;
    }

    // Validate date and age
    try {
      DateTime dob = DateTime.parse(value);
      DateTime today = DateTime.now();
      DateTime minAgeDate = today.subtract(Duration(days: 365 * 18));

      if (dob.isAfter(today)) {
        return 'dob_future_error'.tr;
      } else if (dob.isAfter(minAgeDate)) {
        return 'dob_age_error'.tr;
      }
    } catch (e) {
      return 'Invalid date';
    }

    return null;
  }

  Entities? get selectedEntity {
    final entities = registrationSettings.value.entities;
    if (entities == null) return null;
    for (final entity in entities) {
      if (entity.id == selectedProfileId.value) return entity;
    }
    return null;
  }

  static bool _isTruthySponsored(dynamic value) {
    return value == 1 || value == true || value == '1';
  }

  bool get isPersonalAccount => selectedProfileId.value == 1;

  bool get isSponsoredAccount {
    final entity = selectedEntity;
    if (entity != null && _isTruthySponsored(entity.isSponsored)) {
      return true;
    }
    // Legacy fallback when API omits is_sponsored.
    return selectedProfileId.value == 3;
  }

  bool get isBusinessAccount {
    if (isPersonalAccount || isSponsoredAccount) return false;
    return selectedProfileId.value == 2 ||
        (selectedEntity?.name ?? '').trim().toLowerCase() == 'business';
  }

  bool get isProfessionalAccount => !isPersonalAccount;

  void setProfile(String type, int id) {
    selectedProfile.value = type;
    selectedProfileId.value = id;
    accountTypeError.value = '';
    if (isBusinessAccount) {
      accountType.value = id.toString();
    } else if (isSponsoredAccount) {
      accountType.value = '';
    } else {
      accountType.value = '';
    }
    print('Updated selectedProfileId: ${selectedProfileId.value}');
    print('Updated selectedProfile: ${selectedProfile.value}');
  }

  void togglePasswordVisibility() {
    isObscure.value = !isObscure.value;
  }

  bool validateBusinessTypeFields() {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      return false;
    }
    if (isPersonalAccount) {
      if (dobController.text.trim().isEmpty) {
        return false;
      }
    } else if (isBusinessAccount) {
      if (phoneController.text.trim().isEmpty ||
          businessType.value.trim().isEmpty ||
          contactPhoneController.text.trim().isEmpty ||
          contactEmailController.text.trim().isEmpty ||
          locationController.text.trim().isEmpty) {
        return false;
      }
    } else if (isSponsoredAccount) {
      if (phoneController.text.trim().isEmpty ||
          accountType.value.trim().isEmpty ||
          contactPhoneController.text.trim().isEmpty ||
          contactEmailController.text.trim().isEmpty) {
        return false;
      }
    } else {
      Get.snackbar("upload_error_title".tr, "business_type_missing_error".tr);
      return false;
    }
    return true;
  }

  String? validateCountry() {
    if (selectCountryId.value.isEmpty) {
      countryError.value = 'country_required_error'.tr;
      return countryError.value;
    }
    countryError.value = '';
    return null;
  }

  String? validateCity() {
    if (selectedCityId.value.isEmpty) {
      cityError.value = 'city_required_error'.tr;
      return cityError.value;
    }
    cityError.value = '';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'email_required_error'.tr;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'email_invalid_error'.tr;
    }
    return null;
  }

  String? validateContactEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'contact_email_required_error'.tr;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'email_invalid_error'.tr;
    }
    return null;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'password_required_error'.tr;
    }
    return null;
  }

  String? validateUsername(String? value) {
    return PublicUserIdentity.validateUsernameFormat(value);
  }

  Future<void> checkUsernameAvailability() async {
    final normalized =
        PublicUserIdentity.normalizeUsername(usernameController.text);
    final formatError = validateUsername(normalized);
    if (formatError != null) {
      isUsernameAvailable.value = null;
      isUsernameCheckFailed.value = false;
      return;
    }

    isCheckingUsername.value = true;
    isUsernameCheckFailed.value = false;
    try {
      final result = await UsernameAvailabilityService.check(normalized);
      isUsernameCheckFailed.value = result.isCheckFailed;
      isUsernameAvailable.value =
          result.checked ? result.available : null;
    } finally {
      isCheckingUsername.value = false;
    }
  }

  String? validateName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'name_required_error'.tr;
    }
    if (normalized.length < 3) {
      return 'name_length_error'.tr;
    }
    // Allow Arabic + English letters, numbers and spaces.
    if (!RegExp(r'^[A-Za-z\u0600-\u06FF0-9\s]+$').hasMatch(normalized)) {
      return 'name_format_error'.tr;
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

  String? validateContactPhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'contact_phone_required_error'.tr;
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{7,14}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'phone_invalid_error'.tr;
    }
    return null;
  }

  Future<bool> validateRegister() async {
    print('Step 1: Starting validateRegister');
    isLoading.value = true;
    print('Step 2: Set isLoading to true');
    resetErrors();
    print('Step 3: Reset all error fields');

    // Local validations
    bool isValid = true;
    print('Step 4: Initialized isValid as $isValid');

    if (!formKey.currentState!.validate()) {
      isValid = false;
      print('Step 5: Form validation failed, isValid set to $isValid');
    }

    if (isProfessionalAccount && !validateBusinessTypeFields()) {
      isValid = false;
      print(
        'Step 6: Profile-specific validation failed for profile ID ${selectedProfileId.value}, isValid set to $isValid',
      );
    }

    if (validateCountry() != null) {
      isValid = false;
      print('Step 7: Country validation failed, isValid set to $isValid');
    }

    if (validateCity() != null) {
      isValid = false;
      print('Step 8: City validation failed, isValid set to $isValid');
    }

    if (validateName(nameController.text) != null) {
      // nameError.value = validateName(nameController.text)!;
      isValid = false;
      print(
        'Step 9: Name validation failed for "${nameController.text}", isValid set to $isValid',
      );
    }

    if (validateUsername(usernameController.text) != null) {
      usernameError.value = validateUsername(usernameController.text)!;
      isValid = false;
    } else if (isUsernameCheckFailed.value) {
      usernameError.value = 'username_check_failed_error'.tr;
      isValid = false;
    } else if (isUsernameAvailable.value != true) {
      if (isUsernameAvailable.value == null) {
        await checkUsernameAvailability();
      }
      if (isUsernameCheckFailed.value) {
        usernameError.value = 'username_check_failed_error'.tr;
        isValid = false;
      } else if (isUsernameAvailable.value != true) {
        usernameError.value = 'username_unavailable_error'.tr;
        isValid = false;
      }
    }

    if (validateEmail(emailController.text) != null) {
      isValid = false;
      print(
        'Step 10: Email validation failed for "${emailController.text}", isValid set to $isValid',
      );
    }

    if (!isSocialSignUp.value &&
        validatePassword(passwordController.text) != null) {
      passwordError.value = validatePassword(passwordController.text)!;
      isValid = false;
      print('Step 11: Password validation failed, isValid set to $isValid');
    }

    if (isPersonalAccount &&
        validateDOB(dobController.text) != null) {
      dobError.value = validateDOB(dobController.text)!;
      isValid = false;
      print(
        'Step 12: DOB validation failed for profile ID 1, isValid set to $isValid',
      );
    }

    if (isProfessionalAccount &&
        validatePhoneNumber(phoneController.text) != null) {
      // phoneError.value = validatePhoneNumber(phoneController.text)!;
      isValid = false;
      print(
        'Step 13: Phone validation failed for profile ID 2, isValid set to $isValid',
      );
    }

    if (isProfessionalAccount &&
        validateContactPhoneNumber(contactPhoneController.text) != null) {
      // contactPhoneError.value = validatePhoneNumber(contactPhoneController.text)!;
      isValid = false;
      print(
        'Step 14: Contact phone validation failed for non-profile ID 1, isValid set to $isValid',
      );
    }

    if (isProfessionalAccount &&
        validateContactEmail(contactEmailController.text) != null) {
      // contactEmailError.value = validateEmail(contactEmailController.text)!;
      isValid = false;
      print(
        'Step 15: Contact email validation failed for non-profile ID 1, isValid set to $isValid',
      );
    }

    if (isBusinessAccount &&
        validateWebsite(websiteController.text) != null) {
      // websiteError.value = validateWebsite(websiteController.text)!;
      isValid = false;
      print(
        'Step 16: Website validation failed for profile ID 2, isValid set to $isValid',
      );
    }

    if (isBusinessAccount &&
        locationValidator(locationController.text) != null) {
      // locationError.value = locationValidator(locationController.text)!;
      isValid = false;
      print(
        'Step 17: Location validation failed for profile ID 2, isValid set to $isValid',
      );
    }

    print('Step 18: Completed local validations, isValid: $isValid');

    if (!isValid) {
      isLoading.value = false;
      print(
        'Step 19: Local validation failed, isLoading set to false, returning false',
      );
      return false;
    }

    print('Step 20: All local validations passed, preparing API request');

    // API validation
    Map<String, dynamic> requestBody = {
      "email": emailController.text,
      "entity": selectedProfileId.value,
      if (selectedProfileId.value != 1) "phone": phoneController.text,
      "name": nameController.text,
      "user_name": PublicUserIdentity.normalizeUsername(usernameController.text),
      "password": passwordController.text,
      "dob": dobController.text,
      "country": selectCountryId.value,
      "city": selectedCityId.value,
      if (isBusinessAccount) "business_type": businessType.value,
      if (isProfessionalAccount) "contact_phone": contactPhoneController.text,
      if (isProfessionalAccount) "contact_email": contactEmailController.text,
      if (isBusinessAccount) "website": websiteController.text,
      if (isBusinessAccount) "location": locationController.text,
      if (isBusinessAccount) "latitude": latitude.value,
      if (isBusinessAccount) "longitude": longitude.value,
      'uuid': await resolveFcmDeviceToken(),
      if (isProfessionalAccount)
        'type_of_account':
            accountType.value.isNotEmpty
                ? accountType.value
                : selectedProfileId.value.toString(),
    };

    print('Step 21: Prepared request body: $requestBody');

    try {
      print('Step 22: Sending API request to ${EndPoints.validateRegister}');
      final response = await ApiClient.postRequest(
        EndPoints.validateRegister,
        requestBody,
      );

      print(
        'Step 23: Received API response, status code: ${response.statusCode}',
      );
      print('Step 24: Response body: ${response.body}');

      final data = jsonDecode(response.body);
      print('Step 25: Parsed response data: $data');

      if (response.statusCode == 200 && data['status'] == true) {
        print('Step 26: API validation successful, returning true');
        return true;
      } else {
        print('Step 27: API validation failed');
        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];
          print('Step 28: Processing API errors: $errors');
          errors.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              String errorMsg = value[0];
              print('Step 29: Error for $key: $errorMsg');
              switch (key) {
                case 'email':
                  emailError.value = errorMsg;
                  break;
                case 'phone':
                  phoneError.value = errorMsg;
                  break;
                case 'name':
                  nameError.value = errorMsg;
                  break;
                case 'user_name':
                  usernameError.value = errorMsg;
                  break;
                case 'password':
                  passwordError.value = errorMsg;
                  break;
                case 'dob':
                  dobError.value = errorMsg;
                  break;
                case 'contact_phone':
                  contactPhoneError.value = errorMsg;
                  break;
                case 'contact_email':
                  contactEmailError.value = errorMsg;
                  break;
                case 'website':
                  websiteError.value = errorMsg;
                  break;
                case 'location':
                  locationError.value = errorMsg;
                  break;
                case 'country':
                  countryError.value = errorMsg;
                  break;
                case 'city':
                  cityError.value = errorMsg;
                  break;
                case 'type_of_account':
                  accountTypeError.value = errorMsg;
                  break;
              }
            }
          });
        } else {
          print(
            'Step 30: No specific errors, showing general error message: ${data['message']}',
          );
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Validation failed'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        print('Step 31: API validation failed, returning false');
        return false;
      }
    } catch (e) {
      print('Step 32: Error during API request: $e');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("Something went wrong: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      print('Step 33: Returning false due to error');
      return false;
    } finally {
      isLoading.value = false;
      print('Step 34: Set isLoading to false in finally block');
    }
  }

  // Future<void> subscribeUserToTopics(String entity) async {
  //   FirebaseMessaging messaging = FirebaseMessaging.instance;
  //
  //   try {
  //     // Fixed topic
  //     await messaging.subscribeToTopic("cookster");
  //     print("✅ Subscribed to cookster");
  //
  //     // Dynamic topic based on entity
  //     String topicName = "type_$entity";
  //     await messaging.subscribeToTopic(topicName);
  //     print("✅ Subscribed to $topicName");
  //   } catch (e) {
  //     print("❌ Error subscribing to topics: $e");
  //   }
  // }

  Future<void> submitForm({
    String? packageId,
    Map<String, dynamic>? paymentParams,
  }) async {
    isProfileCreating.value = true;

    String? deviceToken = await resolveFcmDeviceToken();

    Map<String, dynamic> requestBody = {
      "entity": selectedProfileId.value,
      "name": nameController.text,
      "user_name": PublicUserIdentity.normalizeUsername(usernameController.text),
      "email": emailController.text,
      if (selectedProfileId.value != 1) "phone": phoneController.text,
      "password": passwordController.text,
      "dob": dobController.text,
      "country": selectCountryId.value,
      "city": selectedCityId.value,
      if (isBusinessAccount) "business_type": businessType.value,
      if (isProfessionalAccount) "contact_phone": contactPhoneController.text,
      if (isProfessionalAccount) "contact_email": contactEmailController.text,
      if (isBusinessAccount) "website": websiteController.text,
      if (isBusinessAccount) "location": locationController.text,
      if (isBusinessAccount) "latitude": latitude.value,
      if (isBusinessAccount) "longitude": longitude.value,
      "uuid": deviceToken,
      if (isBusinessAccount)
        if (packageId != null) "package_id": packageId,

      // Add payment parameters for business accounts
      if (isBusinessAccount && paymentParams != null) ...{
        "PaymentId": paymentParams["PaymentId"]?.toString() ?? "",
        "TranId": paymentParams["TranId"]?.toString() ?? "",
        "ECI": paymentParams["ECI"]?.toString() ?? "",
        "TrackId": paymentParams["TrackId"]?.toString() ?? "",
        "RRN": paymentParams["RRN"]?.toString() ?? "",
        "cardBrand": paymentParams["cardBrand"]?.toString() ?? "",
        "amount": paymentParams["amount"]?.toString() ?? "",
        "maskedPAN": paymentParams["maskedPAN"]?.toString() ?? "",
        "PaymentType": paymentParams["PaymentType"]?.toString() ?? "",
      },

      if (isProfessionalAccount)
        "type_of_account":
            accountType.value.isNotEmpty
                ? accountType.value
                : selectedProfileId.value.toString(),
    };

    print(requestBody);

    try {
      final response = await ApiClient.postRequest(
        EndPoints.register,
        requestBody,
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      print(response.statusCode);
      log(response.body);

      final user = data['user'];
      final registerSucceeded = data['status'] == true &&
          user is Map<String, dynamic> &&
          (response.statusCode == 200 || response.statusCode == 201);

      if (registerSucceeded) {
        final otpSent = data['otp_sent'] == true;
        final otpDelivery = data['otp_delivery']?.toString() ?? '';
        final resumed = data['resumed'] == true;

        Get.toNamed(
          AppRoutes.signUpOtp,
          arguments: {
            'user': user,
            'email': emailController.text.trim(),
            'deviceToken': deviceToken,
            'otpSent': otpSent,
            'otpDelivery': otpDelivery,
            'resumed': resumed,
          },
        );
      } else if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];
          errors.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              String errorMsg = value[0];
              switch (key) {
                case 'email':
                  emailError.value = errorMsg;
                  break;
                case 'phone':
                  phoneError.value = errorMsg;
                  break;
                case 'name':
                  nameError.value = errorMsg;
                  break;
                case 'user_name':
                  usernameError.value = errorMsg;
                  break;
                case 'password':
                  passwordError.value = errorMsg;
                  break;
                case 'dob':
                  dobError.value = errorMsg;
                  break;
                case 'contact_phone':
                  contactPhoneError.value = errorMsg;
                  break;
                case 'contact_email':
                  contactEmailError.value = errorMsg;
                  break;
                case 'website':
                  websiteError.value = errorMsg;
                  break;
                case 'location':
                  locationError.value = errorMsg;
                  break;
                case 'country':
                  countryError.value = errorMsg;
                  break;
                case 'city':
                  cityError.value = errorMsg;
                  break;
                case 'type_of_account':
                  accountTypeError.value = errorMsg;
                  break;
              }
            }
          });
        } else {
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(
              content: Text(
                ApiMessageLocalizer.localize(
                  data['message'],
                  fallbackLocaleKey: 'form_unknown_error',
                ),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    } catch (e) {
      print("Error submitting form: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("Something went wrong: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isProfileCreating.value = false;
    }
  }

  Future<void> handleFormSubmission() async {
    bool isValid = await validateRegister();

    print("Are you looking here and there ");

    print(isSubscriptionRequired);

    print(selectedProfileId.value);
    if (!isValid) {
      return;
    }
    if (bypassPackagesFlowTemporarily) {
      await submitForm();
      return;
    }
    await submitForm();
  }

  void clearForm() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    dobController.clear();
    contactPhoneController.clear();
    contactEmailController.clear();
    websiteController.clear();
    locationController.clear();
    selectedProfile.value = "Personal";
    selectedProfileId.value = 1;
    isSocialSignUp.value = false;
    isSubscriptionRequired.value = 0;
    businessType.value = "";
    selectCountryId.value = "";
    selectedCityId.value = "";
    latitude.value = 0.0;
    longitude.value = 0.0;
    isProfileCreating.value = false;
    selectedPackageId.value = '';
  }

  Future<void> signInWithFacebook() async {
    isLoading.value = true;
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();
      FacebookAuth.instance.logOut();
      if (loginResult.status != LoginStatus.success) {
        isLoading.value = false;
        return;
      }
      final AccessToken? accessToken = loginResult.accessToken;
      if (accessToken == null) {
        isLoading.value = false;
        return;
      }
      final OAuthCredential credential = FacebookAuthProvider.credential(
        accessToken.tokenString,
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final String email = userCredential.user?.email ?? '';
      final String name = userCredential.user?.displayName ?? '';
      emailController.text = email;
      nameController.text = name;
    } catch (error) {
      print('Facebook sign-in error: $error');
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(SnackBar(content: Text("google_signin_failed".tr)));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchRegistrationSettings() async {
    try {
      isSettingsLoading(true);
      var response = await ApiClient.getRequest(EndPoints.registrationSettings);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        registrationSettings.value = RegistrationSettings.fromJson(data);
        // Keep the user's current selection (default Personal). Never force
        // Business on load — that broke Apple/Google signup form layout.
        final entities = registrationSettings.value.entities ?? <Entities>[];
        for (final entity in entities) {
          if (entity.id == selectedProfileId.value) {
            selectedProfile.value = entity.name ?? selectedProfile.value;
            isSubscriptionRequired.value =
                entity.isSubscriptionRequired ?? isSubscriptionRequired.value;
            break;
          }
        }
        await _applyDefaultCountryAndCityIfNeeded();
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text("Failed to load registration settings"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("PRINTING THE ERROR");
      print(e);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("fetch_site_settings_error".tr),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isSettingsLoading(false);
    }
  }

  Future<void> _applyDefaultCountryAndCityIfNeeded() async {
    if (selectCountryId.value.isNotEmpty && selectedCityId.value.isNotEmpty) {
      return;
    }

    final countries = registrationSettings.value.countries;
    if (countries == null || countries.isEmpty) {
      return;
    }

    Countries? saudi;
    for (final country in countries) {
      if (AppLocationDefaults.isSaudiCountryName(country.name)) {
        saudi = country;
        break;
      }
    }
    if (saudi?.id == null) {
      return;
    }

    if (selectCountryId.value.isEmpty) {
      selectCountryId.value = saudi!.id.toString();
    }

    if (selectedCityId.value.isNotEmpty) {
      return;
    }

    final cityController = Get.isRegistered<CityController>()
        ? Get.find<CityController>()
        : Get.put(CityController());
    await cityController.fetchCities(saudi!.id!);
    for (final city in cityController.cityList) {
      if (AppLocationDefaults.matchesRiyadhCityName(city.name)) {
        selectedCityId.value = city.id?.toString() ?? '';
        cityController.selectCity(city);
        break;
      }
    }
  }

  Future<void> fetchPackagesList() async {
    try {
      isSettingsLoading(true);
      var response = await ApiClient.getRequest(EndPoints.packagesList);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        packagesList.value = PackagesList.fromJson(data);
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text("Failed to load packages list"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("PRINTING THE ERROR");
      print(e);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isSettingsLoading(false);
    }
  }

  Future<void> fetchSiteSettings() async {
    try {
      final response = await ApiClient.getRequest('${EndPoints.siteSettings}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        siteSettings.value = SiteSettings.fromJson(jsonData);
        print(
          "Site Settings Fetched: ${siteSettings.value?.settings?.toJson()}",
        );
      } else {
        print("Failed to fetch site settings: ${response.statusCode}");
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text("fetch_site_settings_error".tr),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error fetching site settings: $e");
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text("fetch_site_settings_error_message".tr),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchRegistrationSettings();
    fetchPackagesList();
    fetchSiteSettings();
  }
}

void showSuccessDialog() {
  AwesomeDialog(
    context: Get.context!,
    dialogType: DialogType.success,
    animType: AnimType.scale,
    title: "success_title".tr,
    desc: "account created successfully".tr,
    btnOkText: "ok".tr,
    btnOkOnPress: () {
      FeedDiskWarmService.instance.warmEarlyFeed(reason: 'signup_success_dialog');
      Get.offAll(
        () => Landing(initialIndex: 0),
        binding: LandingBinding(),
      );
    },
  )..show();
}
