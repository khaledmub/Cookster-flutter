import 'package:cookster/core/video/prefetch_indices.dart';
import 'package:cookster/core/video/reels_video_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDirectionalPrefetchIndices', () {
    test('scroll down warms ahead in scroll direction', () {
      final indices = buildDirectionalPrefetchIndices(
        fromIndex: 5,
        towardIndex: 6,
        depth: 4,
      );
      expect(indices, containsAll([6, 7, 10, 4]));
      expect(indices, isNot(contains(2)));
      expect(indices, isNot(contains(3)));
    });

    test('scroll up warms upward indices only', () {
      final indices = buildDirectionalPrefetchIndices(
        fromIndex: 5,
        towardIndex: 4,
        depth: 3,
      );
      expect(indices, containsAll([4, 3, 1, 6]));
      expect(indices, isNot(contains(8)));
      expect(indices, isNot(contains(9)));
    });

    test('fast scroll extra depth extends ahead window', () {
      final base = buildDirectionalPrefetchIndices(
        fromIndex: 0,
        towardIndex: 1,
        depth: 3,
      );
      final boosted = buildDirectionalPrefetchIndices(
        fromIndex: 0,
        towardIndex: 1,
        depth: 3,
        extraDepth: 1,
      );
      expect(boosted.length, greaterThan(base.length));
      expect(boosted, contains(5));
    });
  });

  group('buildSettledPrefetchIndices', () {
    test('keeps forward depth and one item behind', () {
      final indices = buildSettledPrefetchIndices(visibleIndex: 3, depth: 4);
      expect(indices, containsAll([4, 5, 6, 7, 2]));
    });
  });

  group('ReelsVideoCacheManager budget', () {
    test('maps MB budget to object count', () {
      expect(ReelsVideoCacheManager.maxObjectsForBudgetMb(500), 125);
      expect(ReelsVideoCacheManager.maxObjectsForBudgetMb(1024), 256);
      expect(ReelsVideoCacheManager.maxObjectsForBudgetMb(40), 60);
    });
  });
}
