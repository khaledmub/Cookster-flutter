import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookster/core/widgets/grid_thumbnail_cache.dart';
import 'package:flutter/material.dart';

/// Profile video grid cell — black base so white scaffold does not flash through.
class ProfileGridThumbnail extends StatelessWidget {
  const ProfileGridThumbnail({
    super.key,
    required this.coverUrl,
    this.borderRadius = 12,
    this.logicalSize = 100,
    this.fallbackAsset = 'assets/images/food1.jpg',
  });

  final String? coverUrl;
  final double borderRadius;
  final double logicalSize;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final mem = gridThumbnailMemCacheSize(logicalSize);
    final url = coverUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: Colors.black,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: mem,
                memCacheHeight: mem,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => Image.asset(
                  fallbackAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                errorWidget: (_, __, ___) => Image.asset(
                  fallbackAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Image.asset(
                fallbackAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }
}
