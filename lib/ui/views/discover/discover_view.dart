import 'package:festival_rumour/core/router/app_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/discover/widgets/action_tile.dart';
import 'package:festival_rumour/ui/views/discover/widgets/event_header_card.dart';
import 'package:festival_rumour/ui/views/discover/widgets/grid_option.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../core/providers/festival_provider.dart';
import '../festival/festival_model.dart';
import 'discover_viewmodel.dart';

class DiscoverView extends BaseView<DiscoverViewModel> {
  final VoidCallback? onBack;
  final Function(String)? onNavigateToSub;
  const DiscoverView({super.key, this.onBack, this.onNavigateToSub});

  @override
  DiscoverViewModel createViewModel() => DiscoverViewModel();

  @override
  void onViewModelReady(DiscoverViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, DiscoverViewModel viewModel) {
    return _DiscoverViewContent(viewModel: viewModel, onBack: onBack, onNavigateToSub: onNavigateToSub);
  }
}

/// Stateful widget to manage initialization and keep-alive
class _DiscoverViewContent extends StatefulWidget {
  final DiscoverViewModel viewModel;
  final VoidCallback? onBack;
  final Function(String)? onNavigateToSub;
  
  const _DiscoverViewContent({
    required this.viewModel,
    this.onBack,
    this.onNavigateToSub,
  });
  
  @override
  State<_DiscoverViewContent> createState() => _DiscoverViewContentState();
}

