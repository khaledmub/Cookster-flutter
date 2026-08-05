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
    this.memScale = 1.0,
    this.filterQuality = FilterQuality.medium,
    this.useLqipTier = false,
    this.opaqueBase = true,
  });

  final String imageUrl;
  final String? blurUrl;
  final String? fallbackUrl;
  final String? cacheKey;
  final BoxFit fit;
  final double memScale;
  final FilterQuality filterQuality;
  /// When true, [imageUrl] is stored in the LQIP tier cache even at full memScale.
  final bool useLqipTier;
  /// When false, no black underlay (for overlays on top of another poster).
  final bool opaqueBase;

  @override
  State<ReelGaplessPoster> createState() => _ReelGaplessPosterState();
}

class _ReelGaplessPosterState extends State<ReelGaplessPoster> {
  ImageProvider? _resolvedPrimary;
  ImageProvider? _resolvedBlur;
  int _warmGeneration = 0;

  bool get _isImagePost =>
      widget.cacheKey != null && widget.cacheKey!.startsWith('image_post_');

  bool get _isLqipLayer => widget.useLqipTier || widget.memScale < 1.0;

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
  void didUpdateWidget(ReelGaplessPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.blurUrl != widget.blurUrl) {
      _hydrateFromRamCacheSync();
      _warmProviders();
    }
  }

  ImageProvider? _cachedLqipFor(String url) {
    if (url.isEmpty) {
      return null;
    }
    if (_isImagePost) {
      return ReelImagePostCache.getLqip(url);
    }
    return ReelPosterImageCache.get(ReelPosterTierKeys.lqip(url)) ??
        ReelPosterImageCache.get(url);
  }

  ImageProvider? _cachedFullFor(String url) {
    if (url.isEmpty) {
      return null;
    }
    if (_isImagePost) {
      return ReelImagePostCache.getFull(url);
    }
    return ReelPosterImageCache.get(url);
  }

  ImageProvider? _cachedProviderFor(String url, {required bool lqip}) {
    return lqip ? _cachedLqipFor(url) : _cachedFullFor(url);
  }

  void _putCachedProvider(String url, ImageProvider provider, {required bool lqip}) {
    if (url.isEmpty) {
      return;
    }
    if (_isImagePost) {
      if (lqip) {
        ReelImagePostCache.putLqip(url, provider);
      } else {
        ReelImagePostCache.putFull(url, provider);
      }
    } else if (lqip) {
      ReelPosterImageCache.put(ReelPosterTierKeys.lqip(url), provider);
    } else {
      ReelPosterImageCache.put(url, provider);
    }
  }

  void _hydrateFromRamCacheSync({bool notify = true}) {
    final primary = widget.imageUrl.trim();
    final blur = widget.blurUrl?.trim() ?? '';
    final cachedPrimary = _cachedProviderFor(
      primary,
      lqip: _isLqipLayer,
    );
    var cachedBlur =
        blur.isEmpty ? null : _cachedProviderFor(blur, lqip: true);
    if (cachedBlur == null &&
        !_isLqipLayer &&
        !_isImagePost &&
        primary.isNotEmpty &&
        (blur.isEmpty || blur == primary)) {
      cachedBlur = _cachedLqipFor(primary);
    }
    var changed = false;
    if (cachedPrimary != null && cachedPrimary != _resolvedPrimary) {
      _resolvedPrimary = cachedPrimary;
      changed = true;
    }
    if (cachedBlur != null && cachedBlur != _resolvedBlur) {
      _resolvedBlur = cachedBlur;
      changed = true;
    }
    if (changed && mounted && notify) {
      setState(() {});
    }
  }

  ImageProvider _providerForUrl(String url, {required bool lqip}) {
    if (lqip) {
      return reelPosterLqipPrecacheProvider(url, context);
    }
    return reelPosterPrecacheProvider(url, context);
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
      blurProvider = _cachedProviderFor(blur, lqip: true);
      if (blurProvider == null) {
        blurProvider = _providerForUrl(blur, lqip: true);
        try {
          await precacheImage(blurProvider, context);
          if (!mounted || generation != _warmGeneration) {
            return;
          }
          _putCachedProvider(blur, blurProvider, lqip: true);
          setState(() => _resolvedBlur = blurProvider);
        } catch (_) {}
      }
    }

    if (primary.isNotEmpty) {
      final primaryLqip = _isLqipLayer;
      primaryProvider = _cachedProviderFor(primary, lqip: primaryLqip);
      if (primaryProvider == null) {
        primaryProvider = _providerForUrl(primary, lqip: primaryLqip);
        try {
          await precacheImage(primaryProvider, context);
          if (!mounted || generation != _warmGeneration) {
            return;
          }
          _putCachedProvider(primary, primaryProvider, lqip: primaryLqip);
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
        '[ReelsPoster] image_warmed url=${primary.length > 48 ? '${primary.substring(0, 48)}...' : primary} '
        'lqip=${blur.isNotEmpty || _isLqipLayer} full=${!_isLqipLayer} resolved=${primaryProvider != null}',
      );
    }
  }

  ImageProvider? get _effectiveBlurProvider {
    if (_resolvedBlur != null) {
      return _resolvedBlur;
    }
    final blur = widget.blurUrl?.trim() ?? '';
    final primary = widget.imageUrl.trim();
    if (!_isImagePost &&
        !_isLqipLayer &&
        _resolvedPrimary == null &&
        primary.isNotEmpty &&
        (blur.isEmpty || blur == primary)) {
      return _cachedLqipFor(primary);
    }
    return null;
  }

  bool get _showLqipUnderlay {
    if (_isLqipLayer || _resolvedPrimary != null) {
      return false;
    }
    final blur = widget.blurUrl?.trim() ?? '';
    return blur.isNotEmpty || _effectiveBlurProvider != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedPrimary == null && _resolvedBlur == null) {
      _hydrateFromRamCacheSync(notify: false);
    }

    final effectiveBlur = _effectiveBlurProvider;
    final fallback = widget.fallbackUrl?.trim() ?? '';
    final showOpaqueBase = widget.opaqueBase &&
        _resolvedPrimary == null &&
        effectiveBlur == null &&
        fallback.isEmpty;

    if (!kReleaseMode &&
        !showOpaqueBase &&
        _resolvedPrimary == null &&
        effectiveBlur == null) {
      // Every layer falls back to CachedNetworkImage, whose placeholder is an
      // empty box — this poster paints nothing until bytes decode.
      debugPrint(
        '[PosterBlank] key=${widget.cacheKey} '
        'url=${widget.imageUrl.split('/').last} fallback=$fallback',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Always keep a base while nothing has decoded — `opaqueBase: false`
        // + empty CachedNetworkImage placeholders painted the black scaffold
        // after Near Me location grant (every poster cold at once).
        if (_resolvedPrimary == null)
          const ColoredBox(color: Color(0xFF111111)),
        if (showOpaqueBase) const ColoredBox(color: Colors.black),
        // Paint fallback / thumb immediately so swipe landings never flash a
        // bare black base while the primary decode is still in flight.
        if (_resolvedPrimary == null &&
            fallback.isNotEmpty &&
            fallback != widget.imageUrl.trim())
          _PosterImageLayer(
            url: fallback,
            context: context,
            fit: widget.fit,
            memScale: 0.5,
            filterQuality: FilterQuality.low,
            resolvedProvider: _cachedProviderFor(fallback, lqip: true) ??
                _cachedProviderFor(fallback, lqip: false),
            cacheAsLqip: true,
            isImagePost: _isImagePost,
          ),
        if (_showLqipUnderlay)
          _PosterImageLayer(
            url: (widget.blurUrl?.trim().isNotEmpty == true)
                ? widget.blurUrl!.trim()
                : widget.imageUrl.trim(),
            context: context,
            fit: BoxFit.cover,
            memScale: 0.35,
            filterQuality: FilterQuality.low,
            resolvedProvider: effectiveBlur,
            cacheAsLqip: true,
            isImagePost: _isImagePost,
          ),
        if (widget.imageUrl.trim().isNotEmpty)
          _PosterImageLayer(
            url: widget.imageUrl.trim(),
            context: context,
            fit: widget.fit,
            cacheKey: widget.cacheKey,
            fallbackUrl: widget.fallbackUrl,
            memScale: widget.memScale,
            filterQuality: widget.filterQuality,
            resolvedProvider: _resolvedPrimary,
            cacheAsLqip: _isLqipLayer,
            isImagePost: _isImagePost,
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
    this.cacheAsLqip = false,
    this.isImagePost = false,
  });

  final String url;
  final BuildContext context;
  final BoxFit fit;
  final String? cacheKey;
  final String? fallbackUrl;
  final double memScale;
  final FilterQuality filterQuality;
  final ImageProvider? resolvedProvider;
  final bool cacheAsLqip;
  final bool isImagePost;

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
        placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
        errorWidget: (_, __, ___) {
          final fallback = fallbackUrl?.trim() ?? '';
          if (fallback.isEmpty || fallback == url) {
            return const ColoredBox(color: Color(0xFF111111));
          }
          final (memW, _) = fullScreenPosterMemCacheSize(context);
          final scaledW = (memW * memScale).round().clamp(64, memW);
          return CachedNetworkImage(
            imageUrl: fallback,
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
            imageBuilder: (ctx, imageProvider) => Image(
              image: imageProvider,
              fit: fit,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: filterQuality,
            ),
          );
        },
        imageBuilder: (ctx, imageProvider) {
          if (isImagePost) {
            if (cacheAsLqip) {
              ReelImagePostCache.putLqip(url, imageProvider);
            } else {
              ReelImagePostCache.putFull(url, imageProvider);
            }
          } else if (cacheAsLqip) {
            ReelPosterImageCache.put(ReelPosterTierKeys.lqip(url), imageProvider);
          } else {
            ReelPosterImageCache.put(url, imageProvider);
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
