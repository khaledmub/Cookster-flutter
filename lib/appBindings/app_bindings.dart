import 'dart:async';

import 'package:cookster/captuteImage.dart';
import 'package:cookster/modules/auth/signIn/signInController/signInController.dart';
import 'package:cookster/modules/auth/signUp/signUpController/cityController.dart';
import 'package:cookster/modules/auth/signUp/signUpController/signUpController.dart';
import 'package:cookster/modules/auth/signUp/signUpOtpView/signUpOtpController.dart';
import 'package:cookster/modules/landing/landingController/landingController.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/addCommentControllr.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/saveController.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/sendEmailController.dart';
import 'package:cookster/modules/landing/landingTabs/nearBusiness/nearBusinessController/nearBusinessController.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/profileControlller/professionalProfileController.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:cookster/modules/liked_videos_screen/liked_videos_controller/liked_videos_controller.dart';
import 'package:cookster/modules/onBoarding/onBoardingController/onBoardingController.dart';
import 'package:cookster/modules/promoteVideo/promoteVideoController/promoteVideoController.dart';
import 'package:cookster/modules/search/searchController/searchController.dart';
import 'package:cookster/modules/selectLanguage/selectController/selectLanguageController.dart';
import 'package:cookster/modules/viewReview/addReview/addReviewController/addReviewController.dart';
import 'package:get/get.dart';

class SignInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LogInController>(() => LogInController());
    if (!Get.isRegistered<PromoteVideoController>()) {
      Get.lazyPut<PromoteVideoController>(() => PromoteVideoController());
    }
    if (!Get.isRegistered<LanguageController>()) {
      Get.lazyPut<LanguageController>(() => LanguageController());
    }
  }
}

class SignUpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SignUpController>(() => SignUpController());
    if (!Get.isRegistered<CityController>()) {
      Get.lazyPut<CityController>(() => CityController());
    }
  }
}

class SignUpOtpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SignUpOtpController>(() => SignUpOtpController());
  }
}

class OnBoardingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<OnboardingController>()) {
      Get.put<OnboardingController>(OnboardingController(), permanent: true);
    }
  }
}

class SelectLanguageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LanguageController>(() => LanguageController());
  }
}

class PackagesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SignUpController>()) {
      Get.lazyPut<SignUpController>(() => SignUpController());
    }
  }
}

/// Registers deps required by [VisitProfileView] and related flows outside landing.
void ensureVisitProfileDependencies() {
  ensureLandingProfileControllers();
  ensureReelOverlayDependencies();
  if (!Get.isRegistered<HomeController>()) {
    Get.put<HomeController>(HomeController());
  }
}

/// Registers like / comment / save deps for profile reel and other overlay UIs.
void ensureReelOverlayDependencies() {
  if (!Get.isRegistered<VideoCommentsController>()) {
    Get.put<VideoCommentsController>(VideoCommentsController());
  }
  if (!Get.isRegistered<SaveController>()) {
    Get.lazyPut<SaveController>(() => SaveController());
  }
}

/// Registers profile controllers used across landing tabs and upload flow.
void ensureLandingProfileControllers() {
  if (!Get.isRegistered<ProfileController>()) {
    Get.put<ProfileController>(ProfileController());
  }
  if (!Get.isRegistered<ProfessionalProfileController>()) {
    Get.put<ProfessionalProfileController>(ProfessionalProfileController());
  }
}

class LandingBinding extends Bindings {
  @override
  void dependencies() {
    NearBusinessBinding().dependencies();
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController());
    }
    if (!Get.isRegistered<SaveController>()) {
      Get.lazyPut<SaveController>(() => SaveController());
    }
    if (!Get.isRegistered<PromoteVideoController>()) {
      Get.lazyPut<PromoteVideoController>(() => PromoteVideoController());
    }
    if (!Get.isRegistered<VideoAddController>()) {
      Get.lazyPut<VideoAddController>(() => VideoAddController());
    }
    ensureLandingProfileControllers();
    if (!Get.isRegistered<UserSearchController>()) {
      Get.lazyPut<UserSearchController>(() => UserSearchController());
    }
  }
}

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController());
    }
    if (!Get.isRegistered<UserSearchController>()) {
      Get.lazyPut<UserSearchController>(() => UserSearchController());
    }
    if (!Get.isRegistered<CityController>()) {
      Get.lazyPut<CityController>(() => CityController());
    }
    if (!Get.isRegistered<VideoAddController>()) {
      Get.lazyPut<VideoAddController>(() => VideoAddController());
    }
    if (Get.isRegistered<NavBarController>()) {
      unawaited(Get.find<NavBarController>().getVideoUploadSettings());
    }
  }
}

class EditProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProfileController>()) {
      Get.lazyPut<ProfileController>(() => ProfileController());
    }
    if (!Get.isRegistered<PromoteVideoController>()) {
      Get.lazyPut<PromoteVideoController>(() => PromoteVideoController());
    }
  }
}

class SendEmailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmailController>(() => EmailController());
  }
}

class AddReviewBinding extends Bindings {
  AddReviewBinding(this.professionalId);

  final String professionalId;

  @override
  void dependencies() {
    Get.lazyPut<AddReviewController>(
      () => AddReviewController(professionalId: professionalId),
    );
  }
}

class CameraCaptureBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CameraCaptureControllerX>(() => CameraCaptureControllerX());
  }
}

class NearBusinessBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LocationController>()) {
      Get.put<LocationController>(LocationController(), permanent: true);
    }
  }
}

class LikedVideosBinding extends Bindings {
  LikedVideosBinding(this.userId);

  final String userId;

  @override
  void dependencies() {
    Get.lazyPut<LikedVideosController>(
      () => LikedVideosController(userId: userId),
    );
  }
}

/// Registers GetX deps for [SingleVideoScreen] when opened outside [LandingBinding].
void ensureSingleVideoDependencies() {
  ensureLandingProfileControllers();
  if (!Get.isRegistered<SaveController>()) {
    Get.lazyPut<SaveController>(() => SaveController());
  }
  if (!Get.isRegistered<PromoteVideoController>()) {
    Get.lazyPut<PromoteVideoController>(() => PromoteVideoController());
  }
}
