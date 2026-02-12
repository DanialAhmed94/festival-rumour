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
import 'profile_viewmodel.dart';

/// Simplified profile view for viewing other users' profiles (Instagram-style)
/// Only shows back button and profile title - no other appbar buttons
class ViewUserProfileView extends BaseView<ProfileViewModel> {
  final String userId; // Required userId to view another user's profile
  
  const ViewUserProfileView({super.key, required this.userId});

  @override
  ProfileViewModel createViewModel() => ProfileViewModel();

  @override
  Widget buildView(BuildContext context, ProfileViewModel viewModel) {
    // Initialize and load user profile data on first build
    // Always reload when userId changes to ensure fresh data and follow status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!viewModel.isLoading) {
        viewModel.initialize(context, userId: userId);
      }
    });
    
    return WillPopScope(
      onWillPop: () async {
        // Simple back navigation - just pop
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: _buildSimpleTopBar(context),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    /// Profile Header (Collapsible)
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
                        background: _buildProfileHeader(context, viewModel),
                      ),
                    ),

                    /// Profile Tabs (Pinned)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileTabsDelegate(
                        child: Container(
                          height: AppDimensions.buttonHeightXL,
                          color: AppColors.white,
                          child: _profileTabs(context, viewModel),
                        ),
                      ),
                    ),

                    /// Dynamic Content
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppColors.white,
                        child: _buildDynamicContent(context, viewModel),
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

  /// Simplified top bar - only back button and profile title
  Widget _buildSimpleTopBar(BuildContext context) {
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
              Navigator.pop(context);
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

          SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: double.infinity,
      child: const Divider(
        color: AppColors.primary,
        thickness: 1,
        height: 1,
      ),
    );
  }

  /// Build profile header (reuse from ProfileView logic)
  Widget _buildProfileHeader(BuildContext context, ProfileViewModel viewModel) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        return Padding(
          padding: context.responsivePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              ClipOval(
                child: vm.userPhotoUrl != null && vm.userPhotoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: vm.userPhotoUrl!,
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
                        cacheKey: vm.userPhotoUrl,
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
                      vm.userDisplayName ?? 'User',
                      color: AppColors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.textL,
                    ),
                    SizedBox(height: AppDimensions.spaceS),
                    // Stats - Posts, Followers, Following
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildClickableStat(
                          context,
                          '${vm.postCount}',
                          AppStrings.posts,
                          null, // No navigation
                        ),
                        SizedBox(width: context.getConditionalSpacing()),
                        _buildClickableStat(
                          context,
                          '${vm.followersCount}',
                          AppStrings.followers,
                          () {
                            // Navigate to followers list
                            Navigator.pushNamed(
                              context,
                              AppRoutes.profileList,
                              arguments: {
                                'initialTab': 0, // 0 = Followers tab
                                'username': vm.userDisplayName ?? 'User',
                                'userId': userId,
                              },
                            );
                          },
                        ),
                        SizedBox(width: context.getConditionalSpacing()),
                        _buildClickableStat(
                          context,
                          '${vm.followingCount}',
                          AppStrings.following,
                          () {
                            // Navigate to following list
                            Navigator.pushNamed(
                              context,
                              AppRoutes.profileList,
                              arguments: {
                                'initialTab': 1, // 1 = Following tab
                                'username': vm.userDisplayName ?? 'User',
                                'userId': userId,
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    if (vm.userBio != null && vm.userBio!.isNotEmpty) ...[
                      SizedBox(height: AppDimensions.spaceM),
                      ResponsiveTextWidget(
                        vm.userBio!,
                        color: AppColors.black,
                        fontSize: AppDimensions.textM,
                      ),
                    ],
                    // Follow/Unfollow button (only show if viewing another user)
                    if (!vm.isViewingOwnProfile) ...[
                      SizedBox(height: AppDimensions.spaceM),
                      _buildFollowButton(context, vm),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build follow/unfollow button
  Widget _buildFollowButton(BuildContext context, ProfileViewModel viewModel) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        // Show loading indicator when loading initial follow status
        if (vm.isLoadingFollowStatus) {
          return SizedBox(
            height: AppDimensions.buttonHeightM,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
                ),
              ),
            ),
          );
        }

        // Show professional loading indicator during follow/unfollow operation
        final isUpdating = vm.isUpdatingFollowStatus;
        final isFollowing = vm.isFollowing;

        return SizedBox(
          height: AppDimensions.buttonHeightM,
          child: ElevatedButton(
            onPressed: isUpdating
                ? null // Disable button during operation
                : (isFollowing
                    ? () => vm.unfollowUser(context)
                    : () => vm.followUser(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing
                  ? AppColors.grey300
                  : AppColors.accent,
              foregroundColor: isFollowing
                  ? AppColors.black
                  : AppColors.black,
              disabledBackgroundColor: isFollowing
                  ? AppColors.grey300.withOpacity(0.5)
                  : AppColors.accent.withOpacity(0.7),
              disabledForegroundColor: isFollowing
                  ? AppColors.black.withOpacity(0.7)
                  : AppColors.black.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                side: BorderSide(
                  color: isFollowing
                      ? AppColors.black.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              elevation: isUpdating ? 0 : 2,
            ),
            child: isUpdating
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceS),
                      ResponsiveTextWidget(
                        isFollowing ? 'Unfollowing...' : 'Following...',
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimensions.textM,
                      ),
                    ],
                  )
                : ResponsiveTextWidget(
                    isFollowing ? 'Unfollow' : 'Follow',
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: AppDimensions.textM,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(BuildContext context, String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ResponsiveTextWidget(
          count,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
          fontSize: AppDimensions.textM,
          textAlign: TextAlign.center,
        ),
        ResponsiveTextWidget(
          label,
          color: AppColors.black.withOpacity(0.7),
          fontSize: AppDimensions.textS,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build clickable stat item (for Posts, Followers, Following)
  Widget _buildClickableStat(
    BuildContext context,
    String count,
    String label,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Make entire area tappable
      child: Container(
        // Responsive padding for larger tap area
        padding: EdgeInsets.symmetric(
          horizontal: context.isSmallScreen ? 6 : context.isMediumScreen ? 8 : 10,
          vertical: context.isSmallScreen ? 3 : context.isMediumScreen ? 4 : 5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ResponsiveTextWidget(
              count,
              color: AppColors.black,
              fontWeight: FontWeight.bold,
              fontSize: AppDimensions.textM,
              textAlign: TextAlign.center,
            ),
            ResponsiveTextWidget(
              label,
              color: AppColors.black.withOpacity(0.7),
              fontSize: AppDimensions.textS,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Profile tabs (Posts/Reels)
  Widget _profileTabs(BuildContext context, ProfileViewModel viewModel) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        return Row(
          children: [
            Expanded(
              child: _buildTab(
                context,
                'Posts',
                0,
                vm.selectedTab == 0,
                () => vm.setSelectedTab(0),
              ),
            ),
            Expanded(
              child: _buildTab(
                context,
                'Reels',
                1,
                vm.selectedTab == 1,
                () => vm.setSelectedTab(1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    int index,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: AppDimensions.buttonHeightXL,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: ResponsiveTextWidget(
          label,
          color: isSelected ? AppColors.accent : AppColors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: context.getConditionalSubFont(),
        ),
      ),
    );
  }

  /// Dynamic content based on selected tab
  Widget _buildDynamicContent(BuildContext context, ProfileViewModel viewModel) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(vm.selectedTab),
            child: vm.selectedTab == 0
                ? _profileGridWidget(context, viewModel, key: const ValueKey('posts'))
                : _profileReelsWidget(context, viewModel, key: const ValueKey('reels')),
          ),
        );
      },
    );
  }

  /// Profile grid widget (Posts)
  Widget _profileGridWidget(BuildContext context, ProfileViewModel viewModel, {Key? key}) {
    return Consumer<ProfileViewModel>(
      key: key,
      builder: (context, vm, child) {
        final images = vm.userImages;
        
        // Show loading indicator when initially loading
        if (images.isEmpty && vm.isLoading) {
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
        
        if (images.isEmpty && !vm.isLoading) {
          return Padding(
            padding: EdgeInsets.all(AppDimensions.spaceXL),
            child: Center(
              child: ResponsiveTextWidget(
                'there is nothing to show',
                color: AppColors.black,
                fontSize: context.getConditionalSubFont(),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.isLargeScreen ? 4 : context.isMediumScreen ? 3 : 3,
            mainAxisSpacing: context.isLargeScreen ? 4 : 2,
            crossAxisSpacing: context.isLargeScreen ? 4 : 2,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageUrl = images[index];
            final postInfo = index < vm.imagePostInfos.length
                ? vm.imagePostInfos[index]
                : null;
            
            return GestureDetector(
              onTap: () async {
                // Fetch only the tapped post with full details
                final postInfo = index < vm.imagePostInfos.length
                    ? vm.imagePostInfos[index]
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
                        content: const Text(
                          'Post information not available',
                          style: TextStyle(color: AppColors.black),
                        ),
                        backgroundColor: Colors.red.shade200,
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
                      color: AppColors.primary,
                    ),
                  ),
                );

                // Fetch only the tapped post with full details
                final fullPost = await vm.fetchSinglePost(postInfo);
                
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (fullPost != null && context.mounted) {
                  // Navigate to posts view with only the tapped post
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
                } else if (context.mounted) {
                  // Show error if post not found
                  if (kDebugMode) {
                    print('❌ Post not found or failed to load');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Failed to load post. Please try again.',
                        style: TextStyle(color: AppColors.black),
                      ),
                      backgroundColor: Colors.red.shade200,
                    ),
                  );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SafeCachedNetworkImage(
                    imageUrl: imageUrl,
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
        );
      },
    );
  }

  /// Profile reels widget (Videos)
  Widget _profileReelsWidget(BuildContext context, ProfileViewModel viewModel, {Key? key}) {
    return Consumer<ProfileViewModel>(
      key: key,
      builder: (context, vm, child) {
        final videos = vm.userVideos;
        
        // Show loading indicator when initially loading
        if (videos.isEmpty && vm.isLoading) {
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
        
        if (videos.isEmpty && !vm.isLoading) {
          return Padding(
            padding: EdgeInsets.all(AppDimensions.spaceXL),
            child: Center(
              child: ResponsiveTextWidget(
                'No reels yet',
                color: AppColors.black,
                fontSize: context.getConditionalSubFont(),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.isLargeScreen ? 4 : context.isMediumScreen ? 3 : 3,
            mainAxisSpacing: context.isLargeScreen ? 4 : 2,
            crossAxisSpacing: context.isLargeScreen ? 4 : 2,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final videoUrl = videos[index];
            final postInfo = index < vm.videoPostInfos.length
                ? vm.videoPostInfos[index]
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
                        content: const Text(
                          'Post information not available',
                          style: TextStyle(color: AppColors.black),
                        ),
                        backgroundColor: Colors.red.shade200,
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
                      color: AppColors.primary,
                    ),
                  ),
                );

                // Fetch only the tapped post with full details
                final fullPost = await vm.fetchSinglePost(postInfo);
                
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (fullPost != null && context.mounted) {
                  // Navigate to posts view with only the tapped post
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
                } else if (context.mounted) {
                  // Show error if post not found
                  if (kDebugMode) {
                    print('❌ Post not found or failed to load');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Failed to load post. Please try again.',
                        style: TextStyle(color: AppColors.black),
                      ),
                      backgroundColor: Colors.red.shade200,
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
        );
      },
    );
  }
}

/// Delegate for profile tabs
class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ProfileTabsDelegate({required this.child});

  @override
  double get minExtent => AppDimensions.buttonHeightXL;

  @override
  double get maxExtent => AppDimensions.buttonHeightXL;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_ProfileTabsDelegate oldDelegate) {
    return child != oldDelegate.child;
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
