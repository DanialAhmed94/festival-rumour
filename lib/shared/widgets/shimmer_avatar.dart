import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final String fallbackLetter;
  final Color backgroundColor;

  const ShimmerAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 16,
    this.fallbackLetter = 'U',
    this.backgroundColor = const Color(0x4DFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          fallbackLetter,
          style: TextStyle(
            color: AppColors.black,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: photoUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: AppColors.grey300,
        highlightColor: AppColors.grey100,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.grey300,
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          fallbackLetter,
          style: TextStyle(
            color: AppColors.black,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
