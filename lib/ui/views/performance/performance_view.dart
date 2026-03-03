 import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/models/performance_model.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/router/app_router.dart';
import 'performance_view_model.dart';
import 'performance_detail_view.dart';

class PerformanceView extends BaseView<PerformanceViewModel> {
  final int? festivalId;
  const PerformanceView({super.key, this.festivalId});

  @override
  PerformanceViewModel createViewModel() => PerformanceViewModel();

  @override
  Widget buildView(BuildContext context, PerformanceViewModel viewModel) {
    final effectiveFestivalId = festivalId ?? Provider.of<FestivalProvider>(context, listen: false).selectedFestival?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadPerformancesIfNeeded(effectiveFestivalId);
    });
    
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildPerformanceCard(context),
              const SizedBox(height: AppDimensions.spaceL),
              _buildPerformanceSection(context, effectiveFestivalId),
              const SizedBox(height: AppDimensions.spaceM),
              Expanded(child: _buildPerformanceList(context, viewModel)),
            ],
          ),
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
                color: AppColors.white,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            AppStrings.stageRunningOrder,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.all( AppDimensions.paddingL),
      height: context.screenHeight * 0.25,
      decoration: BoxDecoration(
        color: AppColors.performanceGreen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const ResponsiveTextWidget(
            AppStrings.performance,
            textType: TextType.heading,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: AppDimensions.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Image.asset(
                  AppAssets.performance,
                  width: AppDimensions.iconXXL,
                  height: AppDimensions.iconXXL,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context, int? effectiveFestivalId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const ResponsiveTextWidget(
            AppStrings.performance,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.viewAll, arguments: {'tab': 2, 'festivalId': effectiveFestivalId});
            },
            child: const ResponsiveTextWidget(
              AppStrings.viewAll,
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceList(BuildContext context, PerformanceViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (viewModel.performances.isEmpty) {
      final message = viewModel.errorMessage != null
          ? AppStrings.failedToLoadPerformances
          : AppStrings.noPerformances;
      return Center(
        child: ResponsiveTextWidget(
          message,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }
    final displayList = viewModel.performances.take(4).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final performance = displayList[index];
        return _buildPerformanceCardItem(context, performance);
      },
    );
  }

  Widget _buildPerformanceCardItem(BuildContext context, PerformanceModel performance) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.performanceLightBlue, width: AppDimensions.borderWidthS),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPerformanceCardThumbnail(performance),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  performance.performanceTitle ?? '—',
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.w600,
                  maxLines: 2,
                ),
                if (performance.artistName != null && performance.artistName!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    performance.artistName!,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PerformanceDetailView(performance: performance)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.performanceGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.viewDetail,
                textType: TextType.caption,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCardThumbnail(PerformanceModel performance) {
    const size = 56.0;
    final imageUrl = performance.imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: imageUrl.isEmpty
            ? Image.asset(AppAssets.performance, width: size, height: size, fit: BoxFit.contain)
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
    return Container(
              color: AppColors.performanceGreen,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: const CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Image.asset(AppAssets.performance, width: size, height: size, fit: BoxFit.contain),
              ),
      ),
    );
  }

}
