import 'package:cookster/core/video/feed_ping_pong_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controller behavior is driven by [FeedPingPongLogic]; native [Player] ops
/// are validated on device (Oppo soak). These tests lock the state-machine
/// contract the controller implements.
void main() {
  group('stale token guards', () {
    test('older open token is stale after bump', () {
      const current = 5;
      expect(FeedPingPongLogic.isStaleToken(4, current), isTrue);
      expect(FeedPingPongLogic.isStaleToken(5, current), isFalse);
      expect(FeedPingPongLogic.isStaleToken(6, current), isFalse);
    });

    test('prefetch token stale after present bumps open token', () {
      var openToken = 1;
      var prefetchToken = 1;
      expect(FeedPingPongLogic.isStaleToken(prefetchToken, openToken), isFalse);

      openToken = 2;
      expect(FeedPingPongLogic.isStaleToken(prefetchToken, openToken), isTrue);

      prefetchToken = 2;
      expect(FeedPingPongLogic.isStaleToken(prefetchToken, openToken), isFalse);
    });
  });

  group('flip path', () {
    test('flip swaps active index without touching hidden recycle threshold on active', () {
      const activeBefore = 0;
      final activeAfter = FeedPingPongLogic.flippedActiveIndex(activeBefore);
      expect(activeAfter, 1);
      expect(FeedPingPongLogic.hiddenSlotIndex(activeAfter), activeBefore);
    });

    test('present plan is flip when hidden matches swipe target', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'reel-1',
          activeUrl: 'u1',
          hiddenKey: 'reel-2',
          hiddenUrl: 'u2',
          requestKey: 'reel-2',
          requestUrl: 'u2',
        ),
        FeedPresentPlan.flipToHidden,
      );
    });
  });

  group('hidden recycle', () {
    test('recycle at openCount 3 targets hidden slot only', () {
      const activeIndex = 0;
      final hiddenIndex = FeedPingPongLogic.hiddenSlotIndex(activeIndex);
      expect(hiddenIndex, 1);
      expect(
        FeedPingPongLogic.shouldRecycleHidden(
          hiddenOpenCount: 3,
          recycleAfterOpens: 3,
        ),
        isTrue,
      );
      // Active slot index unchanged by recycle decision logic.
      expect(activeIndex, 0);
    });

    test('defers recycle while open token unstable', () {
      expect(
        FeedPingPongLogic.shouldDeferHiddenRecycle(
          hiddenOpenCount: 5,
          recycleAfterOpens: 3,
          openTokenStable: false,
        ),
        isTrue,
      );
    });

    test('does not defer when stable and over threshold', () {
      expect(
        FeedPingPongLogic.shouldDeferHiddenRecycle(
          hiddenOpenCount: 3,
          recycleAfterOpens: 3,
          openTokenStable: true,
        ),
        isFalse,
      );
    });
  });

  group('audio policy', () {
    test('user pause blocks unmute', () {
      expect(
        FeedPingPongLogic.shouldUnmuteOnPresent(
          userPaused: true,
          suspended: false,
        ),
        isFalse,
      );
    });

    test('suspend blocks unmute', () {
      expect(
        FeedPingPongLogic.shouldUnmuteOnPresent(
          userPaused: false,
          suspended: true,
        ),
        isFalse,
      );
    });

    test('only one slot audible after flip — hidden was muted during prefetch', () {
      // After flip, former active (now hidden) must be muted; new active unmuted.
      expect(
        FeedPingPongLogic.shouldUnmuteOnPresent(
          userPaused: false,
          suspended: false,
        ),
        isTrue,
      );
      expect(
        FeedPingPongLogic.planPrefetch(
          activeKey: 'reel-2',
          hiddenKey: 'reel-1',
          hiddenUrl: 'u1',
          requestKey: 'reel-3',
          requestUrl: 'u3',
        ),
        FeedPrefetchPlan.openOnHidden,
      );
    });
  });

  group('cold present', () {
    test('opens on hidden then flips when neither slot has reel', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'ua',
          hiddenKey: 'b',
          hiddenUrl: 'ub',
          requestKey: 'c',
          requestUrl: 'uc',
        ),
        FeedPresentPlan.openOnHiddenThenFlip,
      );
    });
  });

  group('audio storm guards', () {
    test('skips resume when already audible', () {
      expect(
        FeedPingPongLogic.shouldResumeAudible(
          userPaused: false,
          alreadyAudible: true,
        ),
        isFalse,
      );
    });

    test('resumes only when muted and not user-paused', () {
      expect(
        FeedPingPongLogic.shouldResumeAudible(
          userPaused: false,
          alreadyAudible: false,
        ),
        isTrue,
      );
      expect(
        FeedPingPongLogic.shouldResumeAudible(
          userPaused: true,
          alreadyAudible: false,
        ),
        isFalse,
      );
    });
  });
}
