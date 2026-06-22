import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/feed_ping_pong_controller.dart';
import 'package:cookster/core/video/reels_device_capability_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FeedPingPongController slot mode', () {
    test('defaults to single slot for MTK-safe fallback', () {
      final controller = FeedPingPongController();
      expect(controller.singleSlotMode, isTrue);
    });

    test('dual slot when device constraints allow', () {
      final controller = FeedPingPongController(singleSlotMode: false);
      expect(controller.singleSlotMode, isFalse);
    });
  });

  group('DeviceConstraints defaults', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ReelsDeviceCapabilityStore.instance.resetForTesting();
    });

    test('needsSingleSlotFeedSync defaults false before init', () {
      expect(DeviceConstraints.instance.needsSingleSlotFeedSync, isFalse);
    });

    test('deviceTierSync defaults to tier S before init', () {
      expect(DeviceConstraints.instance.deviceTierSync, ReelsDeviceTier.s);
    });
  });
}
