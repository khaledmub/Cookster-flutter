import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkClass { wifi, mobile, offline }

class NetworkPolicy {
  Future<NetworkClass> currentNetworkClass() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.wifi)) {
      return NetworkClass.wifi;
    }
    if (result.contains(ConnectivityResult.mobile)) {
      return NetworkClass.mobile;
    }
    return NetworkClass.offline;
  }
}
