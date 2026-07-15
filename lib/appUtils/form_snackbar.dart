import 'package:flutter/material.dart';

/// Short, dismissible form errors that do not block editing.
///
/// Default [SnackBar]s stay up for 4s and sit in the way of the next tap.
/// Upload validation should clear the previous bar, auto-hide quickly, and
/// swipe away immediately so the user can keep filling the form.
void showFormSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.red,
  Duration duration = const Duration(milliseconds: 1600),
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}
