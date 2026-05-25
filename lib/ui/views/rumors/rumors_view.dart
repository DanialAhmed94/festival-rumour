import 'package:festival_rumour/ui/views/homeview/widgets/post_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../homeview/post_model.dart';
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
    if (kDebugMode) {
      print('📰 [RumorsView] buildView called, scheduling reinitializeIfFestivalChanged');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        print('📰 [RumorsView] postFrameCallback running, mounted=${context.mounted}');
      }
      if (context.mounted) {
        viewModel.reinitializeIfFestivalChanged(context);
      }
    });

    return _RumorsViewContent(viewModel: viewModel, onBack: onBack);
  }
}

/// Stateful content widget — holds scroll, keys, lifecycle, and route observers.
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

class _RumorsViewContentState extends State<_RumorsViewContent>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        RouteAware {
  final ScrollController _scrollController = ScrollController();

  /// Phase 3: keys by postId (not index) so inserts/reorders keep [GlobalKey] ↔ widget identity.
  final Map<String, GlobalKey<State<PostWidget>>> _postKeysByPostId = {};

  /// Phase 8: coalesced-frame prefetch guard (one addPostFrameCallback per scroll).
  bool _prefetchFrameScheduled = false;

  bool _routeAwareSubscribed = false;

  /// Phase 8: only trigger short-list top-up when posts.length actually changes.
  int _lastShortListTopUpForLength = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Phase 6: lifecycle observer
    _scrollController.addListener(_onScroll);
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

  // ── Phase 6: route-aware video pause ────────────────────────────────────────

  @override
  void didPushNext() => _pauseAllFeedVideos();

  @override
  void didPopNext() {
    // Playback resumes naturally when rows re-enter viewport via VisibilityDetector.
  }

  // ── Phase 6: lifecycle-aware video pause ────────────────────────────────────

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

  // ── Phase 6: adaptive cacheExtent ───────────────────────────────────────────

  double _feedListCacheExtent(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final h = mq?.size.height ?? context.screenHeight;
    if (h <= 1) return 2000;

    final shortest = mq?.size.shortestSide ??
        (context.screenWidth < context.screenHeight
            ? context.screenWidth
            : context.screenHeight);

    if (shortest < 600) return (h * 1.25).clamp(560.0, 1500.0);
    if (shortest < 900) return (h * 1.75).clamp(900.0, 2400.0);
    return (h * 2.2).clamp(1400.0, 3200.0);
  }

  // ── Phase 3: postId-keyed GlobalKeys ────────────────────────────────────────

  void _prunePostKeysForFeed(List<PostModel> feedPosts) {
    final active = <String>{};
    for (var i = 0; i < feedPosts.length; i++) {
      final p = feedPosts[i];
      active.add(
        (p.postId != null && p.postId!.isNotEmpty) ? p.postId! : '__idx_$i',
      );
    }
    _postKeysByPostId.removeWhere((id, _) => !active.contains(id));
  }

  GlobalKey<State<PostWidget>> _globalKeyForPost(PostModel post, int index) {
    final id = (post.postId != null && post.postId!.isNotEmpty)
        ? post.postId!
        : '__idx_$index';
    return _postKeysByPostId.putIfAbsent(id, () => GlobalKey<State<PostWidget>>());
  }

  // ── Phase 8: scroll prefetch ─────────────────────────────────────────────────

  void _onScroll() {
    _schedulePrefetchNearEnd(widget.viewModel);
  }

  void _schedulePrefetchNearEnd(RumorsViewModel viewModel) {
    if (_prefetchFrameScheduled) return;
    _prefetchFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchFrameScheduled = false;
      if (!mounted) return;
      _maybePrefetchMoreFeed(viewModel);
    });
  }

  /// Phase 8: Firestore pagination takes priority over detached buffer restore.
  void _prefetchOlderFeedContent(RumorsViewModel viewModel) {
    if (viewModel.hasMorePosts) {
      if (kDebugMode) {
        print(
          '[FestivalFeed] prefetch -> loadMore (detachedBuffer=${viewModel.detachedBufferLength})',
        );
      }
      viewModel.loadMorePosts();
    } else if (viewModel.hasDetachedOlderChunk) {
      if (kDebugMode) print('[FestivalFeed] prefetch -> restoreDetachedOlderPosts');
      viewModel.restoreDetachedOlderPosts();
    }
  }

  void _maybePrefetchMoreFeed(RumorsViewModel viewModel) {
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
      // Scroll controller unattached during tree churn — skip.
    }
  }

  void _topUpShortFeedIfNeeded(RumorsViewModel viewModel) {
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

  // ── Build ────────────────────────────────────────────────────────────────────

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
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: _buildAppBar(context, vm),
              ),
              Expanded(
                child: _buildFeedList(context, vm),
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
            onTap: widget.onBack ?? () => Navigator.pop(context),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 0),
              child: ResponsiveTextWidget(
                viewModel.festivalTitle != null &&
                        viewModel.festivalTitle!.isNotEmpty
                    ? '${viewModel.festivalTitle} Rumour'
                    : AppStrings.rumors,
                fontSize: context.getConditionalMainFont(),
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppColors.white,
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
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL),
            child: ResponsiveTextWidget(
              AppStrings.noRumorsToShow,
              textType: TextType.body,
              color: AppColors.black,
              fontSize: AppDimensions.textM,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Phase 8: footer slot exists when loading / exhausted / detached buffer present.
    final showFooter = viewModel.isLoadingMore ||
        !viewModel.hasMorePosts ||
        viewModel.hasDetachedOlderChunk;

    _prunePostKeysForFeed(viewModel.posts); // Phase 3

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXS),
      cacheExtent: _feedListCacheExtent(context), // Phase 6
      itemCount: viewModel.posts.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == viewModel.posts.length) {
          return _buildFeedFooter(context, viewModel);
        }

        final post = viewModel.posts[index];
        final postKey = _globalKeyForPost(post, index); // Phase 3
        final postBackgroundColor =
            (index % 2 == 0) ? AppColors.postPinkPurple50 : AppColors.postYellow50;
        final vdKey = (post.postId != null && post.postId!.isNotEmpty)
            ? post.postId!
            : '__idx_$index';

        return RepaintBoundary( // Phase 3
          child: VisibilityDetector( // Phase 3: per-item O(1) video pause
            key: Key('festival_feed_vd_$vdKey'),
            onVisibilityChanged: (VisibilityInfo info) {
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
                  collectionName: viewModel.festivalCollectionName,
                  onReactionSelected: (emotion) {
                    if (emotion.isEmpty) {
                      viewModel.removePostReaction(index);
                    } else {
                      viewModel.updatePostReaction(index, emotion);
                    }
                  },
                  onCommentsUpdated: () {
                    viewModel.refreshPostsAfterComment();
                  },
                  onDeletePost: (postId) {
                    viewModel.deletePost(postId, context);
                  },
                  onEditPost: (postModel) {
                    viewModel.navigateToEditPost(context, postModel);
                  },
                ),
                if (index != viewModel.posts.length - 1)
                  SizedBox(height: context.responsiveSpaceS),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Phase 8: spinner / detached hint / exhausted — replaces the old Load More button.
  Widget _buildFeedFooter(BuildContext context, RumorsViewModel viewModel) {
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
}
