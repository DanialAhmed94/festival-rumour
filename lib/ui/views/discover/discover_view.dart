import 'dart:async';
import 'package:festival_rumour/core/router/app_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/discover/widgets/action_tile.dart';
import 'package:festival_rumour/ui/views/discover/widgets/event_header_card.dart';
import 'package:festival_rumour/ui/views/discover/widgets/grid_option.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/location_permission_helper.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../core/providers/festival_provider.dart';
import '../festival/festival_model.dart';
import 'discover_viewmodel.dart';
import 'widgets/mark_attended_sheet.dart';

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
    // Only use WillPopScope when used as a standalone route (onBack == null).
    // When embedded in NavBaar, we are always in the tree (IndexedStack), so our
    // WillPopScope would run on device back even when Rumors tab is visible,
    // calling onBack (navigateToFestival) and jumping to Festival. Let NavBaar
    // be the single handler for device back when embedded.
    final content = GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          widget.viewModel.unfocusSearch();
        },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Home-style header
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: ResponsivePadding(
                  mobilePadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.appBarHorizontalMobile,
                    vertical: AppDimensions.appBarVerticalMobile,
                  ),
                  tabletPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.appBarHorizontalTablet,
                    vertical: AppDimensions.appBarVerticalTablet,
                  ),
                  desktopPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.appBarHorizontalDesktop,
                    vertical: AppDimensions.appBarVerticalDesktop,
                  ),
                  child: Row(
                    children: [
                      CustomBackButton(onTap: widget.onBack ?? () {}),
                      SizedBox(width: context.getConditionalSpacing()),
                      Expanded(
                        child: ResponsiveTextWidget(
                          AppStrings.overview,
                          textType: TextType.title,
                          fontSize: context.getConditionalMainFont(),
                          color: AppColors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildFavoriteButton(context, widget.viewModel),
                    ],
                  ),
                ),
              ),
              Expanded(
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
    return widget.onBack == null
        ? WillPopScope(
            onWillPop: () async => true,
            child: content,
          )
        : content;
  }

  /// ---------------- BACKGROUND ----------------
  // Background image removed (Discover now uses solid white background to match app-wide header style)

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
        try {
          await widget.viewModel.toggleFavorite(context);
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
          SnackbarUtil.showErrorSnackBar(
            context,
            'Failed to update favorite. Please try again.',
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ResponsiveTextWidget(
            'Favorite',
            textType: TextType.body,
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(width: 6),
          Icon(
            viewModel.isFavorited ? Icons.favorite : Icons.favorite_border,
            color: viewModel.isFavorited ? AppColors.error : AppColors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  /// ---------------- GET READY TEXT ----------------
  Widget _buildGetReadyText() {
    return const ResponsiveTextWidget(
      AppStrings.getReady,
      textType: TextType.body,
      color: AppColors.black,
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
          backgroundColor: AppColors.accent,
          textColor: AppColors.black,
          trailingIconColor: AppColors.black,
          onTap: () => _showCountMeInChoice(context),
        ),
        SizedBox(height: AppDimensions.spaceS),
        ActionTile(
          iconPath: AppAssets.iconcharcter,
          text: AppStrings.inviteYourFestieBestie,
          backgroundColor: const Color(0xFFFC6158),
          textColor: AppColors.white,
          trailingIconColor: AppColors.white,
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
          icon: AppAssets.locationIconSvg,
          onNavigateToSub: widget.onNavigateToSub,
        ),
        GridOption(
          title: AppStrings.chatRooms,
          icon: AppAssets.chatroomIconSvg,
          onTap: () => widget.viewModel.goToChatRooms(context),
        ),
        GridOption(
          title: AppStrings.detail,
          icon: AppAssets.detailIconSvg,
          onNavigateToSub: widget.onNavigateToSub,
        ),
      ],
    );
  }

  /// ---------------- HELPERS ----------------
  void _showCountMeInChoice(BuildContext context) {
    final provider = Provider.of<FestivalProvider>(context, listen: false);
    final festival = provider.selectedFestival;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.screenBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.grey400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ResponsiveTextWidget(
                AppStrings.countMeInChoiceTitle,
                textType: TextType.title,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showShareLocationDialog(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 32, color: AppColors.accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveTextWidget(
                              AppStrings.countMeInShareLocation,
                              textType: TextType.body,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                            const SizedBox(height: 4),
                            ResponsiveTextWidget(
                              AppStrings.countMeInShareLocationDesc,
                              textType: TextType.caption,
                              fontSize: 13,
                              color: AppColors.grey600,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (festival != null) {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: AppColors.screenBackground,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => MarkAttendedSheet(festival: festival),
                    );
                  } else {
                    SnackbarUtil.showErrorSnackBar(
                      context,
                      'Please select a festival first.',
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 32, color: AppColors.accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveTextWidget(
                              AppStrings.countMeInMarkAttended,
                              textType: TextType.body,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                            const SizedBox(height: 4),
                            ResponsiveTextWidget(
                              AppStrings.countMeInMarkAttendedDesc,
                              textType: TextType.caption,
                              fontSize: 13,
                              color: AppColors.grey600,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey600),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareLocationDialog(BuildContext context) {
    final provider = Provider.of<FestivalProvider>(context, listen: false);
    final festival = provider.selectedFestival;
    showDialog(
      context: context,
      builder: (context) => ShareLocationPopup(
        selectedFestivalId: festival?.id,
        selectedFestivalTitle: festival?.title,
      ),
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
        height: 8, // move search bar a bit up
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
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
            ),
            child: Row(
              children: [
                SizedBox(width: context.getConditionalSpacing()),
                // Search icon
                Icon(
                  Icons.search, 
                  color: AppColors.grey700,
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
                        color: AppColors.grey700,
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
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: context.getConditionalFont(),
                    ),
                    cursorColor: AppColors.black,
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
                            color: AppColors.grey700,
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
        color: AppColors.grey200,
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
          color: AppColors.black.withOpacity(0.08),
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
                color: AppColors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
              child: Icon(
                Icons.festival,
                color: AppColors.grey800,
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
                    color: AppColors.black,
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
                      color: AppColors.black.withOpacity(0.6),
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
              color: AppColors.grey700,
              size: context.getConditionalIconSize() * 0.7,
            ),
          ],
        ),
      ),
    );
  }
}
/// ---------------- SHARE LOCATION POPUP ----------------
class ShareLocationPopup extends StatefulWidget {
  /// Festival ID for loading group chat rooms (public + private).
  final int? selectedFestivalId;
  /// Festival name to include in the shared location message (e.g. "at Coachella 2025").
  final String? selectedFestivalTitle;

  const ShareLocationPopup({
    super.key,
    this.selectedFestivalId,
    this.selectedFestivalTitle,
  });

  @override
  State<ShareLocationPopup> createState() => _ShareLocationPopupState();
}

class _ShareLocationPopupState extends State<ShareLocationPopup> {
  bool _globalSharing = false;
  /// Recipients: each map has 'type' ('user' | 'group'). User: userId, displayName, photoUrl, email. Group: chatRoomId, name, isPublic.
  final List<Map<String, dynamic>> _selectedRecipients = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSharing = false;
  Timer? _searchDebounce;
  final FirestoreService _firestoreService = locator<FirestoreService>();
  final AuthService _authService = locator<AuthService>();

  static String? _recipientKey(Map<String, dynamic> r) {
    if (r['type'] == 'group') return r['chatRoomId'] as String?;
    return r['userId'] as String?;
  }

  static String _recipientDisplayName(Map<String, dynamic> r) {
    if (r['type'] == 'group') return r['name'] as String? ?? 'Group';
    return r['displayName'] as String? ?? 'Unknown';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (kDebugMode) {
      print('[ShareLocation] _runSearch query="$query" festivalId=${widget.selectedFestivalId} festivalTitle=${widget.selectedFestivalTitle}');
    }
    setState(() => _isSearching = true);
    try {
      final q = query.trim();
      final selectedKeys = _selectedRecipients.map(_recipientKey).whereType<String>().toSet();
      List<Map<String, dynamic>> combined = [];

      if (q.isNotEmpty) {
        final users = await _firestoreService.searchUsersByName(q, limit: 10);
        for (var u in users) {
          u['type'] = 'user';
          if (!selectedKeys.contains(u['userId'] as String?)) combined.add(u);
        }
        if (kDebugMode) print('[ShareLocation] Search users: ${users.length} found, ${combined.length} added (after excluding selected)');
      }

      final fid = widget.selectedFestivalId;
      final fname = widget.selectedFestivalTitle?.trim() ?? '';
      final uid = _authService.userUid ?? _authService.currentUser?.uid ?? '';
      if (fid != null && fname.isNotEmpty && uid.isNotEmpty) {
        final rooms = await _firestoreService.getChatRoomsForLocationShare(
          userId: uid,
          festivalId: fid,
          festivalName: fname,
          searchQuery: q.isEmpty ? null : q,
          limit: 10,
        );
        int groupsAdded = 0;
        for (var r in rooms) {
          r['type'] = 'group';
          if (!selectedKeys.contains(r['chatRoomId'] as String?)) {
            combined.add(r);
            groupsAdded++;
          }
        }
        if (kDebugMode) print('[ShareLocation] Search groups: ${rooms.length} from API, $groupsAdded added');
      }

      if (mounted) {
        setState(() {
          _searchResults = combined;
          _isSearching = false;
        });
        if (kDebugMode) print('[ShareLocation] _runSearch done: ${combined.length} total results');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('[ShareLocation] _runSearch error: $e');
        print('   $st');
      }
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  void _addRecipient(Map<String, dynamic> item) {
    final key = _recipientKey(item);
    if (key == null || _selectedRecipients.any((e) => _recipientKey(e) == key)) return;
    final type = item['type'] as String? ?? 'user';
    final name = _recipientDisplayName(item);
    if (kDebugMode) print('[ShareLocation] _addRecipient type=$type key=$key name="$name"');
    setState(() {
      _selectedRecipients.add(Map<String, dynamic>.from(item));
      _searchResults = _searchResults.where((e) => _recipientKey(e) != key).toList();
      _searchController.clear();
    });
  }

  void _removeRecipient(Map<String, dynamic> item) {
    final key = _recipientKey(item);
    if (key == null) return;
    if (kDebugMode) print('[ShareLocation] _removeRecipient key=$key');
    setState(() => _selectedRecipients.removeWhere((e) => _recipientKey(e) == key));
  }

  Future<void> _onShareLocation() async {
    final hasFestival = widget.selectedFestivalId != null &&
        (widget.selectedFestivalTitle?.trim().isNotEmpty ?? false);
    final canShareEveryone = _globalSharing && hasFestival;
    final hasRecipients = _selectedRecipients.isNotEmpty;

    if (!_globalSharing && !hasRecipients) {
      if (kDebugMode) print('[ShareLocation] _onShareLocation skipped: no recipients and global off');
      SnackbarUtil.showErrorSnackBar(
        context,
        'Turn on "Share with everyone" or add at least one person or group to share with.',
      );
      return;
    }
    if (_globalSharing && !hasFestival && !hasRecipients) {
      if (kDebugMode) print('[ShareLocation] _onShareLocation skipped: share with everyone but no festival selected');
      SnackbarUtil.showErrorSnackBar(
        context,
        'Select a festival to share with everyone, or add people or groups to share with.',
      );
      return;
    }
    if (kDebugMode) {
      print('[ShareLocation] _onShareLocation start: globalSharing=$_globalSharing hasFestival=$hasFestival recipients=${_selectedRecipients.length}');
    }
    setState(() => _isSharing = true);
    try {
      final result = await LocationPermissionHelper.requestLocationPermission(context);
      if (!mounted) return;
      if (result != LocationPermissionResult.granted) {
        if (kDebugMode) print('[ShareLocation] Location permission not granted: $result');
        if (result == LocationPermissionResult.denied) {
          SnackbarUtil.showErrorSnackBar(context, AppStrings.locationPermissionDenied);
        }
        setState(() => _isSharing = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (kDebugMode) print('[ShareLocation] Position: lat=${position.latitude} lng=${position.longitude}');
      if (!mounted) return;
      final uid = _authService.userUid ?? _authService.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        if (kDebugMode) print('[ShareLocation] Not signed in');
        SnackbarUtil.showErrorSnackBar(context, 'You must be signed in to share location.');
        setState(() => _isSharing = false);
        return;
      }
      final name = _authService.userDisplayName ??
          _authService.currentUser?.displayName ??
          'Someone';
      final senderPhotoUrl = _authService.userPhotoUrl;
      final festivalName = widget.selectedFestivalTitle?.trim();
      final locationMessage = (festivalName != null && festivalName.isNotEmpty)
          ? 'Shared their location at $festivalName'
          : 'Shared their location';

      // 1) Share with everyone = post to this festival's public (community) chat room only (no push notification)
      if (canShareEveryone) {
        final publicRoomId = FirestoreService.getFestivalChatRoomId(
          widget.selectedFestivalId!,
          widget.selectedFestivalTitle!.trim(),
        );
        if (kDebugMode) print('[ShareLocation] Sending to public group (everyone): chatRoomId=$publicRoomId');
        try {
          await _firestoreService.sendLocationShareToChatRoom(
            chatRoomId: publicRoomId,
            senderId: uid,
            senderName: name,
            senderPhotoUrl: senderPhotoUrl,
            lat: position.latitude,
            lng: position.longitude,
            festivalName: festivalName?.isNotEmpty == true ? festivalName : null,
          );
        } catch (e) {
          if (kDebugMode) print('[ShareLocation] Failed to send to public room (may not exist yet): $e');
          if (mounted && !hasRecipients) {
            SnackbarUtil.showErrorSnackBar(
              context,
              'Community chat for this festival is not set up yet. Try adding people or groups to share with.',
            );
            setState(() => _isSharing = false);
            return;
          }
        }
      }

      // 2) Share with selected users and groups
      for (final r in _selectedRecipients) {
        if (r['type'] == 'user') {
          final recipientId = r['userId'] as String?;
          if (recipientId == null || recipientId.isEmpty) continue;
          if (kDebugMode) print('[ShareLocation] Sending to DM recipientId=$recipientId');
          await _firestoreService.sendLocationShareToDmRoom(
            senderId: uid,
            senderName: name,
            senderPhotoUrl: senderPhotoUrl,
            recipientId: recipientId,
            lat: position.latitude,
            lng: position.longitude,
            festivalName: festivalName?.isNotEmpty == true ? festivalName : null,
          );
          // Notify the 1:1 recipient (private DM only)
          NotificationServiceApi.sendPushNotification(
            userIds: [recipientId],
            title: name,
            message: locationMessage,
            chatRoomId: FirestoreService.getDeterministicDmRoomId(uid, recipientId),
            chatRoomName: 'Direct message',
          ).catchError((e) {
            if (kDebugMode) print('[ShareLocation] Push notification (DM) error: $e');
          });
        } else if (r['type'] == 'group') {
          final chatRoomId = r['chatRoomId'] as String?;
          if (chatRoomId == null || chatRoomId.isEmpty) continue;
          if (kDebugMode) print('[ShareLocation] Sending to group chatRoomId=$chatRoomId');
          await _firestoreService.sendLocationShareToChatRoom(
            chatRoomId: chatRoomId,
            senderId: uid,
            senderName: name,
            senderPhotoUrl: senderPhotoUrl,
            lat: position.latitude,
            lng: position.longitude,
            festivalName: festivalName?.isNotEmpty == true ? festivalName : null,
          );
          // Notify other members only for private groups (not festival public room)
          final publicRoomId = (widget.selectedFestivalId != null &&
                  (widget.selectedFestivalTitle?.trim().isNotEmpty ?? false))
              ? FirestoreService.getFestivalChatRoomId(
                  widget.selectedFestivalId!,
                  widget.selectedFestivalTitle!.trim(),
                )
              : null;
          if (publicRoomId == null || chatRoomId != publicRoomId) {
            _firestoreService.getChatRoomDocument(chatRoomId).then((roomDoc) {
              if (roomDoc == null) return;
              final members = roomDoc['members'] as List<dynamic>?;
              if (members == null || members.isEmpty) return;
              final otherMemberIds = members
                  .map((e) => e.toString())
                  .where((id) => id != uid)
                  .toList();
              if (otherMemberIds.isEmpty) return;
              final roomName = roomDoc['name'] as String? ?? 'Group';
              // Single request. Backend must send exactly one FCM per userId in the list.
              NotificationServiceApi.sendPushNotification(
                userIds: otherMemberIds,
                title: name,
                message: locationMessage,
                chatRoomId: chatRoomId,
                chatRoomName: roomName,
              ).catchError((e) {
                if (kDebugMode) print('[ShareLocation] Push notification (group) error: $e');
              });
            }).catchError((e) {
              if (kDebugMode) print('[ShareLocation] getChatRoomDocument error: $e');
            });
          }
        }
      }
      if (!mounted) return;
      if (kDebugMode) print('[ShareLocation] _onShareLocation success, closing dialog');
      SnackbarUtil.showSuccessSnackBar(context, AppStrings.locationSharedSuccess);
      Navigator.pop(context);
    } catch (e, st) {
      if (kDebugMode) {
        print('[ShareLocation] _onShareLocation error: $e');
        print('   $st');
      }
      if (mounted) {
        SnackbarUtil.showErrorSnackBar(
          context,
          'Failed to share location. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: context.responsivePadding,
      child: Padding(
        padding: context.responsivePadding,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCloseButton(context),
              const Icon(Icons.location_on, color: AppColors.accent, size: 48),
              SizedBox(height: AppDimensions.spaceS),
              _buildTitle(),
              SizedBox(height: AppDimensions.spaceM),
              _buildGlobalToggle(context),
              SizedBox(height: AppDimensions.spaceM),
              _buildShareWithSelectedSection(context),
              SizedBox(height: AppDimensions.spaceM),
              _buildShareLocationButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareLocationButton(BuildContext context) {
    return GestureDetector(
      onTap: _isSharing ? null : _onShareLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isSharing ? AppColors.grey400 : AppColors.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isSharing
            ? const SizedBox(
                height: 22,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.black,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            : const ResponsiveTextWidget(
                'Share location',
                textAlign: TextAlign.center,
                textType: TextType.body,
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.close, color: AppColors.black, size: 26),
      ),
    );
  }

  Widget _buildTitle() {
    return const ResponsiveTextWidget(
      AppStrings.shareMyLocation,
      textType: TextType.title,
      color: AppColors.accent,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildGlobalToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  AppStrings.shareWithEveryone,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  AppStrings.shareWithEveryoneHint,
                  textType: TextType.caption,
                  color: AppColors.grey600,
                ),
              ],
            ),
          ),
          Switch(
            value: _globalSharing,
            onChanged: (v) => setState(() => _globalSharing = v),
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildShareWithSelectedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveTextWidget(
          AppStrings.shareWithSelected,
          textType: TextType.body,
          color: AppColors.black,
          fontWeight: FontWeight.w600,
        ),
        SizedBox(height: AppDimensions.spaceS),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: AppColors.black, fontSize: 15),
          decoration: InputDecoration(
            hintText: AppStrings.searchUsersOrGroups,
            hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.black54, size: 22),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.grey400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.grey400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_selectedRecipients.isNotEmpty) ...[
          SizedBox(height: AppDimensions.spaceS),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedRecipients.map((r) {
              final name = _recipientDisplayName(r);
              final isGroup = r['type'] == 'group';
              return Chip(
                avatar: Icon(isGroup ? Icons.group : Icons.person, size: 18, color: AppColors.black54),
                label: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 18, color: AppColors.black54),
                onDeleted: () => _removeRecipient(r),
                backgroundColor: AppColors.accent.withOpacity(0.25),
                side: BorderSide(color: AppColors.grey400),
              );
            }).toList(),
          ),
        ],
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          )
        else if (_searchResults.isNotEmpty) ...[
          SizedBox(height: AppDimensions.spaceS),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey400),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.grey300),
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                final isGroup = item['type'] == 'group';
                final name = isGroup
                    ? (item['name'] as String? ?? 'Group')
                    : (item['displayName'] as String? ?? 'Unknown');
                final subtitle = isGroup
                    ? ((item['isPublic'] == true) ? 'Public group' : 'Private group')
                    : (item['email'] as String?);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _addRecipient(item),
                    borderRadius: BorderRadius.circular(0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          if (isGroup)
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.grey300,
                              child: Icon(Icons.group, color: AppColors.black54, size: 24),
                            )
                          else
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.grey300,
                              backgroundImage: (item['photoUrl'] as String?) != null && (item['photoUrl'] as String).isNotEmpty
                                  ? NetworkImage(item['photoUrl'] as String)
                                  : null,
                              child: (item['photoUrl'] as String?) == null || (item['photoUrl'] as String).isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: AppColors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle != null && subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: AppColors.grey600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline, color: AppColors.black, size: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

}
