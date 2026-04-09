import 'package:flutter_svg/flutter_svg.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../shared/widgets/responsive_widget.dart'; // Make sure locator is registered for NavigationService

class GridOption extends StatelessWidget {
  final String title;
  /// SVG asset path (e.g. [AppAssets.locationIconSvg]). Omit when [iconData] is set.
  final String? icon;
  /// Optional Material icon when no SVG exists (e.g. inner map).
  final IconData? iconData;
  final Function(String)? onNavigateToSub;
  final VoidCallback? onTap;

  const GridOption({
    super.key,
    required this.title,
    this.icon,
    this.iconData,
    this.onNavigateToSub,
    this.onTap,
  }) : assert(
          icon != null || iconData != null,
          'GridOption requires icon or iconData',
        );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Call the passed callback first (if provided)
        if (onTap != null) {
          onTap!();
        } else {
          // Otherwise, use your internal navigation handler
          _handleNavigation(title);
        }
      },

      child: Container(
        height: context.isSmallScreen
            ? context.screenHeight * 0.18
            : context.isMediumScreen
                ? context.screenHeight * 0.20
                : context.screenHeight * 0.22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          color: AppColors.white,
          border: Border.all(color: AppColors.secondary, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                      vertical: AppDimensions.paddingM,
                    ),
                    child: iconData != null
                        ? Icon(
                            iconData,
                            size: context.isSmallScreen ? 40 : 48,
                            color: AppColors.secondary,
                          )
                        : SvgPicture.asset(
                            icon!,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingS,
                  AppDimensions.paddingXS,
                  AppDimensions.paddingS,
                  AppDimensions.paddingS,
                ),
                child: ResponsiveText(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: AppDimensions.textL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Handles navigation based on title
  void _handleNavigation(String title) {
    if (onNavigateToSub != null) {
      switch (title.toUpperCase()) {
        case 'CHAT ROOMS':
          onNavigateToSub!('chat');
          break;
        case 'LOCATION':
          onNavigateToSub!('map');
          break;
        case 'DETAIL':
          onNavigateToSub!('detail');
          break;
        default:
          // Do nothing for unknown titles
          break;
      }
    }
  }
}
