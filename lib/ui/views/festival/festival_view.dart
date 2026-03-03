import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/festival/widgets/festivalcard.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import 'festival_view_model.dart';

class FestivalView extends BaseView<FestivalViewModel> {
  const FestivalView({super.key});

  @override
  FestivalViewModel createViewModel() => FestivalViewModel();

  @override
  void onViewModelReady(FestivalViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.loadFestivals();
  }

  @override
  void onError(BuildContext context, String error) {
    // Custom error snackbar with red background and white text
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: AppColors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget buildView(BuildContext context, FestivalViewModel viewModel) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('🎪 [FestivalView] buildView: isLoading=${viewModel.isLoading}, festivals.length=${viewModel.festivals.length}, allFestivals.length=${viewModel.allFestivals.length}, searchQuery="${viewModel.searchQuery}", filteredFestivals.length=${viewModel.filteredFestivals.length}');
    }
    final pageController = viewModel.pageController;

    return PopScope(
      canPop: false, // Prevent default back button behavior
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Close app when back button is pressed on festival screen
        // Clear all routes and exit
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Exit the app
        // ignore: avoid_print
        if (context.mounted) {
          // On Android, this will close the app
          // On iOS, this will minimize the app
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          viewModel.unfocusSearch();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// Header section (pink background) - search bar + search results when active
                Container(
                  color: const Color(0xFFFC2E95),
                  child: ResponsiveContainer(
                    mobileMaxWidth: double.infinity,
                    tabletMaxWidth: AppDimensions.tabletWidth,
                    desktopMaxWidth: AppDimensions.desktopWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: AppDimensions.spaceS),
                        _buildTopBarWithSearch(context, viewModel),
                        if (viewModel.searchQuery.isNotEmpty)
                          _buildSearchResultsPanel(context, viewModel),
                        SizedBox(height: AppDimensions.spaceS),
                      ],
                    ),
                  ),
                ),

                /// Content section (white background) - logos section and everything below it
                Expanded(
                  child: Container(
                    child: ResponsiveContainer(
                      mobileMaxWidth: double.infinity,
                      tabletMaxWidth: AppDimensions.tabletWidth,
                      desktopMaxWidth: AppDimensions.desktopWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: AppDimensions.spaceS),
                          _buildCreatePostBar(context, viewModel),
                          SizedBox(height: AppDimensions.spaceS),
                          _buildLogosSection(context, viewModel),
                          SizedBox(height: AppDimensions.spaceS),
                          _buildFilterTabBar(context, viewModel),
                          SizedBox(height: AppDimensions.spaceS),
                          _buildViewAllButton(context),

                          SizedBox(
                            height:
                                context.isSmallScreen
                                    ? AppDimensions.spaceM
                                    : AppDimensions.spaceL,
                          ),
                          Expanded(
                            child: _buildFestivalsSlider(
                              context,
                              viewModel,
                              pageController,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarWithSearch(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
      child: Row(
        children: [
          // Search Bar (same design as home view)
          Expanded(
            child: Container(
              height:
                  context.isSmallScreen
                      ? AppDimensions.searchBarHeight * 0.8
                      : context.isMediumScreen
                      ? AppDimensions.searchBarHeight * 0.9
                      : AppDimensions.searchBarHeight * 0.9,
              margin: context.responsiveMargin,
              padding: context.responsivePadding,
              decoration: BoxDecoration(
                // light black with opacity
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
              ),
              child: Row(
                children: [
                  SizedBox(width: context.getConditionalSpacing()),
                  Icon(
                    Icons.search,
                    color: AppColors.white,
                    size: context.getConditionalIconSize(),
                  ),
                  SizedBox(width: context.getConditionalSpacing()),

                  /// 🔹 Search Field
                  Expanded(
                    child: TextField(
                      controller: viewModel.searchController,
                      focusNode: viewModel.searchFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: AppStrings.searchFestivals,
                        hintStyle: const TextStyle(
                          color: AppColors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: AppDimensions.textM,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimensions.textM,
                        height: AppDimensions.searchBarTextHeight,
                      ),
                      cursorColor: AppColors.white,
                      onChanged: (value) {
                        viewModel.setSearchQuery(value);
                      },
                      onSubmitted: (value) {
                        viewModel.unfocusSearch();
                      },
                      textInputAction: TextInputAction.search,
                    ),
                  ),

                  /// 🔹 Search Clear Button - Always reserve space
                  SizedBox(
                    width: AppDimensions.searchBarClearButtonWidth,
                    child:
                        viewModel.currentSearchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.primary,
                                size: AppDimensions.searchBarIconSize,
                              ),
                              onPressed: () {
                                // ✅ Clear search and hide keyboard
                                viewModel.clearSearch();
                                FocusScope.of(context).unfocus();
                              },
                            )
                            : const SizedBox.shrink(),
                  ),
                  
                  SizedBox(width: context.getConditionalSpacing()),

                  /// Settings icon - navigates to settings screen
                  IconButton(
                    onPressed: () => viewModel.navigateToSettings(context),
                    icon: Icon(
                      Icons.settings,
                      color: AppColors.white,
                      size: context.getConditionalIconSize(),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppDimensions.searchBarClearButtonWidth,
                      minHeight: AppDimensions.searchBarClearButtonWidth,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Search results list shown below the search field when user is searching.
  Widget _buildSearchResultsPanel(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.38;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.spaceXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: viewModel.isSearching
            ? _buildSearchLoadingState()
            : viewModel.searchError != null
                ? _buildSearchErrorState(context, viewModel)
                : viewModel.filteredFestivals.isEmpty
                    ? _buildSearchEmptyState(context, viewModel)
                    : _buildSearchResultsList(context, viewModel),
      ),
    );
  }

  Widget _buildSearchErrorState(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    final message = viewModel.searchError ??
        'Something went wrong. Please try again.';
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
          SizedBox(
            width: double.infinity,
            child: ResponsiveTextWidget(
              'Search failed',
              textType: TextType.title,
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceS),
          SizedBox(
            width: double.infinity,
            child: ResponsiveTextWidget(
              message,
              textType: TextType.caption,
              color: AppColors.mutedText,
              textAlign: TextAlign.center,
            ),
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
                    backgroundColor: const Color(0xFFFC2E95),
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
                    'Try again',
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

  Widget _buildSearchLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceXL,
        horizontal: AppDimensions.spaceL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: const Color(0xFFFC2E95),
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

  Widget _buildSearchEmptyState(
    BuildContext context,
    FestivalViewModel viewModel,
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
            decoration: BoxDecoration(
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
          ResponsiveTextWidget(
            'No festivals found',
            textType: TextType.title,
            color: AppColors.black,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spaceS),
          ResponsiveTextWidget(
            'We couldn\'t find anything for "${viewModel.searchQuery}". Try a different name or location.',
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
              foregroundColor: const Color(0xFFFC2E95),
              side: const BorderSide(color: Color(0xFFFC2E95)),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceL,
                vertical: AppDimensions.spaceS,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
            ),
            child: const ResponsiveTextWidget(
              AppStrings.clearSearch,
              textType: TextType.body,
              color: Color(0xFFFC2E95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    final list = viewModel.filteredFestivals;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final festival = list[index];
              final isLast = index == list.length - 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        viewModel.unfocusSearch();
                        viewModel.clearSearch();
                        viewModel.navigateToHome(context, festival);
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
                                borderRadius:
                                    BorderRadius.circular(AppDimensions.radiusS),
                              ),
                              child: Icon(
                                Icons.festival_rounded,
                                color: const Color(0xFFFC2E95),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFestivalsSlider(
    BuildContext context,
    FestivalViewModel viewModel,
    PageController pageController,
  ) {
    if (viewModel.isLoading && viewModel.festivals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.black),
            const SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'Loading',
              textType: TextType.body,
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Slider always shows tab-filtered festivals (search results are in the search panel)
    final festivalsToShow = viewModel.festivals;

    if (festivalsToShow.isEmpty) {
      final emptyMessage = _emptyMessageForFilter(viewModel.currentFilter);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: AppColors.black,
            ),
            const SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              emptyMessage,
              textType: TextType.body,
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: pageController,
      padEnds: true,
      onPageChanged: (page) {
        viewModel.setPage(page);
      },
      itemBuilder: (context, index) {
        final festival = festivalsToShow[index % festivalsToShow.length];
        return SizedBox(
          width: double.infinity,
          child: ResponsivePadding(
            mobilePadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingS,
            ),
            tabletPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
            ),
            desktopPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
            ),
            child: FestivalCard(
              festival: festival,
              onBack: viewModel.goBack,
              onTap: () => viewModel.navigateToHome(context, festival),
              onNext: viewModel.goToNextSlide,
            ),
          ),
        );
      },
    );
  }

  String _emptyMessageForFilter(String filter) {
    switch (filter) {
      case 'live':
        return AppStrings.noLiveFestivals;
      case 'upcoming':
        return AppStrings.noUpcomingFestivals;
      case 'past':
        return AppStrings.noPastFestivals;
      default:
        return AppStrings.noFestivalsAvailable;
    }
  }

  /// "What's on your mind?" bar above the logos row — white container, avatar, pill input, camera icon.
  Widget _buildCreatePostBar(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    final horizontalPadding = context.isSmallScreen
        ? AppDimensions.paddingS
        : context.isMediumScreen
            ? AppDimensions.paddingM
            : AppDimensions.paddingL;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // User avatar (left)
            GestureDetector(
              onTap: () => viewModel.navigateToProfile(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: viewModel.userPhotoUrl != null &&
                          viewModel.userPhotoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: viewModel.userPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.grey300,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Image.asset(
                            AppAssets.profile,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          color: AppColors.grey300,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceS),
            // Pill-shaped input (center)
            Expanded(
              child: GestureDetector(
                onTap: () => viewModel.navigateToCreatePost(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                    vertical: AppDimensions.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Write's on your mind?",
                    style: TextStyle(
                      color: AppColors.grey600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceS),
            // Camera icon (right)
            IconButton(
              onPressed: () => viewModel.navigateToCreatePost(context),
              icon: const Icon(
                Icons.camera_alt,
                color: AppColors.black,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogosSection(BuildContext context, FestivalViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
            context.isSmallScreen
                ? AppDimensions.paddingS
                : context.isMediumScreen
                ? AppDimensions.paddingM
                : AppDimensions.paddingL,
        vertical:
            context.isSmallScreen
                ? AppDimensions.paddingS
                : context.isMediumScreen
                ? AppDimensions.paddingM
                : AppDimensions.paddingM,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Center(
        child: _buildScrollableLogos(context, viewModel),
      ),
    );
  }

  Widget _buildScrollableLogos(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    return _ScrollableLogosWidget(viewModel: viewModel);
  }


  Widget _buildLogoContainer(
    BuildContext context,
    String assetPath, {
    VoidCallback? onTap,
  }) {
    final logoSize =
        context.isSmallScreen
            ? 50.0
            : context.isMediumScreen
            ? 60.0
            : 70.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: logoSize,
        height: logoSize,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image_not_supported,
                color: AppColors.grey600,
                size: logoSize * 0.5,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.viewAllFestivals);
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const ResponsiveTextWidget(
                AppStrings.viewAll,
                textType: TextType.body,
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab bar for Live / Upcoming / Past (same style as chat rooms tabs).
  Widget _buildFilterTabBar(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    final selectedIndex = viewModel.selectedFilterTab;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
      ),
      child: Row(
        children: [
          _buildFilterTab(
            context,
            viewModel,
            index: 0,
            label: AppStrings.live,
            icon: Icons.live_tv,
            isSelected: selectedIndex == 0,
          ),
          _buildFilterTab(
            context,
            viewModel,
            index: 1,
            label: AppStrings.upcoming,
            icon: Icons.schedule,
            isSelected: selectedIndex == 1,
          ),
          _buildFilterTab(
            context,
            viewModel,
            index: 2,
            label: AppStrings.past,
            icon: Icons.history,
            isSelected: selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context,
    FestivalViewModel viewModel, {
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final filter = index == 0 ? 'live' : index == 1 ? 'upcoming' : 'past';
    final isSmall = context.isSmallScreen;
    return Expanded(
      child: GestureDetector(
        onTap: () => viewModel.setFilter(context, filter),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppDimensions.paddingS,
            horizontal: isSmall ? AppDimensions.paddingS : AppDimensions.paddingM,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isSmall ? 14.0 : AppDimensions.iconS,
                  color: isSelected ? AppColors.black : AppColors.white,
                ),
                SizedBox(width: isSmall ? 4 : AppDimensions.spaceS),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.black : AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable Logos Widget
class _ScrollableLogosWidget extends StatefulWidget {
  final FestivalViewModel viewModel;

  const _ScrollableLogosWidget({required this.viewModel});

  @override
  State<_ScrollableLogosWidget> createState() => _ScrollableLogosWidgetState();
}

class _ScrollableLogosWidgetState extends State<_ScrollableLogosWidget> {

  static const double _pinkButtonSize = 88.0;

  @override
  Widget build(BuildContext context) {
    final itemSpacing = context.isSmallScreen ? 12.0 : 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _pinkButtonSize,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: itemSpacing),
            children: [
              _buildFestivalChatBadge(
                context,
                onTap: () => widget.viewModel.navigateToGlobalFeed(context),
              ),
              SizedBox(width: itemSpacing),
              _buildPinkLabelButton(
                context,
                label: 'Festival Toilet',
                onTap: () => widget.viewModel.openAppStoreIOS(crapAdviserAppStoreUrl),
              ),
              SizedBox(width: itemSpacing),
              _buildPinkLabelButton(
                context,
                label: 'Festival Organizer',
                onTap: () => widget.viewModel.openAppStoreIOS(caAppStoreUrl),
              ),
              SizedBox(width: itemSpacing),
              _buildPinkLabelButton(
                context,
                label: 'Festive Foodie',
                onTap: () => widget.viewModel.openAppStoreIOS(festieFoodieAppStoreUrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ResponsiveTextWidget(
            'Download our App Suite',
            textType: TextType.body,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: context.isSmallScreen ? AppDimensions.textM : AppDimensions.textL,
          ),
        ),
      ],
    );
  }

  Widget _buildFestivalChatBadge(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _pinkButtonSize,
        height: _pinkButtonSize,
        decoration: BoxDecoration(
          color: const Color(0xFFFC2E95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _buildTwoLineLabel(context, 'Festival Chat'),
        ),
      ),
    );
  }

  /// First word on top line, second word on bottom line (for all buttons in the row).
  Widget _buildTwoLineLabel(BuildContext context, String label) {
    final parts = label.split(' ');
    final fontSize = context.isSmallScreen ? AppDimensions.textS : AppDimensions.textM;
    if (parts.length >= 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            parts[0],
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            parts.sublist(1).join(' '),
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      label,
      style: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Large pink square button with text label; same style for all app suite buttons.
  Widget _buildPinkLabelButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _pinkButtonSize,
        height: _pinkButtonSize,
        decoration: BoxDecoration(
          color: const Color(0xFFFC2E95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildTwoLineLabel(context, label),
          ),
        ),
      ),
    );
  }
}
