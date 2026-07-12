import 'package:cookster/core/video/network_policy.dart';
import 'package:cookster/core/video/video_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = VideoSourceResolver();

  VideoSourceCandidate mp4(String tier) => VideoSourceCandidate(
        url: 'https://cdn.example.com/videos/1/$tier.mp4',
        type: 'mp4_quality',
      );

  VideoSourceCandidate hls() => const VideoSourceCandidate(
        url: 'https://cdn.example.com/videos/1/hls/master.m3u8',
        type: 'hls',
      );

  group('prioritizeForNetwork', () {
    test('phone wifi prefers 360 then 720 then 1080 with fast start', () {
      final ordered = resolver.prioritizeForNetwork(
        [mp4('360'), mp4('1080'), mp4('720')],
        NetworkClass.wifi,
        isTablet: false,
        fastStartUncached: true,
      );
      expect(
        ordered.map((c) => resolver.mp4Tier(c.url)).toList(),
        ['360', '720', '1080'],
      );
    });

    test('phone wifi prefers 1080 then 720 then 360 without fast start', () {
      final ordered = resolver.prioritizeForNetwork(
        [mp4('360'), mp4('1080'), mp4('720')],
        NetworkClass.wifi,
        isTablet: false,
        fastStartUncached: false,
      );
      expect(
        ordered.map((c) => resolver.mp4Tier(c.url)).toList(),
        ['1080', '720', '360'],
      );
    });

    test('tablet wifi prefers 1080 then 720 then 360', () {
      final ordered = resolver.prioritizeForNetwork(
        [mp4('360'), mp4('1080'), mp4('720')],
        NetworkClass.wifi,
        isTablet: true,
      );
      expect(
        ordered.map((c) => resolver.mp4Tier(c.url)).toList(),
        ['1080', '720', '360'],
      );
    });

    test('mobile fast start prefers 360 then 720 then 1080', () {
      final ordered = resolver.prioritizeForNetwork(
        [mp4('360'), mp4('1080'), mp4('720')],
        NetworkClass.mobile,
        fastStartUncached: true,
      );
      expect(
        ordered.map((c) => resolver.mp4Tier(c.url)).toList(),
        ['360', '720', '1080'],
      );
    });

    test('wifi HLS first when hlsWifiFirst enabled', () {
      final ordered = resolver.prioritizeForNetwork(
        [mp4('360'), mp4('720'), hls()],
        NetworkClass.wifi,
        hlsWifiFirst: true,
      );
      expect(ordered.first.type, 'hls');
    });

    test('single candidate is unchanged', () {
      final single = [mp4('720')];
      expect(
        resolver.prioritizeForNetwork(single, NetworkClass.wifi),
        single,
      );
    });
  });

  group('prioritizeForPreload', () {
    test('visible reel prefetches 720 then 1080 for fast partial cache', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 0,
        dualTier: true,
      );
      expect(ordered.length, 2);
      expect(resolver.mp4Tier(ordered[0].url), '720');
      expect(resolver.mp4Tier(ordered[1].url), '1080');
    });

    test('adjacent indices prefetch 720 then 1080 when available', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 1,
        dualTier: true,
      );
      expect(ordered.length, 3);
      expect(resolver.mp4Tier(ordered[0].url), '720');
      expect(resolver.mp4Tier(ordered[1].url), '1080');
      expect(resolver.mp4Tier(ordered[2].url), '360');
    });

    test('offset 2 still prefetches 720 then 1080 when available', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 2,
        dualTier: true,
      );
      expect(ordered.length, 3);
      expect(resolver.mp4Tier(ordered[0].url), '720');
      expect(resolver.mp4Tier(ordered[1].url), '1080');
    });

    test('deep offset returns 720 when 1080 exists', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 4,
        dualTier: true,
      );
      expect(ordered.length, 1);
      expect(resolver.mp4Tier(ordered.first.url), '720');
    });

    test('falls back to 720 and 360 when no 1080 in dual tier window', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('360'), mp4('720')],
        offsetFromVisible: 1,
        dualTier: true,
      );
      expect(ordered.length, 2);
      expect(resolver.mp4Tier(ordered[0].url), '720');
      expect(resolver.mp4Tier(ordered[1].url), '360');
    });

    test('falls back to 360 only when no 720 or 1080', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('360')],
        offsetFromVisible: 1,
        dualTier: true,
      );
      expect(ordered.length, 1);
      expect(resolver.mp4Tier(ordered.first.url), '360');
    });
  });
}
