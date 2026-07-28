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

  test('parseVideoFeed reads Near Me geo fields on meta and items', () {
    const body = '''
{
  "status": true,
  "data": [
    {
      "id": "reel-1",
      "city_id": 102874,
      "city_name": "Cairo",
      "distance_km": 2.34,
      "distance_basis": "business",
      "location": "Downtown",
      "latitude": 30.04,
      "longitude": 31.23
    }
  ],
  "meta": {
    "has_more": false,
    "geo_scope": "city",
    "geo_city_id": 102874,
    "geo_city_name": "Cairo",
    "geo_radius_km": 50,
    "geo_expanded": false,
    "geo_fallback": false
  }
}
''';

    final feed = parseVideoFeed(body);

    expect(feed.meta?.geoScope, 'city');
    expect(feed.meta?.geoCityId, 102874);
    expect(feed.meta?.geoCityName, 'Cairo');
    expect(feed.meta?.geoRadiusKm, 50);
    expect(feed.videos?.single.cityId, 102874);
    expect(feed.videos?.single.cityName, 'Cairo');
    expect(feed.videos?.single.distanceKm, closeTo(2.34, 0.001));
    expect(feed.videos?.single.distanceBasis, 'business');
    expect(feed.videos?.single.location, 'Downtown');
  });
}
