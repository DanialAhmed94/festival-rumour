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
  const ProfileView({super.key, this.onBack, this.onNavigateToSub});

  @override
  ProfileViewModel createViewModel() => ProfileViewModel();

  @override
  Widget buildView(BuildContext context, ProfileViewModel viewModel) {
    // Initialize and load user profile data on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!viewModel.isLoading && viewModel.postCount == 0 && viewModel.userImages.isEmpty) {
        viewModel.initialize(context);
      }
    });
    return WillPopScope(
      onWillPop: () async {
        print("🔙 Profile screen back button pressed");
        if (onBack != null) {
          onBack!(); // Navigate to home tab
          return false; // Prevent default back behavior
        }
        return true;
      },
      child: Scaffold(
        // floatingActionButton: _buildFloatingButton(context), // ✅ Add FAB here
        // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(

          children: [

            /// 🔹 Fullscreen background image
            Positioned.fill(
              child: Image.asset(
                AppAssets.bottomsheet,
                fit: BoxFit.cover,
              ),
            ),

            /// 🔹 Dark overlay for readability
            Positioned.fill(
              child: Container(color: AppColors.overlayBlack45),
            ),

            /// 🔹 Apply SafeArea to the WHOLE scrollable content
            SafeArea(
              child: CustomScrollView(
                slivers: [

                  /// 🔹 Top Bar as Sliver
                  SliverToBoxAdapter(
                    child: _profileTopBarWidget(context, viewModel),
                  ),
                  
                  /// 🔹 Divider after app bar
                  SliverToBoxAdapter(
                      child: _divider(),
                  ),
                  
                 // SizedBox(height: AppDimensions.spaceXS),

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
                      background: _buildProfileHeader(context, viewModel),
                    ),
                  ),


                  /// 🔹 Profile Tabs (Pinned)
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

                  /// 🔹 Dynamic Content
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
                child: viewModel.authService.userPhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: viewModel.authService.userPhotoUrl!,
                        width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                        height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                          height: context.isLargeScreen ? 110 : context.isMediumScreen ? 100 : 100,
                          color: AppColors.black.withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
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
                        // Enable offline caching
                        cacheKey: viewModel.authService.userPhotoUrl,
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
                      viewModel.authService.userDisplayName ?? AppStrings.name,
                    //  textType: TextType.title,
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.textL,
                    ),
                    SizedBox(height: AppDimensions.spaceS),
                    // Stats aligned with profile picture width
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      //crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<ProfileViewModel>(
                          builder: (context, vm, child) {
                            return _buildClickableStat(
                              context,
                              vm.postCount.toString(),
                              AppStrings.posts,
                              () {
                                if (onNavigateToSub != null) {
                                  onNavigateToSub!('posts');
                                } else {
                                  Navigator.pushNamed(context, AppRoutes.posts);
                                }
                              },
                            );
                          },
                        ),
                        SizedBox(width: context.getConditionalSpacing()),
                        _buildClickableStat(context, "5.4K", AppStrings.followers, () {
                          if (onNavigateToSub != null) {
                            onNavigateToSub!('followers');
                          } else {
                            Navigator.pushNamed(context, AppRoutes.profileList,
                                arguments: 0);
                          }
                        }),
                        SizedBox(width: context.getConditionalSpacing()),
                        _buildClickableStat(context, "340", AppStrings.following, () {
                          if (onNavigateToSub != null) {
                            onNavigateToSub!('following');
                          } else {
                            Navigator.pushNamed(context, AppRoutes.profileList,
                                arguments: 1);
                          }
                        }),
                        SizedBox(width: context.getConditionalSpacing()),
                        _buildClickableStat(context, "3", AppStrings.festivals, () {
                          if (onNavigateToSub != null) {
                            onNavigateToSub!('festivals');
                          } else {
                            Navigator.pushNamed(context, AppRoutes.profileList,
                                arguments: 2);
                          }
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: context.getConditionalSpacing()),

          /// Bio / Description below profile picture
          Consumer<ProfileViewModel>(
            builder: (context, vm, child) {
              final bioText = vm.userBio?.isNotEmpty == true 
                  ? vm.userBio! 
                  : AppStrings.bioDescription;
              return ResponsiveTextWidget(
                bioText,
                color: AppColors.white,
                fontSize: context.getConditionalFont(),
                textAlign: TextAlign.left,
              );
            },
          ),
        ],
      ),
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
    return Padding(
      padding: context.responsivePadding,
      child: Row(
        children: [
          /// Back button
          CustomBackButton(
            onTap: onBack ?? () {},
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

          /// Spacer to push icons to the right
          const Spacer(),

          /// Right-side icons
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
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
                  Navigator.pushNamed(context, AppRoutes.settings);
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
                    color: AppColors.primary,
                  ),
                  SizedBox(height: context.responsivePadding.top),
                  ResponsiveTextWidget(
                    'Loading posts...',
                    color: AppColors.white.withOpacity(0.7),
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
                'No posts yet',
                color: AppColors.white,
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
                          color: AppColors.primary,
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
                      if (onNavigateToSub != null) {
                        if (kDebugMode) {
                          print('🚀 Using onNavigateToSub callback');
                        }
                        onNavigateToSub!('posts');
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
                              color: AppColors.primary,
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
                          color: AppColors.white,
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
                    color: AppColors.primary,
                  ),
                  SizedBox(height: context.responsivePadding.top),
                  ResponsiveTextWidget(
                    'Loading reels...',
                    color: AppColors.white.withOpacity(0.7),
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
                color: AppColors.white,
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
                          color: AppColors.primary,
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
                      if (onNavigateToSub != null) {
                        onNavigateToSub!('posts');
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
                            color: AppColors.white,
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
                          color: AppColors.white,
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
                          color: AppColors.white,
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
     // mainAxisSize: MainAxisSize.max,
      children: [
        ResponsiveTextWidget(
          count,
          textType: TextType.title,
          color: AppColors.white,
          fontWeight: FontWeight.bold,
         // fontSize: AppDimensions.textM,
          fontSize: context.isHighResolutionPhone ? 16 : 12,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ResponsiveTextWidget(
          label,
          textType: TextType.caption,
          color: AppColors.white,
        //fontSize: AppDimensions.textXS,
          fontSize: context.isHighResolutionPhone ? 10 : 8,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildClickableStat(BuildContext context, String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
        child: _buildStat(context, count, label),
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
        color: selectedTab == index ? AppColors.accent : AppColors.white,
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
                        color: AppColors.white, 
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
                  Navigator.pushNamed(context, AppRoutes.jobpost);
                  // Navigate to add job screen if needed
                },
              ),
              const Divider(color: AppColors.yellow, thickness: 1),
              const SizedBox(height: AppDimensions.spaceS),
              _buildJobTile(
                image: AppAssets.job2,
                title: AppStrings.festieHerosJob,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.jobpost);
                  //d post screen if needed
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
