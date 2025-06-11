import 'dart:convert';
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String baseUrl = "${Common.baseUrl}";
  static String _language = "en"; // Default language

  // Initialize language from SharedPreferences
  static Future<void> initLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _language =
        prefs.getString('language') ?? "en"; // Default to 'en' if not set
  }

  // Method to update language
  static Future<void> updateLanguage(String languageCode) async {
    _language = languageCode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'language',
      languageCode,
    ); // Save to SharedPreferences
    print("Updated language to: $_language");
  }

  // GET request with authentication
  static Future<http.Response> getRequest(String endpoint) async {
    await initLanguage(); // Ensure language is initialized
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    print("Token: $token");
    print("Language: $_language");

    final response = await http.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: {
        "Accept": "application/json",
        "Accept-Language": _language,
        "Authorization": token != null ? "Bearer $token" : "",
      },
    );

    return response;
  }

  // POST request with authentication
  static Future<http.Response> postRequest(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initLanguage(); // Ensure language is initialized
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    print("Token: $token");
    print("Language: $_language");

    final response = await http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: {
        "Accept": "application/json",
        "Accept-Language": _language,
        "Content-Type": "application/json",
        "Authorization": token != null ? "Bearer $token" : "",
      },
      body: jsonEncode(data),
    );

    return response;
  }

  static Future<http.Response> postDeleteAccount(
    Map<String, dynamic> data,
  ) async {
    await initLanguage(); // Ensure language is initialized
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    print("Token: $token");
    print("Language: $_language");

    final response = await http.post(
      Uri.parse("$baseUrl${EndPoints.deleteAccount}"),
      headers: {
        "Accept": "application/json",
        "Accept-Language": _language,
        "Content-Type": "application/json",
        "Authorization": token != null ? "Bearer $token" : "",
      },
      body: jsonEncode(data),
    );

    return response;
  }

  // DELETE request with authentication
  static Future<http.Response> deleteRequest(String endpoint) async {
    await initLanguage(); // Ensure language is initialized
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    print("Token: $token");
    print("Language: $_language");

    final response = await http.delete(
      Uri.parse("$baseUrl$endpoint"),
      headers: {
        "Accept": "application/json",
        "Accept-Language": _language,
        "Authorization": token != null ? "Bearer $token" : "",
      },
    );

    return response;
  }
}
