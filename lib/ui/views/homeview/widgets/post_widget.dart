import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../post_model.dart';
import 'feed_video_init_budget.dart';
import 'feed_profile_avatar.dart';
import 'post_media_fullscreen_page.dart';
import 'post_widget_list_header.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final Color backgroundColor;
  final Function(String)? onReactionSelected; // Callback when user selects a reaction
  final VoidCallback? onCommentsUpdated; // Callback when comments are updated
  final Function(String)? onDeletePost; // Callback when user deletes the post
  final Function(PostModel)? onEditPost; // Callback when user edits the post
  final String? collectionName; // Optional collection name (for festival-specific posts)

  PostWidget({
    super.key,
    required this.post,
    required this.backgroundColor,
    this.onReactionSelected,
    this.onCommentsUpdated,
    this.onDeletePost,
    this.onEditPost,
    this.collectionName,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
  
  /// Static method to pause videos in a PostWidget state
  static void pauseVideosIfNeeded(State<PostWidget>? state) {
    if (state is _PostWidgetState) {
      state.pauseAllVideos();
    }
  }
}

class _PostWidgetState extends State<PostWidget> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = locator<AuthService>();
  bool _showReactions = false;
  bool _isContentExpanded = false;
  String? _selectedReaction; // stores emoji / icon selected
  Color _reactionColor = AppColors.white; // default Like color
  PageController? _pageController;
  int _currentPage = 0;

  /// Lines shown before "Show more" appears.
  static const int _kCollapsedMaxLines = 4;
  /// Check if the current user owns this post
  bool get _isOwnPost {
    final currentUser = _authService.currentUser;
    return currentUser != null && widget.post.userId == currentUser.uid;
  }
  
  // Video controllers for each media item (only initialize when needed)
  Map<int, VideoPlayerController?> _videoControllers = {};
  Map<int, ChewieController?> _chewieControllers = {};
  Map<int, bool> _isVideoInitialized = {};
  Map<int, bool> _isInitializingVideo = {};

  @override
  bool get wantKeepAlive {
    // Only keep alive if there are initialized videos to preserve playback state
    // This prevents memory leaks when scrolling through many posts
    return _isVideoInitialized.values.any((initialized) => initialized);
  }

  @override
  void initState() {
    super.initState();
    final mediaCount = widget.post.allMediaPaths.length;
    if (mediaCount > 1) {
      _pageController = PageController();
    }
    
    // Initialize selected reaction from post model
    _selectedReaction = widget.post.userReaction;
    _reactionColor = (_selectedReaction == AppStrings.emojiLike) 
        ? AppColors.reactionLike 
        : AppColors.black;
  }

  @override
  void didUpdateWidget(PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update reaction if post model changed
    if (widget.post.userReaction != oldWidget.post.userReaction) {
      setState(() {
        _selectedReaction = widget.post.userReaction;
        _reactionColor = (_selectedReaction == AppStrings.emojiLike) 
            ? AppColors.reactionLike 
            : AppColors.black;
      });
    }
  }

  void _initializeVideo(int index) async {
    if ((_isVideoInitialized[index] ?? false) || (_isInitializingVideo[index] ?? false)) return;

    final mediaPaths = widget.post.allMediaPaths;
    if (index >= mediaPaths.length) return;

    final videoPath = mediaPaths[index];
    final usesNetworkBudget = _isNetworkUrl(videoPath);

    if (usesNetworkBudget) {
      await FeedVideoInitBudget.acquire();
    }
    if (!mounted) {
      if (usesNetworkBudget) FeedVideoInitBudget.release();
      return;
    }

    setState(() {
      _isInitializingVideo[index] = true;
    });

    try {
      if (usesNetworkBudget) {
        _videoControllers[index] = VideoPlayerController.network(videoPath);
      } else {
        _videoControllers[index] = VideoPlayerController.file(File(videoPath));
      }

      await _videoControllers[index]!.initialize();

      if (mounted) {
        _chewieControllers[index] = ChewieController(
          videoPlayerController: _videoControllers[index]!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoControllers[index]!.value.aspectRatio,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
            backgroundColor: AppColors.onSurface.withOpacity(0.3),
            bufferedColor: AppColors.onSurface.withOpacity(0.5),
          ),
        );
        setState(() {
          _isVideoInitialized[index] = true;
          _isInitializingVideo[index] = false;
        });
      }
    } catch (error) {
      debugPrint('Error initializing video at index $index: $error');
      if (mounted) {
        setState(() {
          _isInitializingVideo[index] = false;
        });
      }
    } finally {
      if (usesNetworkBudget) {
        FeedVideoInitBudget.release();
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    
    // Pause videos that are not on the current page
    for (int i = 0; i < widget.post.allMediaPaths.length; i++) {
      if (i != index) {
        // Pause videos on other pages
        if (_chewieControllers[i] != null && 
            _chewieControllers[i]!.videoPlayerController.value.isPlaying) {
          _chewieControllers[i]!.pause();
        }
      }
    }
    
    // Dispose videos that are not currently visible (not current or adjacent pages)
    // This prevents memory buildup when swiping through carousel
    for (int i = 0; i < widget.post.allMediaPaths.length; i++) {
      if (i != index && i != index - 1 && i != index + 1) {
        // Dispose video controllers for pages far from current
        _disposeVideoAtIndex(i);
      }
    }
    
    // Initialize video if current page is a video
    if (widget.post.isVideoAtIndex(index)) {
      _initializeVideo(index);
    }
  }

  /// Dispose video controllers at a specific index to free memory
  void _disposeVideoAtIndex(int index) {
    _chewieControllers[index]?.dispose();
    _videoControllers[index]?.dispose();
    _chewieControllers.remove(index);
    _videoControllers.remove(index);
    _isVideoInitialized[index] = false;
    _isInitializingVideo[index] = false;
  }

  void _toggleReactions() {
    setState(() {
      _showReactions = !_showReactions;
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    // Dispose all video controllers to prevent memory leaks
    for (var entry in _chewieControllers.entries) {
      entry.value?.dispose();
    }
    for (var entry in _videoControllers.entries) {
      entry.value?.dispose();
    }
    _chewieControllers.clear();
    _videoControllers.clear();
    _isVideoInitialized.clear();
    _isInitializingVideo.clear();
    super.dispose();
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.screenBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          title: const Text(
            'Delete Post',
            style: TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(
              color: AppColors.black54,
              height: 1.3,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (widget.post.postId != null && widget.onDeletePost != null) {
                  widget.onDeletePost!(widget.post.postId!);
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Pause all videos in this post widget
  void pauseAllVideos() {
    for (var entry in _chewieControllers.entries) {
      if (entry.value != null && entry.value!.videoPlayerController.value.isPlaying) {
        entry.value!.pause();
        if (kDebugMode) {
          print('⏸️ Paused video at index ${entry.key} for post ${widget.post.postId}');
        }
      }
    }
  }

  /// Check if any video is currently playing
  bool get hasPlayingVideo {
    return _chewieControllers.values.any(
      (controller) =>
          controller != null && controller.videoPlayerController.value.isPlaying,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final post = widget.post;
    final bool hasMedia = post.hasMedia;
    final bool hasUrl = post.postUrl != null && post.postUrl!.isNotEmpty;
    final bool hasPreviewData = (post.linkPreviewImageUrl != null && post.linkPreviewImageUrl!.isNotEmpty) ||
        (post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty);
    final bool hasLinkPreviewAsMedia = !hasMedia && hasUrl && hasPreviewData;
    final bool hasUrlOnlyNoPreview = !hasMedia && hasUrl && !hasPreviewData;
    final bool showLargeArea = hasMedia || hasLinkPreviewAsMedia;
    final String contentTrimmed = post.content.trim();
    final bool contentIsJustUrl = hasUrlOnlyNoPreview &&
        post.postUrl != null &&
        contentTrimmed == post.postUrl!.trim();

    // Height for the media section (image / video / link-preview thumbnail).
    // Same proportion as the old fixed container height so media looks identical.
    final double mediaHeight = context.isLargeScreen
        ? MediaQuery.sizeOf(context).height * 0.6
        : context.isMediumScreen
            ? MediaQuery.sizeOf(context).height * 0.5
            : MediaQuery.sizeOf(context).height * 0.6;

    // When text is collapsed (or there is no media), keep the original
    // fixed-height layout so the card looks exactly as before.
    // When text is expanded AND there is media, switch to a dynamic-height
    // layout: the container grows freely and the media gets a defined
    // SizedBox height so it stays full-size below the expanded text.
    final bool useFixedLayout = showLargeArea && !_isContentExpanded;

    return Container(
      height: useFixedLayout ? mediaHeight : null,
      constraints: useFixedLayout
          ? null
          : BoxConstraints(minHeight: showLargeArea ? mediaHeight : 200),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.postBorderRadius),
          topRight: Radius.circular(AppDimensions.postBorderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.postShadow.withOpacity(AppDimensions.postBoxShadowOpacity),
            blurRadius: AppDimensions.postBoxShadowBlur,
            offset: const Offset(0, AppDimensions.postBoxShadowOffsetY),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: useFixedLayout ? MainAxisSize.max : MainAxisSize.min,
        children: [
//          Header
          PostWidgetListHeader(
            post: post,
            leading: FeedProfileAvatar(
              key: ValueKey<String>(
                'avatar_${post.userId ?? ''}_${post.userPhotoUrl ?? ''}',
              ),
              userId: post.userId ?? '',
              imageUrl: post.userPhotoUrl,
            ),
            showOwnerMenu: _isOwnPost,
            onEditSelected:
                widget.onEditPost != null ? () => widget.onEditPost!(widget.post) : null,
            onDeleteSelected: () => _showDeleteConfirmation(context),
          ),

          // Post Content: hide when only URL is posted and no preview (avoid showing URL twice)
          if (contentTrimmed.isNotEmpty && !contentIsJustUrl)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.postContentPaddingHorizontal,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildExpandableContent(context, post.content),
              ),
            ),
          // URL in description: when post has (URL + media) OR (URL but no preview data)
          if (hasUrl && (hasMedia || hasUrlOnlyNoPreview)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.postContentPaddingHorizontal,
              ),
              child: _buildCompactLinkRow(post),
            ),
          ],
          const SizedBox(height: AppDimensions.reactionIconSpacing),

          if (hasMedia) ...[
            // useFixedLayout: Expanded fills remaining space in fixed-height card.
            // !useFixedLayout (text expanded): SizedBox keeps media at full height
            // so both the full text above and the full media are visible.
            _mediaWrapper(
              useFixedLayout: useFixedLayout,
              height: mediaHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.postBorderRadius),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: post.hasMultipleMedia
                          ? _buildMediaCarousel()
                          : _buildSingleMedia(),
                    ),
                    Positioned(
                      bottom: 100,
                      right: 12,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleReactions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              ),
                              child: Row(
                                children: [
                                  _selectedReaction == null
                                      ? Icon(Icons.thumb_up,
                                          color: AppColors.white,
                                          size: context.isLargeScreen ? 24 : context.isMediumScreen ? 22 : 20)
                                      : Text(
                                          _selectedReaction!,
                                          style: TextStyle(
                                            fontSize: AppDimensions.textL,
                                            color: _reactionColor,
                                          ),
                                        ),
                                  const SizedBox(width: AppDimensions.spaceXS),
                                  Text(
                                    "${post.totalReactions > 0 ? post.totalReactions : post.likes}",
                                    style: const TextStyle(color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceS),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _openComments(context, post),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    color: AppColors.white,
                                    size: context.isLargeScreen ? 22 : context.isMediumScreen ? 20 : 18,
                                  ),
                                  const SizedBox(width: AppDimensions.spaceXS),
                                  Text(
                                    "${post.comments}",
                                    style: const TextStyle(color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showReactions)
                      Positioned(
                        bottom: 176,
                        right: 0,
                        child: _buildReactionsPopup(),
                      ),
                  ],
                ),
              ),
            ),
          ] else if (hasLinkPreviewAsMedia) ...[
            _mediaWrapper(
              useFixedLayout: useFixedLayout,
              height: mediaHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.postBorderRadius),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildLinkPreviewThumbnailAsMedia(post),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildLinkPreviewOverlayBar(post),
                    ),
                    Positioned(
                      bottom: 72,
                      right: 12,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleReactions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              ),
                              child: Row(
                                children: [
                                  _selectedReaction == null
                                      ? Icon(Icons.thumb_up,
                                          color: AppColors.white,
                                          size: context.isLargeScreen ? 24 : context.isMediumScreen ? 22 : 20)
                                      : Text(
                                          _selectedReaction!,
                                          style: TextStyle(
                                            fontSize: AppDimensions.textL,
                                            color: _reactionColor,
                                          ),
                                        ),
                                  const SizedBox(width: AppDimensions.spaceXS),
                                  Text(
                                    "${post.totalReactions > 0 ? post.totalReactions : post.likes}",
                                    style: const TextStyle(color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceS),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _openComments(context, post),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    color: AppColors.white,
                                    size: context.isLargeScreen ? 22 : context.isMediumScreen ? 20 : 18,
                                  ),
                                  const SizedBox(width: AppDimensions.spaceXS),
                                  Text(
                                    "${post.comments}",
                                    style: const TextStyle(color: AppColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showReactions)
                      Positioned(
                        bottom: 148,
                        right: 0,
                        child: _buildReactionsPopup(),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppDimensions.paddingL),
            _buildNoMediaLikeCommentRow(context, post),

          ],

          const SizedBox(height: AppDimensions.paddingL),

          if (hasMedia || hasLinkPreviewAsMedia) ...[
            Container(
              width: double.infinity,
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite,
                      color: AppColors.reactionLike,
                      size: context.isLargeScreen ? AppDimensions.reactionIconSize + 4 : context.isMediumScreen ? AppDimensions.reactionIconSize + 2 : AppDimensions.reactionIconSize),
                  const SizedBox(width: AppDimensions.reactionIconSpacing),
                  Icon(Icons.thumb_up,
                      color: AppColors.reactionLove,
                      size: context.isLargeScreen ? AppDimensions.reactionIconSize + 4 : context.isMediumScreen ? AppDimensions.reactionIconSize + 2 : AppDimensions.reactionIconSize),
                  const SizedBox(width: AppDimensions.reactionIconSpacing),
                  Text("${post.totalReactions > 0 ? post.totalReactions : post.likes}", style: const TextStyle(color: AppColors.white)),
                  SizedBox(width: context.isLargeScreen
                      ? context.screenWidth * 0.4
                      : context.isMediumScreen
                          ? context.screenWidth * 0.35
                          : context.screenWidth * 0.3),
                  InkWell(
                    onTap: () => _openComments(context, widget.post),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${post.comments} ", style: const TextStyle(color: AppColors.white)),
                        const SizedBox(width: AppDimensions.reactionIconSpacing),
                        Text("${AppStrings.comments} ", style: const TextStyle(color: AppColors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.reactionIconSpacing),
          ],
        ],
      ));
  }

  /// Wraps media in [Expanded] when the card uses a fixed-height layout
  /// (text collapsed), or in a [SizedBox] with a defined height when the
  /// card is dynamic (text expanded) — keeps media full-size in both states.
  Widget _mediaWrapper({
    required bool useFixedLayout,
    required double height,
    required Widget child,
  }) {
    if (useFixedLayout) return Expanded(child: child);
    return SizedBox(height: height, child: child);
  }

  /// Instagram/Facebook-style expandable post text.
  ///
  /// Uses [LayoutBuilder] + [TextPainter] to detect real overflow at
  /// [_kCollapsedMaxLines] without any extra network/IO work. When the text
  /// fits in 4 lines it renders as a plain [Text] with zero overhead.
  ///
  /// Overflow is handled at the **card level** (see [useFixedLayout] in
  /// [build]): when expanded the card switches to a dynamic height so both
  /// the full text and the full media are visible — no cropping of either.
  Widget _buildExpandableContent(BuildContext context, String content) {
    const TextStyle contentStyle = TextStyle(color: AppColors.black, height: 1.4);
    const TextStyle toggleStyle = TextStyle(
      color: AppColors.black,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: content, style: contentStyle),
          maxLines: _kCollapsedMaxLines,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(ctx),
        )..layout(maxWidth: constraints.maxWidth);

        // Short text — render as-is, no toggle needed.
        if (!tp.didExceedMaxLines) {
          return Text(content, style: contentStyle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: contentStyle,
              maxLines: _isContentExpanded ? null : _kCollapsedMaxLines,
              overflow: _isContentExpanded ? null : TextOverflow.clip,
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => setState(() => _isContentExpanded = !_isContentExpanded),
              child: Text(
                _isContentExpanded ? 'Show less' : 'Show more',
                style: toggleStyle,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReactionsPopup() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmojiReaction(AppStrings.emojiLike, AppStrings.like, AppColors.reactionLike),
          _buildEmojiReaction(AppStrings.emojiLove, AppStrings.love),
          _buildEmojiReaction(AppStrings.emojiHaha, AppStrings.haha),
          _buildEmojiReaction(AppStrings.emojiWow, AppStrings.wow),
          _buildEmojiReaction(AppStrings.emojiSad, AppStrings.sad),
          _buildEmojiReaction(AppStrings.emojiAngry, AppStrings.angry),
        ],
      ),
    );
  }

  Future<void> _openComments(BuildContext context, PostModel post) async {
    final effectiveCollection = post.sourceCollection ?? widget.collectionName;
    if (kDebugMode) {
      print('💬 [PostWidget] _openComments: postId=${post.postId}, '
          'post.sourceCollection=${post.sourceCollection}, '
          'widget.collectionName=${widget.collectionName}, '
          'effectiveCollection=$effectiveCollection');
    }
    final arguments = effectiveCollection != null
        ? {'post': post, 'collectionName': effectiveCollection}
        : post;
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.comments,
      arguments: arguments,
    );
    if (result == true && widget.onCommentsUpdated != null) {
      widget.onCommentsUpdated!();
    }
  }

  Future<void> _launchPostUrl(String? urlString) async {
    if (urlString == null || urlString.trim().isEmpty) return;
    String s = urlString.trim();
    if (!s.contains(RegExp(r'^https?://', caseSensitive: false))) {
      s = 'https://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// Compact link row for description: when URL+media or when URL but no preview available.
  Widget _buildCompactLinkRow(PostModel post) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchPostUrl(post.postUrl),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.onSurfaceVariant.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.black.withOpacity(0.06), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.link, size: 20, color: AppColors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post.postUrl!,
                  style: TextStyle(
                    color: AppColors.black54,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Open now',
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: AppColors.black),
            ],
          ),
        ),
      ),
    );
  }

  /// Thumbnail filling the post area (like media) when post has URL but no media.
  Widget _buildLinkPreviewThumbnailAsMedia(PostModel post) {
    final hasImage = post.linkPreviewImageUrl != null && post.linkPreviewImageUrl!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchPostUrl(post.postUrl),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: post.linkPreviewImageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor: AppColors.grey300,
                  highlightColor: AppColors.grey100,
                  child: Container(
                    color: AppColors.grey300,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                errorWidget: (_, __, ___) => _buildLinkPreviewThumbnailPlaceholder(),
              )
            : _buildLinkPreviewThumbnailPlaceholder(),
      ),
    );
  }

  Widget _buildLinkPreviewThumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.onSurfaceVariant.withOpacity(0.08),
            AppColors.onSurfaceVariant.withOpacity(0.14),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, color: AppColors.black45, size: 40),
            const SizedBox(height: 8),
            Text(
              'Link preview',
              style: TextStyle(
                color: AppColors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom overlay bar on the link preview thumbnail: gradient + title/URL + Open now. Professional one-card preview.
  Widget _buildLinkPreviewOverlayBar(PostModel post) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchPostUrl(post.postUrl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.black.withOpacity(0.5),
                AppColors.black.withOpacity(0.82),
                AppColors.black.withOpacity(0.94),
              ],
              stops: const [0.0, 0.4, 0.75, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty)
                        Text(
                          post.linkPreviewTitle!,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (post.postUrl != null && post.postUrl!.isNotEmpty) ...[
                        if (post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty)
                          const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 12,
                              color: AppColors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                post.postUrl!,
                                style: TextStyle(
                                  color: AppColors.white.withOpacity(0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _launchPostUrl(post.postUrl),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Open now',
                            style: TextStyle(
                              color: AppColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.open_in_new, size: 16, color: AppColors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Row below the thumbnail: URL text + Open now button (light grey bar). Used when overlay is not.
  Widget _buildLinkPreviewUrlAndButtonRow(PostModel post) {
    const double radius = 12.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.black.withOpacity(0.08), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty)
                  Text(
                    post.linkPreviewTitle!,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (post.postUrl != null && post.postUrl!.isNotEmpty) ...[
                  if (post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    post.postUrl!,
                    style: TextStyle(
                      color: AppColors.black54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchPostUrl(post.postUrl),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Open now',
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Link preview card: vertical thumbnail (left), title + URL, "Open now" button (right). Used when not using thumbnail-as-media layout.
  Widget _buildLinkPreview(BuildContext context, PostModel post) {
    const double radius = 12.0;
    const double thumbnailWidth = 90.0;
    const double thumbnailHeight = 112.0;
    const double cardHeight = 112.0;

    final hasImage = post.linkPreviewImageUrl != null && post.linkPreviewImageUrl!.isNotEmpty;
    final hasTitle = post.linkPreviewTitle != null && post.linkPreviewTitle!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchPostUrl(post.postUrl),
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.black.withOpacity(0.08), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: post.linkPreviewImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppColors.grey300,
                            highlightColor: AppColors.grey100,
                            child: Container(
                              color: AppColors.grey300,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        errorWidget: (_, __, ___) => _buildLinkPreviewThumbnailPlaceholder(),
                      )
                      : _buildLinkPreviewThumbnailPlaceholder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasTitle)
                          Text(
                            post.linkPreviewTitle!,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (post.postUrl != null && post.postUrl!.isNotEmpty) ...[
                          if (hasTitle) const SizedBox(height: 4),
                          Text(
                            post.postUrl!,
                            style: TextStyle(
                              color: AppColors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _launchPostUrl(post.postUrl),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E8E8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Open now',
                            style: TextStyle(
                              color: AppColors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildNoMediaLikeCommentRow(BuildContext context, PostModel post) {
    // When popup is shown, reserve space above the row so the popup sits inside
    // the Stack's hit-test bounds (otherwise taps on the popup hit the list behind).
    const double popupAreaHeight = 52.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.postContentPaddingHorizontal),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showReactions) const SizedBox(height: popupAreaHeight),
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleReactions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _selectedReaction == null
                              ? Icon(
                                  Icons.thumb_up,
                                  color: AppColors.white,
                                  size: context.isLargeScreen ? 22 : 20,
                                )
                              : Text(
                                  _selectedReaction!,
                                  style: TextStyle(
                                    fontSize: AppDimensions.textL,
                                    color: _reactionColor,
                                  ),
                                ),
                          const SizedBox(width: AppDimensions.spaceXS),
                          Text(
                            "${post.totalReactions > 0 ? post.totalReactions : post.likes}",
                            style: const TextStyle(color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceS),
                  InkWell(
                    onTap: () => _openComments(context, post),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            color: AppColors.white,
                            size: context.isLargeScreen ? 20 : 18,
                          ),
                          const SizedBox(width: AppDimensions.spaceXS),
                          Text(
                            "${post.comments}",
                            style: const TextStyle(color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_showReactions)
            Positioned(
              left: 0,
              bottom: 44,
              child: Material(
                color: Colors.transparent,
                child: _buildReactionsPopup(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmojiReaction(String emoji, String label, [Color color = AppColors.black]) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // If user taps the same reaction, remove it (toggle off)
          if (_selectedReaction == emoji) {
            _selectedReaction = null;
            _reactionColor = AppColors.white;
            // Notify parent to remove reaction
            widget.onReactionSelected?.call('');
          } else {
            _selectedReaction = emoji;
            _reactionColor = (emoji == AppStrings.emojiLike) ? AppColors.reactionLike : AppColors.black;
            // Notify parent to save reaction
            widget.onReactionSelected?.call(emoji);
          }
          _showReactions = false;
        });
        debugPrint("User reacted with $label");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          emoji,
          style: TextStyle(fontSize: AppDimensions.textXXL, color: (emoji == AppStrings.emojiLike) ? AppColors.reactionLike : null),
        ),
      ),
    );
  }

  /// Check if the path is an asset path (starts with 'assets/')
  bool _isAssetPath(String path) {
    return path.startsWith('assets/');
  }

  /// Check if the path is a network URL (starts with 'http://' or 'https://')
  bool _isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  void _openPostMediaFullscreen(BuildContext context, int initialIndex) {
    final paths = widget.post.allMediaPaths;
    if (paths.isEmpty || !paths.any((p) => p.trim().isNotEmpty)) return;
    final idx = initialIndex.clamp(0, paths.length - 1);
    pauseAllVideos();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PostMediaFullscreenPage(
          post: widget.post,
          initialIndex: idx,
        ),
      ),
    );
  }

  Widget _buildTappableImage(String mediaPath, int mediaIndex) {
    return GestureDetector(
      onTap: () => _openPostMediaFullscreen(context, mediaIndex),
      behavior: HitTestBehavior.opaque,
      child: _buildImageWidget(mediaPath),
    );
  }

  /// Build image widget based on path type (asset, network, or local file)
  /// Uses CachedNetworkImage for network images to improve performance
  Widget _buildImageWidget(String mediaPath) {
    if (_isAssetPath(mediaPath)) {
      return Image.asset(
        mediaPath,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else if (_isNetworkUrl(mediaPath)) {
      // Network URL from Firebase Storage - use CachedNetworkImage for better performance
      return CachedNetworkImage(
        imageUrl: mediaPath,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.grey300,
          highlightColor: AppColors.grey100,
          child: Container(
            color: AppColors.grey300,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        errorWidget: (context, url, error) {
          return Container(
            color: AppColors.screenBackground.withOpacity(0.5),
            width: double.infinity,
          );
        },
      );
    } else {
      // Local file path (for backward compatibility with old posts)
      return Image.file(
        File(mediaPath),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.screenBackground.withOpacity(0.5),
            width: double.infinity,
          );
        },
      );
    }
  }

  /// Build media carousel for multiple items
  Widget _buildMediaCarousel() {
    final mediaPaths = widget.post.allMediaPaths;
    
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: mediaPaths.length,
          itemBuilder: (context, index) {
            return _buildMediaItem(index);
          },
        ),
        // Page indicators
        if (mediaPaths.length > 1)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: _buildPageIndicators(mediaPaths.length),
          ),
      ],
    );
  }

  /// Build single media item (image or video)
  Widget _buildSingleMedia() {
    // Check if it's a video using the new structure (mediaPaths) or old structure (isVideo)
    final isVideo = widget.post.isVideoAtIndex(0);
    
    if (isVideo) {
      return _buildVideoThumbnailOrPlayer(0);
    } else {
      // Use allMediaPaths to support both old and new formats
      final mediaPaths = widget.post.allMediaPaths;
      final mediaPath = mediaPaths.isNotEmpty ? mediaPaths[0] : widget.post.imagePath;

      return _buildTappableImage(mediaPath, 0);
    }
  }

  /// Build a single media item at given index
  Widget _buildMediaItem(int index) {
    final mediaPaths = widget.post.allMediaPaths;
    final mediaPath = mediaPaths[index];
    final isVideo = widget.post.isVideoAtIndex(index);

    if (isVideo) {
      return _buildVideoThumbnailOrPlayer(index);
    } else {
      return _buildTappableImage(mediaPath, index);
    }
  }

  /// Build page indicators (dots)
  Widget _buildPageIndicators(int count) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? AppColors.accent
                : AppColors.primary.withOpacity(0.5),
          ),
        ),
      ),
    ),
    );
  }

  /// Build video thumbnail with play button or video player
  Widget _buildVideoThumbnailOrPlayer(int index) {
    if ((_isVideoInitialized[index] ?? false) && _chewieControllers[index] != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Chewie(controller: _chewieControllers[index]!),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: AppColors.black.withOpacity(0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: AppColors.white, size: 22),
                tooltip: 'Full screen',
                onPressed: () => _openPostMediaFullscreen(context, index),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show thumbnail with play button - lazy load video on tap; fullscreen opens the same carousel (mixed posts).
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _initializeVideo(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoThumbnail(index),
                Container(
                  color: AppColors.black.withOpacity(0.3),
                ),
                Center(
                  child: (_isInitializingVideo[index] ?? false)
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : const Icon(
                          Icons.play_circle_filled,
                          color: AppColors.white,
                          size: 64,
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: AppColors.black.withOpacity(0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: AppColors.white),
                tooltip: 'Full screen',
                onPressed: () => _openPostMediaFullscreen(context, index),
              ),
            ),
          ),
        ],
      );
    }
  }

  /// Build video thumbnail from first frame (if available)
  Widget _buildVideoThumbnail(int index) {
    try {
      final mediaPaths = widget.post.allMediaPaths;
      if (index >= mediaPaths.length) {
        return Container(color: AppColors.black);
      }
      
      final videoPath = mediaPaths[index];
      
      // Check if it's a network URL
      if (_isNetworkUrl(videoPath)) {
        // For network videos, show a placeholder with play icon
        // In production, you could use video_thumbnail package to extract first frame
        return Container(
          color: AppColors.black,
          child: const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: AppColors.white,
              size: 64,
            ),
          ),
        );
      } else {
        // Local file path
        final videoFile = File(videoPath);
        if (videoFile.existsSync()) {
          // Use a placeholder image for now
          // In production, you could use video_thumbnail package to extract first frame
          return Container(
            color: AppColors.black,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking video file: $e');
    }
    return Container(
      color: AppColors.black,
    );
  }
}

// class PostWidget extends StatelessWidget {
//   final PostModel post;
//
//   const PostWidget({super.key, required this.post});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.5,
//       margin: const EdgeInsets.symmetric(
//         // horizontal: AppDimensions.postMarginHorizontal,
//         // vertical: AppDimensions.postMarginVertical,
//       ),
//       decoration: BoxDecoration(
//         color: AppColors.postBackground.withOpacity(0.7),
//         borderRadius: BorderRadius.circular(AppDimensions.postBorderRadius),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.postShadow.withOpacity(AppDimensions.postBoxShadowOpacity),
//             blurRadius: AppDimensions.postBoxShadowBlur,
//             offset: const Offset(0, AppDimensions.postBoxShadowOffsetY),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           ListTile(
//             leading: CircleAvatar(
//               backgroundImage: AssetImage(post.imagePath),
//             ),
//             title: Text(
//               post.username,
//               style: const TextStyle(fontWeight: FontWeight.bold,color: AppColors.accent),
//             ),
//             subtitle: Text(post.timeAgo),
//             trailing: const Icon(Icons.more_horiz),
//           ),
//
//           // Post Content
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppDimensions.postContentPaddingHorizontal,
//             ),
//             child: Text(post.content,style: const TextStyle(color: AppColors.primary), ),
//           ),
//           const SizedBox(height: AppDimensions.reactionIconSpacing),
//
//           // Post Image
//           // Post Image with overlayed likes/comments
//           Expanded(
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(AppDimensions.postBorderRadius),
//               child: Stack(
//                 children: [
//                   // The actual post image
//                   Positioned.fill(
//                     child: Image.asset(
//                       post.imagePath,
//                       fit: BoxFit.cover,
//                       width: double.infinity,
//                     ),
//                   ),
//
//                   // Floating Likes/Comments container
//                   Positioned(
//                     bottom: 12, // distance from bottom
//                     right: 12,  // distance from right
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         borderRadius: BorderRadius.circular(24),
//                       ),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // Like count
//                           Column(
//                             children: [
//                               const Icon(Icons.thumb_up,
//                                   color: AppColors.white, size: 20),
//                               const SizedBox(width: AppDimensions.spaceXS),
//                               Text(
//                                 "${post.likes}",
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 16),
//                           // Comment count
//                           Column(
//                             children: [
//                               const Icon(Icons.comment_outlined,
//                                   color: AppColors.white, size: 20),
//                               const SizedBox(width: AppDimensions.spaceXS),
//                               Text(
//                                 "${post.comments}",
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//
//
//           const SizedBox(height: AppDimensions.reactionIconSpacing),
//
//           // Reaction Row
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppDimensions.postContentPaddingHorizontal,
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.favorite,
//                     color: AppColors.reactionLike,
//                     size: AppDimensions.reactionIconSize),
//                 const SizedBox(width: AppDimensions.reactionIconSpacing),
//                 const Icon(Icons.thumb_up,
//                     color: AppColors.reactionLove,
//                     size: AppDimensions.reactionIconSize),
//                 const SizedBox(width: AppDimensions.reactionIconSpacing),
//                 Text("${post.likes}"),
//                 const Spacer(),
//                 Text("${post.comments}${AppStrings.comments}"),
//               ],
//             ),
//           ),
//
//           const Divider(),
//
//           // Actions Row
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: AppDimensions.actionRowSpacing,
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: const [
//                 Icon(Icons.thumb_up_alt_outlined),
//                 Icon(Icons.comment_outlined),
//                 Icon(Icons.share_outlined),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: AppDimensions.reactionIconSpacing),
//         ],
//       ),
//     );
//   }
// }































