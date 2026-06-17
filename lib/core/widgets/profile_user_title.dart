import 'package:cookster/core/user/public_user_identity.dart';
import 'package:flutter/material.dart';

/// TikTok-style profile title: display [name] with @handle underneath.
class ProfileUserTitle extends StatelessWidget {
  const ProfileUserTitle({
    super.key,
    required this.displayName,
    this.userName,
    this.nameStyle,
    this.handleStyle,
    this.textAlign = TextAlign.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String? displayName;
  final String? userName;
  final TextStyle? nameStyle;
  final TextStyle? handleStyle;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim() ?? '';
    final handle = PublicUserIdentity.formatAtHandle(userName);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        if (handle.isNotEmpty)
          Text(
            handle,
            textAlign: textAlign,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: handleStyle,
          ),
      ],
    );
  }
}
