import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';
import '../../shared/extensions/context_extensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {"icon": Icons.home_outlined, "label": AppStrings.home},
      {"icon": Icons.explore_outlined, "label": AppStrings.discover},
      {"icon": Icons.person_outline, "label": AppStrings.profile},
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final double containerWidth = screenWidth / items.length;
    final double iconSize = _getResponsiveIconSize(context);
    final double fontSize = _getResponsiveFontSize(context);
    final double padding = _getResponsivePadding(context);
    final double spacing = _getResponsiveSpacing(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final bool selected = currentIndex == index;
            final item = items[index];

            return GestureDetector(
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: containerWidth,
                padding: EdgeInsets.symmetric(vertical: padding, horizontal: 8),
                child: _buildButton(
                  item,
                  selected,
                  iconSize,
                  fontSize,
                  spacing,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildButton(
    Map<String, dynamic> item,
    bool selected,
    double iconSize,
    double fontSize,
    double spacing,
  ) {
    // Determine colors based on selection state
    final iconColor = selected
        ? AppColors.black // Black for selected (contrasts well with accent)
        : const Color(0xFF9E9E9E); // Light gray for unselected
    final textColor = selected
        ? AppColors.black // Black for selected (contrasts well with accent)
        : const Color(0xFF9E9E9E); // Light gray for unselected (matches icon)

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            selected
                ? AppColors
                    .accent // Use app accent color for selected
                : Colors.transparent, // Transparent for unselected
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item["icon"] as IconData,
            color: iconColor,
            size: iconSize,
          ),
          SizedBox(height: spacing),
          Text(
            item["label"] as String,
            style: TextStyle(
              color: textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 11.sp,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Responsive helper methods
  double _getResponsiveIconSize(BuildContext context) {
    if (context.isHighResolutionPhone) return 28;
    if (context.isLargeScreen) return 32;
    if (context.isMediumScreen) return 26;
    return 24;
  }

  double _getResponsiveFontSize(BuildContext context) {
    if (context.isHighResolutionPhone) return 16;
    if (context.isLargeScreen) return 18;
    if (context.isMediumScreen) return 15;
    return 14;
  }

  double _getResponsivePadding(BuildContext context) {
    if (context.isHighResolutionPhone) return 12; // Reduced from 16
    if (context.isLargeScreen) return 16; // Reduced from 20
    if (context.isMediumScreen) return 10; // Reduced from 14
    return 8; // Reduced from 12
  }

  double _getResponsiveSpacing(BuildContext context) {
    if (context.isHighResolutionPhone) return 6; // Reduced from 8
    if (context.isLargeScreen) return 8; // Reduced from 10
    if (context.isMediumScreen) return 5; // Reduced from 7
    return 4; // Reduced from 6
  }
}
