import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class ActionTile extends StatelessWidget {
  final String iconPath; // image path (PNG/JPG)
  final String text;
  final bool isSelected; // 👈 add this
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? trailingIconColor;

  const ActionTile({
    super.key,
    required this.iconPath,
    required this.text,
    this.isSelected = false, // 👈 default false
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.trailingIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.onSurface),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingM,
          horizontal: AppDimensions.paddingM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      iconPath,
                      height: 24,
                      width: 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceM),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: textColor ??
                            (isSelected ? AppColors.accent : AppColors.primary),
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: isSelected
                  ? const Icon(Icons.check,
                  key: ValueKey('check'),
                  color: AppColors.accent,
                  size: 18)
                  : Icon(
                      Icons.arrow_forward_ios,
                      key: const ValueKey('arrow'),
                      color: trailingIconColor ?? AppColors.white,
                      size: 12,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
