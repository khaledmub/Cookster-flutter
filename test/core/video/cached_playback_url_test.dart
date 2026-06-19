import 'dart:io';
import 'dart:typed_data';

import 'package:cookster/core/video/cached_playback_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikeFastStartMp4', () {
    test('returns true when moov precedes mdat', () async {
      final dir = await Directory.systemTemp.createTemp('reels_cache_test');
      final file = File('${dir.path}/fast.mp4');
      final bytes = Uint8List.fromList([
        ...List.filled(8, 0),
        ...'moov'.codeUnits,
        ...List.filled(40, 0),
        ...'mdat'.codeUnits,
      ]);
      await file.writeAsBytes(bytes);
      expect(await looksLikeFastStartMp4(file), isTrue);
      await dir.delete(recursive: true);
    });

    test('returns false when mdat precedes moov', () async {
      final dir = await Directory.systemTemp.createTemp('reels_cache_test');
      final file = File('${dir.path}/slow.mp4');
      final bytes = Uint8List.fromList([
        ...List.filled(8, 0),
        ...'mdat'.codeUnits,
        ...List.filled(40, 0),
        ...'moov'.codeUnits,
      ]);
      await file.writeAsBytes(bytes);
      expect(await looksLikeFastStartMp4(file), isFalse);
      await dir.delete(recursive: true);
    });
  });
}
