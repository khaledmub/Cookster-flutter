import 'dart:convert';
import 'dart:io'; // For File operations
import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // For accessing app's storage
import 'app_config_model.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() => _instance;

  ConfigService._internal();

  AppConfig? _config;

  /// Load config from local assets and print it
  Future<void> loadLocalConfig() async {
    final jsonString = await rootBundle.loadString('assets/appconfig.json');
    final jsonMap = json.decode(jsonString);
    final localConfig = AppConfig.fromJson(jsonMap);

    print("🔹 Local appconfig.json loaded:");
    print("  Merchant Key: ${localConfig.merchantKey}");
    print("  Terminal ID: ${localConfig.terminalId}");
    print("  Terminal Pass: ${localConfig.terminalPass}");
    print("  Request URL: ${localConfig.requestUrl}");

    // Save to _config if no API fetched yet
    _config ??= localConfig;
  }

  /// Fetch config from API, save to local file, and print both for comparison
  Future<void> fetchConfigFromApi() async {
    print("🌐 Fetching config from API...");

    try {
      final response = await http.get(
        Uri.parse("${Common.baseUrl}${EndPoints.getPaymentKeys}"),
      );

      print("🔹 API Status Code: ${response.statusCode}");
      print("🔹 API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body);
        _config = AppConfig.fromJson(jsonMap);
        print("✅ Config updated from API.");

        // Print updated values from API
        print("🔸 Updated Config from API:");
        print("  Merchant Key: ${_config!.merchantKey}");
        print("  Terminal ID: ${_config!.terminalId}");
        print("  Terminal Pass: ${_config!.terminalPass}");
        print("  Request URL: ${_config!.requestUrl}");

        // Save API response to a local file
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/appconfig.json');
        await file.writeAsString(json.encode(jsonMap));
        print("💾 API config saved to local file: ${file.path}");

        // Read and print the saved local file for comparison
        print("🔄 Reading and printing saved local config for comparison:");
        final savedJsonString = await file.readAsString();
        final savedJsonMap = json.decode(savedJsonString);
        final savedConfig = AppConfig.fromJson(savedJsonMap);
        print("🔹 Saved local config contents:");
        print("  Merchant Key: ${savedConfig.merchantKey}");
        print("  Terminal ID: ${savedConfig.terminalId}");
        print("  Terminal Pass: ${savedConfig.terminalPass}");
        print("  Request URL: ${savedConfig.requestUrl}");

        // Optionally, print original asset file for reference
        print("🔄 Reloading and printing original asset appconfig.json for reference:");
        final assetJsonString = await rootBundle.loadString('assets/appconfig.json');
        final assetJsonMap = json.decode(assetJsonString);
        final assetConfig = AppConfig.fromJson(assetJsonMap);
        print("🔹 Original asset appconfig.json contents:");
        print("  Merchant Key: ${assetConfig.merchantKey}");
        print("  Terminal ID: ${assetConfig.terminalId}");
        print("  Terminal Pass: ${assetConfig.terminalPass}");
        print("  Request URL: ${assetConfig.requestUrl}");
      } else {
        print("❌ Failed to fetch config from API.");
      }
    } catch (e) {
      print("❗ Error while fetching API config: $e");
    }
  }

  AppConfig get config {
    if (_config == null) {
      throw Exception("App config not loaded yet.");
    }
    return _config!;
  }

  bool get isConfigLoaded => _config != null;
}