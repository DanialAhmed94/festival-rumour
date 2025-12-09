import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/festival_provider.dart';

class EventHeaderCard extends StatelessWidget {
  const EventHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FestivalProvider>(
      builder: (context, festivalProvider, child) {
        final selectedFestival = festivalProvider.selectedFestival;
        
        // Show selected festival info if available, otherwise show default/placeholder
        if (selectedFestival != null) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.onSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedFestival.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppDimensions.textXL,
                          color: AppColors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFestival.location,
                        style: const TextStyle(
                          color: AppColors.grey400,
                          fontSize: AppDimensions.textS,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFestival.date,
                        style: const TextStyle(
                          color: AppColors.grey400,
                          fontSize: AppDimensions.textS,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.calendar_month, color: AppColors.accent, size: 18),
                          SizedBox(width: 10),
                          Icon(Icons.location_on, color: AppColors.accent, size: 18),
                          SizedBox(width: 10),
                          Icon(Icons.map, color: AppColors.accent, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceM),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  child: selectedFestival.imagepath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: selectedFestival.imagepath,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 90,
                            height: 90,
                            color: AppColors.onSurfaceVariant.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            AppAssets.festivalimage,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          AppAssets.festivalimage,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
            ),
          );
        }
        
        // Default/placeholder when no festival is selected
    return Container(
      decoration: BoxDecoration(
        color: AppColors.onSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.lunaFest2025,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppDimensions.textXL,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.saturdayOct11RevelstorkUk,
                  style: TextStyle(
                    color: AppColors.grey400,
                    fontSize: AppDimensions.textS,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Icon(Icons.calendar_month, color: AppColors.accent, size: 18),
                    SizedBox(width: 10),
                    Icon(Icons.location_on, color: AppColors.accent, size: 18),
                    SizedBox(width: 10),
                    Icon(Icons.map, color: AppColors.accent, size: 18),
                  ],
                ),
              ],
            ),
          ),
              const SizedBox(width: AppDimensions.spaceM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            child: Image.asset(
              AppAssets.post,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}
