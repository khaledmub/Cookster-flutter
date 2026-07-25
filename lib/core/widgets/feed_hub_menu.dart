import 'package:cookster/appRoutes/appRoutes.dart';
import 'package:cookster/goLive/join_screen.dart';
import 'package:cookster/modules/chatScreen/userChatList.dart';
import 'package:cookster/modules/landing/landingTabs/home/homeController/homeController.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _HubAction { live, chat, filter }

/// Shared navigation for feed hub actions (Live, Chat).
class FeedHubActions {
  FeedHubActions._();

  static void openLive({required bool isAuthenticated}) {
    if (!isAuthenticated) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().silenceHomeReelsForTransition();
    }
    Get.to(() => JoinScreen());
  }

  static Future<void> openChat({required bool isAuthenticated}) async {
    if (!isAuthenticated) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().silenceHomeReelsForTransition();
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    Get.to(() => ChatListScreen(userId: userId));
  }
}

/// Drop-down hub menu for Live, Chat, and Filter.
class FeedHubRadialMenu {
  FeedHubRadialMenu._();

  static Future<void> showFromKey(
    BuildContext context, {
    required GlobalKey anchorKey,
    required VoidCallback onFilter,
    required bool isAuthenticated,
  }) async {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !context.mounted) {
      return;
    }
    await show(
      context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      onFilter: onFilter,
      isAuthenticated: isAuthenticated,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required Rect anchorRect,
    required VoidCallback onFilter,
    required bool isAuthenticated,
  }) async {
    if (!context.mounted) {
      return;
    }
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, _, __) {
        return _FeedHubMenuOverlay(
          anchorRect: anchorRect,
          onLive: () {
            Navigator.of(dialogContext).pop();
            FeedHubActions.openLive(isAuthenticated: isAuthenticated);
          },
          onChat: () {
            Navigator.of(dialogContext).pop();
            FeedHubActions.openChat(isAuthenticated: isAuthenticated);
          },
          onFilter: () {
            Navigator.of(dialogContext).pop();
            onFilter();
          },
          onDismiss: () => Navigator.of(dialogContext).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }
}

class _FeedHubMenuOverlay extends StatelessWidget {
  const _FeedHubMenuOverlay({
    required this.anchorRect,
    required this.onLive,
    required this.onChat,
    required this.onFilter,
    required this.onDismiss,
  });

  final Rect anchorRect;
  final VoidCallback onLive;
  final VoidCallback onChat;
  final VoidCallback onFilter;
  final VoidCallback onDismiss;

  static const _items = [
    _HubMenuItem(
      action: _HubAction.live,
      labelKey: 'livec',
      iconAsset: 'assets/icons/live.svg',
    ),
    _HubMenuItem(
      action: _HubAction.chat,
      labelKey: 'chats',
      iconAsset: 'assets/icons/chatIcon.svg',
    ),
    _HubMenuItem(
      action: _HubAction.filter,
      labelKey: 'Filter',
      iconAsset: 'assets/icons/filter.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    const itemWidth = 72.0;
    const gap = 10.0;
    const horizontalPad = 12.0;
    const menuWidth = itemWidth * 3 + gap * 2 + horizontalPad * 2;

    // Drop below the hub icon, fully inside the screen.
    final top = anchorRect.bottom + 10;
    var left = anchorRect.center.dx - menuWidth / 2;
    left = left.clamp(8.0, screenWidth - menuWidth - 8.0);

    VoidCallback handler(_HubAction action) => switch (action) {
          _HubAction.live => onLive,
          _HubAction.chat => onChat,
          _HubAction.filter => onFilter,
        };

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _HubMenuButton(
                        label: _items[i].labelKey.tr,
                        iconAsset: _items[i].iconAsset,
                        onTap: handler(_items[i].action),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubMenuItem {
  const _HubMenuItem({
    required this.action,
    required this.labelKey,
    required this.iconAsset,
  });

  final _HubAction action;
  final String labelKey;
  final String iconAsset;
}

class _HubMenuButton extends StatelessWidget {
  const _HubMenuButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      height: 22.sp,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header hub trigger (Live / Chat / Filter menu).
class FeedHubIconButton extends StatelessWidget {
  const FeedHubIconButton({
    super.key,
    required this.anchorKey,
    required this.isAuthenticated,
    required this.onFilter,
    this.showFilterBadge = false,
    this.iconSize = 26,
  });

  final GlobalKey anchorKey;
  final bool isAuthenticated;
  final VoidCallback onFilter;
  final bool showFilterBadge;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: anchorKey,
      child: InkWell(
        onTap: () => FeedHubRadialMenu.showFromKey(
          context,
          anchorKey: anchorKey,
          onFilter: onFilter,
          isAuthenticated: isAuthenticated,
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: iconSize,
              ),
              if (showFilterBadge)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
