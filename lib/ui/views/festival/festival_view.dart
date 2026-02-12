import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/festival/widgets/festivalcard.dart';
import 'package:flutter/cupertino.dart';
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
                /// Header section (pink background) - above logos section
                Container(
                  color: const Color(0xFFFC2E95),
                  child: ResponsiveContainer(
                    mobileMaxWidth: double.infinity,
                    tabletMaxWidth: AppDimensions.tabletWidth,
                    desktopMaxWidth: AppDimensions.desktopWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: AppDimensions.spaceS),
                        _buildTopBarWithSearch(context, viewModel),
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
                          SizedBox(height: AppDimensions.spaceS),
                          _buildBottomIcon(context),
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

    // Show filtered festivals if there's a search query, otherwise show all festivals
    final festivalsToShow =
        viewModel.searchQuery.isNotEmpty
            ? viewModel.filteredFestivals
            : viewModel.festivals;

    if (festivalsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.black),
            const SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              viewModel.searchQuery.isNotEmpty
                  ? "${AppStrings.noFestivalsAvailable} for '${viewModel.searchQuery}'"
                  : AppStrings.noFestivalsAvailable,
              textType: TextType.body,
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
            if (viewModel.searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceS),
              TextButton(
                onPressed: () => viewModel.clearSearch(),
                child: const ResponsiveTextWidget(
                  AppStrings.clearSearch,
                  textType: TextType.body,
                  color: AppColors.black,
                ),
              ),
            ],
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

  Widget _buildBottomIcon(BuildContext context) {
    return Center(
      child: Container(
        height: AppDimensions.buttonHeightXL,
        width: AppDimensions.buttonHeightXL,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFB188A), // 0%
              Color(0xFFFD774B), // 52%
              Color(0xFFFED50B), // 100%
            ],
            stops: [0.0, 0.52, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: SvgPicture.asset(
            AppAssets.note,
            width: AppDimensions.iconM,
            height: AppDimensions.iconM,
            color: AppColors.white, // shader drives final color
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final iconTileSize = context.isSmallScreen ? 56.0 : context.isMediumScreen ? 64.0 : 72.0;
    final logoSize = context.isSmallScreen ? 44.0 : context.isMediumScreen ? 52.0 : 56.0;
    final festivalChatWidth = logoSize * 2.4;
    final festivalChatHeight = logoSize * 1.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Festival CHAT badge – taps navigate to global feed
        _buildFestivalChatBadge(
          context,
          width: festivalChatWidth,
          height: festivalChatHeight,
          onTap: () => widget.viewModel.navigateToGlobalFeed(context),
        ),
        SizedBox(width: context.isSmallScreen ? 12 : 16),
        // 2. Three App Store icons with "Download our App Suite" directly under them
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppStoreLogoItem(
                  context,
                  AppAssets.crapAdviserLogo,
                  containerSize: iconTileSize,
                  onTap: () => widget.viewModel.openAppStoreIOS(crapAdviserAppStoreUrl),
                ),
                SizedBox(width: context.isSmallScreen ? 12 : 16),
                _buildAppStoreLogoItem(
                  context,
                  AppAssets.organiserLogo,
                  containerSize: iconTileSize,
                  onTap: () => widget.viewModel.openAppStoreIOS(caAppStoreUrl),
                ),
                SizedBox(width: context.isSmallScreen ? 12 : 16),
                _buildAppStoreLogoItem(
                  context,
                  AppAssets.festieFoodieLogo,
                  containerSize: iconTileSize,
                  onTap: () => widget.viewModel.openAppStoreIOS(festieFoodieAppStoreUrl),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveTextWidget(
              'Download our App Suite',
              textType: TextType.body,
              color: AppColors.black,
              fontWeight: FontWeight.bold,
              fontSize: context.isSmallScreen ? AppDimensions.textM : AppDimensions.textL,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFestivalChatBadge(
    BuildContext context, {
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Image.asset(
              AppAssets.festivalChatIcon,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported,
                  color: AppColors.grey400,
                  size: height * 0.4,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// iOS-style app launcher tile: white rounded container larger than the icon, icon centered inside.
  Widget _buildAppStoreLogoItem(
    BuildContext context,
    String assetPath, {
    required double containerSize,
    VoidCallback? onTap,
  }) {
    final iconSize = containerSize * 0.72;
    final cornerRadius = containerSize * 0.22;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cornerRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: Center(
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported,
                    color: AppColors.grey400,
                    size: iconSize * 0.6,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
