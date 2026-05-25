import 'package:festival_rumour/ui/views/homeview/widgets/post_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import 'home_viewmodel.dart';
import 'post_model.dart';

class HomeView extends BaseView<HomeViewModel> {
  const HomeView({super.key});

  @override
  HomeViewModel createViewModel() => HomeViewModel();

  @override
  void onViewModelReady(HomeViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Initialization moved to _HomeViewContentState.initState to prevent re-initialization
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

class _HomeViewContentState extends State<_HomeViewContent>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        RouteAware {
  final ScrollController _scrollController = ScrollController();
  /// Keys by [PostModel.postId] so list inserts/reorders don't mix up [GlobalKey] ↔ widget identity.
  final Map<String, GlobalKey<State<PostWidget>>> _postKeysByPostId = {};
  bool _prefetchFrameScheduled = false;
  bool _isInitialized = false;
  bool _routeAwareSubscribed = false;
  /// Triggers short-list top-up when `posts.length` changes (not every frame).
  int _lastShortListTopUpForLength = -1;

  @override
  bool get wantKeepAlive => true; // Keep alive when switching tabs

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // Initialize only once
    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.viewModel.initialize();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAwareSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      locator<NavigationService>().routeObserver.subscribe(this, route);
      _routeAwareSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeAwareSubscribed) {
      locator<NavigationService>().routeObserver.unsubscribe(this);
      _routeAwareSubscribed = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _pauseAllFeedVideos();

  @override
  void didPopNext() {
    // Playback resumes only when rows become visible (VisibilityDetector / user).
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseAllFeedVideos();
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _pauseAllFeedVideos() {
    for (final key in _postKeysByPostId.values) {
      PostWidget.pauseVideosIfNeeded(key.currentState);
    }
  }

  /// Viewport-based cache: tighter on phones (less off-screen work / RAM) vs tablets.
  double _feedListCacheExtent(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final h = mq?.size.height ?? context.screenHeight;
    if (h <= 1) return 2000;

    final shortest =
        mq?.size.shortestSide ?? (context.screenWidth < context.screenHeight ? context.screenWidth : context.screenHeight);

    if (shortest < 600) {
      return (h * 1.25).clamp(560.0, 1500.0);
    }
    if (shortest < 900) {
      return (h * 1.75).clamp(900.0, 2400.0);
    }
    return (h * 2.2).clamp(1400.0, 3200.0);
  }

  void _onScroll() {
    _schedulePrefetchNearEnd(widget.viewModel);
  }

  /// One coalesced post-frame check (avoids timer races + reads scroll after layout).
  void _schedulePrefetchNearEnd(HomeViewModel viewModel) {
    if (_prefetchFrameScheduled) return;
    _prefetchFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchFrameScheduled = false;
      if (!mounted) return;
      _maybePrefetchMoreFeed(viewModel);
    });
  }

  /// Prefer loading the next Firestore page when available. Only use the in-memory
  /// detached buffer after pagination reports no more posts — otherwise a non-empty
  /// buffer always "wins" and [restoreDetachedOlderPosts] runs (e.g. with no room
  /// when the feed is at the memory cap), blocking [loadMorePosts].
  void _prefetchOlderFeedContent(HomeViewModel viewModel) {
    if (viewModel.hasMorePosts) {
      if (kDebugMode) {
        print(
          '[GlobalFeed] prefetch -> loadMore (detachedBuffer=${viewModel.detachedBufferLength})',
        );
      }
      viewModel.loadMorePosts();
    } else if (viewModel.hasDetachedOlderChunk) {
      if (kDebugMode) {
        print('[GlobalFeed] prefetch -> restoreDetachedOlderPosts');
      }
      viewModel.restoreDetachedOlderPosts();
    }
  }

  /// Fetch the next page when the user nears the bottom (before the last items).
  void _maybePrefetchMoreFeed(HomeViewModel viewModel) {
    if (!mounted || viewModel.isLoadingMore) return;
    if (!viewModel.hasMorePosts && !viewModel.hasDetachedOlderChunk) return;
    try {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasViewportDimension || !position.hasPixels) return;

      final viewportH = position.viewportDimension;
      final prefetchLead = viewportH * 1.5;
      if (position.maxScrollExtent <= 0) {
        _prefetchOlderFeedContent(viewModel);
        return;
      }
      if (position.pixels >= position.maxScrollExtent - prefetchLead) {
        _prefetchOlderFeedContent(viewModel);
      }
    } catch (_) {
      // ScrollController unattached / multiple positions during tree churn — skip this tick.
    }
  }

