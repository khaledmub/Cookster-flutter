class DeviceConstraints {
  DateTime? _lastSwipeAt;

  bool shouldThrottleFastSwipe() {
    final now = DateTime.now();
    final last = _lastSwipeAt;
    _lastSwipeAt = now;
    if (last == null) {
      return false;
    }
    return now.difference(last).inMilliseconds < 250;
  }

  Future<bool> isBatteryLow() async {
    return false;
  }
}
