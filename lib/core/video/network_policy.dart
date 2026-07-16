import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkClass { wifi, mobile, offline }

class NetworkPolicy {
  Future<NetworkClass> currentNetworkClass() async {
    final result = await Connectivity().checkConnectivity();
    // Any online link uses the high-bandwidth (Wi-Fi) path — same preload
    // depth, quality ladder, and HD upgrade on cellular as on Wi-Fi. We used
    // to throttle mobile / VPN and the feed felt slow only on data.
    if (result.contains(ConnectivityResult.none) || result.isEmpty) {
      return NetworkClass.offline;
    }
    if (result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet) ||
        result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.vpn) ||
        result.contains(ConnectivityResult.other)) {
      return NetworkClass.wifi;
    }
    return NetworkClass.offline;
  }
}
