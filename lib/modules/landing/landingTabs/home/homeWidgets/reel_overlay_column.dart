import 'package:cookster/core/widgets/reel_action_rail.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeModel/videoFeedModel.dart';
import 'package:flutter/material.dart';

/// Legacy wrapper — delegates to [ReelActionRail] with layout presets.
class ReelOverlayColumn extends StatelessWidget {
  const ReelOverlayColumn({
    super.key,
    required this.video,
    required this.isAuthenticated,
    this.listenLive = true,
    this.iconOnlyLikeAndSave = false,
    this.hideViewAndLikeCounts = false,
  });

  final WallVideos video;
  final bool isAuthenticated;
  final bool listenLive;
  final bool iconOnlyLikeAndSave;
  final bool hideViewAndLikeCounts;

  @override
  Widget build(BuildContext context) {
    final layout = hideViewAndLikeCounts
        ? ReelActionRailLayout.profile
        : ReelActionRailLayout.collection;

    return ReelActionRail(
      video: video,
      isAuthenticated: isAuthenticated,
      layout: layout,
      listenLive: listenLive,
    );
  }
}
