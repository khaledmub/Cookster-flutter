import 'package:cookster/core/video/feed_ping_pong_controller.dart';
import 'package:cookster/core/video/feed_ping_pong_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for Oppo/MTK logcat failure modes:
/// - flush index runaway on one decoder (visible slot must not cold-open)
/// - AudioTrack start/stop/flush storms (no redundant resume when audible)
/// - renderFps=0 zombie (hidden recycle never touches visible slot index)
void main() {
  group('MTK: visible slot never cold-opens on swipe', () {
    test('prefetched reel flips without openOnHiddenThenFlip', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'n',
          activeUrl: 'u-n',
          hiddenKey: 'n+1',
          hiddenUrl: 'u-n+1',
          requestKey: 'n+1',
          requestUrl: 'u-n+1',
        ),
        FeedPresentPlan.flipToHidden,
      );
    });

    test('cold swipe always uses hidden-then-flip plan', () {
      for (final hiddenKey in ['other', null, '']) {
        expect(
          FeedPingPongLogic.planPresent(
            activeKey: 'current',
            activeUrl: 'u-c',
            hiddenKey: hiddenKey,
            hiddenUrl: hiddenKey == null ? null : 'u-h',
            requestKey: 'target',
            requestUrl: 'u-t',
          ),
          FeedPresentPlan.openOnHiddenThenFlip,
        );
      }
    });

    test('same reel on active is keepActive only (seek/unmute)', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'same',
          activeUrl: 'u-s',
          hiddenKey: 'other',
          hiddenUrl: 'u-o',
          requestKey: 'same',
          requestUrl: 'u-s',
        ),
        FeedPresentPlan.keepActive,
      );
    });
  });

  group('MTK: audio track storm prevention', () {
    test('present and backup resume do not both unmute when audible', () {
      expect(
        FeedPingPongLogic.shouldResumeAudible(
          userPaused: false,
          alreadyAudible: true,
        ),
        isFalse,
      );
    });

    test('feed audible is volume-only not playing flag', () {
      expect(FeedPingPongLogic.isFeedAudibleByVolume(100), isTrue);
      expect(FeedPingPongLogic.isFeedAudibleByVolume(0), isFalse);
      expect(FeedPingPongLogic.isFeedAudibleByVolume(51), isTrue);
    });

    test('suspend blocks unmute on present', () {
      expect(
        FeedPingPongLogic.shouldUnmuteOnPresent(
          userPaused: false,
          suspended: true,
        ),
        isFalse,
      );
    });
  });

  group('MTK: render surface', () {
    test('flip toggles which slot is stacked on top', () {
      expect(FeedPingPongLogic.flippedActiveIndex(0), 1);
      expect(FeedPingPongLogic.flippedActiveIndex(1), 0);
      expect(FeedPingPongLogic.hiddenSlotIndex(0), 1);
    });
  });

  group('MTK: deferred audio until surface paints', () {
    test('present unmute policy defers to frame-ready path', () {
      expect(
        FeedPingPongLogic.shouldUnmuteOnPresent(
          userPaused: false,
          suspended: false,
        ),
        isTrue,
      );
      expect(
        FeedPingPongLogic.shouldResumeAudible(
          userPaused: false,
          alreadyAudible: false,
        ),
        isTrue,
      );
    });
  });

  group('MTK: revisit seek policy', () {
    test('keepActive plan does not cold-open visible slot', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'same',
          activeUrl: 'u-s',
          hiddenKey: 'other',
          hiddenUrl: 'u-o',
          requestKey: 'same',
          requestUrl: 'u-s',
        ),
        FeedPresentPlan.keepActive,
      );
    });
  });

  group('MTK: hidden recycle isolation', () {
    test('player dispose recycle disabled on feed ping-pong path', () {
      expect(FeedPingPongController.hiddenSlotRecycleEnabled, isFalse);
    });

    test('recycle threshold applies to hidden open count only', () {
      expect(
        FeedPingPongLogic.shouldRecycleHidden(
          hiddenOpenCount: 3,
          recycleAfterOpens: 3,
        ),
        isTrue,
      );
      expect(
        FeedPingPongLogic.shouldRecycleHidden(
          hiddenOpenCount: 2,
          recycleAfterOpens: 3,
        ),
        isFalse,
      );
    });

    test('flip toggles active index — recycle decision is independent', () {
      const before = 0;
      final after = FeedPingPongLogic.flippedActiveIndex(before);
      expect(after, 1);
      expect(FeedPingPongLogic.hiddenSlotIndex(after), before);
    });
  });

  group('MTK: stale operation cancellation', () {
    test('fast swipe invalidates older present token', () {
      expect(FeedPingPongLogic.isStaleToken(2, 5), isTrue);
      expect(FeedPingPongLogic.isStaleToken(5, 5), isFalse);
    });

    test('present bumps invalidate in-flight prefetch', () {
      var openToken = 3;
      const prefetchToken = 2;
      expect(
        FeedPingPongLogic.isStaleToken(prefetchToken, openToken),
        isTrue,
      );
      openToken = 2;
      expect(
        FeedPingPongLogic.isStaleToken(prefetchToken, openToken),
        isFalse,
      );
    });
  });
}
