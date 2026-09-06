import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/navigation/route_back.dart';
import 'package:cookster/modules/rewards/partner_scan_screen.dart';
import 'package:cookster/modules/rewards/rewards_controller.dart';
import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class PartnerRewardScreen extends StatefulWidget {
  const PartnerRewardScreen({super.key});

  @override
  State<PartnerRewardScreen> createState() => _PartnerRewardScreenState();
}

class _PartnerRewardScreenState extends State<PartnerRewardScreen> {
  late final RewardsController _controller;
  final _titleController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = Get.put(RewardsController(), tag: 'partner_rewards');
    _controller.loadCurrentDeal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    Get.delete<RewardsController>(tag: 'partner_rewards');
    super.dispose();
  }

  Future<void> _submit({required bool renew}) async {
    final title = _titleController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (title.isEmpty || quantity < 1) {
      Get.snackbar('error'.tr, 'reward_form_invalid'.tr);
      return;
    }
    final ok =
        renew
            ? await _controller.renewDeal(title: title, quantity: quantity)
            : await _controller.createDeal(title: title, quantity: quantity);
    if (ok) {
      _titleController.clear();
      _quantityController.clear();
      Get.snackbar('success'.tr, renew ? 'reward_renewed'.tr : 'reward_created'.tr);
    } else if (_controller.dealError.value != null) {
      Get.snackbar('error'.tr, _controller.dealError.value!);
    }
  }

  Future<void> _pause() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('reward_pause_title'.tr),
        content: Text('reward_pause_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('reward_pause'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final ok = await _controller.pauseDeal();
    if (ok) {
      Get.snackbar('success'.tr, 'reward_paused'.tr);
    } else if (_controller.dealError.value != null) {
      Get.snackbar('error'.tr, _controller.dealError.value!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorUtils.darkBrown),
          onPressed: () => navigateBack(),
        ),
        title: Text(
          'partner_rewards'.tr,
          style: TextStyle(
            color: ColorUtils.darkBrown,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isDealLoading.value &&
            _controller.currentDeal.value == null &&
            _controller.dealError.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: ColorUtils.darkBrown),
          );
        }
        final deal = _controller.currentDeal.value;
        return RefreshIndicator(
          color: ColorUtils.darkBrown,
          onRefresh: _controller.loadCurrentDeal,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
            children: [
              if (_controller.dealError.value != null && deal == null)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Text(
                    _controller.dealError.value!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13.sp),
                  ),
                ),
              if (deal == null || deal.isExhausted || deal.isPaused)
                _DealForm(
                  titleController: _titleController,
                  quantityController: _quantityController,
                  isRenew: deal != null,
                  isLoading: _controller.isMutating.value,
                  previousTitle: deal?.title,
                  onSubmit: () => _submit(renew: deal != null),
                ),
              if (deal != null) ...[
                if (deal.isActive) ...[
                  _ActiveDealCard(deal: deal),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed:
                        _controller.isMutating.value
                            ? null
                            : () => Get.to(() => const PartnerScanScreen()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.darkBrown,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text('reward_scan'.tr),
                  ),
                  SizedBox(height: 8.h),
                  OutlinedButton(
                    onPressed: _controller.isMutating.value ? null : _pause,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorUtils.darkBrown,
                      minimumSize: Size(double.infinity, 46.h),
                      side: const BorderSide(color: ColorUtils.darkBrown),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text('reward_pause'.tr),
                  ),
                ] else
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: Text(
                      deal.isPaused
                          ? 'reward_status_paused'.tr
                          : 'reward_status_exhausted'.tr,
                      style: TextStyle(
                        color: ColorUtils.grey,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
              ],
              if (_controller.history.isNotEmpty) ...[
                SizedBox(height: 28.h),
                Text(
                  'reward_history'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                    color: ColorUtils.darkBrown,
                  ),
                ),
                SizedBox(height: 8.h),
                for (final item in _controller.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.quantityRemaining}/${item.quantityTotal} · ${item.status}',
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _ActiveDealCard extends StatelessWidget {
  final RewardDeal deal;

  const _ActiveDealCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D6),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: ColorUtils.darkBrown,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'reward_remaining_count'.trParams({
              'remaining': '${deal.quantityRemaining}',
              'total': '${deal.quantityTotal}',
            }),
            style: TextStyle(fontSize: 15.sp, color: ColorUtils.grey),
          ),
        ],
      ),
    );
  }
}

class _DealForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController quantityController;
  final bool isRenew;
  final bool isLoading;
  final String? previousTitle;
  final VoidCallback onSubmit;

  const _DealForm({
    required this.titleController,
    required this.quantityController,
    required this.isRenew,
    required this.isLoading,
    required this.onSubmit,
    this.previousTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRenew ? 'reward_renew_title'.tr : 'reward_create_title'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: ColorUtils.darkBrown,
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: titleController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'reward_item_title'.tr,
            hintText: previousTitle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'reward_quantity'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: isLoading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.darkBrown,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          child:
              isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(isRenew ? 'reward_renew'.tr : 'reward_create'.tr),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
