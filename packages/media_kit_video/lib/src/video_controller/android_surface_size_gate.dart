/// Cookster / Honor-MTK gate: keep Android surface sizes even and stable.
///
/// media_kit's [AndroidVideoController] normally forwards raw codec container
/// sizes (`event.dw` / `event.dh`) straight into
/// `VideoOutputManager.SetSurfaceSize`. Odd heights (e.g. 721 for a 720p file)
/// recreate the ImageReader / BufferQueue even when only parity changed.
///
/// Clamp **before** that native call so reopen/cached switches never tear
/// down the surface for a ±1 odd/even report.
class AndroidSurfaceSizeGate {
  AndroidSurfaceSizeGate._();

  /// Last successfully painted even size (shared across the feed player).
  static int? preferredEvenWidth;
  static int? preferredEvenHeight;

  static void recordPainted(int? width, int? height) {
    if (width == null || height == null || width <= 1 || height <= 1) {
      return;
    }
    preferredEvenWidth = width.isOdd ? width - 1 : width;
    preferredEvenHeight = height.isOdd ? height - 1 : height;
  }

  static void clear() {
    preferredEvenWidth = null;
    preferredEvenHeight = null;
  }

  static int _even(int v) => v.isOdd ? v - 1 : v;

  /// True when [rawW]x[rawH] only differs from [targetW]x[targetH] by odd/even
  /// container padding (same evenized size).
  static bool _sameEvenized(int rawW, int rawH, int targetW, int targetH) {
    return _even(rawW) == _even(targetW) && _even(rawH) == _even(targetH);
  }

  /// Returns size safe for [SetSurfaceSize]; [GatedSurfaceSize.adjusted] is
  /// true when the raw report was changed for a benign parity-only case.
  static GatedSurfaceSize gate({
    required int width,
    required int height,
    int? currentWidth,
    int? currentHeight,
  }) {
    if (width <= 0 || height <= 0) {
      return GatedSurfaceSize(width: width, height: height, adjusted: false);
    }

    final rawW = width;
    final rawH = height;
    var w = _even(width);
    var h = _even(height);
    var adjusted = w != rawW || h != rawH;

    final preferW = preferredEvenWidth;
    final preferH = preferredEvenHeight;
    if (preferW != null &&
        preferH != null &&
        _sameEvenized(rawW, rawH, preferW, preferH)) {
      w = preferW;
      h = preferH;
      adjusted = w != rawW || h != rawH;
    } else if (currentWidth != null &&
        currentHeight != null &&
        _sameEvenized(rawW, rawH, currentWidth, currentHeight)) {
      // Prefer the already-attached surface size over a parity flip.
      w = _even(currentWidth);
      h = _even(currentHeight);
      adjusted = w != rawW || h != rawH;
    }

    return GatedSurfaceSize(width: w, height: h, adjusted: adjusted);
  }
}

class GatedSurfaceSize {
  const GatedSurfaceSize({
    required this.width,
    required this.height,
    required this.adjusted,
  });

  final int width;
  final int height;
  final bool adjusted;
}
