import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String get baseUrl => Common.baseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 25);
  static const Duration _retryBackoff = Duration(milliseconds: 200);

  static final http.Client _client = http.Client();
  static String _language = 'en';
  static String? _authToken;
  static bool _languageLoaded = false;

  static Future<void> hydrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _language = prefs.getString('language') ?? 'en';
    _languageLoaded = true;
  }

  static Future<void> initLanguage() async {
    if (_languageLoaded) return;
    await hydrateFromPrefs();
  }

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static Future<void> updateLanguage(String languageCode) async {
    _language = languageCode;
    _languageLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
  }

  static Map<String, String> _headers({bool jsonBody = false}) {
    return {
      'Accept': 'application/json',
      'Accept-Language': _language,
      if (jsonBody) 'Content-Type': 'application/json',
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
    };
  }

  static bool _isRetryable(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool allowRetry = false,
  }) async {
    await initLanguage();
    try {
      return await request().timeout(_defaultTimeout);
    } catch (e) {
      if (allowRetry && _isRetryable(e)) {
        await Future.delayed(_retryBackoff);
        return await request().timeout(_defaultTimeout);
      }
      rethrow;
    }
  }

  static Uri _resolveUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }
    return Uri.parse('$baseUrl$endpoint');
  }

  static Future<http.Response> getRequest(String endpoint) async {
    final uri = _resolveUri(endpoint);
    if (kDebugMode) {
      debugPrint('GET $uri');
    }
    return _send(
      () => _client.get(
        uri,
        headers: _headers(),
      ),
      allowRetry: true,
    );
  }

  static Future<http.Response> postRequest(
    String endpoint,
    Map<String, dynamic> data, {
    bool allowRetry = false,
  }) async {
    final uri = _resolveUri(endpoint);
    if (kDebugMode) {
      debugPrint('POST $uri');
    }
    return _send(
      () => _client.post(
        uri,
        headers: _headers(jsonBody: true),
        body: jsonEncode(data),
      ),
      allowRetry: allowRetry,
    );
  }

  static Future<http.Response> multipartPost(
    String endpoint, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
  }) async {
    await initLanguage();
    final uri = _resolveUri(endpoint);
    if (kDebugMode) {
      debugPrint('MULTIPART POST $uri');
    }
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers());
    request.fields.addAll(fields);
    request.files.addAll(files);
  return sendMultipartRequest(request);
  }

  /// Sends a pre-built [MultipartRequest] with shared auth, language, and timeout.
  static Future<http.Response> sendMultipartRequest(
    http.MultipartRequest request,
  ) async {
    await initLanguage();
    for (final entry in _headers().entries) {
      request.headers.putIfAbsent(entry.key, () => entry.value);
    }
    final streamed = await request.send().timeout(_defaultTimeout);
    final body = await streamed.stream.bytesToString();
    return http.Response(body, streamed.statusCode, headers: streamed.headers);
  }

  static Future<http.Response> postDeleteAccount(
    Map<String, dynamic> data,
  ) async {
    return _send(
      () => _client.post(
        Uri.parse('$baseUrl${EndPoints.deleteAccount}'),
        headers: _headers(jsonBody: true),
        body: jsonEncode(data),
      ),
    );
  }

  static Future<http.Response> deleteRequest(String endpoint) async {
    final uri = _resolveUri(endpoint);
    return _send(
      () => _client.delete(
        uri,
        headers: _headers(),
      ),
    );
  }
}
