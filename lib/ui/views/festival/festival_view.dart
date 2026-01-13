import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/festival/widgets/festivalcard.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
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
          body: Stack(
            children: [
              /// 🖼 Background image
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppAssets.bottomsheet),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              /// 🎨 Overlay layer (white or black tint)
              Container(
                color: AppColors.primary.withOpacity(
                  0.3,
                ), // You can tweak opacity (0.1–0.4)
              ),

              /// 🧱 Foreground content
              SafeArea(
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
                      //   SizedBox(height: context.getConditionalSpacing()),
                      _titleHeadline(context),
                      SizedBox(height: AppDimensions.spaceS),
                      _buildLogosSection(context, viewModel),
                      SizedBox(height: AppDimensions.spaceS),
                      _buildAnimatedGlobalFeedRow(context, viewModel),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context, FestivalViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.onPrimary.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filter Festivals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFilterOption(
                  context,
                  viewModel,
                  AppStrings.live,
                  Icons.live_tv,
                ),
                _buildFilterOption(
                  context,
                  viewModel,
                  AppStrings.upcoming,
                  Icons.schedule,
                ),
                _buildFilterOption(
                  context,
                  viewModel,
                  AppStrings.past,
                  Icons.history,
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildFilterOption(
    BuildContext context,
    FestivalViewModel viewModel,
    String filter,
    IconData icon,
  ) {
    final isSelected = viewModel.currentFilter == filter;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.accent : AppColors.primary,
      ),
      title: Text(
        filter,
        style: TextStyle(
          color: isSelected ? AppColors.accent : AppColors.primary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        viewModel.setFilter(filter);
        Navigator.pop(context);
      },
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
          // Logo
          Container(
            height: context.getConditionalLogoSize(),
            width: context.getConditionalLogoSize(),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: SvgPicture.asset(AppAssets.logo, color: AppColors.primary),
          ),
          SizedBox(width: AppDimensions.spaceM),

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
                color: AppColors.onPrimary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
              ),
              child: Row(
                children: [
                  SizedBox(width: context.getConditionalSpacing()),
                  Icon(
                    Icons.search,
                    color: AppColors.onSurfaceVariant,
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
                          color: AppColors.grey600,
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
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimensions.textM,
                        height: AppDimensions.searchBarTextHeight,
                      ),
                      cursorColor: AppColors.primary,
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
      return LoadingWidget(message: AppStrings.loadingfestivals);
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
            const Icon(Icons.search_off, size: 64, color: AppColors.white),
            const SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              viewModel.searchQuery.isNotEmpty
                  ? "${AppStrings.noFestivalsAvailable} for '${viewModel.searchQuery}'"
                  : AppStrings.noFestivalsAvailable,
              textType: TextType.body,
              color: AppColors.white,
              textAlign: TextAlign.center,
            ),
            if (viewModel.searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceS),
              TextButton(
                onPressed: () => viewModel.clearSearch(),
                child: const ResponsiveTextWidget(
                  AppStrings.clearSearch,
                  textType: TextType.body,
                  color: AppColors.white,
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
        child: SvgPicture.asset(
          AppAssets.note,
          width: AppDimensions.iconM,
          height: AppDimensions.iconM,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _titleHeadline(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
            context.isSmallScreen
                ? AppDimensions.paddingXS
                : context.isMediumScreen
                ? AppDimensions.paddingS
                : AppDimensions.paddingS,
        vertical:
            context.isSmallScreen
                ? AppDimensions.paddingXS
                : context.isMediumScreen
                ? AppDimensions.paddingS
                : AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(color: AppColors.headlineBackground),
      child: ResponsiveTextWidget(
        AppStrings.headlineText,
        textAlign: TextAlign.center,
        fontSize: AppDimensions.textL,
        //  fontWeight: FontWeight.bold,
        color: AppColors.primary,
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
      decoration: BoxDecoration(color: AppColors.headlineBackground),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Left side: Text section - Flexible to prevent overflow
          Flexible(
            flex: 2,
            child: ResponsiveTextWidget(
              'Tap into more awesomeness',
              textType: TextType.body,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize:
                  context.isSmallScreen
                      ? AppDimensions.textM
                      : AppDimensions.textL,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width:
                context.isSmallScreen
                    ? AppDimensions.spaceM
                    : AppDimensions.spaceL,
          ),
          // Right side: Three logos in white rounded containers
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogoContainer(
                    context,
                    AppAssets.caLogo,
                    onTap: () => viewModel.openAppStoreIOS(caAppStoreUrl),
                  ),
                  SizedBox(width: 16.0),
                  _buildLogoContainer(
                    context,
                    AppAssets.festivalResourceLogo,
                    onTap:
                        () => viewModel.openAppStoreIOS(crapAdviserAppStoreUrl),
                  ),
                  SizedBox(width: 16.0),
                  _buildLogoContainer(
                    context,
                    AppAssets.fetiefoodieLogo,
                    onTap:
                        () =>
                            viewModel.openAppStoreIOS(festieFoodieAppStoreUrl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildAnimatedGlobalFeedRow(
    BuildContext context,
    FestivalViewModel viewModel,
  ) {
    return _AnimatedGlobalFeedRow(
      onTap: () => viewModel.navigateToGlobalFeed(context),
    );
  }
}

/// Animated Global Feed Row Widget
/// Animates in once with a delay after screen load
class _AnimatedGlobalFeedRow extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedGlobalFeedRow({required this.onTap});

  @override
  State<_AnimatedGlobalFeedRow> createState() => _AnimatedGlobalFeedRowState();
}

class _AnimatedGlobalFeedRowState extends State<_AnimatedGlobalFeedRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Delay animation by 400ms after screen load
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal:
                  context.isSmallScreen
                      ? AppDimensions.paddingS
                      : context.isMediumScreen
                      ? AppDimensions.paddingM
                      : AppDimensions.paddingL,
              vertical: AppDimensions.spaceS,
            ),
            padding: EdgeInsets.symmetric(
              horizontal:
                  context.isSmallScreen
                      ? AppDimensions.paddingM
                      : AppDimensions.paddingL,
              vertical:
                  context.isSmallScreen
                      ? AppDimensions.paddingS
                      : AppDimensions.paddingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ResponsiveTextWidget(
                    'The world is buzzing 👀',
                    textType: TextType.body,
                    color: AppColors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    fontSize:
                        context.isSmallScreen
                            ? AppDimensions.textM
                            : AppDimensions.textL,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width:
                      context.isSmallScreen
                          ? AppDimensions.spaceS
                          : AppDimensions.spaceM,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        context.isSmallScreen
                            ? AppDimensions.paddingS
                            : AppDimensions.paddingM,
                    vertical:
                        context.isSmallScreen
                            ? AppDimensions.paddingXS
                            : AppDimensions.paddingS,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ResponsiveTextWidget(
                        'Jump In',
                        textType: TextType.body,
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize:
                            context.isSmallScreen
                                ? AppDimensions.textS
                                : AppDimensions.textM,
                      ),
                      SizedBox(width: context.isSmallScreen ? 4 : 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: context.isSmallScreen ? 12 : 14,
                        color: AppColors.white,
                      ),
                    ],
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
