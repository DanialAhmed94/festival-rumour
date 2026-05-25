import 'package:festival_rumour/core/constants/app_strings.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/chat_badge_service.dart';
import '../../../core/services/current_chat_list_service.dart';
import '../../../core/services/notification_storage_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/providers/festival_provider.dart';
import 'profile_viewmodel.dart';

class ProfileView extends BaseView<ProfileViewModel> {
  final VoidCallback? onBack;
  final Function(String)? onNavigateToSub;
  final String? userId; // Optional userId to view another user's profile
  final String? fromRoute; // Route we came from (for proper back navigation)
  const ProfileView({super.key, this.onBack, this.onNavigateToSub, this.userId, this.fromRoute});

  @override
  ProfileViewModel createViewModel() => ProfileViewModel();

  @override
  void onViewModelReady(ProfileViewModel viewModel) {
    super.onViewModelReady(viewModel);
    locator<ChatBadgeService>().loadFromStorage();
  }

  @override
  Widget buildView(BuildContext context, ProfileViewModel viewModel) {
    return _ProfileViewContent(
      viewModel: viewModel,
      userId: userId,
      fromRoute: fromRoute,
      onBack: onBack,
      onNavigateToSub: onNavigateToSub,
    );
  }
}

/// Stateful widget to manage initialization and keep-alive
class _ProfileViewContent extends StatefulWidget {
  final ProfileViewModel viewModel;
  final String? userId;
  final String? fromRoute;
  final VoidCallback? onBack;
  final Function(String)? onNavigateToSub;
  
  const _ProfileViewContent({
    required this.viewModel,
    this.userId,
    this.fromRoute,
    this.onBack,
    this.onNavigateToSub,
  });
  
  @override
  State<_ProfileViewContent> createState() => _ProfileViewContentState();
}

