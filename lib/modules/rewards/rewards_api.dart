import 'dart:convert';

import 'package:cookster/appUtils/apiEndPoints.dart';
import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:cookster/services/apiClient.dart';
import 'package:http/http.dart' as http;

class RewardsApiException implements Exception {
  final String? errorCode;
  final String? message;
  final int statusCode;

  const RewardsApiException({
    this.errorCode,
    this.message,
    required this.statusCode,
  });
}

class RewardsApi {
  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  Never _throwFailed(http.Response response, Map<String, dynamic> json) {
    throw RewardsApiException(
      errorCode: parseRewardErrorCode(json, statusCode: response.statusCode),
      message: json['message']?.toString(),
      statusCode: response.statusCode,
    );
  }

  Future<RewardMyCode> fetchMyCode() async {
    final response = await ApiClient.getRequest(EndPoints.rewardsMyCode);
    final json = _decode(response);
    if (response.statusCode != 200 || json['status'] == false) {
      _throwFailed(response, json);
    }
    return RewardMyCode.fromJson(json);
  }

  Future<RewardDeal?> fetchCurrentDeal() async {
    final response = await ApiClient.getRequest(EndPoints.rewardsDealCurrent);
    final json = _decode(response);
    final code = parseRewardErrorCode(json, statusCode: response.statusCode);
    if (code == 'no_active_deal') {
      return null;
    }
    if (response.statusCode != 200 || json['status'] == false) {
      _throwFailed(response, json);
    }
    final root = rewardJsonRoot(json);
    if (root['deal'] == null && json['deal'] == null) {
      return null;
    }
    return RewardDeal.fromJson(json);
  }

  Future<RewardDeal> createDeal({
    required String title,
    required int quantity,
  }) async {
    return _mutateDeal(EndPoints.rewardsDealCreate, {
      'title': title,
      'quantity': quantity,
    });
  }

  Future<RewardDeal> renewDeal({
    required String title,
    required int quantity,
  }) async {
    return _mutateDeal(EndPoints.rewardsDealRenew, {
      'title': title,
      'quantity': quantity,
    });
  }

  Future<RewardDeal?> pauseDeal() async {
    final response = await ApiClient.postRequest(EndPoints.rewardsDealPause, {});
    final json = _decode(response);
    if (response.statusCode != 200 || json['status'] == false) {
      _throwFailed(response, json);
    }
    final root = rewardJsonRoot(json);
    if (root['deal'] == null && json['deal'] == null) {
      return null;
    }
    return RewardDeal.fromJson(json);
  }

  Future<RewardScanResult> scan({required String token}) async {
    final response = await ApiClient.postRequest(EndPoints.rewardsScan, {
      'token': token,
    });
    final json = _decode(response);
    final result = RewardScanResult.fromJson(
      json,
      statusCode: response.statusCode,
    );
    if (!result.success) {
      throw RewardsApiException(
        errorCode: result.errorCode,
        message: result.message,
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  Future<List<RewardDeal>> fetchHistory() async {
    final response = await ApiClient.getRequest(EndPoints.rewardsDealHistory);
    final json = _decode(response);
    if (response.statusCode != 200 || json['status'] == false) {
      _throwFailed(response, json);
    }
    return parseRewardDealList(json);
  }

  Future<RewardDeal> _mutateDeal(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiClient.postRequest(endpoint, body);
    final json = _decode(response);
    if (response.statusCode != 200 || json['status'] == false) {
      _throwFailed(response, json);
    }
    return RewardDeal.fromJson(json);
  }
}
