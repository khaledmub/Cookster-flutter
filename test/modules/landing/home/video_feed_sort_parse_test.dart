import 'package:cookster/core/parsing/feed_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseVideoFeed reads data array, timestamps, and meta.sort_by', () {
    const body = '''
{
  "status": true,
  "data": [
    {
      "id": "b26dd728-0000-0000-0000-000000000001",
      "created_at": "2025-04-26T10:00:00.000000Z",
      "updated_at": "2025-04-26T10:00:00.000000Z"
    },
    {
      "id": "bfa12f15-0000-0000-0000-000000000002",
      "created_at": "2026-06-27T14:54:33.000000Z",
      "updated_at": "2026-06-27T14:54:33.000000Z"
    }
  ],
  "meta": {
    "has_more": false,
    "sort_by": "oldest"
  }
}
''';

    final feed = parseVideoFeed(body);

    expect(feed.videos, hasLength(2));
    expect(feed.videos!.first.id, 'b26dd728-0000-0000-0000-000000000001');
    expect(feed.videos!.first.createdAt, '2025-04-26T10:00:00.000000Z');
    expect(feed.meta?.sortBy, 'oldest');
  });
}
