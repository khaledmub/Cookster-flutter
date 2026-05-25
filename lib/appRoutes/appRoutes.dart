import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/modules/auth/signIn/signInView/signInView.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:cookster/modules/search/searchView/searchView.dart';
import 'package:cookster/modules/selectLanguage/selectLanguageView/selectLanguageView.dart';
import 'package:cookster/modules/splash/splashView/splashVIew.dart';
import 'package:get/get.dart';
import '../modules/auth/packages/packageView/packageView.dart';
import '../modules/auth/signUp/signUnView/signUpView.dart';
import '../modules/landing/landingTabs/profile/editProfile/editProfileView/editProfileView.dart';
import '../modules/onBoarding/onBoardingView/onBoardingView.dart';
import '../modules/auth/signUp/signUpOtpView/signUpOtpView.dart';

class AppRoutes {
  static const String home = '/';
  static const String splash = '/splash';
  static const String onBoarding = '/onboarding';
  static const String signIn = '/signIn';
  static const String signUp = '/signUp';
  static const String signUpOtp = '/signUpOtp';
  static const String selectLanguage = '/selectLanguage';
  static const String landing = '/landing';
  static const String editProfile = '/editProfile';
  static const String noInternet = '/noInternet';
  static const String search = '/search';
  static const String packages = '/packages';

  static List<GetPage> pages = [
    GetPage(
      name: packages,
      page: () => PackagesScreen(),
      binding: PackagesBinding(),
    ),
    GetPage(
      name: search,
      page: () => SearchView(),
      binding: SearchBinding(),
    ),
    // GetPage(name: noInternet, page: () => NoInternetScreen()),
    GetPage(
      name: editProfile,
      page: () => EditProfileView(),
      binding: EditProfileBinding(),
    ),
    GetPage(
      name: landing,
      page: () => Landing(),
      binding: LandingBinding(),
    ),
    GetPage(
      name: selectLanguage,
      page: () => SelectLanguageView(),
      binding: SelectLanguageBinding(),
    ),
    GetPage(
      name: signUp,
      page: () => SignVpView(),
      binding: SignUpBinding(),
    ),
    GetPage(
      name: signUpOtp,
      page: () => SignUpOtpView(),
      binding: SignUpOtpBinding(),
    ),
    GetPage(
      name: signIn,
      page: () => const SignInView(),
      binding: SignInBinding(),
    ),
    GetPage(name: splash, page: () => const SplashView()),
    GetPage(
      name: onBoarding,
      page: () => OnBoarding(),
      binding: OnBoardingBinding(),
    ),
  ];
}
