class Common {
  /// Override at build time: `--dart-define=API_BASE_URL=https://other-host/api/`
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');
  static const String testServerIp = String.fromEnvironment('TEST_SERVER_IP');

  static const String _defaultApiBase = 'https://cookster.org/api/';
  static String get baseUrl {
    if (_apiBaseOverride.isNotEmpty) {
      return _apiBaseOverride.endsWith('/')
          ? _apiBaseOverride
          : '$_apiBaseOverride/';
    }
    return _defaultApiBase;
  }

  static bool get isTestApi =>
      baseUrl.contains('mubreq.com') || baseUrl.contains(testServerIp);

  static bool get usesTestServerRouting =>
      testServerIp.isNotEmpty &&
      _apiBaseOverride.isEmpty &&
      baseUrl.contains(testServerIp);

  static String get imageBaseUrl {
    if (baseUrl.contains('mubreq.com')) {
      return 'https://cookster.mubreq.com/storage/';
    }
    if (baseUrl.contains(testServerIp)) {
      return 'https://$testServerIp/storage/';
    }
    return 'https://cookster.org/storage/';
  }

  //
  // static String baseUrl = "http://192.168.1.7/cookster_admin/public/api/";
  //

  // static String imageBaseUrl =
  //     "http://192.168.1.7/cookster_admin/public/storage/";
  static String imageScreen = "${imageBaseUrl}screens";
  static String profileImage = "${imageBaseUrl}front_users";
  static String audioThumbnail = "${imageBaseUrl}audios";
  static String videoUrl = "https://storage.googleapis.com/cookster-storage-v1/videos";
  static String audioUrl = "https://storage.googleapis.com/cookster-storage-v1/audios";

  static String googleMapApiKey = "AIzaSyBxMeZhnLJfK4ax7_GOGDd00OS5-jBFc4M";
}

class EndPoints {
  static String myLikedVideos = "videos/liked_videos_list";
  static String getPaymentKeys = "urway_credentials";
  static String updateReviewVisibility = "update_review_visibility";
  static String updateReviewStatus = "update_review_status";
  static String getReviewList = "user_reviews_list";
  static String addReview = "add_user_review";
  static String getB2BCategoryList = "b2b/b2b_categories";
  static String getB2BList = "b2b/b2b_accounts_list";
  static String b2bStatus = "b2b/change_b2b_status";
  static String blockedUsersList = "blocked_users_list";
  static String blockUser = "block_user";
  static String editVideo = "videos/edit";
  static String followerList = "followers_list";
  static String sponsorVideo = "videos/sponsor/add";
  static String nearedBusiness = "business_accounts/nearest";
  static String subscribe = "packages/subscribe";
  static String changePlanPackages = "packages/list";
  static String notifications = "notifications/list";
  static String addVideoRating = "videos/update_average_rating";
  static String getCity = "cities";
  static String submitEmail = "videos/contact_for_order";
  static String deleteVideo = "videos/delete";
  static String singleVideoDetails = "videos/details";
  static String verifyEmail = "forgot_password/verify_email";
  static String verifyCode = "forgot_password/verify_code";
  static String updatePassword = "forgot_password/update_password";
  static String getSavedVideos = "videos/saved_list";
  static String save = "videos/save_unsave";
  static String submitReport = "videos/reports/add";
  static String contentReport = "reports/categories?type=1";
  static String userProfile = "profile_details";
  static String follow = "follow_unfollow";
  static String unfollow = "follow_unfollow";
  static String removeFollower = "remove_follower";
  static String search = "search";
  static String getVideos = "videos/list";
  static String reels = "reels";
  static String reelsPresign = "reels/presign";
  static String uploadVideo = "videos/create";
  static String videoProcessingStatus = "videos/processing_status";
  static String videoTypes = "videos/settings";
  static String editUserProfile = "edit_profile";
  static String getUserProfile = "profile";
  static String registrationSettings = "registration_settings";
  static String packagesList = "packages/list";
  static String register = "register";
  static String verifyRegistrationOtp = "verify_registration_otp";
  static String resendRegistrationOtp = "resend_registration_otp";
  static String logout = "logout";
  static String login = "login";
  static String loginWithEmail = "login_with_email";
  static String siteSettings = "site_settings";
  static String onBoarding = "started_screens";
  static String validateRegister = "validate_register";
  static String checkUsername = "check_username";
  static String deleteAccount = "delete_account";
}
