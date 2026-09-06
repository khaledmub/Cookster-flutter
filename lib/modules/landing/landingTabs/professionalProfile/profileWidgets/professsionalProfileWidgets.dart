import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/core/profile/profile_share.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../tawkLiveChat/tawkLiveChat.dart';
import '../../blockedUsers/blockedUsersView/blockedUsersView.dart';

class TabBarWidget extends StatelessWidget {
  final List<String> tabs = ["Meals", "Drinks", "Desserts", "Others"];

  TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find();

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Color(0xFFFFF8D6), // Light Yellow Background
        borderRadius: BorderRadius.circular(50.r),
      ),
      child: Obx(
        () => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            bool isSelected = controller.selectedIndex.value == index;
            return GestureDetector(
              onTap: () => controller.changeTab(index),
              child: Container(
                // duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? ColorUtils.primaryColor : Colors.transparent,
                  // Selected tab color
                  borderRadius: BorderRadius.circular(50.r),
                ),
                child: Text(
                  tabs[index].tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  final String number;
  final String label;

  const ProfileStat({super.key, required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: ColorUtils.darkBrown,
          ),
        ),
        Text(
          label.tr,
          style: TextStyle(fontSize: 11.sp, color: ColorUtils.darkBrown),
        ),
      ],
    );
  }
}

class ProfileContactAction {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const ProfileContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class IconButtonWidget extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final String? label;

  const IconButtonWidget({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 44,
          width: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: ColorUtils.secondaryColor,
          ),
          child: Center(
            child: SvgPicture.asset(
              icon,
              height: 20,
              colorFilter: const ColorFilter.mode(
                ColorUtils.darkBrown,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
    if (label == null || label!.isEmpty) {
      return button;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        SizedBox(height: 6.h),
        Text(
          label!.tr,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: ColorUtils.darkBrown,
          ),
        ),
      ],
    );
  }
}

class ProfilePillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProfilePillAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: ColorUtils.primaryColor.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.sp, color: ColorUtils.darkBrown),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.darkBrown,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft cream card grouping contact icons + Share / QR / More pills.
class ProfileActionCard extends StatelessWidget {
  final List<ProfileContactAction> contacts;
  final VoidCallback? onShare;
  final VoidCallback? onQr;
  final VoidCallback? onMore;
  final VoidCallback? onRewardQr;
  final VoidCallback? onPartnerRewards;

  const ProfileActionCard({
    super.key,
    this.contacts = const [],
    this.onShare,
    this.onQr,
    this.onMore,
    this.onRewardQr,
    this.onPartnerRewards,
  });

  bool get _hasContacts => contacts.isNotEmpty;

  bool get _hasPills => onShare != null || onQr != null || onMore != null;

  bool get _hasRewardPills => onRewardQr != null || onPartnerRewards != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasContacts && !_hasPills && !_hasRewardPills) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8D6),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasContacts)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final action in contacts)
                    IconButtonWidget(
                      icon: action.icon,
                      label: action.label,
                      onTap: action.onTap,
                    ),
                ],
              ),
            if (_hasContacts && _hasPills) ...[
              SizedBox(height: 12.h),
              Divider(
                height: 1,
                thickness: 1,
                color: ColorUtils.primaryColor.withValues(alpha: 0.35),
              ),
              SizedBox(height: 12.h),
            ],
            if (_hasPills)
              Row(
                children: [
                  if (onShare != null)
                    Expanded(
                      child: ProfilePillAction(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: onShare!,
                      ),
                    ),
                  if (onShare != null && (onQr != null || onMore != null))
                    SizedBox(width: 8.w),
                  if (onQr != null)
                    Expanded(
                      child: ProfilePillAction(
                        icon: Icons.qr_code_rounded,
                        label: 'QR',
                        onTap: onQr!,
                      ),
                    ),
                  if (onQr != null && onMore != null) SizedBox(width: 8.w),
                  if (onMore != null)
                    Expanded(
                      child: ProfilePillAction(
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        onTap: onMore!,
                      ),
                    ),
                ],
              ),
            if (_hasRewardPills) ...[
              if (_hasPills || _hasContacts) ...[
                SizedBox(height: 12.h),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: ColorUtils.primaryColor.withValues(alpha: 0.35),
                ),
                SizedBox(height: 12.h),
              ],
              Row(
                children: [
                  if (onRewardQr != null)
                    Expanded(
                      child: ProfilePillAction(
                        icon: Icons.card_giftcard_rounded,
                        label: 'reward_qr',
                        onTap: onRewardQr!,
                      ),
                    ),
                  if (onRewardQr != null && onPartnerRewards != null)
                    SizedBox(width: 8.w),
                  if (onPartnerRewards != null)
                    Expanded(
                      child: ProfilePillAction(
                        icon: Icons.storefront_outlined,
                        label: 'partner_rewards',
                        onTap: onPartnerRewards!,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft circular app-bar utility control (support / settings / logout).
class ProfileAppBarCircleIcon extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const ProfileAppBarCircleIcon({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 36,
          width: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: ColorUtils.secondaryColor,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class CustomButtonWidget extends StatelessWidget {
  final String icon;
  final String label;

  const CustomButtonWidget({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorUtils.darkBrown),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(icon, height: 16, color: ColorUtils.darkBrown),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: ColorUtils.darkBrown, fontSize: 12.sp),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

void showProfileQrCodeDialog({String? userEmail, String? userId}) {
  final String profileUrl = profileShareUrl(email: userEmail, userId: userId);
  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan to open profile',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp),
            ),
            const SizedBox(height: 12),
            QrImageView(
              data: profileUrl,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ),
    ),
  );
}

void showMoreOptionsProfile(
  BuildContext context,
  String userName,
  String userEmail,
) {
  // _handleScreenExit();
  // controller.pauseCurrentVideo();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              ListTile(
                leading: Icon(Icons.block, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'blocked_users'.tr,
                  style: TextStyle(color: Colors.black, fontSize: 14.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Get.to(BlockedUsersScreen(userName: userName));
                },
              ),
              ListTile(
                leading: Icon(Icons.support_agent, color: ColorUtils.grey),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.grey,
                ),
                title: Text(
                  'chat_support'.tr,
                  style: TextStyle(color: Colors.black, fontSize: 14.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Get.to(
                    LiveTawkChat(userName: userName, userEmail: userEmail),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
