import 'package:cookster/core/video/feed_ping_pong_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedPingPongLogic.planPresent', () {
    test('flips when hidden already has requested reel', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'url-a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'b',
          requestUrl: 'url-b',
        ),
        FeedPresentPlan.flipToHidden,
      );
    });

    test('flips on key match even when prefetch URL differs', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'url-a',
          hiddenKey: 'b',
          hiddenUrl: 'file:///cached-b',
          requestKey: 'b',
          requestUrl: 'https://cdn/b.mp4',
        ),
        FeedPresentPlan.flipToHidden,
      );
    });

    test('keeps active when already presenting requested reel', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'url-a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'a',
          requestUrl: 'url-a',
        ),
        FeedPresentPlan.keepActive,
      );
    });

    test('cold opens on hidden then flip when neither slot matches', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'url-a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'c',
          requestUrl: 'url-c',
        ),
        FeedPresentPlan.openOnHiddenThenFlip,
      );
    });

    test('keeps active on key match when URL differs (cache vs remote)', () {
      expect(
        FeedPingPongLogic.planPresent(
          activeKey: 'a',
          activeUrl: 'file:///cached-a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'a',
          requestUrl: 'https://cdn/a.mp4',
        ),
        FeedPresentPlan.keepActive,
      );
    });
  });

  group('FeedPingPongLogic.planPrefetch', () {
    test('skips when hidden already bound', () {
      expect(
        FeedPingPongLogic.planPrefetch(
          activeKey: 'a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'b',
          requestUrl: 'other-url',
        ),
        FeedPrefetchPlan.skipAlreadyBound,
      );
    });

    test('skips when same as active key', () {
      expect(
        FeedPingPongLogic.planPrefetch(
          activeKey: 'a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'a',
          requestUrl: 'url-a',
        ),
        FeedPrefetchPlan.skipSameAsActive,
      );
    });

    test('opens on hidden for next reel', () {
      expect(
        FeedPingPongLogic.planPrefetch(
          activeKey: 'a',
          hiddenKey: 'b',
          hiddenUrl: 'url-b',
          requestKey: 'c',
          requestUrl: 'url-c',
        ),
        FeedPrefetchPlan.openOnHidden,
      );
    });
  });

  group('FeedPingPongLogic.recycle', () {
    test('recycles hidden at threshold', () {
      expect(
        FeedPingPongLogic.shouldRecycleHidden(
          hiddenOpenCount: 3,
          recycleAfterOpens: 3,
        ),
        isTrue,
      );
    });

    test('does not recycle hidden below threshold', () {
      expect(
        FeedPingPongLogic.shouldRecycleHidden(
          hiddenOpenCount: 2,
          recycleAfterOpens: 3,
        ),
        isFalse,
      );
    });
  });

  group('FeedPingPongLogic.flippedActiveIndex', () {
    test('toggles between 0 and 1', () {
      expect(FeedPingPongLogic.flippedActiveIndex(0), 1);
      expect(FeedPingPongLogic.flippedActiveIndex(1), 0);
    });
  });
}
