import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../profile_list_view_model.dart';

class AttendedFestivalsTab extends StatelessWidget {
  final ProfileListViewModel viewModel;
  const AttendedFestivalsTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingAttended) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return viewModel.attendedFestivals.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available,
                  color: AppColors.black54,
                  size: 64,
                ),
                const SizedBox(height: AppDimensions.spaceM),
                ResponsiveText(
                  'No attended festivals yet',
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: AppDimensions.textM,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            itemCount: viewModel.attendedFestivals.length,
            itemBuilder: (context, index) {
              final festival = viewModel.attendedFestivals[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: AppColors.grey300,
                    width: AppDimensions.dividerThickness,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppDimensions.imageM,
                      height: AppDimensions.imageM,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.avatarS),
                      ),
                      child: const Icon(
                        Icons.event_available,
                        color: AppColors.primary,
                        size: AppDimensions.imageM,
                      ),
                    ),
                    SizedBox(width: AppDimensions.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveText(
                            festival['title'] ?? 'Unknown Festival',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: AppDimensions.textM,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppDimensions.spaceXS),
                          ResponsiveText(
                            (festival['location'] ?? '').toString().isEmpty
                                ? '—'
                                : (festival['location'] ?? '—').toString(),
                            style: const TextStyle(
                              color: AppColors.grey600,
                              fontSize: AppDimensions.textM,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: AppDimensions.iconL,
                    ),
                  ],
                ),
              );
            },
          );
  }
}
