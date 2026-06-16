import 'dart:convert';

import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deletes the account on the server, revokes the session, and returns to sign-in.
Future<bool> deleteAccountAndSignOut() async {
  final response = await ApiClient.postDeleteAccount({});

  Map<String, dynamic>? data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    data = null;
  }

  final ok = response.statusCode == 200 &&
      (data?['status'] == true || data == null || data['status'] == null);
  if (!ok) {
    return false;
  }

  try {
    await ApiClient.postRequest(EndPoints.logout, {});
  } catch (e) {
    debugPrint('Logout after delete failed: $e');
  }

  try {
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Firebase signOut after delete failed: $e');
  }

  try {
    await GoogleSignIn().signOut();
  } catch (e) {
    debugPrint('Google signOut after delete failed: $e');
  }

  ApiClient.setAuthToken(null);

  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  final language = prefs.getString('language') ?? 'en';
  final selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
  final initLanguage = prefs.getBool('initLanguage') ?? false;

  await prefs.clear();
  await prefs.setBool('onboarding_completed', onboardingCompleted);
  await prefs.setString('language', language);
  await prefs.setString('selectedLanguage', selectedLanguage);
  await prefs.setBool('initLanguage', initLanguage);

  await ApiClient.initLanguage();
  Get.offAllNamed(AppRoutes.signIn);
  return true;
}
