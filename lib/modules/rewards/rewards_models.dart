const String kRewardQrPrefix = 'cookster_redeem:';

Map<String, dynamic> rewardJsonRoot(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    return data;
  }
  return json;
}

String normalizeRewardQrPayload(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return value;
  }
  if (value.startsWith(kRewardQrPrefix)) {
    return value;
  }
  return '$kRewardQrPrefix$value';
}

/// Body value for `POST rewards/scan` — full QR payload.
String rewardScanToken(String scanned) => normalizeRewardQrPayload(scanned);

class RewardMyCode {
  final String payload;
  final int expiresIn;
  final bool eligible;

  const RewardMyCode({
    required this.payload,
    required this.expiresIn,
    required this.eligible,
  });

  factory RewardMyCode.fromJson(Map<String, dynamic> json) {
    final root = rewardJsonRoot(json);
    final rawPayload =
        (root['payload'] ?? root['qr'] ?? root['code'] ?? '').toString();
    final expires = root['expires_in'] ?? root['expiresIn'] ?? 60;
    return RewardMyCode(
      payload: normalizeRewardQrPayload(rawPayload),
      expiresIn: expires is num ? expires.toInt() : 60,
      eligible: root['eligible'] != false,
    );
  }
}

class RewardDeal {
  final String? id;
  final String title;
  final int quantityTotal;
  final int quantityRemaining;
  final String status;
  final String? paymentStatus;

  const RewardDeal({
    this.id,
    required this.title,
    required this.quantityTotal,
    required this.quantityRemaining,
    required this.status,
    this.paymentStatus,
  });

  bool get isActive => status == 'active';
  bool get isExhausted => status == 'exhausted' || quantityRemaining <= 0;
  bool get isPaused => status == 'paused';

  factory RewardDeal.fromJson(Map<String, dynamic> json) {
    final root = rewardJsonRoot(json);
    final dealJson =
        root['deal'] is Map<String, dynamic>
            ? root['deal'] as Map<String, dynamic>
            : root;
    int asInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return RewardDeal(
      id: dealJson['id']?.toString(),
      title: (dealJson['title'] ?? dealJson['item_label'] ?? '').toString(),
      quantityTotal: asInt(
        dealJson['quantity_total'] ?? dealJson['total'] ?? dealJson['quantity'],
      ),
      quantityRemaining: asInt(
        dealJson['quantity_remaining'] ??
            dealJson['remaining'] ??
            dealJson['remaining_cups'],
      ),
      status: (dealJson['status'] ?? 'active').toString(),
      paymentStatus: dealJson['payment_status']?.toString(),
    );
  }
}

class RewardScanResult {
  final bool success;
  final String? errorCode;
  final RewardDeal? deal;
  final String? message;

  const RewardScanResult({
    required this.success,
    this.errorCode,
    this.deal,
    this.message,
  });

  factory RewardScanResult.fromJson(
    Map<String, dynamic> json, {
    int statusCode = 200,
  }) {
    final root = rewardJsonRoot(json);
    final code = parseRewardErrorCode(json, statusCode: statusCode);
    final ok =
        json['status'] == true ||
        (json['status'] != false &&
            statusCode == 200 &&
            (code == null || code == 'success'));
    RewardDeal? deal;
    if (root['deal'] is Map<String, dynamic> ||
        (ok && root['quantity_remaining'] != null)) {
      deal = RewardDeal.fromJson(json);
    }
    return RewardScanResult(
      success: ok && (code == null || code == 'success'),
      errorCode: code,
      deal: deal,
      message: (json['message'] ?? root['message'])?.toString(),
    );
  }
}

/// Maps API `error_code` / HTTP status to a stable code Flutter locales use.
String? parseRewardErrorCode(
  Map<String, dynamic> json, {
  int statusCode = 200,
}) {
  if (statusCode == 429) {
    return 'rate_limited';
  }
  final root = rewardJsonRoot(json);
  final raw =
      (json['error_code'] ??
              json['errorCode'] ??
              root['error_code'] ??
              root['code'])
          ?.toString();
  if (raw != null && raw.isNotEmpty && raw != 'success') {
    return raw;
  }
  if (json['status'] == true) {
    return 'success';
  }
  if (statusCode == 401 || statusCode == 403) {
    final message = (json['message'] ?? '').toString().toLowerCase();
    if (message.contains('partner')) {
      return 'not_a_partner';
    }
    if (message.contains('blocked')) {
      return 'partner_blocked';
    }
  }
  return raw;
}

List<RewardDeal> parseRewardDealList(Map<String, dynamic> json) {
  final root = rewardJsonRoot(json);
  final raw = root['deals'] ?? root['history'] ?? json['deals'];
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => RewardDeal.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

String rewardErrorLocaleKey(String? errorCode) {
  if (errorCode == null || errorCode.isEmpty || errorCode == 'success') {
    return 'reward_error_generic';
  }
  return 'reward_error_$errorCode';
}
