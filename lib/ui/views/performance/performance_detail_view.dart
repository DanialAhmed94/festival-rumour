import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/models/performance_model.dart';

/// Full-screen performance detail (same info as crapadvisor Performancedetail).
/// Used from PerformanceView first-four list and View All performances list.
class PerformanceDetailView extends StatelessWidget {
  final PerformanceModel performance;

  const PerformanceDetailView({super.key, required this.performance});

  @override
  Widget build(BuildContext context) {
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
                    _buildWhiteCard(context, AppStrings.festivalName, performance.festivalName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.events, performance.eventTitle ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.performanceTitle, performance.performanceTitle ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.artist, performance.artistName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, 'Participants', performance.participantName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.specialGuests, performance.specialGuests ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    Row(
                      children: [
                        Expanded(child: _buildWhiteCard(context, AppStrings.startTime, performance.startTime ?? '—')),
                        const SizedBox(width: AppDimensions.spaceM),
                        Expanded(child: _buildWhiteCard(context, AppStrings.endTime, performance.endTime ?? '—')),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceM),
                    Row(
                      children: [
                        Expanded(child: _buildWhiteCard(context, 'Start Date', performance.startDate ?? '—')),
                        const SizedBox(width: AppDimensions.spaceM),
                        Expanded(child: _buildWhiteCard(context, 'End Date', performance.endDate ?? '—')),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(color: AppColors.eventGreen, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: AppColors.primary, size: AppDimensions.iconM),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: ResponsiveTextWidget(
              performance.performanceTitle ?? AppStrings.performance,
              style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCard(BuildContext context, String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.marginS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.eventLightBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [BoxShadow(color: AppColors.onPrimary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveTextWidget(title, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spaceS),
          ResponsiveTextWidget(value, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textM)),
        ],
      ),
    );
  }
}
