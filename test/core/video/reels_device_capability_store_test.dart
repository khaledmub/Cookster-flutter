import 'package:cookster/core/video/device_constraints.dart';
import 'package:cookster/core/video/reels_device_capability_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = ReelsDeviceCapabilityStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store.resetForTesting();
    await store.load();
  });

  group('ReelsDeviceCapabilityStore', () {
    test('fresh profile defaults to tier S', () {
      expect(store.profile.measuredTier, ReelsDeviceTier.s);
      expect(store.profile.consecutiveCleanOpens, 0);
      expect(store.profile.hasCompletedFirstMeasuredOpen, isFalse);
    });

    test('seedInitialTierIfNeeded applies brand prior on fresh install', () async {
      await store.seedInitialTierIfNeeded(ReelsDeviceTier.b);
      expect(store.profile.measuredTier, ReelsDeviceTier.b);
      await store.seedInitialTierIfNeeded(ReelsDeviceTier.a);
      expect(store.profile.measuredTier, ReelsDeviceTier.b);
    });

    test('demotes one tier per failure signature', () async {
      final demoted = await store.recordFailure('timeout');
      expect(demoted, ReelsDeviceTier.a);
      expect(store.profile.measuredTier, ReelsDeviceTier.a);
      expect(store.profile.consecutiveCleanOpens, 0);
      expect(store.profile.hasCompletedFirstMeasuredOpen, isTrue);
      expect(store.profile.failureSignatures, ['timeout']);
    });

    test('promotes after five consecutive clean opens', () async {
      await store.recordFailure('a');
      expect(store.profile.measuredTier, ReelsDeviceTier.a);

      for (var i = 0; i < 4; i++) {
        final promoted = await store.recordCleanOpen();
        expect(promoted, isNull);
      }
      final promoted = await store.recordCleanOpen();
      expect(promoted, ReelsDeviceTier.s);
      expect(store.profile.measuredTier, ReelsDeviceTier.s);
      expect(store.profile.consecutiveCleanOpens, 0);
    });

    test('failure ring caps at 20 entries', () async {
      for (var i = 0; i < 25; i++) {
        await store.recordFailure('sig$i');
      }
      expect(
        store.profile.failureSignatures.length,
        ReelsDeviceCapabilityProfile.failureRingMax,
      );
      expect(store.profile.failureSignatures.first, 'sig5');
      expect(store.profile.failureSignatures.last, 'sig24');
    });

    test('app version change resets clean-open streak only', () async {
      store.resetForTesting();
      SharedPreferences.setMockInitialValues({});
      await store.load(currentAppVersion: '1.0.0');
      for (var i = 0; i < 3; i++) {
        await store.recordCleanOpen();
      }
      expect(store.profile.consecutiveCleanOpens, 3);
      expect(store.profile.storedAppVersion, '1.0.0');

      store.resetForTesting();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reels_device_capability_profile_v1',
        '{"measuredTier":"s","consecutiveCleanOpens":3,'
            '"failureSignatures":[],"lastMeasuredAtMs":0,'
            '"hasCompletedFirstMeasuredOpen":true,"storedAppVersion":"1.0.0"}',
      );
      await store.load(currentAppVersion: '2.0.0');

      expect(store.profile.measuredTier, ReelsDeviceTier.s);
      expect(store.profile.consecutiveCleanOpens, 0);
      expect(store.profile.storedAppVersion, '2.0.0');
    });
  });
}
