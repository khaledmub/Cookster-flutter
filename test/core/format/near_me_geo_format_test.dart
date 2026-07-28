import 'package:cookster/core/format/near_me_geo_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatNearMeDistanceKm uses meters under 1 km', () {
    expect(formatNearMeDistanceKm(0.85), '850m');
    expect(formatNearMeDistanceKm(0.04), '40m');
  });

  test('formatNearMeDistanceKm uses one decimal under 10 km', () {
    expect(formatNearMeDistanceKm(2.34), '2.3 km');
  });

  test('formatNearMeDistanceKm rounds at 10 km and above', () {
    expect(formatNearMeDistanceKm(12.6), '13 km');
  });

  test('isNearMeCityScope recognizes city scopes', () {
    expect(isNearMeCityScope('city'), isTrue);
    expect(isNearMeCityScope('city_then_radius'), isTrue);
    expect(isNearMeCityScope('radius'), isFalse);
  });

  test('resolveNearMeLocationBadge prefers business distance', () {
    final badge = resolveNearMeLocationBadge(
      distanceKm: 1.2,
      distanceBasis: 'business',
      cityName: 'Cairo',
    );
    expect(badge.kind, NearMeLocationBadgeKind.distance);
    expect(badge.distanceFormatted, '1.2 km');
  });

  test('resolveNearMeLocationBadge shows city when basis is city', () {
    final badge = resolveNearMeLocationBadge(
      distanceKm: 5.5,
      distanceBasis: 'city',
      cityName: 'Cairo',
    );
    expect(badge.kind, NearMeLocationBadgeKind.inCity);
    expect(badge.city, 'Cairo');
  });

  test('resolveNearMeLocationBadge hides when nothing available', () {
    final badge = resolveNearMeLocationBadge(
      distanceKm: null,
      distanceBasis: null,
      cityName: null,
    );
    expect(badge.kind, NearMeLocationBadgeKind.none);
  });
}
