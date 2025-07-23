import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../notificationController/notificationController.dart';

class Notifications extends StatefulWidget {
  const Notifications({Key? key}) : super(key: key);

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  final NotificationController notificationController = Get.put(
    NotificationController(),
  );

  @override
  void initState() {
    super.initState();
    notificationController.fetchNotifications(context);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 40.h, bottom: 20.h),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              gradient: LinearGradient(
                colors: [Color(0XFFFFD700), Color(0XFFFFFADC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                Text(
                  "Notifications".tr,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Ensure the fetchNotifications method completes and updates the UI
                await notificationController.fetchNotifications(context);
              },
              child: UpdatesList(),
            ),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }
}

class UpdatesList extends StatelessWidget {
  UpdatesList({Key? key}) : super(key: key);

  final NotificationController notificationController =
      Get.find<NotificationController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (notificationController.isLoading.value) {
        return Center(
          child: PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
        );
      }

      // Wrap the empty state in a scrollable container to allow refresh
      if (notificationController
              .notificationData
              .value
              .notifications
              ?.isEmpty ??
          true) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height -
                200.h, // Adjust height to fill screen
            child: Center(
              child: Text(
                "No notifications available".tr,
                style: TextStyle(
                  color: ColorUtils.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 70),
        itemCount:
            notificationController
                .notificationData
                .value
                .notifications
                ?.length ??
            0,
        itemBuilder: (context, index) {
          final notification =
              notificationController
                  .notificationData
                  .value
                  .notifications![index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: ColorUtils.primaryColor,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            title: Text(
              notification.details?.title ?? "No Title",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(notification.details?.text ?? "No Description"),
            onTap: () {
              // Handle tap event, e.g., navigate to notification.details?.href
            },
          );
        },
        separatorBuilder:
            (context, index) => Divider(height: 1, color: Colors.grey.shade300),
      );
    });
  }
}

class AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