class _DiscoverViewContentState extends State<_DiscoverViewContent> with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  
  @override
  bool get wantKeepAlive => true; // Keep alive when switching tabs
  
  @override
  void initState() {
    super.initState();
    // Initialize only once
    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.viewModel.loadFavoriteStatus(context);
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return WillPopScope(
      onWillPop: () async {
        print("🔙 Discover screen back button pressed");
        if (widget.onBack != null) {
          widget.onBack!();
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          widget.viewModel.unfocusSearch();
        },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: ResponsiveContainer(
                mobileMaxWidth: double.infinity,
                tabletMaxWidth: AppDimensions.tabletWidth,
                desktopMaxWidth: AppDimensions.desktopWidth,
                child: SingleChildScrollView(

                  child: ResponsivePadding(
                    mobilePadding: const EdgeInsets.all(AppDimensions.paddingS),
                    tabletPadding: const EdgeInsets.all(AppDimensions.paddingM),
                    desktopPadding: const EdgeInsets.all(AppDimensions.paddingXL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(context, widget.viewModel),
                        _divider(),
                        _buildSearchBarWithDropdown(context, widget.viewModel),
                        SizedBox(height: AppDimensions.spaceS),
                        const EventHeaderCard(),
                        SizedBox(height: AppDimensions.spaceS),
                        _buildGetReadyText(),
                        SizedBox(height: AppDimensions.spaceS),
                        _buildActionTiles(context),
                        SizedBox(height: AppDimensions.spaceS),
                        _buildGridOptions(context, widget.viewModel),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// ---------------- BACKGROUND ----------------
  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        AppAssets.bottomsheet,
        fit: BoxFit.cover,
      ),
    );
  }

  /// ---------------- TOP BAR ----------------
  Widget _buildTopBar(BuildContext context, DiscoverViewModel viewModel) {
    return Row(
      children: [
        CustomBackButton(onTap: widget.onBack ?? () {}),
        SizedBox(width: context.getConditionalSpacing()),
        ResponsiveTextWidget(
          AppStrings.overview,
          textType: TextType.title,
          fontSize: context.getConditionalMainFont(),
          color: AppColors.primary,
        ),
        const Spacer(),
        _buildFavoriteButton(context, viewModel),
      ],
    );
  }

  /// ---------------- FAVORITE BUTTON ----------------
  Widget _buildFavoriteButton(BuildContext context, DiscoverViewModel viewModel) {
    return GestureDetector(
      onTap: () async {
        final wasFavorited = widget.viewModel.isFavorited;
        try {
          await widget.viewModel.toggleFavorite(context);
          // Show snackbar after successful toggle
          if (widget.viewModel.isFavorited) {
            SnackbarUtil.showSuccessSnackBar(
              context,
              AppStrings.addedToFavorites,
            );
          } else {
            SnackbarUtil.showInfoSnackBar(
              context,
              AppStrings.removedFromFavorites,
            );
          }
        } catch (e) {
          // Error handling is done in view model, just show error snackbar
          SnackbarUtil.showErrorSnackBar(
            context,
            'Failed to update favorite. Please try again.',
          );
        }
      },
      child: Icon(
        viewModel.isFavorited ? Icons.favorite : Icons.favorite_border,
        color: viewModel.isFavorited ? AppColors.error : AppColors.primary,
      ),
    );
  }

  /// ---------------- GET READY TEXT ----------------
  Widget _buildGetReadyText() {
    return const ResponsiveTextWidget(
      AppStrings.getReady,
      textType: TextType.body,
      color: AppColors.white,
      fontWeight: FontWeight.bold,
    );
  }

  /// ---------------- ACTION TILES ----------------
  Widget _buildActionTiles(BuildContext context) {
    // Get selected festival from provider
    final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    final selectedFestival = festivalProvider.selectedFestival;
    
    // Create dynamic text with actual festival name
    final countMeInText = selectedFestival != null
        ? 'Count me in, catch ya at ${selectedFestival.title}'
        : AppStrings.countMeInCatchYaAtLunaFest; // Fallback to default if no festival selected
    
    return Column(
      children: [
        ActionTile(
          iconPath: AppAssets.handicon,
          text: countMeInText,
          onTap: () => _showShareLocationDialog(context),
        ),
        SizedBox(height: AppDimensions.spaceS),
        ActionTile(
          iconPath: AppAssets.iconcharcter,
          text: AppStrings.inviteYourFestieBestie,
          onTap: () => _shareFestival(context),
        ),
      ],
    );
  }

  /// ---------------- GRID OPTIONS ----------------
  Widget _buildGridOptions(BuildContext context, DiscoverViewModel viewModel) {
    return GridView.count(
      crossAxisCount: context.isLargeScreen ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppDimensions.spaceM,
      crossAxisSpacing: context.isLargeScreen ? AppDimensions.spaceL : AppDimensions.spaceM,
      childAspectRatio: context.isLargeScreen ? 1.3 : context.isMediumScreen ? 1.2 : 1.1,
      children: [
        GridOption(
          title: AppStrings.location,
          icon: AppAssets.mapicon,
          onNavigateToSub: widget.onNavigateToSub,
        ),
        GridOption(
          title: AppStrings.chatRooms,
          icon: AppAssets.chaticon,
          onTap: () => widget.viewModel.goToChatRooms(context),
        ),
        GridOption(
          title: AppStrings.rumors,
          icon: AppAssets.rumors,
          onTap: () => widget.viewModel.goToRumors(context),
        ),
        GridOption(
          title: AppStrings.detail,
          icon: AppAssets.detailicon,
          onNavigateToSub: widget.onNavigateToSub,
        ),
      ],
    );
  }

  /// ---------------- HELPERS ----------------
  void _showShareLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ShareLocationPopup(),
    );
  }

  Future<void> _shareFestival(BuildContext context) async {
    await Share.share(
      AppStrings.shareMessage,
      subject: AppStrings.shareSubject,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 0, 0),
    );
  }
  Widget _divider(){
    return  Container(
      width: double.infinity,
      // Remove any outer spacing
      child: const Divider(
        color: AppColors.primary,
        thickness: 1,
        height: 20, // 👈 end at very right
      ),
    );
  }

  /// ---------------- SEARCH BAR WITH DROPDOWN ----------------
  Widget _buildSearchBarWithDropdown(BuildContext context, DiscoverViewModel viewModel) {
    return ResponsiveContainer(
      mobileMaxWidth: double.infinity,
      tabletMaxWidth: double.infinity,
      desktopMaxWidth: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            margin: context.responsiveMargin,
            padding: context.responsivePadding,
            height: context.getConditionalButtonSize(),
            decoration: BoxDecoration(
              color: AppColors.onPrimary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
            ),
            child: Row(
              children: [
                SizedBox(width: context.getConditionalSpacing()),
                // Search icon
                Icon(
                  Icons.search, 
                  color: AppColors.onSurfaceVariant, 
                  size: context.getConditionalIconSize(),
                ),
                SizedBox(width: context.getConditionalSpacing()),
                // Search Field
                Expanded(
                  child: TextField(
                    controller: viewModel.searchController,
                    focusNode: viewModel.searchFocusNode,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      hintStyle: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: context.getConditionalFont(),
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
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: context.getConditionalFont(),
                    ),
                    cursorColor: AppColors.primary,
                    onChanged: (value) {
                      viewModel.setSearchQuery(value, context);
                    },
                    onSubmitted: (value) {
                      viewModel.unfocusSearch();
                    },
                    textInputAction: TextInputAction.search,
                  ),
                ),
                // Search Clear Button
                SizedBox(
                  width: context.getConditionalIconSize(),
                  child: viewModel.currentSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear, 
                            color: AppColors.primary, 
                            size: context.getConditionalIconSize(),
                          ),
                          onPressed: () {
                            viewModel.clearSearch(context);
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(width: context.getConditionalSpacing()),
              ],
            ),
          ),
          // Dropdown with matching festivals
          if (viewModel.hasSearchResults)
            _buildFestivalDropdown(context, viewModel),
        ],
      ),
    );
  }
  
  /// ---------------- FESTIVAL DROPDOWN ----------------
  Widget _buildFestivalDropdown(BuildContext context, DiscoverViewModel viewModel) {
    return Container(
      margin: EdgeInsets.only(
        left: context.responsiveMargin.left,
        right: context.responsiveMargin.right,
        top: AppDimensions.spaceXS,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: AppColors.onPrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(
          vertical: AppDimensions.spaceXS,
        ),
        itemCount: viewModel.filteredFestivals.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.primary.withOpacity(0.2),
          indent: AppDimensions.spaceM,
          endIndent: AppDimensions.spaceM,
        ),
        itemBuilder: (context, index) {
          final festival = viewModel.filteredFestivals[index];
          return _buildFestivalListItem(context, viewModel, festival);
        },
      ),
    );
  }
  
  /// ---------------- FESTIVAL LIST ITEM ----------------
  Widget _buildFestivalListItem(
    BuildContext context,
    DiscoverViewModel viewModel,
    FestivalModel festival,
  ) {
    return InkWell(
      onTap: () {
        viewModel.selectFestival(context, festival);
      },
      child: Padding(
        padding: context.responsivePadding,
        child: Row(
          children: [
            // Festival icon/placeholder
            Container(
              width: context.getConditionalIconSize() * 1.5,
              height: context.getConditionalIconSize() * 1.5,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
              child: Icon(
                Icons.festival,
                color: AppColors.primary,
                size: context.getConditionalIconSize(),
              ),
            ),
            SizedBox(width: context.getConditionalSpacing()),
            // Festival details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveTextWidget(
                    festival.title,
                    textType: TextType.body,
                    fontSize: context.getConditionalFont(),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (festival.location.isNotEmpty) ...[
                    SizedBox(height: AppDimensions.spaceXS),
                    ResponsiveTextWidget(
                      festival.location,
                      textType: TextType.caption,
                      fontSize: context.getConditionalFont() * 0.85,
                      color: AppColors.primary.withOpacity(0.7),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: context.getConditionalSpacing()),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primary.withOpacity(0.5),
              size: context.getConditionalIconSize() * 0.7,
            ),
          ],
        ),
      ),
    );
  }
}
/// ---------------- SHARE LOCATION POPUP ----------------
class ShareLocationPopup extends StatelessWidget {
  const ShareLocationPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.onPrimary.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: context.responsivePadding,
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCloseButton(context),
            const Icon(
              Icons.location_on,
              color: AppColors.accent,
              size: 60,
            ),
            SizedBox(height: AppDimensions.spaceS),
            _buildTitle(),
            SizedBox(height: context.getConditionalSpacing()),
            _buildShareButton(context),
            SizedBox(height: context.getConditionalSpacing()),
            _buildCancelButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.close, color: AppColors.primary),
      ),
    );
  }

  Widget _buildTitle() {
    return const ResponsiveTextWidget(
      AppStrings.shareLocation,
      textType: TextType.body,
      color: AppColors.accent,
      fontWeight: FontWeight.bold,
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        SnackbarUtil.showSuccessSnackBar(
          context,
          AppStrings.locationSharingEnabled,
        );
      },
      child: Container(
        width: double.infinity,
        padding: context.responsivePadding,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const ResponsiveTextWidget(
          AppStrings.locationSharingDescription,
          textAlign: TextAlign.center,
          textType: TextType.body,
          color: AppColors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const ResponsiveTextWidget(
          AppStrings.hidingMyVibe,
          textAlign: TextAlign.center,
          textType: TextType.body,
          color: AppColors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
