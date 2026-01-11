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
        body: Stack(
          children: [
            /// Fullscreen background image
            Positioned.fill(
              child: Image.asset(
                AppAssets.bottomsheet,
                fit: BoxFit.cover,
              ),
            ),

            /// Dark overlay for readability
            Positioned.fill(
              child: Container(color: AppColors.overlayBlack45),
            ),

            /// Apply SafeArea to the WHOLE scrollable content
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  /// Top Bar as Sliver (Simplified - only back button and title)
                  SliverToBoxAdapter(
                    child: _buildSimpleTopBar(context),
                  ),
                  
                  /// Divider after app bar
                  SliverToBoxAdapter(
                    child: _divider(),
                  ),

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
                        color: AppColors.black.withOpacity(0.8),
                        child: _profileTabs(context, viewModel),
                      ),
                    ),
                  ),

                  /// Dynamic Content
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.black.withOpacity(0.8),
                      child: _buildDynamicContent(context, viewModel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Simplified top bar - only back button and profile title
  Widget _buildSimpleTopBar(BuildContext context) {
    return Padding(
      padding: context.responsivePadding,
      child: Row(
        children: [
          /// Back button
          CustomBackButton(
            onTap: () {
              Navigator.pop(context);
            },
          ),

          SizedBox(width: AppDimensions.spaceM),

          /// Profile title
          ResponsiveTextWidget(
            AppStrings.profile,
            textType: TextType.title,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: context.getConditionalMainFont(),
          ),
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
              CircleAvatar(
                radius: context.isLargeScreen ? 55 : context.isMediumScreen ? 50 : 50,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: vm.userPhotoUrl != null && vm.userPhotoUrl!.isNotEmpty
                    ? NetworkImage(vm.userPhotoUrl!)
                    : null,
                child: vm.userPhotoUrl == null || vm.userPhotoUrl!.isEmpty
                    ? Image.asset(
                        AppAssets.profile,
                        width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                        height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              SizedBox(width: context.getConditionalSpacing()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    ResponsiveTextWidget(
                      vm.userDisplayName ?? 'User',
                      color: AppColors.white,
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
                          () {
                            // Navigate to posts view
                            Navigator.pushNamed(context, AppRoutes.posts);
                          },
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
                        color: AppColors.white,
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
        if (vm.isLoadingFollowStatus) {
          return SizedBox(
            height: AppDimensions.buttonHeightM,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: AppDimensions.buttonHeightM,
          child: ElevatedButton(
            onPressed: vm.isFollowing
                ? () => vm.unfollowUser(context)
                : () => vm.followUser(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: vm.isFollowing
                  ? AppColors.black.withOpacity(0.5)
                  : AppColors.primary,
              foregroundColor: vm.isFollowing
                  ? AppColors.white
                  : AppColors.black,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                side: BorderSide(
                  color: vm.isFollowing
                      ? AppColors.white.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            child: ResponsiveTextWidget(
              vm.isFollowing ? 'Unfollow' : 'Follow',
              color: vm.isFollowing
                  ? AppColors.white
                  : AppColors.black,
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
      children: [
        ResponsiveTextWidget(
          count,
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: AppDimensions.textM,
        ),
        ResponsiveTextWidget(
          label,
          color: AppColors.white.withOpacity(0.7),
          fontSize: AppDimensions.textS,
        ),
      ],
    );
  }

  /// Build clickable stat item (for Posts, Followers, Following)
  Widget _buildClickableStat(
    BuildContext context,
    String count,
    String label,
    VoidCallback onTap,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveTextWidget(
              count,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: AppDimensions.textM,
            ),
            ResponsiveTextWidget(
              label,
              color: AppColors.white.withOpacity(0.7),
              fontSize: AppDimensions.textS,
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
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: ResponsiveTextWidget(
          label,
          color: isSelected ? AppColors.primary : AppColors.white.withOpacity(0.6),
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
        
        if (images.isEmpty && !vm.isLoading) {
          return Padding(
            padding: EdgeInsets.all(AppDimensions.spaceXL),
            child: Center(
              child: ResponsiveTextWidget(
                'No posts yet',
                color: AppColors.white.withOpacity(0.6),
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
              onTap: () {
                // Navigate to post detail if needed
                // For now, just show the image
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.black,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.black,
                      child: Icon(
                        Icons.error,
                        color: AppColors.white.withOpacity(0.5),
                      ),
                    );
                  },
                ),
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
        
        if (videos.isEmpty && !vm.isLoading) {
          return Padding(
            padding: EdgeInsets.all(AppDimensions.spaceXL),
            child: Center(
              child: ResponsiveTextWidget(
                'No reels yet',
                color: AppColors.white.withOpacity(0.6),
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
            
            return Container(
              decoration: BoxDecoration(
                color: AppColors.black,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video thumbnail would go here
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: AppColors.white.withOpacity(0.7),
                      size: 48,
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
