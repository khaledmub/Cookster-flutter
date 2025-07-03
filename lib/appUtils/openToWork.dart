import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

class OpenToWorkBadge extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool showOpenToWork;

  const OpenToWorkBadge({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.showOpenToWork = true,
  });

  @override
  Widget build(BuildContext context) {
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
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  "assets/images/sd.png",
                  fit: BoxFit.cover,
                ),
              )
                  : Image.asset(
                "assets/images/sd.png",
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Green crescent band overlay (top layer, conditional)
          if (showOpenToWork)
            CustomPaint(
              size: Size(size, size),
              painter: ImprovedCrescentPainter(),
            ),
        ],
      ),
    );
  }
}

class ImprovedCrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bandWidth = size.width * 0.14; // Slightly wider for better presence

    // Draw the professional band with enhanced effects
    _drawProfessionalBand(canvas, center, radius, bandWidth);

    // Draw the text with professional styling
    _drawProfessionalTextAlongCurve(canvas, center, radius - bandWidth / 2, size.width);
  }

  void _drawProfessionalBand(
      Canvas canvas,
      Offset center,
      double radius,
      double bandWidth,
      ) {
    // Adjusted positioning for bottom left quadrant with longer arc
    const startAngle = math.pi * 0.25; // Start at 270° (bottom left)
    const sweepAngle = math.pi * 1; // Arc length for the band

    // Create multiple layers for depth and professionalism
    // Main professional solid band with fade effect
    final gradientRect = Rect.fromCircle(center: center, radius: radius);
    final professionalGradient = SweepGradient(
      center: Alignment.center,
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        Colors.transparent, // Fade in
        ColorUtils.primaryColor.withOpacity(0.2),
        ColorUtils.primaryColor, // Solid in the middle
        ColorUtils.primaryColor, // Solid in the middle
        ColorUtils.primaryColor.withOpacity(0.2),
        Colors.transparent, // Fade out
      ],
      stops: const [0.0, 0.1, 0.3, 0.7, 0.9, 1.0], // Adjusted stops for smooth fade
    );

    final mainPaint = Paint()
      ..shader = professionalGradient.createShader(gradientRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bandWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - bandWidth / 2),
      startAngle,
      sweepAngle,
      false,
      mainPaint,
    );

    // Inner highlight for premium look
    final innerHighlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - bandWidth * 0.25),
      startAngle,
      sweepAngle,
      false,
      innerHighlightPaint,
    );

    // Subtle inner shadow for depth
    final innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - bandWidth * 0.75),
      startAngle,
      sweepAngle,
      false,
      innerShadowPaint,
    );
  }

  void _drawProfessionalTextAlongCurve(
      Canvas canvas,
      Offset center,
      double radius,
      double totalSize,
      ) {
    const text = 'B2B#'; // Text to display
    // Reducing textSweepAngle to minimize or eliminate gaps between characters
    const textStartAngle = math.pi * 0.65; // Adjusted to center text on arc
    const textSweepAngle = math.pi * 0.3; // Reduced from 0.54π to 0.3π to reduce character gaps
    // Note: Smaller textSweepAngle brings characters closer together; increase for more spacing
    final anglePerChar = textSweepAngle / (text.length );

    for (int i = 0; i < text.length; i++) {
      final angle = textStartAngle + (anglePerChar * i);
      final char = text[i];

      // Calculate position on the circle
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      // Solid opacity (no fade)
      const opacity = 1.0;

      // Professional font sizing
      final fontSize = totalSize * 0.12; // Slightly smaller for elegance
      final isSpace = char == ' ';

      if (!isSpace) {
        // Create professional text styling
        final textStyle = TextStyle(
          color: Colors.black.withOpacity(opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w600, // Semi-bold for professionalism
          letterSpacing: 0.8,
          height: 1.0,
        );

        // Shadow for depth and readability
        final shadowStyle = TextStyle(
          color: Colors.black.withOpacity(opacity * 0.3),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          height: 1.0,
        );

        final shadowTextPainter = TextPainter(
          text: TextSpan(text: char, style: shadowStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

        final mainTextPainter = TextPainter(
          text: TextSpan(text: char, style: textStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

        shadowTextPainter.layout();
        mainTextPainter.layout();

        canvas.save();
        canvas.translate(x, y);
        // Adjust rotation to make text upright in bottom left quadrant
        canvas.rotate(angle - math.pi / 2); // Subtract π/2 to correct orientation

        // Draw shadow with slight offset
        canvas.translate(
          -shadowTextPainter.width / 2 + 0.5,
          -shadowTextPainter.height / 2 + 0.5,
        );
        shadowTextPainter.paint(canvas, Offset.zero);

        // Draw main text
        canvas.translate(-0.5, -0.5);
        mainTextPainter.paint(canvas, Offset.zero);

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}