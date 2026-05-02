import 'dart:math' as math;

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

/// Header of the [AwesomeDialog] (Material icons; no Rive).
class AwesomeDialogHeader extends StatelessWidget {
  const AwesomeDialogHeader({
    required this.dialogType,
    required this.loop,
    Key? key,
  }) : super(key: key);

  final DialogType dialogType;

  /// Unused in this fork (headers are static icons).
  // ignore: unused_field
  final bool loop;

  @override
  Widget build(BuildContext context) {
    switch (dialogType) {
      case DialogType.info:
        return _iconHeader(icon: Icons.info_outline, color: Colors.blue);
      case DialogType.infoReverse:
        return Transform.rotate(
          angle: math.pi,
          child: _iconHeader(icon: Icons.info_outline, color: Colors.blue),
        );
      case DialogType.question:
        return _iconHeader(icon: Icons.help_outline, color: Colors.amber.shade700);
      case DialogType.warning:
        return _iconHeader(icon: Icons.warning_amber_rounded, color: Colors.orange);
      case DialogType.error:
        return _iconHeader(icon: Icons.error_outline, color: Colors.red);
      case DialogType.success:
        return _iconHeader(icon: Icons.check_circle_outline, color: const Color(0xFF00CA71));
      case DialogType.noHeader:
        return const SizedBox.shrink();
    }
  }

  Widget _iconHeader({required IconData icon, required Color color}) {
    return Icon(
      icon,
      size: 72,
      color: color,
    );
  }
}
