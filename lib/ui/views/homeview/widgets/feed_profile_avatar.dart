import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';

/// Small circular avatar for feed headers: stable [ValueKey], bounded decode/cache size,
/// and [RepaintBoundary] so parent post rebuilds (reactions, video state) repaint less around the image.
///
/// Rows that share the same [userId] + [imageUrl] use the same [cacheKey] so in-memory /
/// disk caches dedupe downloads; decoding is capped to roughly on-screen avatar pixels.
class FeedProfileAvatar extends StatelessWidget {
  const FeedProfileAvatar({
    super.key,
    required this.userId,
    required this.imageUrl,
    this.fallbackAsset = AppAssets.profile,
  });

  /// Firestore UID (or empty if missing); included in cache key with [imageUrl].
  final String userId;
  /// Profile photo URL; null/empty uses [fallbackAsset].
  final String? imageUrl;
  final String fallbackAsset;

  static const double _logicalDiameter = 40;

  static int _pixelsForDiameter(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 4.0);
    return (_logicalDiameter * dpr).round();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    final cacheKey =
        '${userId.isEmpty ? 'anon' : userId}|${hasUrl ? url : 'asset'}';

    if (!hasUrl) {
      return CircleAvatar(
        radius: _logicalDiameter / 2,
        backgroundColor: AppColors.primary,
        backgroundImage: AssetImage(fallbackAsset),
      );
    }

    final px = _pixelsForDiameter(context);

    final image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: px,
      memCacheHeight: px,
      maxWidthDiskCache: px,
      maxHeightDiskCache: px,
      filterQuality: FilterQuality.low,
      width: _logicalDiameter,
      height: _logicalDiameter,
      fit: BoxFit.cover,
      placeholder: (context, _) => Shimmer.fromColors(
        baseColor: AppColors.grey300,
        highlightColor: AppColors.grey100,
        child: Container(
          color: AppColors.grey300,
          width: _logicalDiameter,
          height: _logicalDiameter,
        ),
      ),
      errorWidget: (context, loadedUrl, error) {
        return Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          width: _logicalDiameter,
          height: _logicalDiameter,
        );
      },
    );

    return RepaintBoundary(
      child: CircleAvatar(
        radius: _logicalDiameter / 2,
        backgroundColor: AppColors.primary,
        child: ClipOval(child: image),
      ),
    );
  }
}
