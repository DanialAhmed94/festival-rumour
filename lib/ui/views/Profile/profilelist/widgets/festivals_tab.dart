import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/constants/app_strings.dart';
import '../profile_list_view_model.dart';

class FestivalsTab extends StatefulWidget {
  final ProfileListViewModel viewModel;
  const FestivalsTab({super.key, required this.viewModel});

  @override
  State<FestivalsTab> createState() => _FestivalsTabState();
}

class _FestivalsTabState extends State<FestivalsTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
          child: TextField(
            style: const TextStyle(color: AppColors.black),
            cursorColor: AppColors.black,
            decoration: InputDecoration(
              hintText: AppStrings.searchFestivals,
              hintStyle: const TextStyle(color: AppColors.grey600),
              prefixIcon: const Icon(Icons.search, color: AppColors.black54),
              filled: true,
              fillColor: AppColors.grey200,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                borderSide: const BorderSide(color: Colors.transparent), // No border when not focused
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                borderSide: const BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            onChanged: widget.viewModel.searchFestivals,
          ),
        ),
        Expanded(
          child: widget.viewModel.isLoadingFestivals
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.black,
                  ),
                )
              : widget.viewModel.festivals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: AppColors.black54,
                            size: 64,
                          ),
                          const SizedBox(height: AppDimensions.spaceM),
                          ResponsiveText(
                            'No favorite festivals yet',
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
                      itemCount: widget.viewModel.festivals.length,
                      itemBuilder: (context, index) {
                        final festival = widget.viewModel.festivals[index];
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
                                  color: AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppDimensions.avatarS),
                                ),
                                child: const Icon(
                                  Icons.military_tech,
                                  color: AppColors.accent,
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
                                      festival['location'] ?? 'Unknown Location',
                                      style: const TextStyle(
                                        color: AppColors.grey600,
                                        fontSize: AppDimensions.textM,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(right: AppDimensions.spaceXS),
                                child: const Icon(
                                  Icons.favorite,
                                  color: AppColors.red,
                                  size: AppDimensions.iconL,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
