import 'package:flutter/material.dart';

class PulseLogoLoader extends StatefulWidget {
  final String logoPath;
  final double size;

  const PulseLogoLoader({super.key, required this.logoPath, this.size = 60});

  @override
  _PulseLogoLoaderState createState() => _PulseLogoLoaderState();
}

class _PulseLogoLoaderState extends State<PulseLogoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1, end: 1.2).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: child);
      },
      child: Image.asset(
        "assets/images/progress_log.png",
        width: widget.size,
        height: widget.size,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
