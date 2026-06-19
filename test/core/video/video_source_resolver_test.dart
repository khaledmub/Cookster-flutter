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
    test('dual tier returns 360 and 720 for adjacent indices', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 1,
        dualTier: true,
      );
      expect(ordered.length, 2);
      expect(resolver.mp4Tier(ordered[0].url), '360');
      expect(resolver.mp4Tier(ordered[1].url), '720');
    });

    test('deep offset returns 720 only', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360'), mp4('720')],
        offsetFromVisible: 4,
        dualTier: true,
      );
      expect(ordered.length, 1);
      expect(resolver.mp4Tier(ordered.first.url), '720');
    });

    test('falls back to 360 when no 720 in dual tier window', () {
      final ordered = resolver.prioritizeForPreload(
        [mp4('1080'), mp4('360')],
        offsetFromVisible: 1,
        dualTier: true,
      );
      expect(ordered.length, 1);
      expect(resolver.mp4Tier(ordered.first.url), '360');
    });
  });
}
