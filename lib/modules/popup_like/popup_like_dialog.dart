import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class LikePopup extends StatelessWidget {
  final String username;
  final int likeCount;

  const LikePopup({required this.username, required this.likeCount});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom illustration matching the design
          Container(
            height: 220,

            child: SvgPicture.asset("assets/images/liked_count.svg"),
          ),
          const SizedBox(height: 24),
          Text(
            'total_likes'.tr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'likes_message'.trArgs([username, likeCount.toString()]),

            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primaryColor,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'ok'.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.pink.shade400
          ..style = PaintingStyle.fill;

    final path = Path();

    // Create heart shape
    final width = size.width;
    final height = size.height;

    path.moveTo(width / 2, height * 0.25);

    path.cubicTo(
      width / 2,
      height * 0.1,
      width * 0.1,
      height * 0.1,
      width * 0.1,
      height * 0.4,
    );
    path.cubicTo(
      width * 0.1,
      height * 0.6,
      width / 2,
      height * 0.9,
      width / 2,
      height * 0.9,
    );
    path.cubicTo(
      width / 2,
      height * 0.9,
      width * 0.9,
      height * 0.6,
      width * 0.9,
      height * 0.4,
    );
    path.cubicTo(
      width * 0.9,
      height * 0.1,
      width / 2,
      height * 0.1,
      width / 2,
      height * 0.25,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.orange.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25,
      0,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height,
      size.width,
      size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