  /// When content is shorter than the viewport, scroll-based prefetch never runs; load until filled or exhausted.
  void _topUpShortFeedIfNeeded(HomeViewModel viewModel) {
    if (!mounted) return;
    if ((!viewModel.hasMorePosts && !viewModel.hasDetachedOlderChunk) ||
        viewModel.isLoadingMore ||
        viewModel.posts.isEmpty) return;
    try {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasViewportDimension) return;
      if (position.maxScrollExtent > 0) return;
      _prefetchOlderFeedContent(viewModel);
    } catch (_) {}
  }

  /// Drop stale [GlobalKey]s when the feed list changes (no longer O(N) scroll scan).
  void _prunePostKeysForFeed(List<PostModel> feedPosts) {
    final activeKeys = <String>{};
    for (var i = 0; i < feedPosts.length; i++) {
      final p = feedPosts[i];
      activeKeys.add(
        (p.postId != null && p.postId!.isNotEmpty) ? p.postId! : '__idx_$i',
      );
    }
    _postKeysByPostId.removeWhere((id, _) => !activeKeys.contains(id));
  }

  GlobalKey<State<PostWidget>> _globalKeyForPost(PostModel post, int index) {
    final id = (post.postId != null && post.postId!.isNotEmpty)
        ? post.postId!
        : '__idx_$index';
    return _postKeysByPostId.putIfAbsent(
      id,
      () => GlobalKey<State<PostWidget>>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final vm = widget.viewModel;
    final feedCount = vm.posts.length;
    if (feedCount > 0 && feedCount != _lastShortListTopUpForLength) {
      _lastShortListTopUpForLength = feedCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _topUpShortFeedIfNeeded(widget.viewModel);
      });
    }
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
          // Background (no image)
          const Positioned.fill(
            child: ColoredBox(color: AppColors.screenBackground),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFC2E95),
                  child: _buildAppBar(context, widget.viewModel),
                ),
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
        ],
      ),
    );
  }

  Widget _buildFeedList(BuildContext context, HomeViewModel viewModel) {
    if (viewModel.isLoading && viewModel.posts.isEmpty) {
      return SizedBox.expand(
        child: Center(
          child: LoadingWidget(
            message: AppStrings.loadingPosts,
            color: AppColors.black,
          ),
        ),
      );
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

    final showFooter = viewModel.isLoadingMore ||
        !viewModel.hasMorePosts ||
        viewModel.hasDetachedOlderChunk;

    _prunePostKeysForFeed(viewModel.posts);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXS),
      // Build/decode rows ahead of the viewport (Phase 6: adaptive by breakpoint).
      cacheExtent: _feedListCacheExtent(context),
      itemCount: viewModel.posts.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == viewModel.posts.length) {
          return _buildFeedFooter(context, viewModel);
        }

        final post = viewModel.posts[index];
        final postKey = _globalKeyForPost(post, index);
        final postBackgroundColor =
            (index % 2 == 0) ? AppColors.postPinkPurple50 : AppColors.postYellow50;
        final vdKey = (post.postId != null && post.postId!.isNotEmpty)
            ? post.postId!
            : '__idx_$index';

        return RepaintBoundary(
          child: VisibilityDetector(
            key: Key('globe_feed_vd_$vdKey'),
            onVisibilityChanged: (VisibilityInfo info) {
              // Pause when almost off-screen; avoids O(N) scroll work (Phase 3).
              if (info.visibleFraction < 0.12) {
                PostWidget.pauseVideosIfNeeded(postKey.currentState);
              }
            },
            child: Column(
              key: ValueKey('post_column_${post.postId}'),
              children: [
              PostWidget(
                key: postKey,
                post: post,
                backgroundColor: postBackgroundColor,
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
                  viewModel.deletePost(postId, context);
                },
                onEditPost: (postModel) {
                  viewModel.navigateToEditPost(context, postModel);
                },
              ),
              // Conditional spacing between posts
              if (index != viewModel.posts.length - 1)
                SizedBox(height: context.responsiveSpaceS),
            ],
          ),
          ),
        );
      },
    );
  }

  /// End-of-feed: spinner while fetching next page, or a short "caught up" line when done.
  Widget _buildFeedFooter(BuildContext context, HomeViewModel viewModel) {
    if (viewModel.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: const Center(
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (viewModel.hasDetachedOlderChunk && !viewModel.hasMorePosts) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: Center(
          child: ResponsiveTextWidget(
            'Scroll down for earlier posts',
            textType: TextType.body,
            color: AppColors.black,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!viewModel.hasMorePosts) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: Center(
          child: ResponsiveTextWidget(
            'No more posts available',
            textType: TextType.body,
            color: AppColors.black,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
