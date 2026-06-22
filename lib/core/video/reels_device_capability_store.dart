import 'dart:convert';

import 'package:cookster/core/video/device_constraints.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted per-device reel playback capability (not brand-based).
class ReelsDeviceCapabilityProfile {
  const ReelsDeviceCapabilityProfile({
    this.measuredTier = ReelsDeviceTier.s,
    this.consecutiveCleanOpens = 0,
    this.failureSignatures = const [],
    this.lastMeasuredAtMs = 0,
    this.hasCompletedFirstMeasuredOpen = false,
    this.storedAppVersion = '',
  });

  final ReelsDeviceTier measuredTier;
  final int consecutiveCleanOpens;
  final List<String> failureSignatures;
  final int lastMeasuredAtMs;
  final bool hasCompletedFirstMeasuredOpen;
  final String storedAppVersion;

  static const int promoteAfterCleanOpens = 5;
  static const int failureRingMax = 20;

  ReelsDeviceTier get effectiveTier => measuredTier;

  ReelsDeviceCapabilityProfile copyWith({
    ReelsDeviceTier? measuredTier,
    int? consecutiveCleanOpens,
    List<String>? failureSignatures,
    int? lastMeasuredAtMs,
    bool? hasCompletedFirstMeasuredOpen,
    String? storedAppVersion,
  }) {
    return ReelsDeviceCapabilityProfile(
      measuredTier: measuredTier ?? this.measuredTier,
      consecutiveCleanOpens:
          consecutiveCleanOpens ?? this.consecutiveCleanOpens,
      failureSignatures: failureSignatures ?? this.failureSignatures,
      lastMeasuredAtMs: lastMeasuredAtMs ?? this.lastMeasuredAtMs,
      hasCompletedFirstMeasuredOpen: hasCompletedFirstMeasuredOpen ??
          this.hasCompletedFirstMeasuredOpen,
      storedAppVersion: storedAppVersion ?? this.storedAppVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'measuredTier': measuredTier.name,
        'consecutiveCleanOpens': consecutiveCleanOpens,
        'failureSignatures': failureSignatures,
        'lastMeasuredAtMs': lastMeasuredAtMs,
        'hasCompletedFirstMeasuredOpen': hasCompletedFirstMeasuredOpen,
        'storedAppVersion': storedAppVersion,
      };

  factory ReelsDeviceCapabilityProfile.fromJson(Map<String, dynamic> json) {
    final tierName = json['measuredTier']?.toString() ?? 's';
    return ReelsDeviceCapabilityProfile(
      measuredTier: ReelsDeviceTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => ReelsDeviceTier.s,
      ),
      consecutiveCleanOpens: json['consecutiveCleanOpens'] as int? ?? 0,
      failureSignatures: (json['failureSignatures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastMeasuredAtMs: json['lastMeasuredAtMs'] as int? ?? 0,
      hasCompletedFirstMeasuredOpen:
          json['hasCompletedFirstMeasuredOpen'] as bool? ?? false,
      storedAppVersion: json['storedAppVersion']?.toString() ?? '',
    );
  }
}

class ReelsDeviceCapabilityStore {
  ReelsDeviceCapabilityStore._();

  static final ReelsDeviceCapabilityStore instance =
      ReelsDeviceCapabilityStore._();

  static const _prefsKey = 'reels_device_capability_profile_v1';

  ReelsDeviceCapabilityProfile _profile = const ReelsDeviceCapabilityProfile();
  bool _loaded = false;

  ReelsDeviceCapabilityProfile get profile => _profile;

  @visibleForTesting
  void resetForTesting() {
    _loaded = false;
    _profile = const ReelsDeviceCapabilityProfile();
  }

  Future<void> load({String? currentAppVersion}) async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _profile = ReelsDeviceCapabilityProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        _profile = const ReelsDeviceCapabilityProfile();
      }
    }
    if (currentAppVersion != null &&
        currentAppVersion.isNotEmpty &&
        _profile.storedAppVersion.isNotEmpty &&
        _profile.storedAppVersion != currentAppVersion) {
      _profile = _profile.copyWith(
        consecutiveCleanOpens: 0,
        storedAppVersion: currentAppVersion,
      );
      await _persist();
    } else if (currentAppVersion != null &&
        currentAppVersion.isNotEmpty &&
        _profile.storedAppVersion.isEmpty) {
      _profile = _profile.copyWith(storedAppVersion: currentAppVersion);
      await _persist();
    }
    _loaded = true;
  }

  Future<void> markFirstMeasuredOpenComplete() async {
    if (_profile.hasCompletedFirstMeasuredOpen) {
      return;
    }
    _profile = _profile.copyWith(hasCompletedFirstMeasuredOpen: true);
    await _persist();
  }

  /// Fresh install: seed cautious brand prior instead of optimistic S on MTK/OEM.
  Future<void> seedInitialTierIfNeeded(ReelsDeviceTier brandPrior) async {
    if (_profile.hasCompletedFirstMeasuredOpen) {
      return;
    }
    if (_profile.failureSignatures.isNotEmpty ||
        _profile.consecutiveCleanOpens > 0) {
      return;
    }
    if (_profile.measuredTier == ReelsDeviceTier.s &&
        brandPrior != ReelsDeviceTier.s) {
      _profile = _profile.copyWith(measuredTier: brandPrior);
      await _persist();
    }
  }

  Future<ReelsDeviceTier?> recordCleanOpen() async {
    final nextStreak = _profile.consecutiveCleanOpens + 1;
    var tier = _profile.measuredTier;
    ReelsDeviceTier? promoted;
    if (nextStreak >= ReelsDeviceCapabilityProfile.promoteAfterCleanOpens &&
        _tierRank(tier) > 0) {
      tier = _demoteRank(_tierRank(tier) - 1);
      promoted = tier;
      _profile = _profile.copyWith(
        measuredTier: tier,
        consecutiveCleanOpens: 0,
        lastMeasuredAtMs: DateTime.now().millisecondsSinceEpoch,
        hasCompletedFirstMeasuredOpen: true,
      );
    } else {
      _profile = _profile.copyWith(
        consecutiveCleanOpens: nextStreak,
        lastMeasuredAtMs: DateTime.now().millisecondsSinceEpoch,
        hasCompletedFirstMeasuredOpen: true,
      );
    }
    await _persist();
    return promoted;
  }

  Future<ReelsDeviceTier> recordFailure(String signature) async {
    final ring = List<String>.from(_profile.failureSignatures)
      ..add(signature);
    while (ring.length > ReelsDeviceCapabilityProfile.failureRingMax) {
      ring.removeAt(0);
    }
    final demoted = _demoteRank(_tierRank(_profile.measuredTier) + 1);
    _profile = _profile.copyWith(
      measuredTier: demoted,
      consecutiveCleanOpens: 0,
      failureSignatures: ring,
      lastMeasuredAtMs: DateTime.now().millisecondsSinceEpoch,
      hasCompletedFirstMeasuredOpen: true,
    );
    await _persist();
    return demoted;
  }

  int _tierRank(ReelsDeviceTier tier) => switch (tier) {
        ReelsDeviceTier.s => 0,
        ReelsDeviceTier.a => 1,
        ReelsDeviceTier.b => 2,
        ReelsDeviceTier.c => 3,
      };

  ReelsDeviceTier _demoteRank(int rank) {
    return switch (rank.clamp(0, 3)) {
      0 => ReelsDeviceTier.s,
      1 => ReelsDeviceTier.a,
      2 => ReelsDeviceTier.b,
      _ => ReelsDeviceTier.c,
    };
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
  }
}
