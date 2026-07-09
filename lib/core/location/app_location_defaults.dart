import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cookster defaults — Saudi Arabia / Riyadh (replaces legacy Lahore fallback).
class AppLocationDefaults {
  const AppLocationDefaults._();

  static const LatLng mapCenter = LatLng(24.7136, 46.6753);

  static const List<String> saudiCountryNames = [
    'Saudi Arabia',
    'Kingdom of Saudi Arabia',
    'KSA',
    'المملكة العربية السعودية',
    'السعودية',
  ];

  static const List<String> riyadhCityNames = [
    'Riyadh',
    'Ar Riyadh',
    'الرياض',
  ];

  static bool isSaudiCountryName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return false;
    }
    final normalized = name.trim().toLowerCase();
    return saudiCountryNames
        .any((candidate) => candidate.toLowerCase() == normalized);
  }

  static bool matchesRiyadhCityName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return false;
    }
    final normalized = name.trim().toLowerCase();
    return riyadhCityNames
        .any((candidate) => candidate.toLowerCase() == normalized);
  }
}
