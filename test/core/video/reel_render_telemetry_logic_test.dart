import 'package:cookster/core/video/reel_render_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final telemetry = ReelRenderTelemetry.instance;

  group('ReelRenderTelemetry gate logic', () {
    test('non-Android path returns paintReady without platform bridge', () async {
      expect(telemetry.isSupported, isFalse);

      final confirmed = await telemetry.waitForRenderConfirm(
        playerHandle: 0,
        paintReady: true,
      );
      expect(confirmed, isTrue);

      final held = await telemetry.waitForRenderConfirm(
        playerHandle: 0,
        paintReady: false,
      );
      expect(held, isFalse);
    });

    test('render confirm timeout default is 280ms', () {
      expect(ReelRenderTelemetry.renderConfirmTimeoutMs, 280);
      expect(ReelRenderTelemetry.stallSignatureMs, 250);
    });

    test('unregistered handle falls back to paintReady', () async {
      final confirmed = await telemetry.waitForRenderConfirm(
        playerHandle: 42,
        paintReady: false,
      );
      expect(confirmed, isFalse);
    });
  });
}
