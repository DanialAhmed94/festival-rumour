import 'dart:async';
import 'package:festival_rumour/ui/views/homeview/widgets/post_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'rumors_viewmodel.dart';

class RumorsView extends BaseView<RumorsViewModel> {
  const RumorsView({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  RumorsViewModel createViewModel() => RumorsViewModel();

  @override
  void onViewModelReady(RumorsViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, RumorsViewModel viewModel) {
    // Initialize with festival from provider
    // Check if collection name is already set (indicates initialization started)
    // This prevents multiple callbacks from being scheduled
    if (viewModel.festivalCollectionName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check inside callback to prevent race conditions
        if (viewModel.festivalCollectionName == null) {
          viewModel.initialize(context);
        }
      });
    }
    
    return _RumorsViewContent(viewModel: viewModel, onBack: onBack);
  }
}

/// Stateful widget to manage scroll controller and video visibility
class _RumorsViewContent extends StatefulWidget {
  final RumorsViewModel viewModel;
  final VoidCallback? onBack;

  const _RumorsViewContent({
    required this.viewModel,
    this.onBack,
  });

  @override
  State<_RumorsViewContent> createState() => _RumorsViewContentState();
}

class _RumorsViewContentState extends State<_RumorsViewContent> {
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
    return WillPopScope(
      onWillPop: () async {
        if (widget.onBack != null) {
          widget.onBack!();
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background Image - Full screen coverage
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
                    Expanded(
                      child: _buildFeedList(context, widget.viewModel),
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

  Widget _buildAppBar(BuildContext context, RumorsViewModel viewModel) {
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
          CustomBackButton(
            onTap: widget.onBack ??
                () {
                  Navigator.pop(context);
                },
          ),
          const SizedBox(width: AppDimensions.spaceM),
          // Title - Flexible to prevent overflow
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.rumors,
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
        ],
      ),
    );
  }

  Widget _buildFeedList(BuildContext context, RumorsViewModel viewModel) {
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
              collectionName: viewModel.festivalCollectionName, // Pass collection name for comments
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

  Widget _buildLoadMoreButton(BuildContext context, RumorsViewModel viewModel) {
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
}
