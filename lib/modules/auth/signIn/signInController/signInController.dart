import 'dart:convert';
import 'dart:math';
import 'package:cookster/appBindings/app_bindings.dart';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../services/apiClient.dart';

class LogInController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String userName = '';
  var isObscure = true.obs;
  var isLoading = false.obs;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Web client ID from Firebase project (google-services.json client_type: 3).
  // Required in some release/Play builds to reliably get ID token.
  static const String _googleServerClientId =
      '588874074588-ls288jb68aq4dh7igmc5iqr60ogj1o74.apps.googleusercontent.com';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: _googleServerClientId,
  );

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _userIdFromApi(dynamic id) => id?.toString() ?? '';

  static int _entityFromApi(dynamic entity) {
    if (entity is int) {
      return entity;
    }
    if (entity is String) {
      return int.tryParse(entity) ?? 0;
    }
    return 0;
  }

  bool _loginRequiresOtp(Map<String, dynamic> data) {
    return data['otp_required'] == true || data['requires_otp'] == true;
  }

  Future<void> _navigateToRegistrationOtp(
    Map<String, dynamic> user,
    String? deviceToken,
  ) async {
    final email =
        user['email']?.toString() ?? emailController.text.trim();
    try {
      await ApiClient.postRequest(EndPoints.resendRegistrationOtp, {
        'user_id': _userIdFromApi(user['id']),
      });
    } catch (e) {
      debugPrint('Resend registration OTP failed: $e');
    }

    Get.toNamed(
      AppRoutes.signUpOtp,
      arguments: {
        'user': user,
        'email': email,
        'deviceToken': deviceToken,
      },
    );
  }

  Future<void> _completeAuthenticatedLogin(
    Map<String, dynamic> data,
    String? deviceToken,
  ) async {
    final token = data['token']?.toString();
    final user = data['user'];
    if (token == null ||
        token.isEmpty ||
        user is! Map<String, dynamic>) {
      throw StateError('Missing auth token or user payload');
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    ApiClient.setAuthToken(token);
    await prefs.setInt('entity', _entityFromApi(user['entity']));
    await prefs.setString('user_id', _userIdFromApi(user['id']));
    await prefs.setString(
      'user_image',
      user['image']?.toString() ?? '',
    );
    debugPrint('Saving entity_details: ${user['entity_details']}');
    await prefs.setString(
      'entity_details',
      jsonEncode(user['entity_details']),
    );

    await _updateFirestoreUser(user, deviceToken);
    Get.offAllNamed(AppRoutes.landing);
  }

  void togglePasswordVisibility() {
    isObscure.value = !isObscure.value;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'email_required_error'.tr;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) return 'email_invalid_error'.tr;
    return null;
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
    return null;
  }

  // Function to update Firestore with user data and UUID
  Future<void> _updateFirestoreUser(
    Map<String, dynamic> user,
    String? deviceToken,
  ) async {
    try {
      debugPrint("This is the device token: ${deviceToken}");
      await _firestore.collection('users').doc(_userIdFromApi(user['id'])).set({
        "uuid": deviceToken, // Add UUID to Firestore
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields
      debugPrint('Firestore updated for user: ${user['id']}');
    } catch (e) {
      debugPrint('Error updating Firestore: $e');
    }
  }

  // Future<void> subscribeUserToTopics(String entity) async {
  //   FirebaseMessaging messaging = FirebaseMessaging.instance;
  //
  //   try {
  //     // Fixed topic
  //     await messaging.subscribeToTopic("cookster");
  //     debugPrint("✅ Subscribed to cookster");
  //
  //     // Dynamic topic based on entity
  //     String topicName = "type_$entity";
  //     await messaging.subscribeToTopic(topicName);
  //     debugPrint("✅ Subscribed to $topicName");
  //   } catch (e) {
  //     debugPrint("❌ Error subscribing to topics: $e");
  //   }
  // }

  Future<void> loginUser() async {
    isLoading.value = true;
    final endpoint = EndPoints.login;

    String? deviceToken = await FirebaseMessaging.instance.getToken();

    try {
      final response = await ApiClient.postRequest(endpoint, {
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'uuid': deviceToken,
      });

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == true) {
        if (_loginRequiresOtp(data)) {
          final user = data['user'];
          if (user is Map<String, dynamic>) {
            await _navigateToRegistrationOtp(user, deviceToken);
            return;
          }
        }
        await _completeAuthenticatedLogin(data, deviceToken);
      } else if (response.statusCode == 200 &&
          data['user'] is Map<String, dynamic> &&
          _loginRequiresOtp(data)) {
        await _navigateToRegistrationOtp(
          data['user'] as Map<String, dynamic>,
          deviceToken,
        );
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Login failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithEmailUser() async {
    isLoading.value = true;
    String? deviceToken = await FirebaseMessaging.instance.getToken();

    try {
      final response = await ApiClient.postRequest(EndPoints.loginWithEmail, {
        'email': emailController.text.trim(),
        'uuid': deviceToken,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        String token = data['token'];
        Map<String, dynamic> user = data['user'];

        debugPrint("PRINTING THE ENTITY");

        debugPrint('${user['entity']}');

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        ApiClient.setAuthToken(token);
        await prefs.setInt('entity', _entityFromApi(user['entity']));
        await prefs.setString('user_id', _userIdFromApi(user['id']));
        await prefs.setString(
          'user_image',
          user['image']?.toString() ?? '',
        );
        // await prefs.setString(
        //   'entity_details',
        //   jsonEncode(user['entity_details']),
        // );

        debugPrint('Saving entity_details: ${user['entity_details']}');
        await prefs.setString(
          'entity_details',
          jsonEncode(user['entity_details']),
        );

        // await subscribeUserToTopics(user['entity'].toString());

        // Update Firestore with user data and UUID
        await _updateFirestoreUser(user, deviceToken);

        debugPrint("NAVIGATING TO THE USER");

        Get.offAll(
          () => Landing(initialIndex: 0),
          binding: LandingBinding(),
        );
      } else {
        Get.toNamed(
          AppRoutes.signUp,
          parameters: {'email': emailController.text.trim(), 'name': userName},
        );

        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text('enter_inform_to_signup'.tr),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('loginWithEmailUser error: $e\n$stack');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text(
            'something_went_wrong'.tr,
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // Create a SHA256 hash of the nonce
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    isLoading.value = true;

    try {
      // Generate a nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple Sign-In
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create an OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,

        accessToken: appleCredential.authorizationCode,
      );

      // Sign in with Firebase
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(oauthCredential);

      // Extract user information
      final String? email =
          userCredential.user?.email ?? appleCredential.email ?? '';
      final String? name =
          appleCredential.givenName != null &&
                  appleCredential.familyName != null
              ? '${appleCredential.givenName} ${appleCredential.familyName}'
              : userCredential.user?.displayName ?? '';

      emailController.text = email!;
      userName = name ?? '';

      // Call loginWithEmailUser to handle API and Firestore update
      await loginWithEmailUser();
    } catch (error) {
      debugPrint('Apple sign-in error: $error');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('apple_signin_failed'.tr),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isLoading.value = true;

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        isLoading.value = false;
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message:
              'Google returned an empty ID token. Check OAuth client IDs and SHA fingerprints in Firebase.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final String email = userCredential.user?.email ?? '';
      final String name = userCredential.user?.displayName ?? '';
      emailController.text = email;
      userName = name;

      // Call loginWithEmailUser to handle API and Firestore update
      await loginWithEmailUser();
    } on FirebaseAuthException catch (error, stack) {
      debugPrint('Google FirebaseAuth error: ${error.code} ${error.message}\n$stack');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'missing-id-token'
                ? 'google_signin_failed'.tr
                : 'Google: ${error.code}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stack) {
      debugPrint('Google sign-in error: $error\n$stack');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('google_signin_failed'.tr),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithFacebook() async {
    isLoading.value = true;

    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();

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
      userName = name;
      emailController.text = email;

      // Call loginWithEmailUser to handle API and Firestore update
      await loginWithEmailUser();
    } catch (error) {
      debugPrint('Facebook sign-in error: $error');
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(SnackBar(content: Text("google_signin_failed".tr)));
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    ApiClient.setAuthToken(null);

    await _googleSignIn.signOut();

    Get.snackbar(
      'Logged Out',
      'You have been logged out successfully!',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );

    Get.offAllNamed('/login');
  }
}
