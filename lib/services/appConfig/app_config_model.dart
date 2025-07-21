class AppConfig {
  final String merchantKey;
  final String terminalId;
  final String terminalPass;
  final String requestUrl;

  AppConfig({
    required this.merchantKey,
    required this.terminalId,
    required this.terminalPass,
    required this.requestUrl,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      merchantKey: json['merchantKey'],
      terminalId: json['terminalId'],
      terminalPass: json['terminalPass'],
      requestUrl: json['requestUrl'],
    );
  }
}
