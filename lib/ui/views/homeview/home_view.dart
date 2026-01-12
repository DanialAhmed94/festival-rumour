import 'dart:async';
import 'package:festival_rumour/ui/views/homeview/widgets/post_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'home_viewmodel.dart';

class HomeView extends BaseView<HomeViewModel> {
  const HomeView({super.key});

  @override
  HomeViewModel createViewModel() => HomeViewModel();

  @override
  void onViewModelReady(HomeViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Start real-time posts listener
    viewModel.initialize();
  }

  @override
  Widget buildView(BuildContext context, HomeViewModel viewModel) {
    return _HomeViewContent(viewModel: viewModel);
  }
}

/// Stateful widget to manage scroll controller and video visibility
class _HomeViewContent extends StatefulWidget {
  final HomeViewModel viewModel;

  const _HomeViewContent({required this.viewModel});

  @override
  State<_HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<_HomeViewContent> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey<State<PostWidget>>> _postKeys = {};
  Timer? _scrollDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Debounce scroll events to avoid checking too frequently
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      // Check visibility and pause videos for posts not in viewport
      _checkVisibilityAndPauseVideos();
    });
  }

  void _checkVisibilityAndPauseVideos() {
    if (!_scrollController.hasClients) return;

    final viewportTop = _scrollController.offset;
    final viewportBottom = viewportTop + MediaQuery.of(context).size.height;

    for (var entry in _postKeys.entries) {
      final key = entry.value;
      final renderObject = key.currentContext?.findRenderObject();
      
      if (renderObject is RenderBox) {
        final position = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        final postTop = position.dy;
        final postBottom = postTop + size.height;

        // Check if post is visible in viewport (with some margin)
        final isVisible = postBottom > viewportTop - 100 && postTop < viewportBottom + 100;

        if (!isVisible) {
          // Pause videos for posts not visible using the static method
          final postState = key.currentState;
          PostWidget.pauseVideosIfNeeded(postState);
        }
      }
    }
  }

  GlobalKey<State<PostWidget>> _getOrCreateKey(int index) {
    if (!_postKeys.containsKey(index)) {
      _postKeys[index] = GlobalKey<State<PostWidget>>();
    }
    return _postKeys[index]!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
        children: [
          // Background Image - Full screen coverage (const to prevent rebuilds)
          Positioned.fill(
            child: Image.asset(
              AppAssets.bottomsheet,
              fit: BoxFit.cover,
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, widget.viewModel),
                // Conditional spacing based on screen size

                Expanded(
                  child: _buildFeedList(context, widget.viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFloatingButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 5), // Fine-tuned position
      child: FloatingActionButton(
        onPressed: () {
          //   _showPostBottomSheet(context);
        },
        backgroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        elevation: 8,
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, HomeViewModel viewModel) {
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
          // Back button to navigate to festival screen
          CustomBackButton(
            onTap: () => viewModel.navigateToFestival(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          // Logo with responsive sizing
          SvgPicture.asset(
            AppAssets.logo,
            color: AppColors.primary,
            width: context.getConditionalLogoSize(),
           // The getter 'responsivePaddingL' isn't defined for the type 'BuildContext'.
            
            height: context.getConditionalLogoSize(),
          ),
          
          // Title - Flexible to prevent overflow
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.lunaFest2025,
              fontSize: context.getConditionalMainFont(),
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Create Post Icon Button with responsive sizing
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: AppDimensions.iconXL,
            ),
            onPressed: () => viewModel.goToCreatePost(),
          ),

          // Job Icon Button with responsive sizing
          IconButton(
            icon: SvgPicture.asset(
              AppAssets.jobicon,
             width: AppDimensions.iconXL,
              height: AppDimensions.iconXL,
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.allJobs);
            },
          ),
          
          // Conditional spacing before Pro label
          
          // Pro Label - Aligned with search bar dropdown position
          GestureDetector(
            onTap: viewModel.goToSubscription,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: ResponsiveTextWidget(
                AppStrings.proLabel,
                textType: TextType.label,
                fontSize: AppDimensions.textS,
                color: AppColors.proLabelText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(BuildContext context, HomeViewModel viewModel) {
    if (viewModel.isLoading && viewModel.posts.isEmpty) {
      return const LoadingWidget(message: AppStrings.loadingPosts);
    }

    if (viewModel.posts.isEmpty && !viewModel.isLoading) {
      return Center(
        child: ResponsiveTextWidget(
          AppStrings.noPostsAvailable,
          textType: TextType.body,
          color: AppColors.primary,
          fontSize: AppDimensions.textM,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXS),
      cacheExtent: 500, // Cache 500px worth of items for smoother scrolling
      itemCount: viewModel.posts.length + 1, // Always add 1 for load more button or "no more posts" message
      itemBuilder: (context, index) {
        // Show load more button or "no more posts" message at the end
        if (index == viewModel.posts.length) {
          return _buildLoadMoreButton(context, viewModel);
        }

        final post = viewModel.posts[index];
        final postKey = _getOrCreateKey(index);
        
        return Column(
          key: ValueKey('post_column_${post.postId}'),
          children: [
            PostWidget(
              key: postKey,
              post: post,
              onReactionSelected: (emotion) {
                // Update reaction in ViewModel
                if (emotion.isEmpty) {
                  viewModel.removePostReaction(index);
                } else {
                  viewModel.updatePostReaction(index, emotion);
                }
              },
              onCommentsUpdated: () {
                // Refresh posts to update comment counts
                viewModel.refreshPostsAfterComment();
              },
              onDeletePost: (postId) {
                // Handle post deletion
                viewModel.deletePost(postId, context);
              },
            ),
            // Conditional spacing between posts
            if (index != viewModel.posts.length - 1)
              SizedBox(height: context.responsiveSpaceS),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreButton(BuildContext context, HomeViewModel viewModel) {
    // Show "No more posts" message if we've loaded all posts
    if (!viewModel.hasMorePosts && !viewModel.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: Center(
          child: ResponsiveTextWidget(
            'No more posts available',
            textType: TextType.body,
            color: AppColors.white,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Show loading indicator while loading more
    if (viewModel.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        ),
      );
    }

    // Show "Load More" button if there are more posts
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingL,
      ),
      child: Center(
        child: ElevatedButton(
          onPressed: viewModel.loadMorePosts,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.black,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXL,
              vertical: AppDimensions.paddingM,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            elevation: 4,
          ),
          child: ResponsiveTextWidget(
            'Load More',
            textType: TextType.body,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
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
          padding: context.getConditionalPadding(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
           // crossAxisAlignment: CrossAxisAlignment.,
            children: [
               Center(
                child: Padding(
                  padding: context.getConditionalPadding(),
                  child: ResponsiveTextWidget(
                    AppStrings.jobDetails,
                  //  textType: TextType.title,
                    color: AppColors.yellow,
                    fontSize: context.getConditionalFont(),
                  //  fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildJobTile(
                image: AppAssets.job1,
                title: AppStrings.festivalGizzaJob,
                context: context,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.festivalsJob);
                  // Navigate to add job screen if needed
                },
              ),
              const Divider(color: Colors.yellow, thickness: 1),
              // Conditional spacing between job tiles

              _buildJobTile(
                image: AppAssets.job2,
                title: AppStrings.festieHerosJob,
                context: context,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.festivalsJob);
                  // Navigate to another add post screen if needed
                },
              ),
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
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: context.responsiveSpaceXS),
        padding: EdgeInsets.symmetric(horizontal: context.responsivePaddingS.left, vertical: context.responsivePaddingS.top),
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
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    child: Image.asset(
                      image,
                      width: AppDimensions.imageM,
                      height: AppDimensions.imageM,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Conditional spacing between image and text

                  /// Text — flexible and ellipsis
                  Expanded(
                    child: ResponsiveTextWidget(
                      title,
                      textType: TextType.body,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.textL,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            /// Chevron icon (outside Expanded)
            const Icon(Icons.chevron_right, color: Colors.yellow),
          ],
        ),
      ),
    );
  }
}
