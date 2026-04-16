import 'package:cookster/appUtils/appCenterIcon.dart';
import 'package:cookster/modules/auth/signUp/registrationSettingsModel/registrationModel.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/auth/signUp/signUpController/signUpController.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../appUtils/appUtils.dart';
import '../../../../appUtils/colorUtils.dart';
import '../../../../loaders/pulseLoader.dart';
import '../signUpWidgets/selectLocation.dart';

class SignVpView extends StatefulWidget {
  const SignVpView({super.key});

  @override
  State<SignVpView> createState() => _SignVpViewState();
}

class _SignVpViewState extends State<SignVpView> {
  late FocusNode nameFocusNode;
  late FocusNode locationFocusNode;
  late FocusNode emailFocusNode;
  late FocusNode phoneFocusNode;
  late FocusNode passwordFocusNode;
  late FocusNode dobFocusNode;
  late FocusNode contactPhoneFocusNode;
  late FocusNode contactEmailFocusNode;
  final emailKey = GlobalKey<FormFieldState>();
  final passwordFieldKey = GlobalKey<FormFieldState>();
  final locationKey = GlobalKey<FormFieldState>();
  final phoneKey = GlobalKey<FormFieldState>();
  final dobKey = GlobalKey<FormFieldState>();
  final contactPhoneKey = GlobalKey<FormFieldState>();
  final contactEmailKey = GlobalKey<FormFieldState>();
  final nameKey = GlobalKey<FormFieldState>();
  final websiteKey = GlobalKey<FormFieldState>();
  final locationController = TextEditingController();
  String _language = 'en'; // Default to English
  // Load language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  late dynamic googleSignInBit = -1;

  final SignUpController signUpController = Get.put(SignUpController());

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    locationFocusNode = FocusNode();
    nameFocusNode = FocusNode();
    emailFocusNode = FocusNode();
    phoneFocusNode = FocusNode();
    passwordFocusNode = FocusNode();
    dobFocusNode = FocusNode();
    contactPhoneFocusNode = FocusNode();
    contactEmailFocusNode = FocusNode();

    // Load SharedPreferences asynchronously in addPostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final SignUpController signUpController = Get.find();
      String? email = Get.parameters['email'];
      String? name = Get.parameters['name'];

      // Get instance of SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Load the google_sign_in bit, default to 0 if not set
      setState(() {
        googleSignInBit = prefs.getInt('google_sign_in') ?? 0;

        if (googleSignInBit == 1)
          signUpController.passwordController.text = "Welcome@119";
      });

