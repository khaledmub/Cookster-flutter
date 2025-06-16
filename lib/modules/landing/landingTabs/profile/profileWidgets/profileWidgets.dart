import 'package:cookster/appUtils/colorUtils.dart';
import 'package:cookster/modules/landing/landingTabs/profile/profileControlller/profileController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ColorUtils.darkBrown,
          ),
        ),
        Text(
          label.tr,
          style: TextStyle(fontSize: 12.sp, color: ColorUtils.darkBrown),
        ),
      ],
    );
  }
}

class IconButtonWidget extends StatelessWidget {
  final String icon;

  const IconButtonWidget({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ColorUtils.darkBrown),
      ),
      child: SvgPicture.asset(icon, height: 20.sp, color: ColorUtils.darkBrown),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorUtils.darkBrown),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(icon, height: 16, color: ColorUtils.darkBrown),
          SizedBox(width: 8),
          Text(label, style: TextStyle(color: ColorUtils.darkBrown)),
        ],
      ),
    );
  }
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
                leading: Icon(Icons.block, color: ColorUtils.grey),
                trailing: Icon(Icons.support_agent, color: ColorUtils.grey),
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
