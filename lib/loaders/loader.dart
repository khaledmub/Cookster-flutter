import 'package:flutter/material.dart';
import 'dart:math';

class LogoLoader extends StatefulWidget {
  final double size; // Customize the size of the loader
  final String logoPath; // Pass the logo asset path

  const LogoLoader({super.key, required this.logoPath, this.size = 60});

  @override
  _LogoLoaderState createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(); // Infinite loop animation

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(angle: _animation.value, child: child);
      },
      child: Image.asset(
        widget.logoPath,
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
