import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/feed_ping_pong_controller.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('needsSingleSlotFeedSync defaults true before init', () {
      expect(DeviceConstraints.instance.needsSingleSlotFeedSync, isTrue);
    });

    test('deviceTierSync defaults to tier B before init', () {
      expect(DeviceConstraints.instance.deviceTierSync, ReelsDeviceTier.b);
    });
  });
}
