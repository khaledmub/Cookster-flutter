import 'package:flutter/material.dart';
import 'dart:math' as math;

class OpenToWorkBadge extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const OpenToWorkBadge({super.key, this.imageUrl, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final ImageProvider imageProvider =
        (imageUrl != null && imageUrl!.isNotEmpty)
            ? NetworkImage(imageUrl!)
            : const AssetImage("assets/images/sd.png");

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Profile image circle (bottom layer)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              image:
                  imageProvider != null
                      ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                      : null,
            ),
          ),
          // Green crescent band overlay with fade effect (top layer)
          CustomPaint(
            size: Size(size, size),
            painter: FadeOutCrescentPainter(),
          ),
        ],
      ),
    );
  }
}

class FadeOutCrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bandWidth = size.width * 0.16; // Increased thickness

    // Draw the green band with proper fade effect
    _drawFadedBand(canvas, center, radius, bandWidth);

    // Draw the text
    _drawTextAlongCurve(canvas, center, radius - bandWidth / 2, size.width);
  }

  void _drawFadedBand(
    Canvas canvas,
    Offset center,
    double radius,
    double bandWidth,
  ) {
    // Define the arc parameters to match the image
    const startAngle = math.pi * 0.05; // Start from top-left
    const sweepAngle = math.pi * 1.5; // 270 degrees clockwise
    const steps = 100; // Number of segments for smooth fade

    final stepAngle = sweepAngle / steps;

    for (int i = 0; i < steps; i++) {
      final currentAngle = startAngle + (stepAngle * i);
      final progress = i / (steps - 1); // 0 to 1

      // Modified fade effect to ensure ends are visible
      double opacity = 1;
      // if (progress < 0.1) {
      //   opacity = 1.0; // Keep first part fully visible
      // } else if (progress > 0.9) {
      //   opacity = 1.0; // Keep last part fully visible
      // } else {
      //   opacity = 0.8; // Slightly reduced opacity in middle
      // }

      final paint =
          Paint()
            ..color = const Color(0xFF0F7B0F).withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = bandWidth
            ..strokeCap = StrokeCap.butt;

      // Draw small arc segment
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - bandWidth / 2),
        currentAngle,
        stepAngle * 1.5, // Slight overlap to avoid gaps
        false,
        paint,
      );
    }
  }

  void _drawTextAlongCurve(
    Canvas canvas,
    Offset center,
    double radius,
    double totalSize,
  ) {
    const text = '#OPENTOWORK';

    // Match text with the band positioning from top-left to bottom-right
    const textStartAngle = math.pi * 0.15; // Start from top-left
    const textSweepAngle = math.pi * 1.5; // Follow 270 degrees clockwise
    final anglePerChar = textSweepAngle / (text.length * 1.5); // Reduced gap

    for (int i = 0; i < text.length; i++) {
      final angle = textStartAngle + (anglePerChar * i) + 10;
      final char = text[i];
      final progress = i / (text.length - 1);

      // Match text opacity with band fade
      double opacity = 1;

      // Calculate position
      final y = center.dy + radius * math.cos(angle);
      final x = center.dy + radius * math.sin(angle);

      // Create text painter
      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: Colors.white.withOpacity(opacity),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2); // Rotate to follow curve
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
