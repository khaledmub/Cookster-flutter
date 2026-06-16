/// Pure decision logic for feed ping-pong — unit-testable without native [Player].
enum FeedPresentPlan {
  /// Hidden slot already has the reel — flip visibility, no open on visible slot.
  flipToHidden,

  /// Active slot already has the reel — seek/unmute only.
  keepActive,

  /// Cold present — open on the hidden slot, then flip (never open on visible).
  openOnHiddenThenFlip,
}

enum FeedPrefetchPlan {
  skipAlreadyBound,
  skipSameAsActive,
  openOnHidden,
}

class FeedPingPongLogic {
  const FeedPingPongLogic._();

  static FeedPresentPlan planPresent({
    required String? activeKey,
    required String? activeUrl,
    required String? hiddenKey,
    required String? hiddenUrl,
    required String requestKey,
    required String requestUrl,
  }) {
    if (hiddenKey != null &&
        hiddenKey.isNotEmpty &&
        hiddenKey == requestKey) {
      return FeedPresentPlan.flipToHidden;
    }
    if (activeKey != null &&
        activeKey.isNotEmpty &&
        activeKey == requestKey) {
      return FeedPresentPlan.keepActive;
    }
    return FeedPresentPlan.openOnHiddenThenFlip;
  }

  static FeedPrefetchPlan planPrefetch({
    required String? activeKey,
    required String? hiddenKey,
    required String? hiddenUrl,
    required String requestKey,
    required String requestUrl,
  }) {
    if (hiddenKey != null &&
        hiddenKey.isNotEmpty &&
        hiddenKey == requestKey) {
      return FeedPrefetchPlan.skipAlreadyBound;
    }
    if (activeKey == requestKey) {
      return FeedPrefetchPlan.skipSameAsActive;
    }
    return FeedPrefetchPlan.openOnHidden;
  }

  static bool shouldRecycleHidden({
    required int hiddenOpenCount,
    required int recycleAfterOpens,
  }) {
    return hiddenOpenCount >= recycleAfterOpens;
  }

  static int flippedActiveIndex(int currentActiveIndex) => 1 - currentActiveIndex;

  static int hiddenSlotIndex(int activeSlotIndex) => 1 - activeSlotIndex;

  /// True when an async operation started with [token] should be abandoned.
  static bool isStaleToken(int token, int currentToken) => token < currentToken;

  /// Whether presenting a reel should unmute the active slot.
  static bool shouldUnmuteOnPresent({
    required bool userPaused,
    required bool suspended,
  }) {
    return !userPaused && !suspended;
  }

  /// Avoid AudioTrack start/stop storms — skip redundant resume when already audible.
  static bool shouldResumeAudible({
    required bool userPaused,
    required bool alreadyAudible,
  }) {
    return !userPaused && !alreadyAudible;
  }

  /// Feed audible state is volume-only on MTK (never trust [Player.state.playing]).
  static bool isFeedAudibleByVolume(int volume) => volume > 50;

  /// Hidden recycle must never run on the currently visible slot.
  static bool shouldDeferHiddenRecycle({
    required int hiddenOpenCount,
    required int recycleAfterOpens,
    required bool openTokenStable,
  }) {
    if (!openTokenStable) {
      return true;
    }
    return !shouldRecycleHidden(
      hiddenOpenCount: hiddenOpenCount,
      recycleAfterOpens: recycleAfterOpens,
    );
  }
}
