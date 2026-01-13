import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_assets.dart';
import '../festival_model.dart';


class FestivalCard extends StatefulWidget {
  final FestivalModel festival;
  final VoidCallback? onBack;
  final VoidCallback? onTap;
  final VoidCallback? onNext;

  const FestivalCard({
    super.key,
    required this.festival,
    this.onBack,
    this.onTap,
    this.onNext,
  });

  @override
  State<FestivalCard> createState() => _FestivalCardState();
}

class _FestivalCardState extends State<FestivalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    // Play animation once when card is first displayed
    _playAnimation();
  }

  void _playAnimation() {
    if (!_hasPlayed && mounted) {
      _hasPlayed = true;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: AppDimensions.eventCardAspectRatio,
        child: Stack(
          children: [
            // Background Image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    child: widget.festival.imagepath.isNotEmpty
                  ? Image.network(
                      widget.festival.imagepath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to asset image if network image fails
                        return Image.asset(
                          AppAssets.festivalimage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        // Show loading indicator while image loads
                        return Container(
                          color: AppColors.onSurfaceVariant.withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      AppAssets.festivalimage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
            // Overlay and Content
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                child: Stack(
                  children: [
                    // Overlay
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.eventOverlay,
                      ),
                    ),

                    // Status badge (Past, Live, or Upcoming)
                    Positioned(
                      top: AppDimensions.paddingS,
                      left: AppDimensions.paddingS,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingM,
                            vertical: AppDimensions.paddingXS),
                        decoration: BoxDecoration(
                          color: AppColors.nowBadge,
                          borderRadius:
                          BorderRadius.circular(AppDimensions.radiusS),
                        ),
                        child: Text(
                          _getStatusText(widget.festival.status),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppDimensions.textXL,
                          ),
                        ),
                      ),
                    ),

                    // Back icon
                    Positioned(
                      top: AppDimensions.paddingS,
                      right: AppDimensions.paddingS,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.onPrimary,
                          border: Border.all(
                            color: AppColors.primary, // border color
                            width: 2.0, // border thickness
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.primary,
                          ),
                          onPressed: widget.onNext,
                        ),
                      ),
                    ),

                    // Lottie Animation at center (plays for 2 seconds)
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        // Hide animation after 2 seconds
                        if (_animationController.value >= 1.0) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Lottie.asset(
                            'assets/logos/anim_swipe.json',
                            fit: BoxFit.contain,
                            controller: _animationController,
                            width: 200,
                            height: 200,
                            frameRate: FrameRate(60), // Optimize frame rate
                          ),
                        );
                      },
                    ),

                    // Bottom Info
                    Positioned(
                      left: AppDimensions.paddingL,
                      right: AppDimensions.paddingL,
                      bottom: AppDimensions.paddingL,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.festival.location,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: AppDimensions.textS,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spaceXS),
                          Text(
                            widget.festival.title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: AppDimensions.textXXL,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spaceXS),
                          Text(
                            widget.festival.date,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: AppDimensions.textS,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get status text based on festival status
  String _getStatusText(FestivalStatus status) {
    switch (status) {
      case FestivalStatus.past:
        return AppStrings.past;
      case FestivalStatus.live:
        return AppStrings.live;
      case FestivalStatus.upcoming:
        return AppStrings.upcoming;
    }
  }
}
