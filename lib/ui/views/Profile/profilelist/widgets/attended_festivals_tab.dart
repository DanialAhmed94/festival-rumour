import 'package:cached_network_image/cached_network_image.dart';
import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../profile_list_view_model.dart';

class AttendedFestivalsTab extends StatelessWidget {
  final ProfileListViewModel viewModel;
  final void Function(BuildContext context, Map<String, dynamic> item)? onFestivalTap;

  const AttendedFestivalsTab({super.key, required this.viewModel, this.onFestivalTap});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingAttended) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.black),
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
                ResponsiveTextWidget(
                  'No attended festivals yet',
                  textType: TextType.body,
                  color: AppColors.black,
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            itemCount: viewModel.attendedFestivals.length,
            itemBuilder: (context, index) {
              final festival = viewModel.attendedFestivals[index];
              return InkWell(
                onTap: onFestivalTap != null
                    ? () => onFestivalTap!(context, festival)
                    : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                child: Container(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _buildFestivalImage(festival['imagepath']?.toString() ?? ''),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveTextWidget(
                            festival['title'] ?? 'Unknown Festival',
                            textType: TextType.body,
                            color: AppColors.black,
                            fontWeight: FontWeight.w600,
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppDimensions.spaceXS),
                          ResponsiveTextWidget(
                            (festival['location'] ?? '').toString().isEmpty
                                ? '—'
                                : (festival['location'] ?? '—').toString(),
                            textType: TextType.caption,
                            color: AppColors.grey600,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.black,
                      size: AppDimensions.iconL,
                    ),
                  ],
                ),
              ),
            );
            },
          );
  }

  Widget _buildFestivalImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Image.asset(AppAssets.festivalimage, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: AppColors.grey300,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => Image.asset(AppAssets.festivalimage, fit: BoxFit.cover),
    );
  }
}
