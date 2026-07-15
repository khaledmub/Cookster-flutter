import 'package:flutter/material.dart';

/// First Accept after install leaves a delayed [Navigator.pop] that forces the
/// upload form off (~150–800ms). [PopScope.canPop] cannot stop [Navigator.pop]
/// — only [Route.didPop] returning false can refuse it.
class UploadFormPopGuard {
  UploadFormPopGuard() : absorbing = ValueNotifier<bool>(true) {
    active = this;
  }

  /// Currently pushed upload-form guard (if any). Clear before intentional
  /// navigation (publish [Get.offAll], user back).
  static UploadFormPopGuard? active;

  final ValueNotifier<bool> absorbing;

  /// Set when the form was disposed while still absorbing (forced pop won).
  bool closedByStalePop = false;

  void allowUserPop() {
    absorbing.value = false;
  }

  void dispose() {
    if (active == this) {
      active = null;
    }
    absorbing.dispose();
  }
}

class UploadFormPageRoute extends MaterialPageRoute<void> {
  UploadFormPageRoute({
    required this.guard,
    required WidgetBuilder builder,
  }) : super(
          builder: builder,
          settings: const RouteSettings(name: '/VideoPreviewScreen'),
        );

  final UploadFormPopGuard guard;

  @override
  bool didPop(void result) {
    if (guard.absorbing.value) {
      return false;
    }
    return super.didPop(result);
  }
}
