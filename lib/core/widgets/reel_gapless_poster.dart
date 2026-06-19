import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Instagram-style reel poster: fixed full-screen slot, blur LQIP underlay, cover
/// fit only — never intrinsic sizing (no resize flash while bytes decode).
class ReelGaplessPoster extends StatefulWidget {
  const ReelGaplessPoster({
    super.key,
    required this.imageUrl,
    this.blurUrl,
    this.fallbackUrl,
    this.cacheKey,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final String? blurUrl;
  final String? fallbackUrl;
  final String? cacheKey;
  final BoxFit fit;

  @override
  State<ReelGaplessPoster> createState() => _ReelGaplessPosterState();
}

class _ReelGaplessPosterState extends State<ReelGaplessPoster> {
  ImageProvider? _resolvedPrimary;
  ImageProvider? _resolvedBlur;
  bool _warming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hydrateFromRamCache();
    _warmProviders();
  }

  @override
  void didUpdateWidget(ReelGaplessPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.blurUrl != widget.blurUrl) {
      _resolvedPrimary = null;
      _resolvedBlur = null;
      _hydrateFromRamCache();
      _warmProviders();
    }
  }

  void _hydrateFromRamCache() {
    final primary = widget.imageUrl.trim();
    final blur = widget.blurUrl?.trim() ?? '';
    final cachedPrimary =
        primary.isEmpty ? null : ReelPosterImageCache.get(primary);
    final cachedBlur = blur.isEmpty ? null : ReelPosterImageCache.get(blur);
    if (cachedPrimary != null || cachedBlur != null) {
      setState(() {
        if (cachedPrimary != null) {
          _resolvedPrimary = cachedPrimary;
        }
        if (cachedBlur != null) {
          _resolvedBlur = cachedBlur;
        }
      });
    }
  }

  Future<void> _warmProviders() async {
    if (!mounted || _warming) {
      return;
    }
    _warming = true;
    final blur = widget.blurUrl?.trim() ?? '';
    final primary = widget.imageUrl.trim();
    ImageProvider? blurProvider;
    ImageProvider? primaryProvider;
    if (blur.isNotEmpty) {
      blurProvider = reelPosterPrecacheProvider(blur, context);
      final cached = ReelPosterImageCache.get(blur);
      if (cached == null) {
        try {
          await precacheImage(blurProvider, context);
          ReelPosterImageCache.put(blur, blurProvider);
        } catch (_) {}
      } else {
        blurProvider = cached;
      }
    }
    if (primary.isNotEmpty) {
      primaryProvider = reelPosterPrecacheProvider(primary, context);
      final cached = ReelPosterImageCache.get(primary);
      if (cached == null) {
        try {
          await precacheImage(primaryProvider, context);
          ReelPosterImageCache.put(primary, primaryProvider);
        } catch (_) {}
      } else {
        primaryProvider = cached;
      }
    }
    _warming = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _resolvedBlur = blurProvider;
      _resolvedPrimary = primaryProvider;
    });
    if (!kReleaseMode && primary.isNotEmpty) {
      debugPrint(
        '[ReelsPoster] image_warmed url=${primary.length > 48 ? '${primary.substring(0, 48)}...' : primary} '
        'blur=${blur.isNotEmpty} resolved=${primaryProvider != null}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (widget.blurUrl != null &&
            widget.blurUrl!.trim().isNotEmpty &&
            _resolvedPrimary == null)
          _PosterImageLayer(
            url: widget.blurUrl!.trim(),
            context: context,
            fit: BoxFit.cover,
            memScale: 0.35,
            filterQuality: FilterQuality.low,
            resolvedProvider: _resolvedBlur,
          ),
        if (widget.imageUrl.trim().isNotEmpty)
          _PosterImageLayer(
            url: widget.imageUrl.trim(),
            context: context,
            fit: widget.fit,
            cacheKey: widget.cacheKey,
            fallbackUrl: widget.fallbackUrl,
            resolvedProvider: _resolvedPrimary,
          ),
      ],
    );
  }
}

class _PosterImageLayer extends StatelessWidget {
  const _PosterImageLayer({
    required this.url,
    required this.context,
    required this.fit,
    this.cacheKey,
    this.fallbackUrl,
    this.memScale = 1.0,
    this.filterQuality = FilterQuality.medium,
    this.resolvedProvider,
  });

  final String url;
  final BuildContext context;
  final BoxFit fit;
  final String? cacheKey;
  final String? fallbackUrl;
  final double memScale;
  final FilterQuality filterQuality;
  final ImageProvider? resolvedProvider;

  @override
  Widget build(BuildContext buildContext) {
    final (memW, memH) = fullScreenPosterMemCacheSize(context);
    final scaledW = (memW * memScale).round().clamp(64, memW);
    final scaledH = (memH * memScale).round().clamp(64, memH);

    if (resolvedProvider != null) {
      return Positioned.fill(
        child: Image(
          image: resolvedProvider!,
          fit: fit,
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
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: scaledW,
        memCacheHeight: scaledH,
        filterQuality: filterQuality,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) {
          final fallback = fallbackUrl?.trim() ?? '';
          if (fallback.isEmpty || fallback == url) {
            return const SizedBox.shrink();
          }
          final (memW, memH) = fullScreenPosterMemCacheSize(context);
          final scaledW = (memW * memScale).round().clamp(64, memW);
          final scaledH = (memH * memScale).round().clamp(64, memH);
          return CachedNetworkImage(
            imageUrl: fallback,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: scaledW,
            memCacheHeight: scaledH,
            filterQuality: filterQuality,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
            imageBuilder: (ctx, imageProvider) => Image(
              image: imageProvider,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: filterQuality,
            ),
          );
        },
        imageBuilder: (ctx, imageProvider) {
          ReelPosterImageCache.put(url, imageProvider);
          return Image(
            image: imageProvider,
            fit: fit,
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
