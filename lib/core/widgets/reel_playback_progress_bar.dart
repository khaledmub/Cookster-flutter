import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/appUtils/colorUtils.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// TikTok-style draggable progress bar with frame preview while scrubbing.
class ReelPlaybackProgressBar extends StatefulWidget {
  const ReelPlaybackProgressBar({
    super.key,
    required this.player,
    this.previewPosterUrl,
    this.bottomInset = 0,
    this.horizontalInset = 12,
    this.height = 3,
    this.scrubHitHeight = 28,
  });

  final Player? player;
  final String? previewPosterUrl;
  final double bottomInset;
  final double horizontalInset;
  final double height;
  final double scrubHitHeight;

  @override
  State<ReelPlaybackProgressBar> createState() =>
      _ReelPlaybackProgressBarState();
}

class _ReelPlaybackProgressBarState extends State<ReelPlaybackProgressBar> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isScrubbing = false;
  double? _scrubFraction;
  bool _wasPlayingBeforeScrub = false;
  Uint8List? _previewBytes;
  Timer? _seekDebounce;
  Timer? _screenshotDebounce;
  int _seekGeneration = 0;
  final GlobalKey _trackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _attach(widget.player);
  }

  @override
  void didUpdateWidget(ReelPlaybackProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _cancelScrub();
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
      if (!mounted || _isScrubbing) {
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

  void _cancelScrub() {
    _seekDebounce?.cancel();
    _screenshotDebounce?.cancel();
    _seekDebounce = null;
    _screenshotDebounce = null;
    _isScrubbing = false;
    _scrubFraction = null;
    _previewBytes = null;
    _wasPlayingBeforeScrub = false;
  }

  double _fractionFromGlobalDx(double globalDx) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return 0;
    }
    final local = box.globalToLocal(Offset(globalDx, 0));
    return (local.dx / box.size.width).clamp(0.0, 1.0);
  }

  Duration _durationAtFraction(double fraction) {
    if (_duration <= Duration.zero) {
      return Duration.zero;
    }
    final ms = (_duration.inMilliseconds * fraction).round();
    return Duration(milliseconds: ms.clamp(0, _duration.inMilliseconds));
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _beginScrub(double globalDx) async {
    final player = widget.player;
    if (player == null || _duration <= Duration.zero) {
      return;
    }
    _wasPlayingBeforeScrub = player.state.playing;
    if (_wasPlayingBeforeScrub) {
      try {
        await player.pause();
      } on Object catch (_) {}
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isScrubbing = true;
      _scrubFraction = _fractionFromGlobalDx(globalDx);
    });
    _scheduleSeek(_scrubFraction!);
  }

  void _updateScrub(double globalDx) {
    if (!_isScrubbing) {
      return;
    }
    setState(() => _scrubFraction = _fractionFromGlobalDx(globalDx));
    _scheduleSeek(_scrubFraction!);
  }

  void _scheduleSeek(double fraction) {
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 48), () {
      unawaited(_seekToFraction(fraction));
    });
  }

  Future<void> _seekToFraction(double fraction) async {
    final player = widget.player;
    if (player == null || _duration <= Duration.zero) {
      return;
    }
    final target = _durationAtFraction(fraction);
    final generation = ++_seekGeneration;
    try {
      await player.seek(target);
    } on Object catch (_) {
      return;
    }
    if (!mounted || generation != _seekGeneration) {
      return;
    }
    setState(() => _position = target);
    _scheduleScreenshot();
  }

  void _scheduleScreenshot() {
    _screenshotDebounce?.cancel();
    _screenshotDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_capturePreviewFrame());
    });
  }

  Future<void> _capturePreviewFrame() async {
    final player = widget.player;
    if (player == null || !_isScrubbing || !mounted) {
      return;
    }
    try {
      final bytes = await player.screenshot(format: 'image/jpeg');
      if (!mounted || !_isScrubbing || bytes == null || bytes.isEmpty) {
        return;
      }
      setState(() => _previewBytes = bytes);
    } on Object catch (_) {}
  }

  Future<void> _endScrub(double globalDx) async {
    final player = widget.player;
    if (player == null) {
      _cancelScrub();
      return;
    }
    final fraction = _fractionFromGlobalDx(globalDx);
    _seekDebounce?.cancel();
    _screenshotDebounce?.cancel();
    final target = _durationAtFraction(fraction);
    try {
      await player.seek(target);
    } on Object catch (_) {}
    if (mounted) {
      setState(() {
        _position = target;
        _isScrubbing = false;
        _scrubFraction = null;
        _previewBytes = null;
      });
    }
    if (_wasPlayingBeforeScrub) {
      try {
        await player.play();
      } on Object catch (_) {}
    }
    _wasPlayingBeforeScrub = false;
  }

  @override
  void dispose() {
    _cancelScrub();
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null || _duration <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final fraction = (_isScrubbing ? _scrubFraction : null) ??
        (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final barHeight = _isScrubbing ? widget.height + 2 : widget.height;
    final previewDuration = _durationAtFraction(fraction);
    final trackWidth = MediaQuery.sizeOf(context).width -
        widget.horizontalInset * 2;
    final previewLeft = (widget.horizontalInset +
            (trackWidth * fraction) -
            48)
        .clamp(widget.horizontalInset, trackWidth + widget.horizontalInset - 96);

    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (_isScrubbing)
            Positioned(
              left: previewLeft,
              bottom: widget.scrubHitHeight + 8,
              child: _ScrubPreviewBubble(
                previewBytes: _previewBytes,
                posterUrl: widget.previewPosterUrl,
                timeLabel: _formatDuration(previewDuration),
              ),
            ),
          SizedBox(
            height: widget.scrubHitHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                unawaited(_beginScrub(details.globalPosition.dx));
              },
              onHorizontalDragUpdate: (details) {
                _updateScrub(details.globalPosition.dx);
              },
              onHorizontalDragEnd: (details) {
                unawaited(_endScrub(details.globalPosition.dx));
              },
              onHorizontalDragCancel: () {
                final player = widget.player;
                if (player != null && _wasPlayingBeforeScrub) {
                  unawaited(() async {
                    try {
                      await player.play();
                    } on Object catch (_) {}
                  }());
                }
                if (mounted) {
                  setState(_cancelScrub);
                } else {
                  _cancelScrub();
                }
              },
              onTapDown: (details) {
                unawaited(_beginScrub(details.globalPosition.dx));
              },
              onTapUp: (details) {
                unawaited(_endScrub(details.globalPosition.dx));
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.horizontalInset,
                  ),
                  child: ClipRRect(
                    key: _trackKey,
                    borderRadius: BorderRadius.circular(barHeight),
                    child: SizedBox(
                      height: barHeight,
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
                                    ColorUtils.primaryColor
                                        .withValues(alpha: 0.82),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ColorUtils.primaryColor
                                        .withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isScrubbing)
                            Align(
                              alignment: Alignment(
                                -1 + (2 * fraction),
                                0,
                              ),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: ColorUtils.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.35),
                                      blurRadius: 4,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrubPreviewBubble extends StatelessWidget {
  const _ScrubPreviewBubble({
    required this.previewBytes,
    required this.posterUrl,
    required this.timeLabel,
  });

  final Uint8List? previewBytes;
  final String? posterUrl;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: previewBytes != null
                  ? Image.memory(
                      previewBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : posterUrl != null && posterUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: posterUrl!,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Colors.white54,
                          ),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                timeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
