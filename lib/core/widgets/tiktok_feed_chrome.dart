import 'package:flutter/material.dart';

/// TikTok-style feed chrome tokens (gradients, tab chrome, action labels).
class TikTokFeedChrome {
  const TikTokFeedChrome._();

  static const double topGradientHeight = 128;
  static const double bottomGradientHeight = 260;
  static const double actionRailBottomInset = 12;
  static const double feedTabBarHeight = 54;
  static const double actionIconSize = 22;
  static const double actionAvatarSize = 44;
  static const double tabFontSize = 16;
  static const double tabHorizontalPadding = 12;

  static const List<Color> topGradientColors = [
    Color(0xB3000000),
    Color(0x66000000),
    Color(0x00000000),
  ];

  static const List<Color> bottomGradientColors = [
    Color(0x00000000),
    Color(0x59000000),
    Color(0xB3000000),
  ];

  static TextStyle tabLabel({required bool selected}) {
    return TextStyle(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      fontSize: tabFontSize,
      letterSpacing: 0.2,
      shadows: selected ? labelShadow : null,
    );
  }

  static TextStyle actionCount = const TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    shadows: labelShadow,
  );

  static BoxDecoration actionPillDecoration = BoxDecoration(
    color: Colors.black.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.12),
      width: 0.5,
    ),
  );

  static TextStyle actionCaption = const TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    shadows: labelShadow,
  );

  static TextStyle userName = const TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    shadows: labelShadow,
  );

  static TextStyle bodyCaption = const TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    shadows: labelShadow,
  );

  static const List<Shadow> labelShadow = [
    Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
  ];
}

class TikTokFeedTopGradient extends StatelessWidget {
  const TikTokFeedTopGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: TikTokFeedChrome.topGradientHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: TikTokFeedChrome.topGradientColors,
            ),
          ),
        ),
      ),
    );
  }
}

class TikTokFeedBottomGradient extends StatelessWidget {
  const TikTokFeedBottomGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: TikTokFeedChrome.bottomGradientHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: TikTokFeedChrome.bottomGradientColors,
            ),
          ),
        ),
      ),
    );
  }
}

class TikTokFeedTabLabel extends StatelessWidget {
  const TikTokFeedTabLabel({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TikTokFeedChrome.tabHorizontalPadding,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TikTokFeedChrome.tabLabel(selected: selected),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TikTokFeedTopIconButton extends StatelessWidget {
  const TikTokFeedTopIconButton({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}
