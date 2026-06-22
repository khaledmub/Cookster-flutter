import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mutes feed playback when a Get route is pushed; attempts resume on pop.
class ReelsPlaybackRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _onRouteStackChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _onRouteStackChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _onRouteStackChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _onRouteStackChanged();
  }

  void _onRouteStackChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<HomeController>()) {
        return;
      }
      final home = Get.find<HomeController>();
      home.syncPlaybackWithRouteStack(
        hasOverlay: Get.key.currentState?.canPop() ?? false,
      );
    });
  }
}
