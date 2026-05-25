import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
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
      body: GestureDetector(
        onTap: () => viewModel.unfocusSearch(),
        behavior: HitTestBehavior.deferToChild,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportH = constraints.maxHeight;
              const reservedTabsAndSpacersApprox = 120.0;
              const pinkBarApprox = 56.0;
              final searchSectionMaxHeight = math.min(
                math.max(
                  104.0,
                  viewportH -
                      reservedTabsAndSpacersApprox -
                      pinkBarApprox,
                ),
                viewportH * 0.62,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    color: _pinkAppBar,
                    child: _buildAppBar(context, viewModel),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: searchSectionMaxHeight,
                    ),
                    child: SingleChildScrollView(
                      clipBehavior: Clip.hardEdge,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSearchBar(context, viewModel),
                            if (viewModel.searchQuery.trim().isNotEmpty) ...[
                              const SizedBox(
                                height: AppDimensions.spaceS,
                              ),
                              _buildSearchResultsPanel(
                                context,
                                viewModel,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceM),
                  _buildTabBar(context, viewModel),
                  const SizedBox(height: AppDimensions.spaceM),
                  Expanded(child: _buildBody(context, viewModel)),
                ],
              );
            },
          ),
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

  Widget _buildSearchBar(
    BuildContext context,
    ViewAllFestivalsViewModel viewModel,
  ) {
    final barHeight =
        context.isSmallScreen
            ? AppDimensions.searchBarHeight * 0.85
            : context.isMediumScreen
            ? AppDimensions.searchBarHeight * 0.9
            : AppDimensions.searchBarHeight * 0.9;
    return Container(
      height: barHeight,
      padding: context.responsivePadding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          SizedBox(width: context.getConditionalSpacing()),
          Icon(
            Icons.search,
            color: _pinkAppBar,
            size: context.getConditionalIconSize(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          Expanded(
            child: TextField(
              controller: viewModel.searchController,
              focusNode: viewModel.searchFocusNode,
              textAlignVertical: TextAlignVertical.center,
              onChanged: viewModel.setSearchQuery,
              onSubmitted: (_) => viewModel.unfocusSearch(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: AppStrings.searchFestivals,
                hintStyle: TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: AppDimensions.textM,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
                fontSize: AppDimensions.textM,
                height: AppDimensions.searchBarTextHeight,
              ),
              cursorColor: _pinkAppBar,
            ),
          ),
          SizedBox(
            width: AppDimensions.searchBarClearButtonWidth,
            child:
                viewModel.currentSearchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.mutedText,
                        size: AppDimensions.searchBarIconSize,
                      ),
                      onPressed: () {
                        viewModel.clearSearch();
                        FocusScope.of(context).unfocus();
                      },
                      padding: EdgeInsets.zero,
                    )
                    : const SizedBox.shrink(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
        ],
      ),
    );
  }

  Widget _buildSearchResultsPanel(
    BuildContext context,
    ViewAllFestivalsViewModel viewModel,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: AppDimensions.spaceXS,
        bottom: AppDimensions.spaceXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: viewModel.isSearching
            ? _buildSearchLoadingState()
            : viewModel.searchError != null
            ? _buildSearchErrorState(context, viewModel)
            : viewModel.searchResults.isEmpty
            ? _buildSearchEmptyState(context, viewModel)
            : _buildSearchResultsList(context, viewModel),
      ),
    );
  }

  Widget _buildSearchLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceM,
        horizontal: AppDimensions.spaceL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Color(0xFFFC2E95),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceM),
          ResponsiveTextWidget(
            'Searching…',
            textType: TextType.body,
            color: AppColors.mutedText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchErrorState(
    BuildContext context,
    ViewAllFestivalsViewModel viewModel,
  ) {
    final message =
        viewModel.searchError ?? 'Something went wrong. Please try again.';
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceL,
        horizontal: AppDimensions.spaceM,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spaceM),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            'Search failed',
            textType: TextType.title,
            color: AppColors.black,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          ResponsiveTextWidget(
            message,
            textType: TextType.caption,
            color: AppColors.mutedText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceL),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    viewModel.clearSearch();
                    FocusScope.of(context).unfocus();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                    side: BorderSide(color: AppColors.mutedText),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceM,
                      vertical: AppDimensions.spaceS,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusM),
                    ),
                  ),
                  child: const ResponsiveTextWidget(
                    AppStrings.clearSearch,
                    textType: TextType.body,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceM),
              Expanded(
                child: FilledButton(
                  onPressed: () => viewModel.retrySearch(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _pinkAppBar,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceL,
                      vertical: AppDimensions.spaceS,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusM),
                    ),
                  ),
                  child: const ResponsiveTextWidget(
                    AppStrings.retry,
                    textType: TextType.body,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState(
    BuildContext context,
    ViewAllFestivalsViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceL,
        horizontal: AppDimensions.spaceM,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceM),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            AppStrings.noFestivalsAvailable,
            textType: TextType.title,
            color: AppColors.black,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          ResponsiveTextWidget(
            'We could not find anything for "${viewModel.searchQuery}". Try another name or location.',
            textType: TextType.caption,
            color: AppColors.mutedText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceL),
          OutlinedButton(
            onPressed: () {
              viewModel.clearSearch();
              FocusScope.of(context).unfocus();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _pinkAppBar,
              side: const BorderSide(color: _pinkAppBar),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceL,
                vertical: AppDimensions.spaceS,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
            ),
            child: ResponsiveTextWidget(
              AppStrings.clearSearch,
              textType: TextType.body,
              color: _pinkAppBar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(
    BuildContext context,
    ViewAllFestivalsViewModel viewModel,
  ) {
    final list = viewModel.searchResults;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spaceM,
          AppDimensions.spaceS,
          AppDimensions.spaceM,
          AppDimensions.spaceXS,
        ),
        child: ResponsiveTextWidget(
          '${list.length} ${list.length == 1 ? 'result' : 'results'}',
          textType: TextType.caption,
          color: AppColors.mutedText,
        ),
      ),
      const Divider(height: 1),
    ];

    for (var index = 0; index < list.length; index++) {
      final festival = list[index];
      final isLast = index == list.length - 1;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  viewModel.unfocusSearch();
                  viewModel
                      .navigateToHome(context, festival)
                      .then((_) {
                        if (context.mounted) viewModel.clearSearch();
                      });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceM,
                    vertical: AppDimensions.spaceS,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusS,
                          ),
                        ),
                        child: const Icon(
                          Icons.festival_rounded,
                          color: Color(0xFFFC2E95),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ResponsiveTextWidget(
                              festival.title,
                              textType: TextType.body,
                              color: AppColors.black,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (festival.location.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              ResponsiveTextWidget(
                                festival.location,
                                textType: TextType.caption,
                                color: AppColors.mutedText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                indent: AppDimensions.spaceM + 44 + AppDimensions.spaceM,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
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

    return AbsorbPointer(
      absorbing: viewModel.navbarGateBusy,
      child: NotificationListener<ScrollNotification>(
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
              onTap: () {
                unawaited(viewModel.navigateToHome(context, festival));
              },
            );
          },
        ),
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
