import 'package:geolocator/geolocator.dart';

/// Serializes Geolocator permission and position requests across controllers.
///
/// Geolocator throws `A request for location permissions is already running`
/// when two requests overlap, and Home (Near Me), Discover, hashtag reels and
/// signup all ask independently during startup. Every caller must go through
/// here so only one native prompt is ever in flight.
class LocationPermissionGate {
  LocationPermissionGate._();

  static Future<LocationPermission>? _permissionRequest;
  static Future<Position?>? _positionRequest;

  static bool isGranted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  /// Returns the current permission, prompting at most once even when several
  /// callers race. Never throws.
  static Future<LocationPermission> ensurePermission() async {
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
    if (permission != LocationPermission.denied) {
      return permission;
    }
    final pending = _permissionRequest;
    if (pending != null) {
      return pending;
    }
    final request = Geolocator.requestPermission();
    _permissionRequest = request;
    try {
      return await request;
    } catch (_) {
      return LocationPermission.denied;
    } finally {
      if (identical(_permissionRequest, request)) {
        _permissionRequest = null;
      }
    }
  }

  /// A position for the current session, coalescing concurrent callers.
  ///
  /// Falls back to the last known fix when the GPS lock times out so a slow
  /// or unavailable fix never blocks the feed for the full [timeLimit].
  static Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.low,
    Duration timeLimit = const Duration(seconds: 10),
  }) {
    final pending = _positionRequest;
    if (pending != null) {
      return pending;
    }
    final request = _resolvePosition(accuracy: accuracy, timeLimit: timeLimit);
    _positionRequest = request;
    return request.whenComplete(() {
      if (identical(_positionRequest, request)) {
        _positionRequest = null;
      }
    });
  }

  static Future<Position?> _resolvePosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit,
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Best-effort immediate fix with no prompt — used to seed the feed before
  /// the real lock lands.
  static Future<Position?> lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
