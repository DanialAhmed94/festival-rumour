import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/models/bulletin_model.dart';

/// Full-screen view showing a single bulletin's detail (title, content, time, date).
/// Used when opening "View Detail" from View All news list.
class BulletinDetailView extends StatelessWidget {
  final BulletinModel bulletin;

  const BulletinDetailView({super.key, required this.bulletin});

  @override
  Widget build(BuildContext context) {
    final title = bulletin.title ?? AppStrings.news;
    final content = bulletin.content ?? '';
    final timeStr = bulletin.time ?? '—';
    final dateStr = bulletin.date ?? '—';

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(
                      context,
                      AppStrings.titleName,
                      title,
                      Icons.auto_fix_high,
                    ),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildInfoCard(
                      context,
                      AppStrings.content,
                      content,
                      Icons.content_paste,
                    ),
                    const SizedBox(height: AppDimensions.spaceM),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard2(
                            context,
                            AppStrings.time,
                            timeStr,
                            Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceM),
                        Expanded(
                          child: _buildInfoCard2(
                            context,
                            AppStrings.date,
                            dateStr,
                            Icons.calendar_today,
                          ),
                        ),
                      ],
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

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.eventGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          ResponsiveTextWidget(
            AppStrings.bulletinPreview,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: AppDimensions.iconM,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  label,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  value,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard2(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.newsLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: AppDimensions.iconS,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  label,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  value,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
