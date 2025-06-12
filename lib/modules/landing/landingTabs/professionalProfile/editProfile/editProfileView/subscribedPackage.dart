import 'package:cookster/appUtils/appUtils.dart';
import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:cookster/modules/landing/landingTabs/professionalProfile/changePlan/changePlanView/changePlanView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../appUtils/colorUtils.dart';
import '../../../profile/profileModel/profileModel.dart';

class SubscriptionPackageView extends StatefulWidget {
  final Subscription subscription; // Subscription object from UserDetails

  const SubscriptionPackageView({key, required this.subscription})
    : super(key: key);

  @override
  State<SubscriptionPackageView> createState() =>
      _SubscriptionPackageViewState();
}

class _SubscriptionPackageViewState extends State<SubscriptionPackageView> {
  // Format date for readability
  String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    final date = DateTime.parse(dateString);
    return DateFormat.yMMMMd('en_US').format(date); // e.g., April 1, 2025
  }

  String _language = 'en';

  // Default to English
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  final VideoAddController controller = Get.find();

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = _language == 'ar';
    // Create a number formatter for comma-separated numbers
    final NumberFormat numberFormat = NumberFormat("#,##0", "en_US");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorUtils.primaryColor,
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: ColorUtils.goldGradient),
          ),
          Positioned(
            // Conditionally set left or right based on language
            left: isRtl ? null : 16,
            right: isRtl ? 16 : null,
            top: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                try {
                  print("Tapped");
                  Get.back();
                } catch (e) {
                  print(e);
                }
              },
              child: Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6BE00),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isRtl ? Icons.arrow_back : Icons.arrow_back,
                    color: ColorUtils.darkBrown,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(top: 20),
                height: 50.h,
                width: 50.h,
                child: Image.asset("assets/images/appIconC.png"),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //<Card with dynamic height
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: ColorUtils.darkBrown, width: 2.0),
                  ),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    // Ensures Column takes only needed space
                    children: [
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: ColorUtils.darkBrown,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16.r),
                            topRight: Radius.circular(16.r),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                textAlign: TextAlign.center,
                                widget.subscription.title ?? 'Package',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '${controller.siteSettings.value!.settings!.currencySymbol} ${numberFormat.format(widget.subscription.amount)}', // Formatted price
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '${widget.subscription.duration} ${"months".tr}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildDetailRow(
                          'end_date'.tr,
                          formatDate(widget.subscription.endDate),
                          valueColor: Colors.red, // Set end date value to red
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, left: 16.0),
                        child: HtmlWidget(
                          widget.subscription.description ?? '',
                          textStyle: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h), // Add some padding at the bottom
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AppButton(
                  text: "change_plan".tr,
                  onTap: () {
                    Get.to(ChangePlanView());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build each detail row with optional row and value color
  Widget _buildDetailRow(
    String label,
    String value, {
    Color? rowColor,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: rowColor ?? Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              color: valueColor ?? rowColor ?? Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}
