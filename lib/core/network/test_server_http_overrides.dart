import 'dart:io';

import 'package:cookster/appUtils/apiEndPoints.dart';

/// Allows HTTPS to the GCP test VM when the cert is issued for cookster.org.
class TestServerHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final testIp = Common.testServerIp;
    if (testIp.isNotEmpty) {
      client.badCertificateCallback = (cert, host, port) {
        return host == testIp;
      };
    }
    return client;
  }
}