class _ProfileViewContentState extends State<_ProfileViewContent> with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  String? _lastUserId;

  // Step 5: prevents scheduling refreshUserProfileInfo more than once per
  // rebuild burst. Cleared when the PostFrameCallback actually fires.
  bool _profileRefreshScheduled = false;

  // Phase 3: scroll prefetch
  final ScrollController _scrollController = ScrollController();
  bool _prefetchFrameScheduled = false;
  int _lastGridTopUpLength = -1; // track grid length for short-list top-up

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastUserId = widget.userId;
    _scrollController.addListener(_onScroll);
    if (!_isInitialized || _lastUserId != widget.userId) {
      _isInitialized = true;
      _lastUserId = widget.userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.viewModel.isLoading) {
          widget.viewModel.initialize(context, userId: widget.userId, fromRoute: widget.fromRoute);
        }
      });
    }
  }
  
  @override
  void didUpdateWidget(_ProfileViewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if userId changed
    if (oldWidget.userId != widget.userId) {
      _isInitialized = false;
      _lastUserId = widget.userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.viewModel.isLoading) {
          widget.viewModel.initialize(context, userId: widget.userId, fromRoute: widget.fromRoute);
        }
      });
    }
    // Refresh profile info when returning to own profile.
    // Guard: only schedule one PostFrameCallback per rebuild burst; the flag
    // is cleared when the callback fires so the next genuine navigation event
    // (e.g. return from edit-profile) can schedule again.
    else if (widget.viewModel.isInitialized &&
        widget.userId == null &&
        oldWidget.userId == null &&
        !_profileRefreshScheduled) {
      _profileRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _profileRefreshScheduled = false;
        if (mounted) {
          widget.viewModel.refreshUserProfileInfo();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll prefetch (Phase 3) ────────────────────────────────────────────

  void _onScroll() {
    _schedulePrefetchNearEnd();
  }

  void _schedulePrefetchNearEnd() {
    if (_prefetchFrameScheduled) return;
    _prefetchFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchFrameScheduled = false;
      if (!mounted) return;
      _maybePrefetchMoreGrid();
    });
  }

  void _maybePrefetchMoreGrid() {
    final vm = widget.viewModel;
    if (vm.isLoadingMoreImages || vm.isLoadingMoreVideos) return;
    final tab = vm.selectedTab;
    final hasMore = tab == 0 ? vm.hasMoreImages : vm.hasMoreVideos;
    if (!hasMore) return;
    try {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasViewportDimension || !position.hasPixels) return;
      final prefetchLead = position.viewportDimension * 1.5;
      if (position.maxScrollExtent <= 0) {
        _loadMoreForCurrentTab(vm);
        return;
      }
      if (position.pixels >= position.maxScrollExtent - prefetchLead) {
        _loadMoreForCurrentTab(vm);
      }
    } catch (_) {}
  }

  void _topUpShortGridIfNeeded() {
    final vm = widget.viewModel;
    final tab = vm.selectedTab;
    final hasMore = tab == 0 ? vm.hasMoreImages : vm.hasMoreVideos;
    if (!hasMore) return;
    if (vm.isLoadingMoreImages || vm.isLoadingMoreVideos) return;
    try {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasViewportDimension) return;
      if (position.maxScrollExtent > 0) return;
      _loadMoreForCurrentTab(vm);
    } catch (_) {}
  }

  void _loadMoreForCurrentTab(ProfileViewModel vm) {
    if (vm.selectedTab == 0) {
      vm.loadMoreImages(context);
    } else {
      vm.loadMoreVideos(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // PopScope replaces deprecated WillPopScope (Flutter 3.12+).
    // canPop = false when we intercept back navigation ourselves;
    // onPopInvokedWithResult handles the custom logic when didPop is false.
    return PopScope(
      canPop: widget.onBack == null &&
          !(widget.fromRoute != null && widget.userId != null),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return; // default pop already happened — nothing to do
        if (kDebugMode) {
          print('🔙 Profile back intercepted (userId: ${widget.userId}, fromRoute: ${widget.fromRoute})');
        }
        if (widget.onBack != null) {
          widget.onBack!();
          return;
        }
        if (widget.fromRoute != null && widget.userId != null) {
          Navigator.popUntil(context, (route) {
            return route.settings.name == widget.fromRoute || route.isFirst;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: _profileTopBarWidget(context, widget.viewModel),
              ),
              // Consumer rebuilds only the scroll view on ViewModel notifications.
              // SliverGrid is viewport-culled — O(visible) layout, not O(N).
              Expanded(
                child: Consumer<ProfileViewModel>(
                  builder: (ctx, vm, _) {
                    // Trigger short-list top-up when grid length changes.
                    final gridLen = vm.selectedTab == 0
                        ? vm.userImages.length
                        : vm.userVideos.length;
                    if (gridLen > 0 && gridLen != _lastGridTopUpLength) {
                      _lastGridTopUpLength = gridLen;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _topUpShortGridIfNeeded();
                      });
                    }
                    return _buildScrollView(ctx, vm);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CustomScrollView _buildScrollView(BuildContext context, ProfileViewModel vm) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        /// Profile Header (collapsible)
        SliverAppBar(
          expandedHeight: context.isSmallScreen
              ? context.screenHeight * 0.25
              : context.screenHeight * 0.24,
          floating: false,
          pinned: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProfileHeader(context, vm),
          ),
        ),

        /// Tabs (pinned)
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileTabsDelegate(
            child: Container(
              height: AppDimensions.buttonHeightXL,
              color: AppColors.white,
              child: _profileTabs(context, vm),
            ),
          ),
        ),

        /// Grid content — viewport-culled slivers (no shrinkWrap)
        if (vm.selectedTab == 0)
          ..._buildImageSlivers(context, vm)
        else
          ..._buildVideoSlivers(context, vm),
      ],
    );
  }
  // Widget _buildFloatingButton(BuildContext context) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 10, right: 5), // Fine-tuned position
  //     child: FloatingActionButton(
  //       onPressed: () {
  //         _showPostBottomSheet(context);
  //       },
  //       backgroundColor: AppColors.onPrimary,
  //       child: const Icon(Icons.add, color: Colors.white, size: 30),
  //       elevation: 8,
  //       shape: const CircleBorder(),
  //     ),
  //   );
  // }


        /// ---------------- INSTAGRAM-LIKE PROFILE HEADER ---------------- 
  Widget _buildProfileHeader(BuildContext context, ProfileViewModel viewModel) {
    return Selector<ProfileViewModel, String?>(
      selector: (_, vm) => vm.userPhotoUrl,
      builder: (context, userPhotoUrl, child) {
        return Selector<ProfileViewModel, String?>(
          selector: (_, vm) => vm.userDisplayName,
          builder: (context, userDisplayName, child) {
            return Container(
              padding: context.responsivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  /// Profile info (Username & followers left — Picture right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipOval(
                        child: userPhotoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: userPhotoUrl,
                                width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                  height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                  color: AppColors.black.withOpacity(0.3),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.black,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Image.asset(
                                  AppAssets.profile,
                                  width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                  height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                  fit: BoxFit.cover,
                                ),
                                cacheKey: userPhotoUrl,
                                maxWidthDiskCache: 200,
                                maxHeightDiskCache: 200,
                              )
                            : Image.asset(
                                AppAssets.profile,
                                width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                                fit: BoxFit.cover,
                              ),
                      ),
                      SizedBox(width: context.getConditionalSpacing()),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Username
                            ResponsiveTextWidget(
                              userDisplayName ?? 'User',
                              color: AppColors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: AppDimensions.textL,
                            ),
                            SizedBox(height: AppDimensions.spaceS),
                            // Stats in horizontal ListView to avoid overflow
                            Consumer<ProfileViewModel>(
                              builder: (context, vm, child) {
                                return SizedBox(
                                  height: 52,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    shrinkWrap: true,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: 5,
                                    separatorBuilder: (_, __) => SizedBox(width: context.getConditionalSpacing()),
                                    itemBuilder: (context, index) {
                                      switch (index) {
                                        case 0:
                                          return _buildClickableStat(
                                            context,
                                            vm.postCount.toString(),
                                            AppStrings.posts,
                                            null,
                                          );
                                        case 1:
                                          return _buildClickableStat(
                                            context,
                                            '${vm.followersCount}',
                                            AppStrings.followers,
                                            () {
                                              if (widget.onNavigateToSub != null) {
                                                widget.onNavigateToSub!('followers');
                                              } else {
                                                final currentUserId = vm.authService.userUid ?? vm.authService.currentUser?.uid;
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.profileList,
                                                  arguments: {
                                                    'initialTab': 0,
                                                    'username': vm.userDisplayName ?? 'User',
                                                    'userId': currentUserId,
                                                  },
                                                );
                                              }
                                            },
                                          );
                                        case 2:
                                          return _buildClickableStat(
                                            context,
                                            '${vm.followingCount}',
                                            AppStrings.following,
                                            () {
                                              if (widget.onNavigateToSub != null) {
                                                widget.onNavigateToSub!('following');
                                              } else {
                                                final currentUserId = vm.authService.userUid ?? vm.authService.currentUser?.uid;
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.profileList,
                                                  arguments: {
                                                    'initialTab': 1,
                                                    'username': vm.userDisplayName ?? 'User',
                                                    'userId': currentUserId,
                                                  },
                                                );
                                              }
                                            },
                                          );
                                        case 3:
                                          return _buildClickableStat(
                                            context,
                                            '${vm.favoriteFestivalsCount}',
                                            'Favourite Festivals',
                                            () {
                                              if (widget.onNavigateToSub != null) {
                                                widget.onNavigateToSub!('festivals');
                                              } else {
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.profileList,
                                                  arguments: {
                                                    'initialTab': 2,
                                                    'username': vm.userDisplayName ?? 'User',
                                                  },
                                                );
                                              }
                                            },
                                          );
                                        case 4:
                                          return _buildClickableStat(
                                            context,
                                            '${vm.attendedFestivalsCount}',
                                            'Attended festivals',
                                            () {
                                              if (widget.onNavigateToSub != null) {
                                                widget.onNavigateToSub!('attended');
                                              } else {
                                                Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.profileList,
                                                  arguments: {
                                                    'initialTab': 3,
                                                    'username': vm.userDisplayName ?? 'User',
                                                    'userId': vm.authService.userUid ?? vm.authService.currentUser?.uid,
                                                  },
                                                );
                                              }
                                            },
                                          );
                                        default:
                                          return const SizedBox.shrink();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.getConditionalSpacing()),
                  /// Bio / Description below profile picture
                  Selector<ProfileViewModel, String?>(
                    selector: (_, vm) => vm.userBio,
                    builder: (context, userBio, child) {
                      final bioText = userBio?.isNotEmpty == true 
                          ? userBio! 
                          : AppStrings.bioDescription;
                      return ResponsiveTextWidget(
                        bioText,
                        color: AppColors.black,
                        fontSize: context.getConditionalFont(),
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // _buildDynamicContent replaced by _buildImageSlivers / _buildVideoSlivers below.
  /// ---------------- TOP BAR ---------------- 
  Widget _profileTopBarWidget(BuildContext context, ProfileViewModel viewModel) {
    return ResponsivePadding(
      mobilePadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalMobile,
        vertical: AppDimensions.appBarVerticalMobile,
      ),
      tabletPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalTablet,
        vertical: AppDimensions.appBarVerticalTablet,
      ),
      desktopPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.appBarHorizontalDesktop,
        vertical: AppDimensions.appBarVerticalDesktop,
      ),
      child: Row(
        children: [
          /// Back button
          CustomBackButton(
            onTap: () {
        if (widget.onBack != null) {
          widget.onBack!();
              } else {
                // Handle back navigation based on where we came from
                if (widget.fromRoute != null) {
                  // If viewing another user's profile, pop until we reach the original route
                  if (widget.userId != null) {
                    // Pop until we reach the route we came from (e.g., search screen)
                    Navigator.popUntil(context, (route) {
                      final routeName = route.settings.name;
                      final matches = routeName == widget.fromRoute;
                      if (matches || route.isFirst) {
                        return true; // Stop at matching route or first route
                      }
                      return false; // Continue popping
                    });
                  } else {
                    // Viewing own profile - just pop
                    Navigator.pop(context);
                  }
                } else {
                  // Default: just pop
                  Navigator.pop(context);
                }
              }
            },
          ),

          SizedBox(width: context.getConditionalSpacing()),

          /// Profile title (match Chat / Discover pink app bars: title type + ellipsis)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 0),
              child: ResponsiveTextWidget(
                AppStrings.profile,
                textAlign: TextAlign.center,
                textType: TextType.title,
                fontSize: context.getConditionalMainFont(),
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          /// Spacer to push icons to the right
          const Spacer(),

          /// Right-side icons
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              if (widget.userId == null)
                IconButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.createPost);
                    if (context.mounted) {
                      await viewModel.refreshPostsOnly(context);
                    }
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                  padding: context.responsivePadding,
                  constraints: BoxConstraints(
                    minWidth: context.getConditionalIconSize(),
                    minHeight: context.getConditionalIconSize(),
                  ),
                  tooltip: AppStrings.createPost,
                ),
              if (widget.userId == null) SizedBox(width: context.getConditionalSpacing()),
              if (widget.userId == null)
                ListenableBuilder(
                  listenable: Listenable.merge([
                    locator<ChatBadgeService>(),
                    locator<CurrentChatListService>(),
                  ]),
                  builder: (context, _) {
                    final badgeService = locator<ChatBadgeService>();
                    final listService = locator<CurrentChatListService>();
                    final roomIds = listService.roomIds;
                    // Only show badge when the DM room list is known.
                    // When empty the user hasn't opened chats yet and
                    // hasUnread would include public/stale rooms.
                    final hasUnreadChats = roomIds.isNotEmpty &&
                        badgeService.hasUnreadInRooms(roomIds);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.chatList);
                          },
                          icon: Icon(
                            Icons.chat,
                            color: AppColors.white,
                            size: AppDimensions.iconL,
                          ),
                          padding: context.responsivePadding,
                          constraints: BoxConstraints(
                            minWidth: context.getConditionalIconSize(),
                            minHeight: context.getConditionalIconSize(),
                          ),
                          tooltip: 'Chats',
                        ),
                        if (hasUnreadChats)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.black.withOpacity(0.26),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (widget.userId == null) SizedBox(width: context.getConditionalSpacing()),
              IconButton(
                onPressed: () async {
                  // Refresh posts only
                  await viewModel.refreshPostsOnly(context);
                },
                icon: Icon(
                  Icons.refresh,
                  color: AppColors.white, 
                  size: AppDimensions.iconL,
                ),
                padding: context.responsivePadding,
                constraints: BoxConstraints(
                  minWidth: context.getConditionalIconSize(),
                  minHeight: context.getConditionalIconSize(),
                ),
              ),
              IconButton(
                onPressed: () {
                  // Navigate to search users screen
                  Navigator.pushNamed(context, AppRoutes.searchUsers);
                },
                icon: Icon(
                  Icons.search,
                  color: AppColors.white, 
                  size: AppDimensions.iconL,
                ),
                padding: context.responsivePadding,
                constraints: BoxConstraints(
                  minWidth: context.getConditionalIconSize(),
                  minHeight: context.getConditionalIconSize(),
                ),
              ),
              ListenableBuilder(
                listenable: locator<NotificationStorageService>(),
                builder: (context, _) {
                  final hasNotifications = locator<NotificationStorageService>().items.isNotEmpty;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.notification);
                        },
                        icon: Icon(Icons.notifications_none,
                            color: AppColors.white,
                            size: AppDimensions.iconL),
                        padding: context.responsivePadding,
                        constraints: BoxConstraints(
                          minWidth: context.getConditionalIconSize(),
                          minHeight: context.getConditionalIconSize(),
                        ),
                      ),
                      if (hasNotifications)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration:  BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withOpacity(0.26),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(){
    return  Container(
      width: double.infinity,
      // Remove any outer spacing
      child: const Divider(
        color: AppColors.primary,
        thickness: 1,
        height: 1,// end at very right
      ),
    );
  }

  /// ---------------- SLIVER GRID BUILDERS ----------------
  /// Returns viewport-culled SliverGrid slivers for the images tab.
  /// No shrinkWrap — only visible cells are laid out.
  List<Widget> _buildImageSlivers(BuildContext context, ProfileViewModel vm) {
    final images = vm.userImages;

    if (images.isEmpty && vm.isLoading) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.black),
                SizedBox(height: context.responsivePadding.top),
                ResponsiveTextWidget(
                  'Loading posts...',
                  color: AppColors.black.withOpacity(0.7),
                  fontSize: AppDimensions.textM,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (images.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.all(context.responsivePadding.top),
            child: Center(
              child: ResponsiveTextWidget(
                'there is nothing to show',
                color: AppColors.black,
                fontSize: AppDimensions.textM,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.isLargeScreen ? 4 : 3,
          mainAxisSpacing: context.isLargeScreen ? 4 : 2,
          crossAxisSpacing: context.isLargeScreen ? 4 : 2,
        ),
        itemCount: images.length,
        itemBuilder: (ctx, index) => _buildImageGridCell(ctx, vm, index),
      ),
      SliverToBoxAdapter(
        child: _buildImagesFooter(context, vm),
      ),
    ];
  }

  Widget _buildImageGridCell(BuildContext context, ProfileViewModel vm, int index) {
    final images = vm.userImages;
    final postInfo = index < vm.imagePostInfos.length ? vm.imagePostInfos[index] : null;
    return GestureDetector(
      onTap: () => _onImageGridTap(context, vm, index, postInfo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SafeCachedNetworkImage(
            imageUrl: images[index],
            fit: BoxFit.cover,
            placeholder: Container(
              color: AppColors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: AppColors.black)),
            ),
            errorWidget: Container(
              color: AppColors.screenBackground.withOpacity(0.5),
              child: const Icon(Icons.broken_image_outlined, color: AppColors.grey600, size: 32),
            ),
          ),
          if (postInfo != null && (postInfo['hasMultipleMedia'] as bool? ?? false))
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.collections, color: AppColors.accent, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onImageGridTap(
    BuildContext context,
    ProfileViewModel vm,
    int index,
    Map<String, dynamic>? postInfo,
  ) async {
    if (kDebugMode) {
      print('🖱️ Tapped image at index $index — postId=${postInfo?['postId']}, collection=${postInfo?['collectionName']}');
    }
    if (postInfo == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post information not available'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.black)),
      );
    }
    final fullPost = await vm.fetchSinglePost(postInfo);
    if (context.mounted) Navigator.pop(context);
    if (fullPost != null && context.mounted) {
      if (widget.onNavigateToSub != null) {
        widget.onNavigateToSub!('posts');
      } else {
        final collectionName = postInfo['collectionName'] as String?;
        final result = await Navigator.pushNamed(
          context,
          AppRoutes.posts,
          arguments: {'posts': [fullPost], 'collectionName': collectionName},
        );
        if (context.mounted && result is Map<String, dynamic>) {
          final deletedIds = result['deletedPostIds'] as List<String>?;
          if (deletedIds != null && deletedIds.isNotEmpty) vm.removeDeletedPosts(deletedIds);
          if (result['wasEdited'] == true) vm.refreshPostsOnly(context);
        }
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load post. Please try again.'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildImagesFooter(BuildContext context, ProfileViewModel vm) {
    if (vm.isLoadingMoreImages) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.responsivePadding.top),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
          ),
        ),
      );
    }
    // hasMore: prefetch fires automatically — no button needed.
    // !hasMore: grid is exhausted.
    return const SizedBox.shrink();
  }


  /// Returns viewport-culled SliverGrid slivers for the videos tab.
  List<Widget> _buildVideoSlivers(BuildContext context, ProfileViewModel vm) {
    final videos = vm.userVideos;

    if (videos.isEmpty && vm.isLoading) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.black),
                SizedBox(height: context.responsivePadding.top),
                ResponsiveTextWidget(
                  'Loading reels...',
                  color: AppColors.black.withOpacity(0.7),
                  fontSize: AppDimensions.textM,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (videos.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.all(context.responsivePadding.top),
            child: Center(
              child: ResponsiveTextWidget('No reels yet', color: AppColors.black, fontSize: AppDimensions.textM),
            ),
          ),
        ),
      ];
    }

    return [
      SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.isLargeScreen ? 4 : 3,
          mainAxisSpacing: context.isLargeScreen ? 4 : 2,
          crossAxisSpacing: context.isLargeScreen ? 4 : 2,
        ),
        itemCount: videos.length,
        itemBuilder: (ctx, index) => _buildVideoGridCell(ctx, vm, index),
      ),
      SliverToBoxAdapter(
        child: _buildVideosFooter(context, vm),
      ),
    ];
  }

  Widget _buildVideoGridCell(BuildContext context, ProfileViewModel vm, int index) {
    final postInfo = index < vm.videoPostInfos.length ? vm.videoPostInfos[index] : null;
    return GestureDetector(
      onTap: () => _onVideoGridTap(context, vm, index, postInfo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: AppColors.black.withOpacity(0.5),
            child: Center(
              child: Icon(Icons.play_circle_outline, color: AppColors.black, size: context.responsiveIconXL),
            ),
          ),
          if (postInfo != null && (postInfo['hasMultipleMedia'] as bool? ?? false))
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.collections, color: AppColors.accent, size: 16),
              ),
            ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.videocam, color: AppColors.black, size: context.responsiveIconM),
          ),
        ],
      ),
    );
  }

  Future<void> _onVideoGridTap(
    BuildContext context,
    ProfileViewModel vm,
    int index,
    Map<String, dynamic>? postInfo,
  ) async {
    if (kDebugMode) {
      print('🖱️ Tapped video at index $index — postId=${postInfo?['postId']}, collection=${postInfo?['collectionName']}');
    }
    if (postInfo == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post information not available'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.black)),
      );
    }
    final fullPost = await vm.fetchSinglePost(postInfo);
    if (context.mounted) Navigator.pop(context);
    if (fullPost != null && context.mounted) {
      if (widget.onNavigateToSub != null) {
        widget.onNavigateToSub!('posts');
      } else {
        final collectionName = postInfo['collectionName'] as String?;
        final result = await Navigator.pushNamed(
          context,
          AppRoutes.posts,
          arguments: {'posts': [fullPost], 'collectionName': collectionName},
        );
        if (context.mounted && result is Map<String, dynamic>) {
          final deletedIds = result['deletedPostIds'] as List<String>?;
          if (deletedIds != null && deletedIds.isNotEmpty) vm.removeDeletedPosts(deletedIds);
          if (result['wasEdited'] == true) vm.refreshPostsOnly(context);
        }
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load post. Please try again.'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildVideosFooter(BuildContext context, ProfileViewModel vm) {
    if (vm.isLoadingMoreVideos) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.responsivePadding.top),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// ---------------- HELPERS ---------------- 
  Widget _buildStat(BuildContext context, String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ResponsiveTextWidget(
          count,
          textType: TextType.title,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
         // fontSize: AppDimensions.textM,
          fontSize: context.isHighResolutionPhone ? 16 : 12,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        ResponsiveTextWidget(
          label,
          textType: TextType.caption,
          color: AppColors.black,
        //fontSize: AppDimensions.textXS,
          fontSize: context.isHighResolutionPhone ? 10 : 8,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildClickableStat(BuildContext context, String count, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Make entire area tappable
      child: Container(
        // Responsive padding for larger tap area
        padding: EdgeInsets.symmetric(
          horizontal: context.isSmallScreen ? 6 : context.isMediumScreen ? 8 : 10,
          vertical: context.isSmallScreen ? 3 : context.isMediumScreen ? 4 : 5,
        ),
        child: _buildStat(context, count, label),
      ),
    );
  }


  // Widget _buildMiniStat(String count, String label) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(count,
  //           style: TextStyle(
  //               color: AppColors.white,
  //               fontWeight: FontWeight.bold,
  //               fontSize: context.isSmallScreen
  //                   ? AppDimensions.textS
  //                   : context.isMediumScreen
  //                       ? AppDimensions.textM
  //                       : AppDimensions.textL)),
  //       Text(label,
  //           style: TextStyle(
  //               color: AppColors.white,
  //               fontSize: context.isSmallScreen
  //                   ? AppDimensions.textXS
  //                   : context.isMediumScreen
  //                       ? AppDimensions.textS
  //                       : AppDimensions.textM)),
  //     ],
  //   );
  // }

  Widget _profileTabs(BuildContext context, ProfileViewModel viewModel) {
    return Container(
      height: AppDimensions.buttonHeightXL,
      child: Selector<ProfileViewModel, int>(
        selector: (context, vm) => vm.selectedTab,
        builder: (context, selectedTab, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _tabIcon(context, viewModel, Icons.grid_on, 0, selectedTab),
              ),
              Expanded(
                child: _tabIcon(context, viewModel, Icons.video_collection_outlined, 1, selectedTab),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabIcon(BuildContext context, ProfileViewModel viewModel, IconData icon, int index, int selectedTab) {
    return IconButton(
      icon: Icon(
        icon,
        color: selectedTab == index ? AppColors.accent : AppColors.black,
        size: context.responsiveIconM,
      ),
      onPressed: () => viewModel.setSelectedTab(index),
      padding: EdgeInsets.all(context.responsivePadding.left),
      constraints: BoxConstraints(
        minWidth: context.responsiveIconXL,
        minHeight: context.responsiveIconXL,
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(
              backgroundColor: AppColors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: context.isSmallScreen 
                        ? AppDimensions.paddingL
                        : context.isMediumScreen 
                            ? AppDimensions.paddingXL
                            : AppDimensions.paddingXXL,
                    left: context.isSmallScreen 
                        ? AppDimensions.paddingM
                        : context.isMediumScreen 
                            ? AppDimensions.paddingL
                            : AppDimensions.paddingXL,
                    child: IconButton(
                      icon: Icon(
                        Icons.close, 
                        color: AppColors.black, 
                        size: context.responsiveIconL,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }


  void _showPostBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.onPrimary.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    AppStrings.postJob,
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: AppDimensions.textL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildJobTile(
                image: AppAssets.job1,
                title: AppStrings.festivalGizzaJob,
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.pushNamed(
                    context,
                    AppRoutes.jobpost,
                    arguments: {'category': 'Festival Gizza'},
                  );
                },
              ),
              const Divider(color: AppColors.yellow, thickness: 1),
              const SizedBox(height: AppDimensions.spaceS),
              _buildJobTile(
                image: AppAssets.job2,
                title: AppStrings.festieHerosJob,
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.pushNamed(
                    context,
                    AppRoutes.jobpost,
                    arguments: {'category': 'Festie Heroes'},
                  );
                },
              ),
              const SizedBox(height: AppDimensions.paddingS),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobTile({
    required String image,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
         // color: Colors.white.withOpacity(0.1),
         // borderRadius: BorderRadius.circular(10),
         // border: Border.all(color: Colors.yellow, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            /// Left side (Image + Text)
            Expanded(
              child: Row(
                children: [

                  /// Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      image,
                      width: AppDimensions.imageM,
                      height: AppDimensions.imageM,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: AppDimensions.paddingS),

                  /// Text — flexible and ellipsis
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppDimensions.textL,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// Chevron icon (outside Expanded)
            const Icon(Icons.chevron_right, color: AppColors.yellow),
          ],
        ),
      ),
    );
  }
}

/// ---------------- SLIVER PERSISTENT HEADER DELEGATE ----------------
class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ProfileTabsDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 56.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

/// Safe CachedNetworkImage wrapper that suppresses 404 exceptions
/// Prevents app crashes when images are deleted from Firebase Storage
class _SafeCachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;

  const _SafeCachedNetworkImage({
    required this.imageUrl,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
  });

  @override
  State<_SafeCachedNetworkImage> createState() => _SafeCachedNetworkImageState();
}

class _SafeCachedNetworkImageState extends State<_SafeCachedNetworkImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // If we've already encountered an error, just show the error widget
    if (_hasError) {
      return widget.errorWidget;
    }

    // Wrap in Builder to catch errors at widget level
    return Builder(
      builder: (context) {
        // Use CachedNetworkImage but catch any exceptions
        try {
          return CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: widget.fit,
            placeholder: (context, url) => widget.placeholder,
            errorWidget: (context, url, error) {
              // Mark as error and show error widget
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasError) {
                  setState(() {
                    _hasError = true;
                  });
                }
              });
              return widget.errorWidget;
            },
            cacheKey: widget.imageUrl,
            maxWidthDiskCache: 1000,
            maxHeightDiskCache: 1000,
          );
        } catch (e) {
          // Catch any exceptions during build
          if (mounted && !_hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            });
          }
          return widget.errorWidget;
        }
      },
    );
  }
}
