/// Formats Near Me geo fields from the reels API for UI badges and notices.
String formatNearMeDistanceKm(double km) {
  if (km.isNaN || km.isInfinite || km < 0) {
    return '';
  }
  if (km < 1) {
    final meters = (km * 1000).round();
    if (meters <= 0) {
      return '';
    }
    return '${meters}m';
  }
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km';
  }
  return '${km.round()} km';
}

bool isNearMeCityScope(String? geoScope) {
  final scope = geoScope?.trim().toLowerCase() ?? '';
  return scope == 'city' || scope.contains('city');
}

enum NearMeLocationBadgeKind { distance, inCity, none }

class NearMeLocationBadge {
  const NearMeLocationBadge._(this.kind, {this.distanceFormatted, this.city});

  final NearMeLocationBadgeKind kind;
  final String? distanceFormatted;
  final String? city;

  static const none = NearMeLocationBadge._(NearMeLocationBadgeKind.none);

  bool get isVisible => kind != NearMeLocationBadgeKind.none;
}

NearMeLocationBadge resolveNearMeLocationBadge({
  required double? distanceKm,
  required String? distanceBasis,
  required String? cityName,
}) {
  final basis = distanceBasis?.trim().toLowerCase();
  if (distanceKm != null && basis == 'business') {
    final formatted = formatNearMeDistanceKm(distanceKm);
    if (formatted.isNotEmpty) {
      return NearMeLocationBadge._(
        NearMeLocationBadgeKind.distance,
        distanceFormatted: formatted,
      );
    }
  }

  final city = cityName?.trim();
  if (city != null && city.isNotEmpty) {
    return NearMeLocationBadge._(
      NearMeLocationBadgeKind.inCity,
      city: city,
    );
  }

  return NearMeLocationBadge.none;
}
