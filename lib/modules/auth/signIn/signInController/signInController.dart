import 'dart:convert';
import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/landing/landingView/landingView.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../services/apiClient.dart';

class LogInController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String userName = '';
  var isObscure = true.obs;
  var isLoading = false.obs;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Initialize GoogleSignIn with the scopes you need
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      await _firestore.collection('users').doc(user['id']).set({
        "uuid": deviceToken, // Add UUID to Firestore
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields
      print('Firestore updated for user: ${user['id']}');
    } catch (e) {
      print('Error updating Firestore: $e');
    }
  }

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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        String token = data['token'];
        Map<String, dynamic> user = data['user'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setInt('entity', user['entity']);

        await prefs.setString('user_id', user['id']);
        await prefs.setString('user_image', user['image'] ?? '');
        print('Saving entity_details: ${user['entity_details']}');
        await prefs.setString(
          'entity_details',
          jsonEncode(user['entity_details']),
        );

        print(
          "PRINTING THE ID: ${user['entity']} AND THE TOKEN: ${deviceToken}",
        );

        // Update Firestore with user data and UUID
        await _updateFirestoreUser(user, deviceToken);

        Get.offAllNamed(AppRoutes.landing);
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

        print("PRINTING THE ENTITY");

        print(user['entity']);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setInt('entity', user['entity']);
        await prefs.setString('user_id', user['id']);
        await prefs.setString('user_image', user['image'] ?? '');
        // await prefs.setString(
        //   'entity_details',
        //   jsonEncode(user['entity_details']),
        // );

        print('Saving entity_details: ${user['entity_details']}');
        await prefs.setString(
          'entity_details',
          jsonEncode(user['entity_details']),
        );

        // Update Firestore with user data and UUID
        await _updateFirestoreUser(user, deviceToken);

        print("NAVIGATING TO THE USER");

        Get.offAll(Landing(initialIndex: 0));
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
    } catch (error) {
      print('Google sign-in error: $error');
      ScaffoldMessenger.of(
        Get.context!,
      ).showSnackBar(SnackBar(content: Text("google_signin_failed".tr)));
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
      print('Facebook sign-in error: $error');
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