      if (email != null && email.isNotEmpty) {
        signUpController.emailController.text = email;
      }
      if (name != null && name.isNotEmpty) {
        signUpController.nameController.text = name;
      }
    });
  }

  @override
  void dispose() {
    locationFocusNode.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    phoneFocusNode.dispose();
    passwordFocusNode.dispose();
    dobFocusNode.dispose();
    contactPhoneFocusNode.dispose();
    contactEmailFocusNode.dispose();
    super.dispose();
  }

  final CityController cityController = Get.put(CityController());

  String getIconPath(int id) {
    switch (id) {
      case 1:
        return "assets/icons/personal.svg";
      case 2:
        return "assets/icons/business.svg";
      case 3:
        return "assets/icons/chef.svg";
      default:
        return "assets/icons/chef.svg"; // Provide a default icon
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';

    return Obx(() {
      Map<String, int> businessType = {};
      List<String> businessTypeName =
          signUpController.registrationSettings.value.businessTypes?.values
              ?.map((business) {
                if (business.name != null && business.id != null) {
                  businessType[business.name!] = business.id!;
                  return business.name!;
                }
                return null;
              })
              .whereType<String>()
              .toList() ??
          [];

      Map<String, int> typeOfAccount = {};
      List<String> typeOfAccountName =
          signUpController.registrationSettings.value.typeOfAccounts?.values
              ?.map((account) {
                if (account.name != null && account.id != null) {
                  typeOfAccount[account.name!] = account.id!;
                  return account.name!;
                }
                return null;
              })
              .whereType<String>()
              .toList() ??
          [];

      Map<String, int> allCountries = {};
      List<String> countryName =
          signUpController.registrationSettings.value.countries
              ?.map((country) {
                if (country.name != null && country.id != null) {
                  allCountries[country.name!] = country.id!;
                  return country.name!;
                }
                return null;
              })
              .whereType<String>()
              .toList() ??
          [];

      Map<String, int> cities = {};
      List<String> city =
          cityController.cityList
              .map((city) {
                if (city.name != null && city.id != null) {
                  cities[city.name!] = city.id!;
                  return city.name!;
                }
                return null;
              })
              .whereType<String>()
              .toList() ??
          [];
      return signUpController.registrationSettings.value.businessTypes == null
          ? Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PulseLogoLoader(
                          logoPath: "assets/images/appIcon.png",
                          size: 80,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          )
          : Scaffold(
        backgroundColor: ColorUtils.secondaryColor,
            appBar: AppBar(
              backgroundColor: ColorUtils.primaryColor,
              toolbarHeight: 0,
              elevation: 0,
            ),
            body: Stack(
              children: [
                Container(
                  height: Get.height,
                  decoration: const BoxDecoration(
                    gradient: ColorUtils.goldGradient,
                  ),
                ),

                SizedBox(
                  height: Get.height,
                  child: SingleChildScrollView(
                    child: Stack(
                      children: [
                        // Background Gradient
                        Form(
                          key: signUpController.formKey,
                          child: Column(
                            spacing: 10.h,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                children: [
                                  // Back Button on the Left
                                  Positioned(
                                    // Conditionally set left or right based on language
                                    left: isRtl ? null : 16,
                                    right: isRtl ? 16 : null,
                                    top: 20,
                                    // Assuming .h is from a package like flutter_screenutil, replace with 20 if not using it
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        try {
                                          print("Tapped");
                                          Get.back();
                                        } catch (e) {
                                          print(e);
                                        }
                                      },
                                      child: Container(
                                        height: 40,
                                        width: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE6BE00),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            // Use right chevron for Arabic, left chevron for English
                                            isRtl
                                                ? Icons.arrow_back
                                                : Icons.arrow_back,
                                            color: ColorUtils.darkBrown,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Center Logo
                                  AppCenterIcon(),
                                ],
                              ),

                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40.r),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Column(
                                    // spacing: 10.h,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      SizedBox(height: 20.h),
                                      Text(
                                        "sign up".tr,
                                        style: TextStyle(
                                          color: ColorUtils.darkBrown,
                                          fontSize: 30.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'signUpSubtitle'.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 10),

                                      Text(
                                        "select_your_account_type".tr,
                                        style: TextStyle(
                                          color: ColorUtils.darkBrown,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10),

                                      Obx(
                                        () => Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children:
                                              signUpController
                                                          .registrationSettings
                                                          .value
                                                          .entities !=
                                                      null
                                                  ? signUpController
                                                      .registrationSettings
                                                      .value
                                                      .entities!
                                                      .map(
                                                        (entity) =>
                                                            _buildProfileOption(
                                                              type: entity,
                                                              label:
                                                                  entity
                                                                      .name ??
                                                                  '',
                                                              iconPath:
                                                                  getIconPath(
                                                                    entity
                                                                        .id!,
                                                                  ),
                                                            ),
                                                      )
                                                      .toList()
                                                  : [],
                                        ),
                                      ),
                                      SizedBox(height: 10),

                                      ///
                                      Obx(
                                        () => Text(
                                          textAlign: TextAlign.center,
                                          _getSelectedEntityText(),
                                          style: TextStyle(
                                            color: ColorUtils.darkBrown,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppUtils.customPasswordTextField(
                                            controller:
                                                signUpController
                                                    .nameController,
                                            validator:
                                                signUpController.validateName,
                                            focusNode: nameFocusNode,
                                            keyboardType: TextInputType.name,
                                            fieldKey: nameKey,
                                            labelText: "Name".tr,
                                            svgIconPath:
                                                "assets/icons/editProfile.svg",
                                            textInputAction:
                                                TextInputAction.next,
                                            isPasswordField: false,
                                          ),
                                          SizedBox(height: 10),

                                          Obx(
                                            () =>
                                                signUpController
                                                        .nameError
                                                        .value
                                                        .isNotEmpty
                                                    ? Padding(
                                                      padding:
                                                          EdgeInsets.only(
                                                            top: 4.h,
                                                            left: 16.w,
                                                          ),
                                                      child: Text(
                                                        signUpController
                                                            .nameError
                                                            .value,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(
                                                                    context,
                                                                  )
                                                                  .colorScheme
                                                                  .error,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                      // Email Field
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppUtils.customPasswordTextField(
                                            fieldKey: emailKey,
                                            controller:
                                                signUpController
                                                    .emailController,
                                            validator:
                                                signUpController
                                                    .validateEmail,
                                            focusNode: emailFocusNode,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            labelText: "Email".tr,
                                            svgIconPath:
                                                "assets/icons/email.svg",
                                            textInputAction:
                                                TextInputAction.next,
                                            isPasswordField: false,
                                          ),

                                          // SizedBox(height: 10),
                                          Obx(
                                            () =>
                                                signUpController
                                                        .emailError
                                                        .value
                                                        .isNotEmpty
                                                    ? Column(
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                top: 4.h,
                                                                left: 8,
                                                                right: 8,
                                                              ),
                                                          child: Text(
                                                            signUpController
                                                                .emailError
                                                                .value,
                                                            style: TextStyle(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .error,
                                                              // Standard Material error color
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(height: 10),
                                                      ],
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                        ],
                                      ),

                                      if (signUpController
                                              .selectedProfileId
                                              .value !=
                                          1)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(height: 10),

                                            AppUtils.customPasswordTextField(
                                              fieldKey: phoneKey,
                                              onChanged: (_) {
                                                signUpController
                                                    .phoneError
                                                    .value = "";
                                              },
                                              controller:
                                                  signUpController
                                                      .phoneController,
                                              validator:
                                                  signUpController
                                                      .validatePhoneNumber,
                                              focusNode: phoneFocusNode,
                                              keyboardType:
                                                  TextInputType.phone,
                                              labelText: "Phone Number".tr,
                                              svgIconPath:
                                                  "assets/icons/phone.svg",
                                              textInputAction:
                                                  TextInputAction.next,
                                              isPasswordField: false,
                                            ),

                                            // SizedBox(height: 10),
                                            Obx(
                                              () =>
                                                  signUpController
                                                          .phoneError
                                                          .value
                                                          .isNotEmpty
                                                      ? Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.h,
                                                              left: 8,
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          signUpController
                                                              .phoneError
                                                              .value,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .error,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      )
                                                      : SizedBox.shrink(),
                                            ),
                                            SizedBox(height: 10),
                                          ],
                                        ),
                                      SizedBox(height: 10),

                                      Obx(() {
                                        print(signUpController.isLoading);
                                        return googleSignInBit == 0
                                            ? Column(
                                              children: [
                                                AppUtils.customPasswordTextField(
                                                  fieldKey: passwordFieldKey,
                                                  svgIconPath:
                                                      "assets/icons/password.svg",

                                                  obscureText:
                                                      signUpController
                                                          .isObscure
                                                          .value,
                                                  labelText: "password".tr,
                                                  validator:
                                                      signUpController
                                                          .validatePassword,
                                                  controller:
                                                      signUpController
                                                          .passwordController,
                                                  focusNode:
                                                      passwordFocusNode,
                                                  toggleObscureText:
                                                      signUpController
                                                          .togglePasswordVisibility,
                                                  isPasswordField: true,
                                                  onSubmitted: (_) {
                                                    // String email = controller.emailController.text;
                                                    // String password = controller.passwordController.text;
                                                    //
                                                  },
                                                ),
                                                SizedBox(height: 10),

                                                Text(
                                                  "password_limit".tr,
                                                  style: TextStyle(
                                                    fontSize: 8.sp,
                                                  ),
                                                ),
                                                SizedBox(height: 10),
                                              ],
                                            )
                                            : SizedBox.shrink();
                                      }),

                                      if (signUpController
                                              .selectedProfileId
                                              .value ==
                                          1)
                                        InkWell(
                                          onTap: () async {
                                            // Parse the current value in dobController, if any
                                            DateTime initialDate;
                                            if (signUpController
                                                .dobController
                                                .text
                                                .isNotEmpty) {
                                              try {
                                                initialDate = DateFormat(
                                                  'yyyy-MM-dd',
                                                ).parse(
                                                  signUpController
                                                      .dobController
                                                      .text,
                                                );
                                              } catch (e) {
                                                // If parsing fails, default to Jan 1, 2000
                                                initialDate = DateTime(
                                                  2000,
                                                  1,
                                                  1,
                                                );
                                              }
                                            } else {
                                              // Default to Jan 1, 2000 for the first time
                                              initialDate = DateTime(
                                                2000,
                                                1,
                                                1,
                                              );
                                            }

                                            DateTime? pickedDate =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate: initialDate,
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime.now(),
                                                );

                                            if (pickedDate != null) {
                                              String formattedDate =
                                                  DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(pickedDate);
                                              signUpController
                                                  .dobController
                                                  .text = formattedDate;

                                              // Trigger form validation to clear any existing error
                                              if (dobKey.currentState !=
                                                  null) {
                                                dobKey.currentState!
                                                    .validate();
                                              }
                                            }
                                          },
                                          child: IgnorePointer(
                                            child: AppUtils.customPasswordTextField(
                                              fieldKey: dobKey,
                                              validator:
                                                  signUpController
                                                      .validateDOB,
                                              controller:
                                                  signUpController
                                                      .dobController,
                                              focusNode: dobFocusNode,
                                              keyboardType:
                                                  TextInputType.none,
                                              // Disable manual input
                                              labelText: "dob".tr,
                                              svgIconPath:
                                                  "assets/icons/calendar.svg",
                                              textInputAction:
                                                  TextInputAction.next,
                                              isPasswordField: false,
                                            ),
                                          ),
                                        ),
                                      Obx(
                                        () =>
                                            signUpController
                                                        .selectedProfileId
                                                        .value ==
                                                    2
                                                ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    // Text(
                                                    //   "select-business-type".tr,
                                                    //   style: TextStyle(
                                                    //     color:
                                                    //         ColorUtils
                                                    //             .darkBrown,
                                                    //     fontWeight:
                                                    //         FontWeight.w500,
                                                    //     fontSize: 16.sp,
                                                    //   ),
                                                    // ),
                                                    // SizedBox(height: 10),
                                                    // spacing fix
                                                    DropdownFlutter<
                                                      String
                                                    >.new(
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          signUpController
                                                                  .businessTypeError
                                                                  .value =
                                                              "please_select_business_type"
                                                                  .tr;
                                                        }
                                                        return null;
                                                      },

                                                      closedHeaderPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 16,
                                                          ),
                                                      decoration: CustomDropdownDecoration(
                                                        hintStyle: TextStyle(
                                                          color: Colors.black,
                                                        ),

                                                        prefixIcon: Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                right: 8.0,
                                                              ),
                                                          child: SvgPicture.asset(
                                                            "assets/icons/business.svg",
                                                          ),
                                                        ),
                                                        closedBorderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        expandedBorderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        closedFillColor:
                                                            Colors
                                                                .transparent,
                                                        closedBorder: Border.all(
                                                          color:
                                                              signUpController
                                                                      .businessTypeError
                                                                      .value
                                                                      .isNotEmpty
                                                                  ? Colors.red
                                                                  : Color(
                                                                    0xFFBDBDBD,
                                                                  ).withOpacity(
                                                                    0.3,
                                                                  ),
                                                          width: 0.8,
                                                        ),
                                                        closedSuffixIcon:
                                                            const Icon(
                                                              Icons
                                                                  .keyboard_arrow_down_rounded,
                                                              size: 18,
                                                            ),
                                                      ),

                                                      hintText:
                                                          "select-business-type"
                                                              .tr,
                                                      items: businessTypeName,
                                                      onChanged: (
                                                        String? selectedValue,
                                                      ) {
                                                        if (selectedValue !=
                                                            null) {
                                                          int? selectedId =
                                                              businessType[selectedValue]; // Get ID from map
                                                          signUpController
                                                              .businessTypeError
                                                              .value = "";
                                                          signUpController
                                                                  .businessType
                                                                  .value =
                                                              selectedId
                                                                  .toString();
                                                        }
                                                      },
                                                    ),

                                                    Obx(
                                                      () =>
                                                          signUpController
                                                                  .businessTypeError
                                                                  .value
                                                                  .isNotEmpty
                                                              ? Padding(
                                                                padding: EdgeInsets.only(
                                                                  top: 4.h,
                                                                  left:
                                                                      isRtl
                                                                          ? 8.w
                                                                          : 8.w,
                                                                  right:
                                                                      isRtl
                                                                          ? 8.w
                                                                          : 8.w,
                                                                ),
                                                                child: Text(
                                                                  signUpController
                                                                      .businessTypeError
                                                                      .value,
                                                                  style: TextStyle(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.error,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              )
                                                              : SizedBox.shrink(),
                                                    ),
                                                  ],
                                                )
                                                : SizedBox.shrink(),
                                      ),
                                      SizedBox(height: 10),

                                      // Country Selection
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Text(
                                          //   "Select your country".tr,
                                          //   style: TextStyle(
                                          //     color: ColorUtils.darkBrown,
                                          //     fontWeight: FontWeight.w500,
                                          //     fontSize: 16.sp,
                                          //   ),
                                          // ),
                                          // SizedBox(height: 10),
                                          InkWell(
                                            onTap:
                                                () =>
                                                    showCountrySelectionDialog(
                                                      context,
                                                      allCountries,
                                                      countryName,
                                                    ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                // horizontal: 12.w,
                                                vertical: 6.h,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      signUpController
                                                              .countryError
                                                              .value
                                                              .isNotEmpty
                                                          ? Colors.red
                                                          : Color(
                                                            0xFFBDBDBD,
                                                          ).withOpacity(0.3),
                                                  width: 0.8,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8.r,
                                                    ),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    width: 40,
                                                    height: 40,
                                                    child: SvgPicture.asset(
                                                      "assets/icons/earth.svg",
                                                      fit: BoxFit.contain,
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                            Colors.black,
                                                            BlendMode.srcIn,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Obx(
                                                    () => Container(
                                                      constraints:
                                                          BoxConstraints(
                                                            maxWidth: 200.w,
                                                          ),
                                                      // Adjust width as needed
                                                      child: Text(
                                                        signUpController
                                                                .selectCountryId
                                                                .value
                                                                .isEmpty
                                                            ? "Select your country"
                                                                .tr
                                                            : countryName.firstWhere(
                                                              (name) =>
                                                                  allCountries[name]
                                                                      .toString() ==
                                                                  signUpController
                                                                      .selectCountryId
                                                                      .value,
                                                              orElse:
                                                                  () =>
                                                                      "Select your country"
                                                                          .tr,
                                                            ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          // color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  Spacer(),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () =>
                                                signUpController
                                                        .countryError
                                                        .value
                                                        .isNotEmpty
                                                    ? Padding(
                                                      padding:
                                                          EdgeInsets.only(
                                                            top: 4.h,
                                                            left:
                                                                isRtl
                                                                    ? 8.w
                                                                    : 8.w,
                                                            right:
                                                                isRtl
                                                                    ? 8.w
                                                                    : 8.w,
                                                          ),
                                                      child: Text(
                                                        signUpController
                                                            .countryError
                                                            .value,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(
                                                                    context,
                                                                  )
                                                                  .colorScheme
                                                                  .error,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),

                                      // City Selection
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Text(
                                          //   "Select your city".tr,
                                          //   style: TextStyle(
                                          //     color: ColorUtils.darkBrown,
                                          //     fontWeight: FontWeight.w500,
                                          //     fontSize: 16.sp,
                                          //   ),
                                          // ),
                                          // SizedBox(height: 10),
                                          InkWell(
                                            onTap:
                                                () => showCitySelectionDialog(
                                                  context,
                                                  cities,
                                                  city,
                                                ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                // horizontal: 12.w,
                                                vertical: 6.h,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      signUpController
                                                              .cityError
                                                              .value
                                                              .isNotEmpty
                                                          ? Colors.red
                                                          : Color(
                                                            0xFFBDBDBD,
                                                          ).withOpacity(0.3),
                                                  width: 0.8,
                                                ),

                                                borderRadius:
                                                    BorderRadius.circular(
                                                      8.r,
                                                    ),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    width: 40,
                                                    height: 40,
                                                    child: SvgPicture.asset(
                                                      "assets/icons/earth.svg",
                                                      fit: BoxFit.contain,
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                            Colors.black,
                                                            BlendMode.srcIn,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),

                                                  Obx(
                                                    () => Container(
                                                      constraints:
                                                          BoxConstraints(
                                                            maxWidth: 200.w,
                                                          ),
                                                      // Adjust max width as needed
                                                      child: Text(
                                                        signUpController
                                                                .selectedCityId
                                                                .value
                                                                .isEmpty
                                                            ? "Select your city"
                                                                .tr
                                                            : city.firstWhere(
                                                              (name) =>
                                                                  cities[name]
                                                                      .toString() ==
                                                                  signUpController
                                                                      .selectedCityId
                                                                      .value,
                                                              orElse:
                                                                  () =>
                                                                      "Select your city"
                                                                          .tr,
                                                            ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  Spacer(),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () =>
                                                signUpController
                                                        .cityError
                                                        .value
                                                        .isNotEmpty
                                                    ? Padding(
                                                      padding:
                                                          EdgeInsets.only(
                                                            top: 4.h,
                                                            left:
                                                                isRtl
                                                                    ? 8.w
                                                                    : 8.w,
                                                            right:
                                                                isRtl
                                                                    ? 8.w
                                                                    : 8.w,
                                                          ),
                                                      child: Text(
                                                        signUpController
                                                            .cityError
                                                            .value,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(
                                                                    context,
                                                                  )
                                                                  .colorScheme
                                                                  .error,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                          ),
                                        ],
                                      ),

                                      // SizedBox(height: 10),
                                      if (signUpController
                                              .selectedProfileId
                                              .value !=
                                          1)
                                        SizedBox(height: 10),

                                      Obx(() {
                                        return signUpController
                                                    .selectedProfileId
                                                    .value ==
                                                2
                                            ? Column(
                                              children: [
                                                AppUtils.customPasswordTextField(
                                                  fieldKey: contactPhoneKey,
                                                  controller:
                                                      signUpController
                                                          .contactPhoneController,
                                                  validator:
                                                      signUpController
                                                          .validateContactPhoneNumber,
                                                  focusNode:
                                                      contactPhoneFocusNode,
                                                  keyboardType:
                                                      TextInputType.phone,

                                                  labelText:
                                                      "Contact Phone".tr,
                                                  svgIconPath:
                                                      "assets/icons/phone.svg",
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  isPasswordField: false,
                                                ),

                                                Obx(
                                                  () =>
                                                      signUpController
                                                              .contactPhoneError
                                                              .value
                                                              .isNotEmpty
                                                          ? Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  top: 4.h,
                                                                  left: 16.w,
                                                                ),
                                                            child: Text(
                                                              signUpController
                                                                  .contactPhoneError
                                                                  .value,
                                                              style: TextStyle(
                                                                color:
                                                                    Theme.of(
                                                                      context,
                                                                    ).colorScheme.error,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          )
                                                          : SizedBox.shrink(),
                                                ),
                                                SizedBox(height: 10),

                                                AppUtils.customPasswordTextField(
                                                  fieldKey: contactEmailKey,
                                                  // Add the missing fieldKey
                                                  controller:
                                                      signUpController
                                                          .contactEmailController,
                                                  validator:
                                                      signUpController
                                                          .validateContactEmail,
                                                  focusNode:
                                                      contactEmailFocusNode,
                                                  keyboardType:
                                                      TextInputType
                                                          .emailAddress,
                                                  labelText:
                                                      "Contact Email Address"
                                                          .tr,
                                                  svgIconPath:
                                                      "assets/icons/email.svg",
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  isPasswordField: false,
                                                  onChanged: (value) {
                                                    // Trigger validation on text change to clear error if valid
                                                    if (contactEmailKey
                                                            .currentState !=
                                                        null) {
                                                      contactEmailKey
                                                          .currentState!
                                                          .validate();
                                                      if (signUpController
                                                              .validateEmail(
                                                                value,
                                                              ) ==
                                                          null) {
                                                        signUpController
                                                                .contactEmailError
                                                                .value =
                                                            ''; // Clear error
                                                      }
                                                    }
                                                  },
                                                ),
                                                SizedBox(height: 10),

                                                Obx(
                                                  () =>
                                                      signUpController
                                                              .contactEmailError
                                                              .value
                                                              .isNotEmpty
                                                          ? Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  top: 4.h,
                                                                  left: 16.w,
                                                                ),
                                                            child: Text(
                                                              signUpController
                                                                  .contactEmailError
                                                                  .value,
                                                              style: TextStyle(
                                                                color:
                                                                    Theme.of(
                                                                      context,
                                                                    ).colorScheme.error,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          )
                                                          : SizedBox.shrink(),
                                                ),
                                              ],
                                            )
                                            : SizedBox.shrink();
                                      }),

                                      Obx(() {
                                        return signUpController
                                                    .selectedProfileId
                                                    .value ==
                                                2
                                            ? Column(
                                              spacing: 12.h,
                                              children: [
                                                AppUtils.customPasswordTextField(
                                                  fieldKey: websiteKey,
                                                  validator:
                                                      signUpController
                                                          .validateWebsite,
                                                  svgIconPath:
                                                      "assets/icons/website.svg",

                                                  labelText: "Website".tr,
                                                  controller:
                                                      signUpController
                                                          .websiteController,
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    var result = await Get.to(
                                                      () => LocationPickerScreen(
                                                        initialLatitude:
                                                            signUpController
                                                                .latitude
                                                                .value,
                                                        initialLongitude:
                                                            signUpController
                                                                .longitude
                                                                .value,
                                                        initialAddress:
                                                            signUpController
                                                                    .locationController
                                                                    .text
                                                                    .isNotEmpty
                                                                ? signUpController
                                                                    .locationController
                                                                    .text
                                                                : null,
                                                      ),
                                                    );
                                                    if (result != null) {
                                                      // Update controller and reactive variables
                                                      signUpController
                                                              .locationController
                                                              .text =
                                                          result['address'];
                                                      signUpController
                                                              .latitude
                                                              .value =
                                                          result['latitude'];
                                                      signUpController
                                                              .longitude
                                                              .value =
                                                          result['longitude'];

                                                      // Trigger validation to clear error if valid
                                                      if (locationKey
                                                              .currentState !=
                                                          null) {
                                                        locationKey
                                                            .currentState!
                                                            .validate();
                                                        if (signUpController
                                                                .locationValidator(
                                                                  result['address'],
                                                                ) ==
                                                            null) {
                                                          signUpController
                                                                  .locationError
                                                                  .value =
                                                              ''; // Clear the error
                                                        }
                                                      }

                                                      // Debug prints
                                                      print(
                                                        'LATITUDE: ${result['latitude']}',
                                                      );
                                                      print(
                                                        'LONGITUDE: ${result['longitude']}',
                                                      );
                                                    } else {
                                                      print(
                                                        "Location selection canceled or failed",
                                                      );
                                                    }
                                                  },
                                                  child: IgnorePointer(
                                                    child: AppUtils.customPasswordTextField(
                                                      fieldKey: locationKey,
                                                      validator:
                                                          signUpController
                                                              .locationValidator,
                                                      svgIconPath:
                                                          "assets/icons/location.svg",
                                                      controller:
                                                          signUpController
                                                              .locationController,
                                                      labelText:
                                                          "Location".tr,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                            : SizedBox.shrink();
                                      }),

                                      // if (signUpController
                                      //         .selectedProfileId
                                      //         .value ==
                                      //     2)
                                      //   SizedBox(height: 10),
                                      if (signUpController
                                              .selectedProfileId
                                              .value ==
                                          8)
                                        Obx(
                                          () =>
                                              signUpController
                                                          .selectedProfileId
                                                          .value ==
                                                      8
                                                  ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Text(
                                                      //   "select_account_type"
                                                      //       .tr,
                                                      //   style: TextStyle(
                                                      //     color:
                                                      //         ColorUtils
                                                      //             .darkBrown,
                                                      //     fontWeight:
                                                      //         FontWeight.w500,
                                                      //     fontSize: 16.sp,
                                                      //   ),
                                                      // ),
                                                      // SizedBox(height: 10),
                                                      // spacing fix
                                                      DropdownFlutter<
                                                        String
                                                      >.new(
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            signUpController
                                                                    .accountTypeError
                                                                    .value =
                                                                'please_select_account_type'
                                                                    .tr;
                                                          }
                                                          return null;
                                                        },

                                                        closedHeaderPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 16,
                                                            ),
                                                        decoration: CustomDropdownDecoration(
                                                          hintStyle: TextStyle(
                                                            color:
                                                                Colors.black,
                                                          ),
                                                          prefixIcon: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 8.0,
                                                                ),
                                                            child: SvgPicture.asset(
                                                              "assets/icons/business.svg",
                                                            ),
                                                          ),
                                                          closedBorderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          expandedBorderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          closedFillColor:
                                                              Colors
                                                                  .transparent,
                                                          closedBorder: Border.all(
                                                            color:
                                                                signUpController
                                                                        .accountTypeError
                                                                        .isNotEmpty
                                                                    ? Colors
                                                                        .red
                                                                    : Color(
                                                                      0xFFBDBDBD,
                                                                    ).withOpacity(
                                                                      0.3,
                                                                    ),
                                                          ),
                                                          closedSuffixIcon:
                                                              const Icon(
                                                                Icons
                                                                    .keyboard_arrow_down_rounded,
                                                                size: 18,
                                                              ),
                                                        ),
                                                        hintText:
                                                            "select_account_type"
                                                                .tr,
                                                        items:
                                                            typeOfAccountName,
                                                        onChanged: (
                                                          String?
                                                          selectedValue,
                                                        ) {
                                                          if (selectedValue !=
                                                              null) {
                                                            int? selectedId =
                                                                typeOfAccount[selectedValue]; // Get ID from map
                                                            signUpController
                                                                    .accountType
                                                                    .value =
                                                                selectedId
                                                                    .toString();
                                                            signUpController
                                                                .accountTypeError
                                                                .value = "";
                                                            print(
                                                              "Selected Account Type: $selectedId",
                                                            );
                                                          }
                                                        },
                                                      ),

                                                      Obx(
                                                        () =>
                                                            signUpController
                                                                    .accountTypeError
                                                                    .value
                                                                    .isNotEmpty
                                                                ? Padding(
                                                                  padding: EdgeInsets.only(
                                                                    top: 4.h,
                                                                    left:
                                                                        isRtl
                                                                            ? 8.w
                                                                            : 8.w,
                                                                    right:
                                                                        isRtl
                                                                            ? 8.w
                                                                            : 8.w,
                                                                  ),
                                                                  child: Text(
                                                                    signUpController
                                                                        .accountTypeError
                                                                        .value,
                                                                    style: TextStyle(
                                                                      color:
                                                                          Theme.of(
                                                                            context,
                                                                          ).colorScheme.error,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                )
                                                                : SizedBox.shrink(),
                                                      ),
                                                    ],
                                                  )
                                                  : SizedBox.shrink(),
                                        ),
                                      SizedBox(height: 10),

                                      Obx(() {
                                        return AppButton(
                                          isLoading:
                                              signUpController
                                                  .isLoading
                                                  .value ||
                                              signUpController
                                                  .isProfileCreating
                                                  .value,
                                          text: "sign up".tr,
                                          onTap: () async {
                                            await signUpController
                                                .handleFormSubmission();
                                          },
                                        );
                                      }),

                                      SizedBox(height: 10),

                                      SizedBox(height: 20.h),
                                    ],
                                  ),
                                ),
                              ),

                              // Text(
                              //   "or sign up with".tr,
                              //   style: TextStyle(
                              //     fontSize: 14.sp,
                              //     fontWeight: FontWeight.w500,
                              //   ),
                              // ),
                              // Padding(
                              //   padding: const EdgeInsets.symmetric(
                              //     horizontal: 16.0,
                              //   ),
                              //   child: Row(
                              //     mainAxisAlignment: MainAxisAlignment.center,
                              //     children: [
                              //       SocialButton(
                              //         backgroundColor: Color(
                              //           0xFF3C79E6,
                              //         ).withOpacity(0.2),
                              //         iconPath: 'assets/images/google.png',
                              //         onTap: () {
                              //           signUpController.signUpWithGoogle();
                              //           if (kDebugMode) {
                              //             print('Google Clicked');
                              //           }
                              //         },
                              //       ),
                              //       SizedBox(width: 16),
                              //       // Spacing between buttons
                              //       if (Platform
                              //           .isIOS) // Only show on iOS devices
                              //         SocialButton(
                              //           backgroundColor: Colors.black
                              //               .withOpacity(0.2),
                              //           iconPath: 'assets/images/apple.png',
                              //           onTap: () {
                              //             if (kDebugMode) {
                              //               print('Apple Clicked');
                              //             }
                              //           },
                              //         ),
                              //       if (Platform.isIOS) SizedBox(width: 16),
                              //       // Add spacing if Apple button is shown
                              //       SocialButton(
                              //         backgroundColor: Color(
                              //           0xFF3C79E6,
                              //         ).withOpacity(0.2),
                              //
                              //         iconPath: 'assets/images/facebook.png',
                              //         onTap: () {
                              //           signUpController.signInWithFacebook();
                              //           if (kDebugMode) {
                              //             print('Facebook Clicked');
                              //           }
                              //         },
                              //       ),
                              //     ],
                              //   ),
                              // ),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(text: "already_have_account".tr),
                                    TextSpan(
                                      text: "sign_in".tr,
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () {
                                              Get.back();
                                              // You can use Navigator.push() here to go to the Sign Up screen.
                                            },
                                    ),
                                  ],
                                ),
                              ),

                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12.sp,
                                  ),
                                  children: [
                                    TextSpan(text: "enquiry_contact_us".tr),
                                    TextSpan(
                                      text: "contact_us".tr,
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () async {
                                              // Get email from controller
                                              final String? email =
                                                  signUpController
                                                      .siteSettings
                                                      .value
                                                      ?.settings
                                                      ?.email;

                                              if (email == null ||
                                                  email.isEmpty) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Email address not available',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              // Create the mailto URL
                                              final Uri emailUri = Uri(
                                                scheme: 'mailto',
                                                path: email,
                                                queryParameters: {
                                                  'subject': 'Contact Us',
                                                  // Pre-fill subject
                                                },
                                              );

                                              // Launch the mail app
                                              if (await canLaunchUrl(
                                                emailUri,
                                              )) {
                                                await launchUrl(emailUri);
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'No email app found',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
            ),
          );
    });
  }

  Widget _buildProfileOption({
    required Entities type,
    required String label,
    required String iconPath,
  }) {
    bool isSelected = signUpController.selectedProfileId.value == type.id!;

    return GestureDetector(
      onTap: () {
        signUpController.selectedProfileId.value = type.id!;

        signUpController.isSubscriptionRequired.value =
            type.isSubscriptionRequired!;

        signUpController.setProfile(label, type.id!);
      },
      child: Column(
        children: [
          Container(
            width: 90.sp,
            height: 48.sp,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? ColorUtils.primaryColor
                      : ColorUtils.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: SvgPicture.asset(
              iconPath,
              height: 28.sp,
              width: 28.sp,
              colorFilter: ColorFilter.mode(
                isSelected ? Colors.black : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? ColorUtils.darkBrown : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  String _getSelectedEntityText() {
    final selectedEntity = signUpController.registrationSettings.value.entities!
        .firstWhere(
          (entity) => entity.id == signUpController.selectedProfileId.value,
        );

    print(selectedEntity.description);

    print("THIS IS THE SELECTED ENTITY: ${selectedEntity.description}");

    // print(object)

    // Replace 'description' with the actual property name that contains the text
    // Common property names might be: description, subtitle, text, details, etc.
    return selectedEntity.description ?? "No description available".tr;
  }
}

void showCountrySelectionDialog(
  BuildContext context,
  Map<String, int> allCountries,
  List<String> countryName,
) {
  final SignUpController signUpController = Get.find();
  final CityController cityController = Get.put(CityController());

  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCountryName = countryName.obs;

  // Get the name of the already selected country, if any
  String initialCountryName = '';
  for (var c in countryName) {
    if (allCountries[c]?.toString() == signUpController.selectCountryId.value) {
      initialCountryName = c;
      break;
    }
  }
  RxString selectedCountryName = initialCountryName.obs;

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
                      "assets/icons/earth.svg",
                      width: 24.w,
                      height: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "select_country_dialog_label".tr,
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
                hintText: 'search_country_placeholder'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: Color(0xFFBDBDBD).withOpacity(0.3),
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
            SizedBox(height: 10.h),

            /// **Scrollable Country List**
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

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              selectedCountryName.value = country;
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 200.w,
                                    ),
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
                          ),
                          if (index < filteredCountryName.length - 1)
                            Divider(
                              height: 1.h,
                              thickness: 1.r,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: 5.h),
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCountryName.value.isNotEmpty
                        ? () async {
                          Get.back();

                          int? selectedId =
                              allCountries[selectedCountryName.value];
                          if (selectedId != null) {
                            signUpController.isLoading.value = true;

                            signUpController.selectCountryId.value =
                                selectedId.toString();
                            signUpController.countryError.value = '';
                            await cityController.fetchCities(selectedId);
                            signUpController.isLoading.value = false;
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

void showCitySelectionDialog(
  BuildContext context,
  Map<String, int> cities,
  List<String> city,
) {
  final SignUpController signUpController = Get.find();

  // Controller for search field
  final TextEditingController searchController = TextEditingController();
  RxList<String> filteredCityName = city.obs;
  RxString selectedCityName =
      city
          .firstWhereOrNull(
            (c) =>
                cities[c]?.toString() == signUpController.selectedCityId.value,
          )
          ?.obs ??
      ''.obs;

  // Filter cities based on search input
  void filterCities(String query) {
    if (query.isEmpty) {
      filteredCityName.value = city;
    } else {
      filteredCityName.value =
          city
              .where((city) => city.toLowerCase().contains(query.toLowerCase()))
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
                      "assets/icons/earth.svg",
                      width: 24.w,
                      height: 24.w,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "select_city_dialog_label".tr,
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
                hintText: 'search_city_placeholder'.tr,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: Color(0xFFBDBDBD).withOpacity(0.3),
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
            SizedBox(height: 10.h),

            /// **Scrollable City List**
            /// Scrollable City List
            Container(
              height: 220.h,
              child: SingleChildScrollView(
                child: Obx(
                  () => Column(
                    children: List.generate(filteredCityName.length, (index) {
                      String cityName = filteredCityName[index];
                      bool isSelected = selectedCityName.value == cityName;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              selectedCityName.value = cityName;
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 200.w,
                                    ),
                                    child: Text(
                                      cityName,
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
                          ),
                          if (index < filteredCityName.length - 1)
                            Divider(
                              height: 1.h,
                              thickness: 1.r,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

            SizedBox(height: 5.h),

            /// Submit Button
            Obx(
              () => ElevatedButton(
                onPressed:
                    selectedCityName.value.isNotEmpty
                        ? () {
                          int? selectedId = cities[selectedCityName.value];
                          if (selectedId != null) {
                            signUpController.selectedCityId.value =
                                selectedId.toString();
                            signUpController.cityError.value = '';
                            print("SUBMITTED CITY ID: $selectedId");
                            Get.back(); // Close dialog
                          }
                        }
                        : null, // Disable button when no city selected
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
