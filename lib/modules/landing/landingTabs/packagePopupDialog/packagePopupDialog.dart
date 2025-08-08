import 'package:cookster/modules/landing/landingTabs/add/videoAddController/videoAddController.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as dir;
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../appUtils/colorUtils.dart';
import '../../../promoteVideo/promoteVideoView/promoteVideoView.dart';

final VideoAddController controller = Get.find();

void showPackageDialog(BuildContext context, {required List<dynamic>? videos}) {
  // Check if videos is null or empty
  if (videos == null || videos.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('no_video_data_available'.tr)));
    return;
  }

  // Get the first video's data
  final video = videos[0];

  // Date formatter for "20 May, 2025"
  final dateFormat = DateFormat('d MMMM, yyyy');

  // Format dates or show 'N/A' if null
  final startDate =
      video.startDate.toString();
  final endDate = video.endDate.toString();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return _AnimatedDialog(
        videos: videos,
        startDate: startDate,
        endDate: endDate,
        video: video,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutQuint),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      );
    },
  );
}

class _AnimatedDialog extends StatelessWidget {
  final List<dynamic> videos;
  final dynamic video;
  final String startDate;
  final String endDate;

  _AnimatedDialog({
    required this.videos,
    required this.video,
    required this.startDate,
    required this.endDate,
  });

  bool _isValidValue(dynamic value) {
    return value != null &&
        value.toString().isNotEmpty &&
        value.toString() != 'N/A';
  }

  // Number formatter for pricing values (e.g., 100.00)
  final _numberFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '${controller.siteSettings.value!.settings!.currencySymbol} ',
    decimalDigits: 2,
  );

  // Function to show bottom sheet with all cities
  void _showCitiesBottomSheet(BuildContext context, List<String>? cities) {
    if (cities == null || cities.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Text(
                        'cities'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: cities.length,
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${index + 1}. $city',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final packageValue =
        video.sponsorType != null
            ? (video.sponsorType == 1 ? 'Basic'.tr : 'Premium'.tr)
            : 'N/A';

    final packageColor =
        packageValue == 'Premium' ? ColorUtils.darkBrown : Colors.black87;

    String formatDate(String startDate) {
      // Parse the string to DateTime
      DateTime parsedDate = DateTime.parse(startDate);
      // Format to desired pattern: "26 Aug, 2025 12:00 PM"
      return DateFormat('dd MMM, yyyy hh:mm a').format(parsedDate);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'promoted_video_info'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            if (_isValidValue(packageValue))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        packageValue == 'Premium'
                            ? Color(0xFFFFD700).withOpacity(0.1)
                            : Color(0xFFC0C0C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          packageValue == 'Premium'
                              ? Color(0xFFFFD700).withOpacity(0.2)
                              : Color(0xFFC0C0C0).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    packageValue,
                    style: TextStyle(
                      color:
                          packageValue == 'Premium'
                              ? Color(0xFFFFD700)
                              : Color(0xFFC0C0C0),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (_isValidValue(video.cities?.toString()))
                      _DetailTile(
                        label: 'cities'.tr,
                        value: '', // Empty value to hide cities text
                        showViewButton: true, // Enable View button for cities
                        onViewTap: () {
                          // Check if video.cities is a String and split it, or use as is if already a List
                          final cities =
                              video.cities is String
                                  ? (video.cities as String)
                                      .split(',')
                                      .map((c) => c.trim())
                                      .toList()
                                  : video.cities is List
                                  ? List<String>.from(video.cities)
                                  : null;
                          _showCitiesBottomSheet(context, cities);
                        },
                      ),
                    if (_isValidValue(video.days?.toString()))
                      _DetailTile(
                        label: 'total_days'.tr,
                        value: video.days?.toString() ?? 'N/A',
                      ),
                    if (_isValidValue(video.perDayPrice?.toString()))
                      _DetailTile(
                        label: 'per_day_price'.tr,
                        value:
                            video.perDayPrice != null
                                ? _numberFormat.format(video.perDayPrice)
                                : 'N/A',
                      ),
                    if (_isValidValue(video.discountAmount) &&
                        video.discountAmount > 0)
                      _DetailTile(
                        label: 'discount'.tr,
                        value:
                            video.discountAmount != null
                                ? _numberFormat.format(video.discountAmount)
                                : 'N/A',
                        valueColor: Colors.green.shade700,
                        valueIcon: Icons.discount_outlined,
                      ),
                    if (_isValidValue(
                      video.totalAmount != null && video.discountAmount != null
                          ? (video.totalAmount - video.discountAmount)
                              .toString()
                          : null,
                    ))
                      _DetailTile(
                        label: 'sub_total'.tr,
                        value:
                            (video.totalAmount != null &&
                                    video.discountAmount != null)
                                ? _numberFormat.format(video.totalAmount)
                                : 'N/A',
                        isBold: true,
                      ),
                    if (_isValidValue(startDate))
                      _DetailTile(
                        label: 'start_date'.tr,
                        value: formatDate(startDate), // Format the date here
                        valueIcon: Icons.calendar_today_outlined,
                        valueIconSize: 16,
                      ),
                    if (_isValidValue(endDate))
                      _DetailTile(
                        label: 'end_date'.tr,
                        value: formatDate(endDate), // Format the date here
                        valueIcon: Icons.calendar_today_outlined,
                        valueIconSize: 16,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.to(() => PromoteVideoView(videos: videos));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.darkBrown,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "change_plan".tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? valueIcon;
  final double? valueIconSize;
  final bool isBold;
  final VoidCallback? onTap;
  final bool showViewButton; // New flag for showing View button
  final VoidCallback? onViewTap; // Callback for View button

  const _DetailTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueIcon,
    this.valueIconSize = 18,
    this.isBold = false,
    this.onTap,
    this.showViewButton = false, // Default to false
    this.onViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                if (valueIcon != null) ...[
                  Icon(
                    valueIcon,
                    size: valueIconSize,
                    color: valueColor ?? Colors.black54,
                  ),
                  const SizedBox(width: 6),
                ],
                if (value.isNotEmpty) ...[
                  Directionality(
                    textDirection: dir.TextDirection.ltr,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          color: valueColor ?? Colors.black87,
                          fontWeight:
                              isBold ? FontWeight.w700 : FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                if (showViewButton) ...[
                  if (value.isNotEmpty) const SizedBox(width: 8),
                  TextButton(
                    onPressed: onViewTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(50, 30),
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'view'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
