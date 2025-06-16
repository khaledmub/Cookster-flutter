import 'dart:io';
import 'package:flutter/material.dart' as dir;

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as rtl;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../appUtils/apiEndPoints.dart';
import '../../../../../../appUtils/colorUtils.dart';
import '../../../../../../loaders/pulseLoader.dart';
import '../../../../../../services/apiClient.dart';
import '../../../../../auth/signUp/signUpController/cityController.dart';
import '../../../../../promoteVideo/promoteVideoController/promoteVideoController.dart';
import '../../profileControlller/profileController.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final ProfileController profileController = Get.find();
  final PromoteVideoController controller = Get.find();

  final _formKey = GlobalKey<FormState>();

  late String initialName;
  late String initialEmail;
  late String initialDob;
  late String initialPhone;
  late String initialPassword;
  late int initialCountry;
  late int initialCity;
  int initialAccountType = -1; // Default value instead of 'late'
  late dynamic googleSignInBit = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      // Set google_sign_in to 0 in SharedPreferences
      googleSignInBit = prefs.getInt('google_sign_in') ?? 0;
      // Optionally update googleSignInBit
    });
    var userDetails = profileController.simpleUserDetails.value?.user;
    var additionalData =
        profileController.simpleUserDetails.value?.additionalData;
    if (userDetails != null) {
      initialName = userDetails.name ?? '';
      initialEmail = userDetails.email ?? '';
      initialDob = userDetails.dob ?? '';
      initialPhone = userDetails.phone ?? '';

      if (additionalData != null && additionalData.typeOfAccount != null) {
        initialAccountType = additionalData.typeOfAccount;
        profileController.selectedAccountType.value =
            initialAccountType.toString();
      } else {
        // Optionally reset selectedAccountType if no valid type exists
        profileController.selectedAccountType.value = '-1';
      }

      initialCity = userDetails.city; // Use string '-1' or another valid string

      initialCountry =
          userDetails.country; // Use string '-1' or another valid string

      profileController.nameController.text = initialName;
      profileController.emailController.text = initialEmail;
      profileController.birthdayController.text = initialDob;
      profileController.phoneNumberController.text = initialPhone;
      profileController.countryId = initialCountry;
      profileController.cityId = initialCity;
      profileController.selectedCityId.value = initialCity.toString();
      profileController.selectCountryId.value = initialCountry.toString();

      cityController.fetchCities(
        int.parse('${profileController.selectCountryId.value}'),
      );
    } else {
      // Handle null userDetails case with defaults
      initialName = '';
      initialEmail = '';
      initialDob = '';
      initialPhone = '';
      initialCountry = -1;
      initialCity = -1;
      initialAccountType = -1;
      profileController.selectedAccountType.value = '-1';
      profileController.selectedCityId.value = '-1';
      profileController.selectCountryId.value = '-1';
    }
  }

  bool hasChanges() {
    return profileController.nameController.text != initialName ||
        profileController.emailController.text != initialEmail ||
        profileController.birthdayController.text != initialDob ||
        profileController.phoneNumberController.text != initialPhone ||
        profileController.passwordController.text.isNotEmpty ||
        profileController.selectedCityId.value != initialCity.toString() ||
        profileController.selectedAccountType.value !=
            initialAccountType.toString() ||
        profileController.selectCountryId.value != initialCountry.toString() ||
        profileController.selectedImage.value !=
            null; // Check if a new image is selected
  }

  void saveChanges() {
    if (!hasChanges()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("does_not_change_anything".tr)));
      return;
    }

    if (_formKey.currentState!.validate()) {
      profileController
          .updateUserProfile(
            phoneNumber:
                profileController.phoneNumberController.text.trim().isNotEmpty
                    ? profileController.phoneNumberController.text.trim()
                    : null,

            name:
                profileController.nameController.text.trim().isNotEmpty
                    ? profileController.nameController.text.trim()
                    : null,
            dob:
                profileController.birthdayController.text.trim().isNotEmpty
                    ? profileController.birthdayController.text.trim()
                    : null,
            password:
                profileController.passwordController.text.trim().isNotEmpty
                    ? profileController.passwordController.text.trim()
                    : null,
            // Password only sent if not empty
            imageFile: profileController.selectedImage.value,
            context: context,
          )
          .then((_) {
            profileController.selectedImage.value =
                null; // Image reset after update
          });
    }
  }

  final CityController cityController = Get.put(CityController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,

        centerTitle: true,
        title: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Profile".tr,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Align(
              alignment:
                  Directionality.of(context) == rtl.TextDirection.rtl
                      ? Alignment.topRight
                      : Alignment.topLeft,
              child: InkWell(
                onTap: () {
                  Get.back();
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: ColorUtils.grey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: ColorUtils.darkBrown,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Obx(() {
            var userDetails = profileController.simpleUserDetails.value?.user;
            var countries =
                profileController
                    .simpleUserDetails
                    .value
                    ?.formSettings
                    ?.countries;

            var accountTypes =
                profileController.simpleUserDetails.value != null &&
                        profileController
                                .simpleUserDetails
                                .value!
                                .formSettings !=
                            null &&
                        profileController
                                .simpleUserDetails
                                .value!
                                .formSettings!
                                .typeOfAccount !=
                            null
                    ? profileController
                        .simpleUserDetails
                        .value!
                        .formSettings!
                        .typeOfAccount!
                        .values
                    : [];

            print('userDetails: $userDetails, countries: $countries');
            var cities = cityController.cityList;
            if (userDetails == null)
              return Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: PulseLogoLoader(
                        logoPath: "assets/images/appIcon.png",
                        size: 80,
                      ),
                    ),
                  ],
                ),
              ); // Handle null safety
            Map<String, int> allCountries = {};
            List<String> countryName =
                countries?.map<String>((country) {
                  allCountries[country.name!] = country.id!;
                  return country.name!;
                }).toList() ??
                [];

            String? selectedCountryName =
                allCountries.entries
                    .firstWhere(
                      (entry) => entry.value == userDetails.country,
                      orElse: () => const MapEntry('', 0),
                    )
                    .key;
            if (!countryName.contains(selectedCountryName) ||
                selectedCountryName.isEmpty) {
              selectedCountryName = null;
            }

            // Populate account types
            Map<String, int> allTypeOfAccount = {};
            List<String> typeOfAccountName =
                accountTypes != null
                    ? accountTypes.map<String>((accountType) {
                      if (accountType.name != null && accountType.id != null) {
                        allTypeOfAccount[accountType.name!] = accountType.id!;
                      }
                      return accountType.name ?? '';
                    }).toList()
                    : [];

            print(
              'allTypeOfAccount: $allTypeOfAccount, typeOfAccountName: $typeOfAccountName',
            );

            String? selectedTypeOfAccountName =
                allTypeOfAccount.entries
                    .firstWhere(
                      (entry) {
                        print(
                          'Checking entry: ${entry.key}, value: ${entry.value}',
                        );
                        print(
                          'Comparing with typeOfAccount: ${profileController.simpleUserDetails.value!.additionalData!.typeOfAccount}',
                        );
                        return entry.value ==
                            profileController
                                .simpleUserDetails
                                .value!
                                .additionalData!
                                .typeOfAccount;
                      },
                      orElse: () {
                        print(
                          'No matching entry found, returning default MapEntry',
                        );
                        return const MapEntry('', 0);
                      },
                    )
                    .key;
            print('Selected account name: $selectedTypeOfAccountName');
            if (!typeOfAccountName.contains(selectedTypeOfAccountName) ||
                selectedTypeOfAccountName.isEmpty) {
              selectedTypeOfAccountName = null;
            }

            Map<String, int> allCities = {};
            List<String> cityName =
                cities.map<String>((city) {
                  allCities[city.name!] = city.id!;
                  return city.name!;
                }).toList();

            String? selectedCityName =
                allCities.entries
                    .firstWhere(
                      (entry) => entry.value == userDetails.city,
                      orElse: () => const MapEntry('', 0),
                    )
                    .key;
            if (!cityName.contains(selectedCityName) ||
                selectedCityName.isEmpty) {
              selectedCityName = null;
            }

            return Stack(
              children: [
                Column(
                  spacing: 16.h,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Obx(() {
                              return Container(
                                height: 80.h,
                                width: 80.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.primaryColor,
                                  ),
                                ),
                                child:
                                    profileController.selectedImage.value !=
                                            null
                                        ? ClipOval(
                                          child: Image.file(
                                            profileController
                                                .selectedImage
                                                .value!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : ClipOval(
                                          // Ensure all images are clipped properly
                                          child:
                                              userDetails.image == null
                                                  ? Image.asset(
                                                    "assets/images/sd.png",
                                                    fit:
                                                        BoxFit
                                                            .cover, // Centering & scaling
                                                  )
                                                  : CachedNetworkImage(
                                                    imageUrl:
                                                        '${Common.profileImage}/${userDetails.image!}',
                                                    fit: BoxFit.cover,
                                                    // Makes sure it scales properly
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Icon(
                                                              Icons.error,
                                                              size: 40,
                                                              color: Colors.red,
                                                            ),
                                                  ),
                                        ),
                              );
                            }),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () async {
                                  File? pickedImage =
                                      await profileController.pickImage();
                                  if (pickedImage != null) {
                                    profileController.selectedImage.value =
                                        pickedImage;
                                  }
                                },
                                child: SvgPicture.asset(
                                  "assets/icons/addProfile.svg",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      "@${userDetails.name}",
                      style: TextStyle(
                        color: ColorUtils.darkBrown,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CustomTextField(
                        validator: profileController.nameValidator,
                        label: "Name",
                        hintText: "Enter Name",
                        iconPath: "assets/icons/editProfile.svg",
                        controller: profileController.nameController,
                      ),
                    ),
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomTextField(
                          label: "Email".tr,
                          hintText: "Enter Email",
                          iconPath: "assets/icons/email.svg",
                          controller: profileController.emailController,
                        ),
                      ),
                    ),

                    if (userDetails.phone != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomTextField(
                          validator: profileController.validatePhoneNumber,
                          label: "Phone Number".tr,
                          hintText: "Enter Phone Number".tr,
                          iconPath: "assets/icons/editProfile.svg",
                          controller: profileController.phoneNumberController,
                        ),
                      ),

                    if (googleSignInBit == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomTextField(
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            if (value.length < 8) {
                              return 'password_length_error'.tr;
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                              return 'password_uppercase_error'.tr;
                            }
                            if (!RegExp(
                              r'[!@#$%^&*(),.?":{}|<>]',
                            ).hasMatch(value)) {
                              return 'password_special_char_error'.tr;
                            }
                            return null;
                          },
                          label: "Enter New Password",
                          hintText: "Enter New Password",
                          iconPath: "assets/icons/password.svg",
                          controller: profileController.passwordController,
                        ),
                      ),

                    Obx(() {
                      // Check if registrationSettings and entities are valid

                      if (controller
                                  .entityDetails
                                  .value['subscription_required'] !=
                              1 &&
                          controller.entityDetails.value['is_sponsored'] != 1) {
                        // Explicit int comparison for boolean
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: CustomTextField(
                            validator: profileController.dobValidator,
                            label: "dob".tr,
                            hintText: "Enter Date of Birth",
                            iconPath: "assets/icons/calendar.svg",
                            controller: profileController.birthdayController,
                            readOnly: true,
                            // Prevent manual text entry
                            onTap: () async {
                              print(
                                "Current DOB: ${profileController.birthdayController.text}",
                              );

                              // Define the date range for the picker
                              final DateTime firstDate = DateTime(1900);
                              final DateTime lastDate = DateTime.now();

                              // Get the user's existing DOB from the controller
                              DateTime initialDate;
                              String currentDob =
                                  profileController.birthdayController.text;

                              if (currentDob.isNotEmpty) {
                                try {
                                  // Try parsing the DOB with 'yyyy-MM-dd' format
                                  initialDate = DateFormat(
                                    'yyyy-MM-dd',
                                  ).parseStrict(currentDob);
                                } catch (e) {
                                  try {
                                    // Fallback to 'dd-MM-yyyy' format
                                    initialDate = DateFormat(
                                      'dd-MM-yyyy',
                                    ).parseStrict(currentDob);
                                  } catch (e) {
                                    print("Error parsing DOB: $e");
                                    // Default to 18 years ago if parsing fails
                                    initialDate = DateTime.now().subtract(
                                      Duration(days: 18 * 365),
                                    );
                                  }
                                }

                                // Ensure the parsed date is within the valid range
                                if (initialDate.isBefore(firstDate)) {
                                  initialDate = firstDate;
                                } else if (initialDate.isAfter(lastDate)) {
                                  initialDate = lastDate;
                                }
                              } else {
                                // Default to 18 years ago if no DOB is set
                                initialDate = DateTime.now().subtract(
                                  Duration(days: 18 * 365),
                                );
                              }

                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: firstDate,
                                lastDate: lastDate,
                              );

                              if (pickedDate != null) {
                                // Format date to yyyy-MM-dd format
                                String formattedDate = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(pickedDate);
                                profileController.birthdayController.text =
                                    formattedDate;
                              }
                            },
                          ),
                        );
                      }
                      // Return an empty widget if the condition is false
                      return const SizedBox.shrink();
                    }),

                    InkWell(
                      onTap: () {
                        showProfileCountrySelectionDialog(
                          context,
                          allCountries,
                          countryName,
                          // selectedCountryName,
                          countryId: int.parse(
                            profileController.selectCountryId.value,
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: ColorUtils.greyTextFieldBorderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset("assets/icons/state.svg"),
                            SizedBox(width: 16),

                            Text(
                              profileController.selectCountryId.value.isEmpty
                                  ? "Select your country"
                                  : countryName.firstWhere(
                                    (name) =>
                                        allCountries[name].toString() ==
                                        profileController.selectCountryId.value,
                                    orElse: () => "Select your country",
                                  ),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showProfileCitySelectionDialog(
                          context,
                          allCities,
                          cityName,
                          selectedCityName,
                          cityId: int.parse(
                            profileController.selectedCityId.value,
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: ColorUtils.greyTextFieldBorderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset("assets/icons/state.svg"),
                            SizedBox(width: 16),

                            Text(
                              profileController.selectedCityId.value.isEmpty
                                  ? "Select your city"
                                  : cityName.firstWhere(
                                    (name) =>
                                        allCities[name].toString() ==
                                        profileController.selectedCityId.value,
                                    orElse: () => "Select your city",
                                  ),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),

                    if (typeOfAccountName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: DropdownFlutter<String>(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please select an account type";
                            }
                            return null;
                          },
                          closedHeaderPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: CustomDropdownDecoration(
                            prefixIcon: SvgPicture.asset(
                              "assets/icons/business.svg",
                            ),
                            closedBorderRadius: BorderRadius.circular(8),
                            expandedBorderRadius: BorderRadius.circular(8),
                            closedFillColor: Colors.grey.shade100,
                            closedBorder: Border.all(
                              color: ColorUtils.greyTextFieldBorderColor,
                              width: 0.8,
                            ),
                            closedSuffixIcon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                          ),
                          hintText: "Select Account Type",
                          items: typeOfAccountName,
                          initialItem: selectedTypeOfAccountName,
                          onChanged: (String? selectedValue) {
                            if (selectedValue != null) {
                              int? selectedId = allTypeOfAccount[selectedValue];
                              if (selectedId != null) {
                                profileController.selectedAccountType.value =
                                    selectedId.toString();
                                print(
                                  "Selected Account Type ID: $selectedId, Name: $selectedValue",
                                );
                              }
                            }
                          },
                        ),
                      ),

                    InkWell(
                      onTap: () {
                        Get.toNamed(AppRoutes.selectLanguage);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: ColorUtils.greyTextFieldBorderColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            SvgPicture.asset("assets/icons/earth.svg"),
                            SizedBox(width: 16.w),
                            Text("Change Language".tr),
                            Spacer(),
                            Directionality.of(context) == rtl.TextDirection.rtl
                                ? Icon(Icons.arrow_forward)
                                : Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.warning,
                          animType: AnimType.bottomSlide,
                          title: 'sure_to_delete_account'.tr,
                          desc: 'sure_to_delete_description'.tr,
                          btnCancelOnPress: () {
                            // Do nothing, dialog will close
                          },
                          btnOkOnPress: () async {
                            try {
                              // Call the delete_account API
                              final response =
                                  await ApiClient.postDeleteAccount({});

                              print(response.body);

                              if (response.statusCode == 200) {
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();

                                // Store the onboarding_completed, language, and selectedLanguage values before clearing
                                bool onboardingCompleted =
                                    prefs.getBool('onboarding_completed') ??
                                    false;
                                String language =
                                    prefs.getString('language') ??
                                    'en'; // Default to 'en' as per ApiClient
                                String selectedLanguage =
                                    prefs.getString('selectedLanguage') ??
                                    'English'; // Default to 'English' as per LanguageController
                                bool initLanguage =
                                    prefs.getBool('initLanguage') ?? false;

                                // Clear all preferences
                                await prefs.clear();

                                // Restore the onboarding_completed, language, and selectedLanguage values
                                await prefs.setBool(
                                  'onboarding_completed',
                                  onboardingCompleted,
                                );
                                await prefs.setString('language', language);
                                await prefs.setString(
                                  'selectedLanguage',
                                  selectedLanguage,
                                );
                                await prefs.setBool(
                                  'initLanguage',
                                  initLanguage,
                                );

                                // Clear in-memory user data
                                profileController.userDetails.value =
                                    null; // Assuming this is defined elsewhere
                                profileController.simpleUserDetails.value =
                                    null; // Assuming this is defined elsewhere
                                profileController.followersList
                                    .clear(); // Assuming this is defined elsewhere
                                profileController.followingList
                                    .clear(); // Assuming this is defined elsewhere

                                // Reinitialize ApiClient language
                                await ApiClient.initLanguage();
                                // Navigate to SignIn screen
                                Get.offAllNamed(
                                  AppRoutes.signIn,
                                ); // Replace with your sign-in route
                              } else {
                                // Show error in ScaffoldMessenger
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete account: ${response.statusCode}',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } catch (e) {
                              // Show error in ScaffoldMessenger
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting account: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          btnOkText: 'ok'.tr,
                          btnCancelText: 'cancel'.tr,
                        ).show();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.redAccent),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.white),
                            SizedBox(width: 16.w),
                            Text(
                              "Delete Account".tr,
                              // Updated text to reflect action
                              style: TextStyle(color: Colors.white),
                            ),
                            Spacer(),
                            Directionality.of(context) == dir.TextDirection.rtl
                                ? Icon(Icons.arrow_forward, color: Colors.white)
                                : Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AppButton(
                        onTap: saveChanges,
                        text: "Save Changes",
                        isLoading: profileController.isProfileUpdating.value,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
                cityController.isLoading.value
                    ? Container(
                      height: Get.height,
                      width: Get.width,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [CircularProgressIndicator()],
                          ),
                        ],
                      ),
                    )
                    : SizedBox.shrink(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

void showProfileCountrySelectionDialog(
  BuildContext context,
  Map<String, int> allCountries,
  List<String> countryName, {
  int? countryId, // Optional parameter for initial country ID
}) {
  final ProfileController profileController = Get.find();
  final CityController cityController = Get.put(CityController());

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;

  // Initialize selected country name based on countryId
  String initialCountryName = '';
  if (countryId != null) {
    initialCountryName =
        allCountries.entries
            .firstWhere(
              (entry) => entry.value == countryId,
              orElse: () => MapEntry('', 0),
            )
            .key;
  }
  RxString selectedCountryName = initialCountryName.obs;

  // Filter countries based on search input
  void filterCountries(String query) {
    if (query.isEmpty) {
      filteredCountryName.value = countryName;
    } else {
      filteredCountryName.value =
          countryName
              .where(
                (country) =>
                    country.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
  }

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 350.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      "assets/icons/state.svg",
                      width: 24.w,
                      height: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Select Country".tr,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search country...'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: ColorUtils.greyTextFieldBorderColor,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: (value) => filterCountries(value),
            ),
            SizedBox(height: 16.h),

            /// Scrollable Country List
            Container(
              height: 240.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(filteredCountryName.length, (
                      index,
                    ) {
                      String country = filteredCountryName[index];
                      bool isSelected = selectedCountryName.value == country;

                      return InkWell(
                        onTap: () {
                          selectedCountryName.value = country;
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 200.w),
                                child: Text(
                                  country,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                width: 20.w,
                                height: 20.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.primaryColor,
                                    width: 2,
                                  ),
                                  color:
                                      isSelected
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            /// Submit Button
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCountryName.value.isNotEmpty
                        ? () async {
                          int? selectedId =
                              allCountries[selectedCountryName.value];
                          if (selectedId != null) {
                            profileController.countryId = selectedId;
                            profileController.selectCountryId.value =
                                selectedId.toString();
                            profileController.cityId = 0;
                            profileController.selectedCityId.value = '';
                            cityController.cityList.clear();

                            await cityController.fetchCities(selectedId);

                            // Prepare cities
                            Map<String, int> allCities = {};
                            List<String> cityName =
                                cityController.cityList.map<String>((city) {
                                  allCities[city.name!] = city.id!;
                                  return city.name!;
                                }).toList();

                            Get.back(); // Close country dialog

                            showProfileCitySelectionDialog(
                              context,
                              allCities,
                              cityName,
                              '',
                            );
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  "Submit".tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showProfileCitySelectionDialog(
  BuildContext context,
  Map<String, int> allCities,
  List<String> cityName,
  String? selectedCityName, {
  int? cityId,
}) {
  final ProfileController profileController = Get.find();

  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCityName = cityName.obs;

  // Set initial selected city name from cityId
  String initialCityName = '';
  if (cityId != null) {
    initialCityName =
        allCities.entries
            .firstWhere(
              (entry) => entry.value == cityId,
              orElse: () => MapEntry('', 0),
            )
            .key;
  }
  RxString selectedCity = initialCityName.obs;

  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityName.value = cityName;
    } else {
      filteredCityName.value =
          cityName
              .where((city) => city.toLowerCase().contains(query.toLowerCase()))
              .toList();
    }
  }

  Get.dialog(
    barrierDismissible: false,
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        width: 350.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      "assets/icons/state.svg",
                      width: 24.w,
                      height: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Select City".tr,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    if (selectedCity.value.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Please select a city before closing".tr,
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      Get.back();
                    }
                  },
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search city...'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: ColorUtils.greyTextFieldBorderColor,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: ColorUtils.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 12.w,
                ),
              ),
              onChanged: filterCities,
            ),
            SizedBox(height: 16.h),

            /// Scrollable City List
            Container(
              height: 230.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(filteredCityName.length, (index) {
                      String city = filteredCityName[index];
                      bool isSelected = selectedCity.value == city;

                      return InkWell(
                        onTap: () {
                          selectedCity.value = city;
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 200.w),
                                child: Text(
                                  city,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                width: 20.w,
                                height: 20.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ColorUtils.primaryColor,
                                    width: 2,
                                  ),
                                  color:
                                      isSelected
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            /// Submit Button
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCity.value.isNotEmpty
                        ? () {
                          int? selectedId = allCities[selectedCity.value];
                          if (selectedId != null) {
                            profileController.cityId = selectedId;
                            profileController.selectedCityId.value =
                                selectedId.toString();
                            print('Selected City ID: $selectedId');
                            print('Selected City Name: ${selectedCity.value}');
                            Get.back();
                          }
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  "Submit".tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
