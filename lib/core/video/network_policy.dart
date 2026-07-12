import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkClass { wifi, mobile, offline }

class NetworkPolicy {
  Future<NetworkClass> currentNetworkClass() async {
    final result = await Connectivity().checkConnectivity();
    // Wi-Fi / ethernet are the high-bandwidth path.
    if (result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet)) {
      return NetworkClass.wifi;
    }
    if (result.contains(ConnectivityResult.mobile)) {
      return NetworkClass.mobile;
    }
    // VPN / "other" are online but often bandwidth-limited — use the mobile
    // ladder (360-first + 720 upgrade) instead of uncached 1080.
    if (result.contains(ConnectivityResult.vpn) ||
        result.contains(ConnectivityResult.other)) {
      return NetworkClass.mobile;
    }
    return NetworkClass.offline;
  }
}
