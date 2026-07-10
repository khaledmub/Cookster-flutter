import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Visible-slot image holder for reel feeds — mirrors [ReelVideoPlayer]'s role
/// but for static image posts. One stable widget swaps providers without
/// rebuilding the whole page stack.
class ReelImageDisplay extends StatefulWidget {
  const ReelImageDisplay({
    super.key,
    required this.imageUrl,
    this.blurUrl,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.overlayMode = false,
  });

  final String imageUrl;
  final String? blurUrl;
  final String? cacheKey;
  final BoxFit fit;
  /// When true, stay transparent until full-res is ready so the thumb poster
  /// underneath remains visible (no black flash).
  final bool overlayMode;

  @override
  State<ReelImageDisplay> createState() => ReelImageDisplayState();
}

class ReelImageDisplayState extends State<ReelImageDisplay> {
  ImageProvider? _resolvedPrimary;
  ImageProvider? _resolvedBlur;
  int _warmGeneration = 0;

  @override
  void initState() {
    super.initState();
    _hydrateFromRamCacheSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hydrateFromRamCacheSync();
    _warmProviders();
  }

  @override
  void didUpdateWidget(ReelImageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.blurUrl != widget.blurUrl) {
      _hydrateFromRamCacheSync();
      _warmProviders();
    }
  }

  void _hydrateFromRamCacheSync() {
    final primary = widget.imageUrl.trim();
    final blur = widget.blurUrl?.trim() ?? '';
    final cachedPrimary =
        primary.isEmpty ? null : ReelImagePostCache.getFull(primary);
    final cachedBlur = blur.isEmpty ? null : ReelImagePostCache.getLqip(blur);
    var changed = false;
    if (cachedPrimary != null && cachedPrimary != _resolvedPrimary) {
      _resolvedPrimary = cachedPrimary;
      changed = true;
    }
    if (cachedBlur != null && cachedBlur != _resolvedBlur) {
      _resolvedBlur = cachedBlur;
      changed = true;
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _warmProviders() async {
    if (!mounted) {
      return;
    }
    final generation = ++_warmGeneration;
    final blur = widget.blurUrl?.trim() ?? '';
    final primary = widget.imageUrl.trim();
    ImageProvider? blurProvider = _resolvedBlur;
    ImageProvider? primaryProvider = _resolvedPrimary;

    if (blur.isNotEmpty) {
      blurProvider = ReelImagePostCache.getLqip(blur);
      if (blurProvider == null) {
        blurProvider = reelPosterLqipPrecacheProvider(blur, context);
        try {
          await precacheImage(blurProvider, context);
          if (!mounted || generation != _warmGeneration) {
            return;
          }
          ReelImagePostCache.putLqip(blur, blurProvider);
          setState(() => _resolvedBlur = blurProvider);
        } catch (_) {}
      }
    }

    if (primary.isNotEmpty) {
      primaryProvider = ReelImagePostCache.getFull(primary);
      if (primaryProvider == null) {
        primaryProvider = reelPosterPrecacheProvider(primary, context);
        try {
          await precacheImage(primaryProvider, context);
          if (!mounted || generation != _warmGeneration) {
            return;
          }
          ReelImagePostCache.putFull(primary, primaryProvider);
        } catch (_) {}
      }
    }

    if (!mounted || generation != _warmGeneration) {
      return;
    }
    setState(() {
      _resolvedBlur = blurProvider;
      _resolvedPrimary = primaryProvider;
    });
    if (!kReleaseMode && primary.isNotEmpty) {
      debugPrint(
        '[ReelImageDisplay] warmed url=${primary.length > 48 ? '${primary.substring(0, 48)}...' : primary} '
        'blur=${blur.isNotEmpty} resolved=${primaryProvider != null}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedPrimary == null && _resolvedBlur == null) {
      _hydrateFromRamCacheSync();
    }

    if (widget.overlayMode && _resolvedPrimary == null) {
      return const SizedBox.shrink();
    }

    final showOpaqueBase =
        !widget.overlayMode && _resolvedPrimary == null && _resolvedBlur == null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showOpaqueBase) const ColoredBox(color: Colors.black),
        if (blurUrlVisible)
          _ImageLayer(
            url: widget.blurUrl!.trim(),
            context: context,
            fit: BoxFit.cover,
            memScale: 0.35,
            filterQuality: FilterQuality.low,
            resolvedProvider: _resolvedBlur,
            cacheAsLqip: true,
          ),
        if (widget.imageUrl.trim().isNotEmpty && _resolvedPrimary != null)
          _ImageLayer(
            url: widget.imageUrl.trim(),
            context: context,
            fit: widget.fit,
            cacheKey: widget.cacheKey,
            resolvedProvider: _resolvedPrimary,
            cacheAsLqip: false,
          ),
      ],
    );
  }

  bool get blurUrlVisible {
    return !widget.overlayMode &&
        widget.blurUrl != null &&
        widget.blurUrl!.trim().isNotEmpty &&
        _resolvedPrimary == null;
  }
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({
    required this.url,
    required this.context,
    required this.fit,
    this.cacheKey,
    this.memScale = 1.0,
    this.filterQuality = FilterQuality.medium,
    this.resolvedProvider,
    this.cacheAsLqip = false,
  });

  final String url;
  final BuildContext context;
  final BoxFit fit;
  final String? cacheKey;
  final double memScale;
  final FilterQuality filterQuality;
  final ImageProvider? resolvedProvider;
  final bool cacheAsLqip;

  @override
  Widget build(BuildContext buildContext) {
    final (memW, _) = fullScreenPosterMemCacheSize(context);
    final scaledW = (memW * memScale).round().clamp(64, memW);

    if (resolvedProvider != null) {
      return Positioned.fill(
        child: Image(
          image: resolvedProvider!,
          fit: fit,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          filterQuality: filterQuality,
        ),
      );
    }

    return Positioned.fill(
      child: CachedNetworkImage(
        key: cacheKey != null ? ValueKey<String>(cacheKey!) : null,
        imageUrl: url,
        fit: fit,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: scaledW,
        filterQuality: filterQuality,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
        imageBuilder: (ctx, imageProvider) {
          if (cacheAsLqip) {
            ReelImagePostCache.putLqip(url, imageProvider);
          } else {
            ReelImagePostCache.putFull(url, imageProvider);
          }
          return Image(
            image: imageProvider,
            fit: fit,
            alignment: Alignment.center,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            filterQuality: filterQuality,
          );
        },
      ),
    );
  }
}
