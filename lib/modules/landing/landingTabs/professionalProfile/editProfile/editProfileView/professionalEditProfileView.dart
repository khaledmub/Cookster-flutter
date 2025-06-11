import 'dart:io';
import 'package:flutter/material.dart' as dir;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../appUtils/apiEndPoints.dart';
import '../../../../../../appUtils/colorUtils.dart';
import '../../../../../../loaders/pulseLoader.dart';
import '../../../../../../services/apiClient.dart';
import '../../../../../auth/signUp/signUpWidgets/selectLocation.dart';
import '../../profileControlller/professionalProfileController.dart';

class EditProfessionalProfileView extends StatefulWidget {
  const EditProfessionalProfileView({super.key});

  @override
  State<EditProfessionalProfileView> createState() =>
      _EditProfessionalProfileViewState();
}

class _EditProfessionalProfileViewState
    extends State<EditProfessionalProfileView> {
  final ProfessionalProfileController profileController = Get.find();
  final CityController cityController = Get.put(CityController());
  final _formKey = GlobalKey<FormState>();

  late String initialName;
  late String initialEmail;
  late String initialDob;
  late String initialPhone;
  late String initialContactEmail;
  late String initialContactPhone;
  late String initialWebsite;
  late String initialLocation;
  late int initialCountryId;
  late int initialCityId;
  late int initialMenuId;
  late int initialCountry;
  late int initialCity;
  late dynamic googleSignInBit = -1;

  @override
  void initState() {
    getEntity();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      // Set google_sign_in to 0 in SharedPreferences
      googleSignInBit = prefs.getInt('google_sign_in') ?? 0;
      // Optionally update googleSignInBit
    });
    super.initState();
    var userDetails = profileController.userDetails.value?.user;
    var additionalSettings =
        profileController.userDetails.value?.additionalData;
    if (userDetails != null) {
      initialName = userDetails.name ?? '';
      initialEmail = userDetails.email ?? '';
      initialDob = userDetails.dob ?? '';
      initialPhone = userDetails.phone ?? '';
      initialContactEmail = additionalSettings!.contactEmail ?? '';
      initialContactPhone = additionalSettings.contactPhone ?? '';
      initialWebsite = additionalSettings.website ?? '';
      initialLocation = additionalSettings.location ?? '';
      initialCountry =
          userDetails.country; // Use string '-1' or another valid string
      initialCity = userDetails.city; // Use string '-1' or another valid string

      profileController.nameController.text = initialName;
      profileController.emailController.text = initialEmail;
      profileController.birthdayController.text = initialDob;
      profileController.phoneNumberController.text = initialPhone;
      profileController.contactPhoneController.text = initialContactPhone;
      profileController.contactEmailController.text = initialContactEmail;
      profileController.locationController.text = initialLocation;
      profileController.websiteController.text = initialWebsite;

      profileController.latitude = additionalSettings.latitude.toString();
      profileController.longitude = additionalSettings.longitude.toString();
      profileController.selectCountryId.value = initialCountry.toString();
      profileController.selectedCityId.value = initialCity.toString();

      initialCountryId = userDetails.country;
      initialCityId = userDetails.city;
      initialMenuId = additionalSettings.businessType ?? 0;

      cityController.fetchCities(initialCountryId);
    }
  }

  bool hasChanges() {
    return profileController.nameController.text != initialName ||
        profileController.emailController.text != initialEmail ||
        profileController.birthdayController.text != initialDob ||
        profileController.phoneNumberController.text != initialPhone ||
        profileController.contactPhoneController.text != initialContactPhone ||
        profileController.contactEmailController.text != initialContactEmail ||
        profileController.emailController.text != initialWebsite ||
        profileController.locationController.text != initialLocation ||
        profileController.selectedImage.value != null ||
        profileController.selectedCityId.value != initialCity.toString() ||
        profileController.selectCountryId.value != initialCountry.toString() ||
        profileController.menuId != initialMenuId ||
        profileController.passwordController.text.trim().isNotEmpty;
  }

  void saveChanges() {
    if (!hasChanges()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No changes detected!")));
      return;
    }

    if (_formKey.currentState!.validate()) {
      profileController
          .updateUserProfile(
            name:
                profileController.nameController.text.trim().isNotEmpty
                    ? profileController.nameController.text.trim()
                    : null,
            dob:
                profileController.birthdayController.text.trim().isNotEmpty
                    ? profileController.birthdayController.text.trim()
                    : null,
            contactEmail:
                profileController.contactEmailController.text.trim().isNotEmpty
                    ? profileController.contactEmailController.text.trim()
                    : null,
            contactPhone:
                profileController.contactPhoneController.text.trim().isNotEmpty
                    ? profileController.contactPhoneController.text.trim()
                    : null,
            website:
                profileController.websiteController.text.trim().isNotEmpty
                    ? profileController.websiteController.text.trim()
                    : null,
            location:
                profileController.locationController.text.trim().isNotEmpty
                    ? profileController.locationController.text.trim()
                    : null,
            latitude:
                profileController.latitude.isNotEmpty
                    ? profileController.latitude
                    : null,
            longitude:
                profileController.longitude.isNotEmpty
                    ? profileController.longitude
                    : null,
            password:
                profileController.passwordController.text.trim().isNotEmpty
                    ? profileController.passwordController.text.trim()
                    : null,
            imageFile: profileController.selectedImage.value,
            context: context,
          )
          .then((_) {
            profileController.selectedImage.value = null;
          });
    }
  }

  int entity = -1;

  Future<int> getEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      entity = prefs.getInt('entity') ?? 0;
    });
    return entity;
  }

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
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Profile".tr,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            Align(
              alignment:
                  Directionality.of(context) == TextDirection.rtl
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
            var userDetails = profileController.userDetails.value?.user;
            var additionalSettings =
                profileController.userDetails.value?.additionalData;
            var countries =
                profileController.userDetails.value?.formSettings?.countries;
            var cities = cityController.cityList;
            var businessTypes =
                profileController
                    .userDetails
                    .value
                    ?.formSettings
                    ?.businessTypes;

            if (userDetails == null || additionalSettings == null) {
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PulseLogoLoader(
                        logoPath: "assets/images/appIcon.png",
                        size: 80,
                      ),
                      SizedBox(height: 10),
                      Text("Loading...", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

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

            Map<String, int> allMenuItems = {};
            List<String> menuItemName =
                businessTypes?.values?.map<String>((menu) {
                  allMenuItems[menu.name!] = menu.id!;
                  return menu.name!;
                }).toList() ??
                [];

            String? selectedMenuItem =
                allMenuItems.entries
                    .firstWhere(
                      (entry) => entry.value == additionalSettings.businessType,
                      orElse: () => const MapEntry('', 0),
                    )
                    .key;
            if (!menuItemName.contains(selectedMenuItem) ||
                selectedMenuItem.isEmpty) {
              selectedMenuItem = null;
            }

            return Stack(
              children: [
                Column(
                  spacing: 20,
                  children: [
                    // SizedBox(height: 16.h),
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
                                          child:
                                              userDetails.image == null
                                                  ? Image.asset(
                                                    "assets/images/sd.png",
                                                    fit: BoxFit.cover,
                                                  )
                                                  : CachedNetworkImage(
                                                    imageUrl:
                                                        '${Common.profileImage}/${userDetails.image!}',
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            const Icon(
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
                        validator: profileController.usernameValidator,
                        label: "Name".tr,
                        hintText: "Enter Name".tr,
                        iconPath: "assets/icons/editProfile.svg",
                        controller: profileController.nameController,
                      ),
                    ),
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomTextField(
                          validator: profileController.emailValidator,
                          label: "email".tr,
                          hintText: "Enter Email".tr,
                          iconPath: "assets/icons/email.svg",
                          controller: profileController.emailController,
                        ),
                      ),
                    ),

                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomTextField(
                          label: "Phone Number".tr,
                          hintText: "Enter Phone Number".tr,
                          iconPath: "assets/icons/phone.svg",
                          controller: profileController.phoneNumberController,
                        ),
                      ),
                    ),

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
                        label: "Enter New Password".tr,
                        hintText: "Enter New Password".tr,
                        iconPath: "assets/icons/password.svg",
                        controller: profileController.passwordController,
                      ),
                    ),

                    if (entity == 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade100,
                            border: Border.all(
                              color: ColorUtils.greyTextFieldBorderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              SvgPicture.asset("assets/icons/business.svg"),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownFlutter<String>(
                                  closedHeaderPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                  decoration: CustomDropdownDecoration(
                                    closedBorderRadius: BorderRadius.circular(
                                      8,
                                    ),
                                    expandedBorderRadius: BorderRadius.circular(
                                      8,
                                    ),
                                    closedFillColor: Colors.transparent,
                                    closedSuffixIcon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  hintText: "please_select_business_type".tr,
                                  items: menuItemName,
                                  initialItem: selectedMenuItem,
                                  onChanged: (String? selectedValue) {
                                    if (selectedValue != null) {
                                      int? selectedId =
                                          allMenuItems[selectedValue];
                                      profileController.menuId =
                                          selectedId!.toInt();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    InkWell(
                      onTap: () {
                        showProfileCountrySelectionDialog(
                          context,
                          allCountries,
                          countryName,
                          selectedCountryName,
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
                                  ? "Select your country".tr
                                  : countryName.firstWhere(
                                    (name) =>
                                        allCountries[name].toString() ==
                                        profileController.selectCountryId.value,
                                    orElse: () => "Select your country".tr,
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
                                  ? "Select your city".tr
                                  : cityName.firstWhere(
                                    (name) =>
                                        allCities[name].toString() ==
                                        profileController.selectedCityId.value,
                                    orElse: () => "Select your city".tr,
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

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CustomTextField(
                        validator: profileController.phoneValidator,
                        label: "Contact Phone".tr,
                        hintText: "Enter Phone Number".tr,
                        iconPath: "assets/icons/phone.svg",
                        controller: profileController.contactPhoneController,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CustomTextField(
                        validator: profileController.emailValidator,
                        label: "Contact Email Address".tr,
                        hintText: "Enter Contact Email".tr,
                        iconPath: "assets/icons/email.svg",
                        controller: profileController.contactEmailController,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CustomTextField(
                        validator: profileController.validateWebsite,
                        label: "Website".tr,
                        hintText: "Enter Website".tr,
                        iconPath: "assets/icons/website.svg",
                        controller: profileController.websiteController,
                      ),
                    ),
                    if (entity == 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          spacing: 16.h,
                          children: [
                            InkWell(
                              onTap: () async {
                                var result = await Get.to(
                                  () => LocationPickerScreen(
                                    initialLatitude: double.parse(
                                      profileController.latitude,
                                    ),
                                    initialLongitude: double.parse(
                                      profileController.longitude,
                                    ),

                                    initialAddress:
                                        profileController
                                                .locationController
                                                .text
                                                .isNotEmpty
                                            ? profileController
                                                .locationController
                                                .text
                                            : null,
                                  ),
                                );
                                if (result != null) {
                                  profileController.locationController.text =
                                      result['address'];
                                  profileController.latitude =
                                      result['latitude'];
                                  profileController.longitude =
                                      result['longitude'];
                                  profileController.locationController.text =
                                      result['address'];

                                  print('LATITUDE: ${result['latitude']}');
                                  print('LONGITUDE: ${result['longitude']}');
                                } else {
                                  print("error");
                                }
                              },

                              child: IgnorePointer(
                                child: CustomTextField(
                                  validator:
                                      profileController.locationValidator,
                                  label: "Location".tr,
                                  hintText: "Select Location".tr,
                                  iconPath: "assets/icons/location.svg",
                                  controller:
                                      profileController.locationController,
                                ),
                              ),
                            ),
                          ],
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            SvgPicture.asset("assets/icons/earth.svg"),
                            SizedBox(width: 16.w),
                            Text("Change Language".tr),
                            const Spacer(),
                            Directionality.of(context) == TextDirection.rtl
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
                          title:
                          'sure_to_delete_account'.tr,
                          desc:
                          'sure_to_delete_description'.tr,
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
                          btnOkText: 'Confirm',
                          btnCancelText: 'Cancel',
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
                        text: "Save Changes".tr,
                        isLoading: profileController.isProfileUpdating.value,
                      ),
                    ),
                    const SizedBox(height: 20),
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
  List<String> countryName,
  String? selectedCountryName, {
  int? countryId, // Optional parameter for initial country ID
}) {
  final ProfessionalProfileController profileController = Get.find();
  final CityController cityController = Get.put(CityController());

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;

  // Set initial country selection based on countryId if provided
  if (countryId != null) {
    profileController.countryId = countryId;
    profileController.selectCountryId.value = countryId.toString();
    // Find the country name corresponding to the countryId
    String? initialCountryName =
        allCountries.entries
            .firstWhere(
              (entry) => entry.value == countryId,
              orElse:
                  () => MapEntry('', 0), // Return a dummy entry if not found
            )
            .key;
    if (initialCountryName.isNotEmpty) {
      selectedCountryName = initialCountryName;
    }
  }

  // Rest of the code remains unchanged
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
            /// **Header (Title + Close Button)**
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

            /// **Search Field**
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

            /// **Scrollable Country List**
            Container(
              height: 240.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCountryName.length,
                      (index) => InkWell(
                        onTap: () async {
                          String selectedCountry = filteredCountryName[index];
                          Navigator.pop(context); // Close country dialog

                          int? selectedId = allCountries[selectedCountry];
                          if (selectedId != null) {
                            profileController.countryId = selectedId.toInt();
                            profileController.selectCountryId.value =
                                selectedId.toString();
                            profileController.cityId = 0; // Reset city
                            profileController.selectedCityId.value =
                                ''; // Reset selected city ID
                            cityController.cityList.clear(); // Clear cities

                            // Fetch cities for the selected country
                            await cityController.fetchCities(selectedId);

                            // Prepare city data for the city dialog
                            Map<String, int> allCities = {};
                            List<String> cityName =
                                cityController.cityList.map<String>((city) {
                                  allCities[city.name!] = city.id!;
                                  return city.name!;
                                }).toList();

                            String? selectedCityName = '';

                            // Show city selection dialog
                            showProfileCitySelectionDialog(
                              context,
                              allCities,
                              cityName,
                              selectedCityName,
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                filteredCountryName[index],
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight:
                                      profileController.countryId ==
                                              allCountries[filteredCountryName[index]]
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: Colors.black,
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
                                      profileController.countryId ==
                                              allCountries[filteredCountryName[index]]
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
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
  int? cityId, // Optional parameter for initial city ID
}) {
  final ProfessionalProfileController profileController = Get.find();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCityName = cityName.obs;

  // Set initial city selection based on cityId if provided
  if (cityId != null) {
    profileController.cityId = cityId;
    profileController.selectedCityId.value = cityId.toString();
    // Find the city name corresponding to the cityId
    String? initialCityName =
        allCities.entries
            .firstWhere(
              (entry) => entry.value == cityId,
              orElse:
                  () => MapEntry('', 0), // Return a dummy entry if not found
            )
            .key;
    if (initialCityName.isNotEmpty) {
      selectedCityName = initialCityName;
    }
  }

  // Filter cities based on search input
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
    barrierDismissible: false, // Prevent dismissing by tapping outside
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
            /// **Header (Title + Close Button)**
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
                    // Check if a city is selected
                    if (profileController.selectedCityId.value.isEmpty) {
                      // Show SnackBar if no city is selected
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
                      // Close dialog if a city is selected
                      Get.back();
                    }
                  },
                  child: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            /// **Search Field**
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
              onChanged: (value) => filterCities(value),
            ),
            SizedBox(height: 16.h),

            /// **Scrollable City List**
            Container(
              height: 230.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(
                      filteredCityName.length,
                      (index) => InkWell(
                        onTap: () {
                          String selectedCity = filteredCityName[index];
                          int? selectedId = allCities[selectedCity];
                          if (selectedId != null) {
                            profileController.cityId = selectedId.toInt();
                            profileController.selectedCityId.value =
                                selectedId.toString();
                            print(
                              'Selected City ID: $selectedId, Selected City Name: $selectedCity',
                            );
                            print(
                              'City ID: ${profileController.cityId}, City Name: ${profileController.selectedCityId.value}',
                            );
                            // Close dialog after selecting a city
                            Navigator.pop(context);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                filteredCityName[index],
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight:
                                      profileController.cityId ==
                                              allCities[filteredCityName[index]]
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: Colors.black,
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
                                      profileController.cityId ==
                                              allCities[filteredCityName[index]]
                                          ? ColorUtils.primaryColor
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    ),
  );
}
