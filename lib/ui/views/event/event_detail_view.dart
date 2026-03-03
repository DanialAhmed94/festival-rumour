import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/models/event_model.dart';

/// Full-screen event detail (same info as crapadvisor EventDetail).
/// Used from EventView first-four list and View All events list.
class EventDetailView extends StatelessWidget {
  final EventModel event;

  const EventDetailView({super.key, required this.event});

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
                    _buildWhiteCard(context, AppStrings.titleName, event.eventTitle ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.content, event.eventDescription ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.crowdCapacity, event.crowdCapacity ?? '—'),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildImageSection(context),
                    const SizedBox(height: AppDimensions.spaceM),
                    Row(
                      children: [
                        Expanded(child: _buildWhiteCard(context, AppStrings.startTime, event.startTime ?? '—')),
                        const SizedBox(width: AppDimensions.spaceM),
                        Expanded(child: _buildWhiteCard(context, AppStrings.endTime, event.endTime ?? '—')),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildWhiteCard(context, AppStrings.date, event.startDate ?? '—'),
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
              event.eventTitle ?? AppStrings.events,
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

  Widget _buildImageSection(BuildContext context) {
    final imageUrl = event.imageUrl;
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
          ResponsiveTextWidget(AppStrings.image, style: const TextStyle(color: AppColors.onPrimary, fontSize: AppDimensions.textL, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spaceM),
          SizedBox(
            height: AppDimensions.imageXXL,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator(color: AppColors.black, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) : null));
                      },
                      errorBuilder: (_, __, ___) => Center(child: Image.asset(AppAssets.assignmentIcon, fit: BoxFit.contain)),
                    )
                  : Center(child: Image.asset(AppAssets.assignmentIcon, fit: BoxFit.contain)),
            ),
          ),
        ],
      ),
    );
  }
}
