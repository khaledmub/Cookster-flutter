import 'dart:async';

import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Thin playback progress indicator for reel videos (TikTok-style).
class ReelPlaybackProgressBar extends StatefulWidget {
  const ReelPlaybackProgressBar({
    super.key,
    required this.player,
    this.bottomInset = 0,
    this.horizontalInset = 12,
    this.height = 3,
  });

  final Player? player;
  final double bottomInset;
  final double horizontalInset;
  final double height;

  @override
  State<ReelPlaybackProgressBar> createState() =>
      _ReelPlaybackProgressBarState();
}

class _ReelPlaybackProgressBarState extends State<ReelPlaybackProgressBar> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _attach(widget.player);
  }

  @override
  void didUpdateWidget(ReelPlaybackProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _detach();
      _attach(widget.player);
    }
  }

  void _attach(Player? player) {
    if (player == null) {
      return;
    }
    _position = player.state.position;
    _duration = player.state.duration;
    _positionSub = player.stream.position.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => _position = position);
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (!mounted || duration <= Duration.zero) {
        return;
      }
      setState(() => _duration = duration);
    });
  }

  void _detach() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionSub = null;
    _durationSub = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null || _duration <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final fraction = (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);

    return Positioned(
      left: widget.horizontalInset,
      right: widget.horizontalInset,
      bottom: widget.bottomInset,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ColorUtils.primaryColor,
                            ColorUtils.primaryColor.withValues(alpha: 0.82),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ColorUtils.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
