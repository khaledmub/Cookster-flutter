  /// Scroll-direction-aware prefetch index list for reels.
///
/// When scrolling down ([towardIndex] > [fromIndex]), warms +1..+depth ahead
/// and one item behind. When scrolling up, mirrors in the opposite direction.
List<int> buildDirectionalPrefetchIndices({
  required int fromIndex,
  required int towardIndex,
  required int depth,
  int extraDepth = 0,
}) {
  final effectiveDepth = depth + extraDepth;
  if (effectiveDepth <= 0) {
    return [towardIndex];
  }
  if (towardIndex == fromIndex) {
    return <int>{
      towardIndex,
      for (var step = 1; step <= effectiveDepth; step++) fromIndex + step,
      fromIndex - 1,
      if (effectiveDepth >= 2) fromIndex - 2,
    }.toList();
  }

  final direction = towardIndex > fromIndex ? 1 : -1;
  final indices = <int>{
    towardIndex,
    towardIndex + direction,
    if (effectiveDepth >= 2) towardIndex + direction * 2,
    fromIndex - direction,
    if (effectiveDepth >= 2) fromIndex - direction * 2,
  };
  for (var step = 1; step <= effectiveDepth; step++) {
    indices.add(towardIndex + direction * step);
  }
  return indices.toList();
}

/// After page settle — bias forward but keep one item behind in disk cache.
List<int> buildSettledPrefetchIndices({
  required int visibleIndex,
  required int depth,
}) {
  if (depth <= 0) {
    return [visibleIndex];
  }
  return <int>{
    visibleIndex,
    for (var step = 1; step <= depth; step++) visibleIndex + step,
    visibleIndex - 1,
    if (depth >= 2) visibleIndex - 2,
  }.toList();
}

/// Fast scroll threshold (fractional pages per second) for +1 prefetch depth.
const double kReelsFastScrollVelocityThreshold = 2.0;
