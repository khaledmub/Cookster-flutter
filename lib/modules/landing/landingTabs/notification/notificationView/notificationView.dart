import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome

import '../../../../../appUtils/colorUtils.dart';
import '../../../../../loaders/pulseLoader.dart';
import '../notificationController/notificationController.dart'; // Adjust path

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

    // Fetch notifications when the screen loads
    notificationController.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,

        body: Column(
          children: [
            // Static Header (Replaces AppBar)
            Container(
              padding: EdgeInsets.only(top: 20.h, bottom: 20.h),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
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
                  // Uncomment if you want to add a settings icon
                  // GestureDetector(
                  //   onTap: () {
                  //     // Add navigation or action here
                  //   },
                  //   child: Padding(
                  //     padding: EdgeInsets.only(right: 8),
                  //     child: SvgPicture.asset(
                  //       "assets/icons/settings.svg",
                  //       height: 24,
                  //       width: 24,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
            // Scrollable Notification List
            Expanded(child: UpdatesList()),
            SizedBox(height: 50),
          ],
        ),
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
      // Show loading indicator while fetching
      if (notificationController.isLoading.value) {
        return Center(
          child: PulseLogoLoader(logoPath: "assets/images/appIconC.png"),
        );
      }

      // Show message if no notifications
      if (notificationController
          .notificationData
          .value
          .notifications
          ?.isEmpty ??
          true) {
        return Center(child: Text("No notifications available".tr));
      }

      // Build scrollable list of notifications
      return ListView.separated(
        padding: const EdgeInsets.only(top: 16),
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
            // trailing: const Icon(
            //   Icons.arrow_forward_ios,
            //   size: 16,
            //   color: Colors.grey,
            // ),
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

// Custom Clipper for Rounded Bottom AppBar (Optional, not used here)
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