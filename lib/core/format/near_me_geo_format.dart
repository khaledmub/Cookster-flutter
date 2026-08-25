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

/// Joins city names for banners: `A, B & C`.
String formatCityGroupList(Iterable<String> cities) {
  final list = cities
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  if (list.isEmpty) {
    return '';
  }
  if (list.length == 1) {
    return list.first;
  }
  if (list.length == 2) {
    return '${list[0]} & ${list[1]}';
  }
  return '${list.sublist(0, list.length - 1).join(', ')} & ${list.last}';
}

/// City-group label for Near Me / location-filtered feeds.
///
/// Prefers server-provided group names, then unique [WallVideos.cityName] /
/// resolved catalog names from the loaded page(s). The GPS anchor city is
/// always included so Dhahran still shows even when the first page is mostly
/// Dammam/Khobar posts.
List<String> cityGroupDisplayNames({
  required String? anchorCityName,
  List<String>? serverGroupNames,
  Iterable<String?> videoCityNames = const [],
  Iterable<int?> videoCityIds = const [],
  Map<int, String> catalogNamesById = const {},
}) {
  final names = <String>{};

  void addName(String? raw) {
    final n = raw?.trim() ?? '';
    if (n.isNotEmpty && n.toLowerCase() != 'null') {
      names.add(n);
    }
  }

  addName(anchorCityName);
  for (final n in serverGroupNames ?? const <String>[]) {
    addName(n);
  }
  for (final n in videoCityNames) {
    addName(n);
  }
  for (final id in videoCityIds) {
    if (id == null || id <= 0) {
      continue;
    }
    addName(catalogNamesById[id]);
  }

  final ordered = names.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final anchor = anchorCityName?.trim();
  if (anchor != null &&
      anchor.isNotEmpty &&
      ordered.remove(anchor)) {
    ordered.insert(0, anchor);
  }
  return ordered;
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
