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
  
  @override
  bool get wantKeepAlive => true; // Keep alive when switching tabs
  
  @override
  void initState() {
    super.initState();
    _lastUserId = widget.userId;
    // Initialize only once or when userId changes
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
    // Refresh profile info when returning to own profile
    else if (widget.viewModel.isInitialized && widget.userId == null && oldWidget.userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.viewModel.refreshUserProfileInfo();
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return WillPopScope(
      onWillPop: () async {
        print("🔙 Profile screen back button pressed (userId: ${widget.userId}, fromRoute: ${widget.fromRoute})");
        if (widget.onBack != null) {
          widget.onBack!(); // Navigate to home tab
          return false; // Prevent default back behavior
        }
        // If we have a fromRoute and are viewing another user's profile, pop until we reach it
        if (widget.fromRoute != null && widget.userId != null) {
          Navigator.popUntil(context, (route) {
            final routeName = route.settings.name;
            final matches = routeName == widget.fromRoute;
            if (matches || route.isFirst) {
              return true; // Stop at matching route or first route
            }
            return false; // Continue popping
          });
          return false; // Prevent default back behavior
        }
        return true; // Default: allow normal back navigation
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
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    /// 🔹 Profile Header (Collapsible)
                    SliverAppBar(
                      expandedHeight: context.isSmallScreen
                          ? context.screenHeight * 0.25
                          : context.isMediumScreen
                          ? context.screenHeight * 0.24
                          : context.screenHeight * 0.24,
                      floating: false,
                      pinned: false,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildProfileHeader(context, widget.viewModel),
                      ),
                    ),

                    /// 🔹 Profile Tabs (Pinned)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileTabsDelegate(
                        child: Container(
                          height: AppDimensions.buttonHeightXL,
                          color: AppColors.white,
                          child: _profileTabs(context, widget.viewModel),
                        ),
                      ),
                    ),

                    /// 🔹 Dynamic Content
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppColors.white,
                        child: _buildDynamicContent(context, widget.viewModel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                            // Stats aligned with profile picture width
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Consumer<ProfileViewModel>(
                                  builder: (context, vm, child) {
                                    return _buildClickableStat(
                                      context,
                                      vm.postCount.toString(),
                                      AppStrings.posts,
                                      null, // No navigation
                                    );
                                  },
                                ),
                                SizedBox(width: context.getConditionalSpacing()),
                                Consumer<ProfileViewModel>(
                                  builder: (context, vm, child) {
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
                                  },
                                ),
                                SizedBox(width: context.getConditionalSpacing()),
                                Consumer<ProfileViewModel>(
                                  builder: (context, vm, child) {
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
                                  },
                                ),
                                SizedBox(width: context.getConditionalSpacing()),
                                Consumer<ProfileViewModel>(
                                  builder: (context, vm, child) {
                                    return _buildClickableStat(
                                      context,
                                      '${vm.favoriteFestivalsCount}',
                                      AppStrings.festivals,
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
                                  },
                                ),
                              ],
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

  /// ---------------- DYNAMIC CONTENT ---------------- 
  Widget _buildDynamicContent(BuildContext context, ProfileViewModel viewModel) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: vm.selectedTab == 0
              ? _profileGridWidget(context, key: const ValueKey('posts'))
              : _profileReelsWidget(context, key: const ValueKey('reels')),
        );
      },
    );
  }
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

          /// Profile title
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.profile,
              textType: TextType.title,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: context.getConditionalMainFont(),
              textAlign: TextAlign.center,
            ),
          ),

          /// Spacer to push icons to the right
          const Spacer(),

          /// Right-side icons
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
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
              IconButton(
                onPressed: () => _showPostBottomSheet(context),
                icon: Icon(Icons.add_box_outlined,
                    color: AppColors.white, 
                    size: AppDimensions.iconL),
                padding: context.responsivePadding,
                constraints: BoxConstraints(
                  minWidth: context.getConditionalIconSize(),
                  minHeight: context.getConditionalIconSize(),
                ),
              ),
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
              IconButton(
                onPressed: () {
                  // Navigate to settings immediately
                  Navigator.pushNamed(context, AppRoutes.settings).then((_) {
                    // When returning from settings, refresh profile info
                    // Use then() instead of await for non-blocking navigation
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted && widget.viewModel.isInitialized && widget.userId == null) {
                        // Reset refresh flags to allow refresh
                        widget.viewModel.resetRefreshFlags();
                        // Refresh profile info to show updated changes
                        widget.viewModel.refreshUserProfileInfo();
                      }
                    });
                  });
                },
                icon: Icon(Icons.settings,
                    color: AppColors.white, 
                    size: AppDimensions.iconL),
                padding: context.responsivePadding,
                constraints: BoxConstraints(
                  minWidth: context.getConditionalIconSize(),
                  minHeight: context.getConditionalIconSize(),
                ),
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

  /// ---------------- GRID / REELS / REPOSTS ---------------- 
  Widget _profileGridWidget(BuildContext context, {Key? key}) {
    return Consumer<ProfileViewModel>(
      key: key,
      builder: (context, viewModel, child) {
        final images = viewModel.userImages;
        final hasMore = viewModel.hasMoreImages;
        final isLoadingMore = viewModel.isLoadingMoreImages;

        // Show loading indicator when initially loading
        if (images.isEmpty && viewModel.isLoading) {
          return Padding(
            padding: EdgeInsets.all(context.responsivePadding.top * 2),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.black,
                  ),
                  SizedBox(height: context.responsivePadding.top),
                  ResponsiveTextWidget(
                    'Loading posts...',
                    color: AppColors.black.withOpacity(0.7),
                    fontSize: AppDimensions.textM,
                  ),
                ],
              ),
            ),
          );
        }

        // Show empty state when not loading and no images
        if (images.isEmpty && !viewModel.isLoading) {
          return Padding(
            padding: EdgeInsets.all(context.responsivePadding.top),
            child: Center(
              child: ResponsiveTextWidget(
                'there is nothing to show',
                color: AppColors.black,
                fontSize: AppDimensions.textM,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.isLargeScreen ? 4 : context.isMediumScreen ? 3 : 3,
                mainAxisSpacing: context.isLargeScreen ? 4 : 2,
                crossAxisSpacing: context.isLargeScreen ? 4 : 2,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final postInfo = index < viewModel.imagePostInfos.length
                    ? viewModel.imagePostInfos[index]
                    : null;
                
                return GestureDetector(
                  onTap: () async {
                    // Fetch only the tapped post with full details
                    final postInfo = index < viewModel.imagePostInfos.length
                        ? viewModel.imagePostInfos[index]
                        : null;
                    
                    if (kDebugMode) {
                      print('🖱️ User tapped on post at index $index');
                      if (postInfo != null) {
                        print('   Post ID: ${postInfo['postId']}');
                        print('   Collection: ${postInfo['collectionName']}');
                      } else {
                        print('   ⚠️ No post info available for this index');
                      }
                    }

                    if (postInfo == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Post information not available'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          color: AppColors.black,
                        ),
                      ),
                    );

                    // Fetch only the tapped post with full details
                    final fullPost = await viewModel.fetchSinglePost(postInfo);
                    
                    // Close loading dialog
                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    if (fullPost != null && context.mounted) {
                      // Navigate to posts view with only the tapped post
                      if (widget.onNavigateToSub != null) {
                        if (kDebugMode) {
                          print('🚀 Using onNavigateToSub callback');
                        }
                        widget.onNavigateToSub!('posts');
                      } else {
                        final collectionName = postInfo['collectionName'] as String?;
                        if (kDebugMode) {
                          print('🚀 Navigating to PostsView with single post');
                          print('   Collection: $collectionName');
                        }
                        Navigator.pushNamed(
                          context,
                          AppRoutes.posts,
                          arguments: {
                            'posts': [fullPost], // Single post in a list
                            'collectionName': collectionName,
                          },
                        );
                      }
                    } else if (context.mounted) {
                      // Show error if post not found
                      if (kDebugMode) {
                        print('❌ Post not found or failed to load');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load post. Please try again.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SafeCachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppColors.black.withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        errorWidget: Image.asset(
                          AppAssets.proback,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Show icon overlay if post has multiple media
                      if (postInfo != null && (postInfo['hasMultipleMedia'] as bool? ?? false))
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.collections,
                              color: AppColors.accent, // Yellow color
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            // Load More button
            if (hasMore)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.responsivePadding.top,
                  horizontal: context.responsivePadding.left,
                ),
                child: ElevatedButton(
                  onPressed: isLoadingMore
                      ? null
                      : () => viewModel.loadMoreImages(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsivePadding.left * 2,
                      vertical: context.responsivePadding.top,
                    ),
                  ),
                  child: isLoadingMore
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : ResponsiveTextWidget(
                          'Load More',
                          color: AppColors.black,
                          fontSize: AppDimensions.textM,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }


  Widget _profileReelsWidget(BuildContext context, {Key? key}) {
    return Consumer<ProfileViewModel>(
      key: key,
      builder: (context, viewModel, child) {
        final videos = viewModel.userVideos;
        final hasMore = viewModel.hasMoreVideos;
        final isLoadingMore = viewModel.isLoadingMoreVideos;

        // Show loading indicator when initially loading
        if (videos.isEmpty && viewModel.isLoading) {
          return Padding(
            padding: EdgeInsets.all(context.responsivePadding.top * 2),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.black,
                  ),
                  SizedBox(height: context.responsivePadding.top),
                  ResponsiveTextWidget(
                    'Loading reels...',
                    color: AppColors.black.withOpacity(0.7),
                    fontSize: AppDimensions.textM,
                  ),
                ],
              ),
            ),
          );
        }

        // Show empty state when not loading and no videos
        if (videos.isEmpty && !viewModel.isLoading) {
          return Padding(
            padding: EdgeInsets.all(context.responsivePadding.top),
            child: Center(
              child: ResponsiveTextWidget(
                'No reels yet',
                color: AppColors.black,
                fontSize: AppDimensions.textM,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.isLargeScreen ? 4 : context.isMediumScreen ? 3 : 3,
                mainAxisSpacing: context.isLargeScreen ? 4 : 2,
                crossAxisSpacing: context.isLargeScreen ? 4 : 2,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final postInfo = index < viewModel.videoPostInfos.length
                    ? viewModel.videoPostInfos[index]
                    : null;
                
                return GestureDetector(
                  onTap: () async {
                    // Fetch only the tapped video post with full details
                    if (kDebugMode) {
                      print('🖱️ User tapped on video at index $index');
                      if (postInfo != null) {
                        print('   Post ID: ${postInfo['postId']}');
                        print('   Collection: ${postInfo['collectionName']}');
                      } else {
                        print('   ⚠️ No post info available for this index');
                      }
                    }

                    if (postInfo == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Post information not available'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          color: AppColors.black,
                        ),
                      ),
                    );

                    // Fetch only the tapped post with full details
                    final fullPost = await viewModel.fetchSinglePost(postInfo);
                    
                    // Close loading dialog
                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    if (fullPost != null && context.mounted) {
                      // Navigate to posts view with only the tapped post
                      if (widget.onNavigateToSub != null) {
                        widget.onNavigateToSub!('posts');
                      } else {
                        final collectionName = postInfo['collectionName'] as String?;
                        if (kDebugMode) {
                          print('🚀 Navigating to PostsView with single post');
                          print('   Collection: $collectionName');
                        }
                        Navigator.pushNamed(
                          context,
                          AppRoutes.posts,
                          arguments: {
                            'posts': [fullPost], // Single post in a list
                            'collectionName': collectionName,
                          },
                        );
                      }
                    } else if (context.mounted) {
                      // Show error if post not found
                      if (kDebugMode) {
                        print('❌ Post not found or failed to load');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load post. Please try again.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video thumbnail placeholder
                      Container(
                        color: AppColors.black.withOpacity(0.5),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: AppColors.black,
                            size: context.responsiveIconXL,
                          ),
                        ),
                      ),
                      // Show icon overlay if post has multiple videos
                      if (postInfo != null && (postInfo['hasMultipleMedia'] as bool? ?? false))
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.collections,
                              color: AppColors.accent, // Yellow color
                              size: 16,
                            ),
                          ),
                        ),
                      // Video indicator
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Icon(
                          Icons.videocam,
                          color: AppColors.black,
                          size: context.responsiveIconM,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Load More button
            if (hasMore)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.responsivePadding.top,
                  horizontal: context.responsivePadding.left,
                ),
                child: ElevatedButton(
                  onPressed: isLoadingMore
                      ? null
                      : () => viewModel.loadMoreVideos(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsivePadding.left * 2,
                      vertical: context.responsivePadding.top,
                    ),
                  ),
                  child: isLoadingMore
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : ResponsiveTextWidget(
                          'Load More',
                          color: AppColors.black,
                          fontSize: AppDimensions.textM,
                        ),
                ),
              ),
          ],
        );
      },
    );
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
