import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/backbutton.dart';
import '../extensions/context_extensions.dart';
import 'responsive_text_widget.dart';
import 'responsive_widget.dart';

/// Pink header bar matching [DetailView] and main festival sub-screens.
class PinkSubpageHeader extends StatelessWidget {
  const PinkSubpageHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  static const Color barColor = Color(0xFFFC2E95);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: barColor,
      child: ResponsivePadding(
        mobilePadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.appBarHorizontalMobile,
          vertical: AppDimensions.appBarVerticalMobile,
        ),
        tabletPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.appBarHorizontalTablet,
          vertical: AppDimensions.appBarVerticalTablet,
        ),
        desktopPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.appBarHorizontalDesktop,
          vertical: AppDimensions.appBarVerticalDesktop,
        ),
        child: Row(
          children: [
            CustomBackButton(
              onTap: onBack ?? () => Navigator.of(context).pop(),
            ),
            SizedBox(width: context.getConditionalSpacing()),
            Expanded(
              child: ResponsiveTextWidget(
                title,
                textType: TextType.title,
                fontSize: context.getConditionalMainFont(),
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
