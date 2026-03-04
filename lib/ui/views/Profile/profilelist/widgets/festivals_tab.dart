import 'package:cached_network_image/cached_network_image.dart';
import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/constants/app_strings.dart';
import '../profile_list_view_model.dart';

class FestivalsTab extends StatefulWidget {
  final ProfileListViewModel viewModel;
  final void Function(BuildContext context, Map<String, dynamic> item)? onFestivalTap;

  const FestivalsTab({super.key, required this.viewModel, this.onFestivalTap});

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
                          ResponsiveTextWidget(
                            'No favorite festivals yet',
                            textType: TextType.body,
                            color: AppColors.black,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                      itemCount: widget.viewModel.festivals.length,
                      itemBuilder: (context, index) {
                        final festival = widget.viewModel.festivals[index];
                        return InkWell(
                          onTap: widget.onFestivalTap != null
                              ? () => widget.onFestivalTap!(context, festival)
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
                                      festival['location'] ?? 'Unknown Location',
                                      textType: TextType.caption,
                                      color: AppColors.grey600,
                                      maxLines: 1,
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
                        ),
                      );
                      },
                    ),
        ),
      ],
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
