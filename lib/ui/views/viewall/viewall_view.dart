import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/models/toilet_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/performance_model.dart';
import '../toilet/toilet_detail_view.dart';
import '../event/event_detail_view.dart';
import '../performance/performance_detail_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../event/event_view.dart';
import '../performance/performance_view.dart';
import '../news/bulletin_detail_view.dart';
import '../../../core/models/bulletin_model.dart';
import 'viewall_view_model.dart';

class ViewAllView extends BaseView<ViewAllViewModel> {
  final VoidCallback? onBack;
  final int? initialTab;
  final int? festivalIdForToilets;
  const ViewAllView({super.key, this.onBack, this.initialTab, this.festivalIdForToilets});

  @override
  ViewAllViewModel createViewModel() =>
      ViewAllViewModel(initialTab: initialTab, festivalIdForToilets: festivalIdForToilets);

  @override
  Widget buildView(BuildContext context, ViewAllViewModel viewModel) {
    final festivalId = festivalIdForToilets ?? Provider.of<FestivalProvider>(context, listen: false).selectedFestival?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.selectedTab == 0 && viewModel.events.isEmpty && !viewModel.isLoading && festivalId != null) {
        viewModel.loadEventsIfNeeded(festivalId);
      } else if (viewModel.selectedTab == 2 && viewModel.performances.isEmpty && !viewModel.isLoading && festivalId != null) {
        viewModel.loadPerformancesIfNeeded(festivalId);
      } else if (viewModel.selectedTab == 3 && viewModel.toilets.isEmpty && !viewModel.isLoading && festivalId != null) {
        viewModel.loadToiletsIfNeeded(festivalId);
      }
    });
    return WillPopScope(
      onWillPop: () async {
        if (onBack != null) {
          onBack!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            /// 🔹 Background image
            Positioned.fill(
              child: Image.asset(
                AppAssets.bottomsheet,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.grey50, AppColors.white],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context, viewModel),
                  if (viewModel.showTabSelector) ...[
                    const SizedBox(height: AppDimensions.spaceM),
                    _buildTabSelector(context, viewModel),
                    const SizedBox(height: AppDimensions.spaceM),
                  ] else
                    const SizedBox(height: AppDimensions.spaceM),
                  Expanded(child: _buildContent(context, viewModel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ViewAllViewModel viewModel) {
    String title = AppStrings.events;
    if (viewModel.selectedTab == 0) {
      title = ' ${AppStrings.events}';
    } else if (viewModel.selectedTab == 1) {
      title = '${AppStrings.lunaNews}';
    } else if (viewModel.selectedTab == 2) {
      title = '${AppStrings.performance}';
    } else if (viewModel.selectedTab == 3) {
      title = AppStrings.toilets;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          GestureDetector(onTap: onBack ?? () => Navigator.pop(context),
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
          ResponsiveTextWidget(
            title,
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context, ViewAllViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
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
              AppStrings.events,
              0,
              viewModel.selectedTab == 0,
              AppColors.eventGreen,
              () => viewModel.setSelectedTab(0),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceXS),
          Expanded(
            child: _buildTabButton(
              context,
              AppStrings.lunaNews,
              1,
              viewModel.selectedTab == 1,
              AppColors.newsGreen,
              () => viewModel.setSelectedTab(1),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceXS),
          Expanded(
            child: _buildTabButton(
              context,
              AppStrings.performance,
              2,
              viewModel.selectedTab == 2,
              AppColors.performanceGreen,
              () => viewModel.setSelectedTab(2),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceXS),
          Expanded(
            child: _buildTabButton(
              context,
              AppStrings.toilets,
              3,
              viewModel.selectedTab == 3,
              AppColors.newsGreen,
              () => viewModel.setSelectedTab(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    int index,
    bool isSelected,
    Color selectedColor,
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
          color: isSelected ? selectedColor : Colors.transparent,
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

  Widget _buildContent(BuildContext context, ViewAllViewModel viewModel) {
    switch (viewModel.selectedTab) {
      case 0:
        return _buildEventsList(context, viewModel);
      case 1:
        return _buildNewsList(context, viewModel);
      case 2:
        return _buildPerformancesList(context, viewModel);
      case 3:
        return _buildToiletsList(context, viewModel);
      default:
        return _buildEventsList(context, viewModel);
    }
  }

  Widget _buildToiletsList(BuildContext context, ViewAllViewModel viewModel) {
    if (viewModel.isLoading && viewModel.toilets.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (viewModel.toilets.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noData,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.toilets.length,
      itemBuilder: (context, index) {
        final toilet = viewModel.toilets[index];
        return _buildToiletCard(context, toilet);
      },
    );
  }

  Widget _buildToiletCard(BuildContext context, ToiletModel toilet) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
          _buildToiletCardThumbnail(toilet),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  toilet.toiletTypeName,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                if (toilet.festivalName != null && toilet.festivalName!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    toilet.festivalName!,
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
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ToiletDetailView(toilet: toilet),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.newsGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: ResponsiveTextWidget(
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

  /// Card thumbnail uses toilet type image (same as resource_module allToilets).
  Widget _buildToiletCardThumbnail(ToiletModel toilet) {
    final imageUrl = toilet.toiletTypeImageUrl;
    const size = 56.0;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Image.asset(AppAssets.toiletdetail, width: size, height: size, fit: BoxFit.cover)
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.newsGreen,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: const CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.toiletdetail,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, ViewAllViewModel viewModel) {
    if (viewModel.isLoading && viewModel.events.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (viewModel.events.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noEvents,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.events.length,
      itemBuilder: (context, index) {
        final event = viewModel.events[index];
        return _buildEventCard(context, event);
      },
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
          _buildEventCardThumbnail(event),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  event.eventTitle ?? '—',
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                  maxLines: 2,
                ),
                if (event.eventDescription != null && event.eventDescription!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    event.eventDescription!,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailView(event: event)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.eventGreen,
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

  Widget _buildEventCardThumbnail(EventModel event) {
    const size = 44.0;
    final imageUrl = event.imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: imageUrl.isEmpty
            ? Image.asset(AppAssets.assignmentIcon, width: size, height: size, fit: BoxFit.contain)
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.eventGreen,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: const CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Image.asset(AppAssets.assignmentIcon, width: size, height: size, fit: BoxFit.contain),
              ),
      ),
    );
  }

  Widget _buildNewsList(BuildContext context, ViewAllViewModel viewModel) {
    if (viewModel.isLoading && viewModel.bulletins.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }
    if (viewModel.bulletins.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noNews,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.bulletins.length,
      itemBuilder: (context, index) {
        final bulletin = viewModel.bulletins[index];
        return _buildNewsCard(context, bulletin);
      },
    );
  }

  Widget _buildNewsCard(BuildContext context, BulletinModel bulletin) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.newsGreen,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              AppAssets.news,
              width: AppDimensions.iconL,
              height: AppDimensions.iconL,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  bulletin.title ?? AppStrings.news,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                if (bulletin.content != null && bulletin.content!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    bulletin.content!,
                    textType: TextType.caption,
                    color: AppColors.grey600,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => BulletinDetailView(bulletin: bulletin),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.newsGreen,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: ResponsiveTextWidget(
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

  Widget _buildPerformancesList(BuildContext context, ViewAllViewModel viewModel) {
    if (viewModel.isLoading && viewModel.performances.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (viewModel.performances.isEmpty) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noData,
          textType: TextType.body,
          color: AppColors.grey600,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      itemCount: viewModel.performances.length,
      itemBuilder: (context, index) {
        final performance = viewModel.performances[index];
        return _buildPerformanceCard(context, performance);
      },
    );
  }

  Widget _buildPerformanceCard(BuildContext context, PerformanceModel performance) {
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
    const size = 44.0;
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
