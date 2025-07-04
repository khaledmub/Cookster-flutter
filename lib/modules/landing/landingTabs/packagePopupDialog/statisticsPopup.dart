import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as dir;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../appUtils/colorUtils.dart';

void showVideoStatsDialog(BuildContext context, {required dynamic video}) {
  if (video == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('no_video_data_available'.tr)));
    return;
  }

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
      return _VideoStatsDialog(video: video);
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

class _VideoStatsDialog extends StatelessWidget {
  final dynamic video;

  _VideoStatsDialog({required this.video});

  bool _isValidValue(dynamic value) {
    return value != null && value.toString().isNotEmpty;
  }

  final _numberFormat = NumberFormat.compact(locale: 'en_US');

  @override
  Widget build(BuildContext context) {
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
                  'view_statistics'.tr,
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
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: StreamBuilder<
                  List<DocumentSnapshot<Map<String, dynamic>>>
                >(
                  stream: ZipStream.zip2(
                    FirebaseFirestore.instance
                        .collection('videos')
                        .doc(video)
                        .snapshots(),
                    FirebaseFirestore.instance
                        .collection('countContactClick')
                        .doc(video)
                        .snapshots(),
                    (videoSnap, clickSnap) => [videoSnap, clickSnap],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData ||
                        snapshot.data!.any((s) => !s.exists)) {
                      return Column(
                        children: [
                          _DetailTile(
                            label: 'likes'.tr,
                            value: '0',
                            valueIcon: Icons.favorite_border,
                            valueIconSize: 16,
                          ),
                          _DetailTile(
                            label: 'views'.tr,
                            value: '0',
                            valueIcon: Icons.visibility_outlined,
                            valueIconSize: 16,
                          ),
                          _DetailTile(
                            label: 'total_clicks'.tr,
                            value: '0',
                            valueIcon: Icons.touch_app_outlined,
                            valueIconSize: 16,
                          ),
                        ],
                      );
                    }
                    final videoSnapshot = snapshot.data![0];
                    final clickSnapshot = snapshot.data![1];
                    final videoData = videoSnapshot.data() ?? {};
                    final clickData = clickSnapshot.data() ?? {};
                    final likes = videoData['likes'] as List<dynamic>? ?? [];
                    final views = videoData['views'] as List<dynamic>? ?? [];
                    final totalClicks = clickData['totalClicks'] as int? ?? 0;
                    final likeCount = likes.length;
                    final viewCount = views.length;
                    final formattedLikeCount =
                        likeCount > 1000
                            ? _numberFormat.format(likeCount)
                            : likeCount.toString();
                    final formattedViewCount =
                        viewCount > 1000
                            ? _numberFormat.format(viewCount)
                            : viewCount.toString();
                    final formattedTotalClicks =
                        totalClicks > 1000
                            ? _numberFormat.format(totalClicks)
                            : totalClicks.toString();

                    return Column(
                      children: [
                        _DetailTile(
                          label: 'likes'.tr,
                          value: formattedLikeCount,
                          valueIcon: Icons.favorite_border,
                          valueIconSize: 16,
                          valueColor: Colors.redAccent,
                        ),
                        _DetailTile(
                          label: 'views'.tr,
                          value: formattedViewCount,
                          valueIcon: Icons.visibility_outlined,
                          valueIconSize: 16,
                          valueColor: Colors.blueAccent,
                        ),
                        _DetailTile(
                          label: 'total_clicks'.tr,
                          value: formattedTotalClicks,
                          valueIcon: Icons.touch_app_outlined,
                          valueIconSize: 16,
                          valueColor: Colors.greenAccent,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
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
                  'close'.tr,
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

  const _DetailTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueIcon,
    this.valueIconSize = 18,
    this.isBold = false,
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
              Directionality(
                textDirection: dir.TextDirection.ltr,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: valueColor ?? Colors.black87,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
