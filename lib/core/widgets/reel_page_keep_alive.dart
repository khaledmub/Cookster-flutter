import 'package:flutter/material.dart';

/// Keeps a reel [PageView] child alive after first build so decoded image
/// posters are not torn down when the page scrolls off-screen.
class ReelPageKeepAlive extends StatefulWidget {
  const ReelPageKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<ReelPageKeepAlive> createState() => _ReelPageKeepAliveState();
}

class _ReelPageKeepAliveState extends State<ReelPageKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
