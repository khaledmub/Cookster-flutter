import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double currentPosition;
  final double selectedDuration;

  WaveformPainter({
    required this.waveformData,
    required this.currentPosition,
    required this.selectedDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('WaveformPainter: Starting paint method');
    print('Canvas Size: $size');
    print('Waveform Data Length: ${waveformData.length}');
    print('Waveform Data Sample: ${waveformData.take(5).toList()}');
    print('Current Position: $currentPosition');
    print('Selected Duration: $selectedDuration');

    final paint = Paint()..color = Colors.white;
    final selectionPaint = Paint()..color = Colors.red;

    if (waveformData.isEmpty) {
      print('Warning: Waveform data is empty, skipping rendering');
      return;
    }

    // Add a background to see the canvas clearly
    final bgPaint = Paint()..color = Colors.grey[800]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    double step = size.width / waveformData.length;
    print('Calculated Step: $step');

    double amp = size.height / 2;
    print('Calculated Amplitude (amp): $amp');

    // Scale waveform data for better visibility
    const amplitudeScale = 10.0; // Increase this if needed

    // Draw full waveform
    print('Starting to draw waveform lines...');
    for (int i = 0; i < waveformData.length - 1; i++) {
      double y1 = amp - (waveformData[i] * amplitudeScale).clamp(0, amp);
      double y2 = amp - (waveformData[i + 1] * amplitudeScale).clamp(0, amp);
      print('Line $i: Start (${i * step}, $y1) to (${(i + 1) * step}, $y2)');
      canvas.drawLine(
        Offset(i * step, y1),
        Offset((i + 1) * step, y2),
        paint,
      );
    }

    // Adjust totalDuration to match actual audio duration (e.g., 19s for your case)
    double totalDuration = 19.0; // Replace with actual duration if known
    print('Calculated Total Duration: $totalDuration');

    double selectionWidth = (currentPosition / totalDuration) * size.width;
    print('Calculated Selection Width: $selectionWidth');

    double selectionEnd = ((currentPosition + selectedDuration) / totalDuration) * size.width;
    print('Calculated Selection End: $selectionEnd');

    if (selectionEnd > size.width) {
      print('Selection End exceeds width, clamping to $size.width');
      selectionEnd = size.width;
    }

    print('Drawing selection rectangle from 0 to $selectionEnd');
    canvas.drawRect(
      Rect.fromLTWH(0, 0, selectionEnd.clamp(0, size.width), size.height),
      selectionPaint,
    );

    print('WaveformPainter: Finished paint method');
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    bool needsRepaint = waveformData != oldDelegate.waveformData ||
        currentPosition != oldDelegate.currentPosition ||
        selectedDuration != oldDelegate.selectedDuration;
    print('shouldRepaint: $needsRepaint (WaveformData: ${waveformData != oldDelegate.waveformData}, '
        'CurrentPosition: ${currentPosition != oldDelegate.currentPosition}, '
        'SelectedDuration: ${selectedDuration != oldDelegate.selectedDuration})');
    return needsRepaint;
  }
}