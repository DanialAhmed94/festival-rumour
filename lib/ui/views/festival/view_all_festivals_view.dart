import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'festival_model.dart';
import 'view_all_festivals_view_model.dart';

class ViewAllFestivalsView extends BaseView<ViewAllFestivalsViewModel> {
  const ViewAllFestivalsView({super.key});

  @override
  ViewAllFestivalsViewModel createViewModel() => ViewAllFestivalsViewModel();

  @override
  void onViewModelReady(ViewAllFestivalsViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.loadInitial();
  }

  static const Color _pinkAppBar = Color(0xFFFC2E95);

  @override
  Widget buildView(BuildContext context, ViewAllFestivalsViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              color: _pinkAppBar,
              child: _buildAppBar(context, viewModel),
            ),
            const SizedBox(height: AppDimensions.spaceL),
            _buildTabBar(context, viewModel),
            const SizedBox(height: AppDimensions.spaceM),
            Expanded(child: _buildBody(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ViewAllFestivalsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => viewModel.goBack(),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.white,
              size: AppDimensions.iconM,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          const Expanded(
            child: ResponsiveTextWidget(
              AppStrings.viewAllFestivals,
              textType: TextType.body,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, ViewAllFestivalsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingXS),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                context,
                AppStrings.live,
                0,
                viewModel.selectedTab == 0,
                () => viewModel.setSelectedTab(0),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceXS),
            Expanded(
              child: _buildTabButton(
                context,
                AppStrings.upcoming,
                1,
                viewModel.selectedTab == 1,
                () => viewModel.setSelectedTab(1),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceXS),
            Expanded(
              child: _buildTabButton(
                context,
                AppStrings.past,
                2,
                viewModel.selectedTab == 2,
                () => viewModel.setSelectedTab(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    int index,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingS,
          horizontal: AppDimensions.paddingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _pinkAppBar : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: Center(
          child: ResponsiveTextWidget(
            label,
            textType: TextType.caption,
            color: isSelected ? AppColors.white : AppColors.black,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ViewAllFestivalsViewModel viewModel) {
    if (viewModel.isLoading && viewModel.festivals.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }

    final filtered = viewModel.filteredFestivals;
    if (viewModel.festivals.isNotEmpty && filtered.isEmpty && !viewModel.isLoading) {
      final emptyMessage = viewModel.selectedTab == 0
          ? AppStrings.noLiveFestivals
          : viewModel.selectedTab == 1
              ? AppStrings.noUpcomingFestivals
              : AppStrings.noPastFestivals;
      return Center(
        child: ResponsiveTextWidget(
          emptyMessage,
          textType: TextType.body,
          color: AppColors.grey600,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (viewModel.festivals.isEmpty && !viewModel.isLoading) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noFestivalsAvailable,
          textType: TextType.body,
          color: AppColors.grey600,
          textAlign: TextAlign.center,
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          viewModel.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.spaceS,
        ),
        itemCount: filtered.length + (viewModel.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceXXL),
              child: SizedBox(
                height: viewModel.isLoadingMore ? 80.0 : 24.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceM),
                  child: Center(
                    child: viewModel.isLoadingMore
                        ? const CircularProgressIndicator(color: AppColors.black)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          }
          final festival = filtered[index];
          return _FestivalListTile(
            festival: festival,
            onTap: () => viewModel.navigateToHome(context, festival),
          );
        },
      ),
    );
  }
}

class _FestivalListTile extends StatelessWidget {
  final FestivalModel festival;
  final VoidCallback onTap;

  const _FestivalListTile({
    required this.festival,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              child: SizedBox(
                width: 72,
                height: 72,
                child: festival.imagepath.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: festival.imagepath,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.grey300,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          AppAssets.festivalimage,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        AppAssets.festivalimage,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveTextWidget(
                    festival.title,
                    textType: TextType.body,
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                    maxLines: 2,
                  ),
                  if (festival.location.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spaceXS),
                    ResponsiveTextWidget(
                      festival.location,
                      textType: TextType.caption,
                      color: AppColors.grey600,
                      maxLines: 1,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    festival.date,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey600),
          ],
        ),
      ),
    );
  }
}
