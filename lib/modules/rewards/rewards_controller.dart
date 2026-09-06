import 'dart:async';

import 'package:cookster/modules/rewards/rewards_api.dart';
import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:get/get.dart';

class RewardsController extends GetxController {
  RewardsController({RewardsApi? api}) : _api = api ?? RewardsApi();

  final RewardsApi _api;

  final isCodeLoading = false.obs;
  final isDealLoading = false.obs;
  final isMutating = false.obs;
  final isScanning = false.obs;

  final myCode = Rxn<RewardMyCode>();
  final currentDeal = Rxn<RewardDeal>();
  final history = <RewardDeal>[].obs;
  final codeError = RxnString();
  final dealError = RxnString();

  Timer? _refreshTimer;

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  String messageFor(RewardsApiException error) {
    final key = rewardErrorLocaleKey(error.errorCode);
    final translated = key.tr;
    if (translated != key) {
      return translated;
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return 'reward_error_generic'.tr;
  }

  Future<void> loadMyCode() async {
    isCodeLoading.value = true;
    codeError.value = null;
    try {
      final code = await _api.fetchMyCode();
      myCode.value = code;
      _scheduleRefresh(code.expiresIn);
    } on RewardsApiException catch (error) {
      codeError.value = messageFor(error);
    } catch (_) {
      codeError.value = 'reward_error_generic'.tr;
    } finally {
      isCodeLoading.value = false;
    }
  }

  void _scheduleRefresh(int expiresIn) {
    _refreshTimer?.cancel();
    final waitSeconds = (expiresIn - 10).clamp(15, 60);
    _refreshTimer = Timer(Duration(seconds: waitSeconds), () {
      loadMyCode();
    });
  }

  Future<void> loadCurrentDeal({bool withHistory = true}) async {
    isDealLoading.value = true;
    dealError.value = null;
    try {
      currentDeal.value = await _api.fetchCurrentDeal();
      if (withHistory) {
        try {
          history.assignAll(await _api.fetchHistory());
        } catch (_) {
          // History is secondary; keep the current deal visible.
        }
      }
    } on RewardsApiException catch (error) {
      dealError.value = messageFor(error);
    } catch (_) {
      dealError.value = 'reward_error_generic'.tr;
    } finally {
      isDealLoading.value = false;
    }
  }

  Future<bool> createDeal({required String title, required int quantity}) {
    return _runDealMutation(() => _api.createDeal(title: title, quantity: quantity));
  }

  Future<bool> renewDeal({required String title, required int quantity}) {
    return _runDealMutation(() => _api.renewDeal(title: title, quantity: quantity));
  }

  Future<bool> pauseDeal() {
    return _runDealMutation(_api.pauseDeal);
  }

  Future<bool> _runDealMutation(Future<RewardDeal?> Function() action) async {
    isMutating.value = true;
    dealError.value = null;
    try {
      currentDeal.value = await action();
      await loadCurrentDeal();
      return true;
    } on RewardsApiException catch (error) {
      dealError.value = messageFor(error);
      return false;
    } catch (_) {
      dealError.value = 'reward_error_generic'.tr;
      return false;
    } finally {
      isMutating.value = false;
    }
  }

  Future<RewardScanResult?> scanPayload(String scanned) async {
    if (isScanning.value) {
      return null;
    }
    isScanning.value = true;
    try {
      return await _api.scan(token: rewardScanToken(scanned));
    } on RewardsApiException catch (error) {
      return RewardScanResult(
        success: false,
        errorCode: error.errorCode,
        message: messageFor(error),
      );
    } catch (_) {
      return RewardScanResult(
        success: false,
        errorCode: null,
        message: 'reward_error_generic'.tr,
      );
    } finally {
      isScanning.value = false;
    }
  }
}
