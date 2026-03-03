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

  static const Color _accentGreen = AppColors.eventGreen;
  static const Color _cardColor = AppColors.eventLightBlue;

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
                    _buildSectionLabel(context, 'Details'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.festival_rounded, AppStrings.festivalName, performance.festivalName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.event_rounded, AppStrings.events, performance.eventTitle ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.music_note_rounded, AppStrings.performanceTitle, performance.performanceTitle ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.person_rounded, AppStrings.artist, performance.artistName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.groups_rounded, 'Participants', performance.participantName ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.star_rounded, AppStrings.specialGuests, performance.specialGuests ?? '—'),
                    const SizedBox(height: AppDimensions.spaceS),
                    _buildDetailCard(context, Icons.note_alt_rounded, 'Special Notes', performance.technicalRequirementSpecialNotes ?? '—'),
                    const SizedBox(height: AppDimensions.spaceL),
                    _buildSectionLabel(context, 'Schedule'),
                    const SizedBox(height: AppDimensions.spaceS),
                    Row(
                      children: [
                        Expanded(child: _buildDetailCard(context, Icons.schedule_rounded, AppStrings.startTime, performance.startTime ?? '—')),
                        const SizedBox(width: AppDimensions.spaceS),
                        Expanded(child: _buildDetailCard(context, Icons.schedule_rounded, AppStrings.endTime, performance.endTime ?? '—')),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceS),
                    Row(
                      children: [
                        Expanded(child: _buildDetailCard(context, Icons.calendar_today_rounded, 'Start Date', performance.startDate ?? '—')),
                        const SizedBox(width: AppDimensions.spaceS),
                        Expanded(child: _buildDetailCard(context, Icons.calendar_today_rounded, 'End Date', performance.endDate ?? '—')),
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

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.spaceXS, bottom: AppDimensions.spaceXS),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.onPrimary.withOpacity(0.7),
          fontSize: AppDimensions.textS,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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

  Widget _buildDetailCard(BuildContext context, IconData icon, String title, String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        splashColor: _accentGreen.withOpacity(0.15),
        highlightColor: _accentGreen.withOpacity(0.08),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            border: Border.all(color: AppColors.onPrimary.withOpacity(0.06), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.onPrimary.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: Icon(icon, color: _accentGreen, size: 22),
              ),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveTextWidget(
                      title,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: AppDimensions.textS,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXS),
                    ResponsiveTextWidget(
                      value,
                      style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textM),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
