import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/di/locator.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../post_model.dart';

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
  String? _selectedReaction; // stores emoji / icon selected
  Color _reactionColor = AppColors.white; // default Like color
  PageController? _pageController;
  int _currentPage = 0;
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
    
    setState(() {
      _isInitializingVideo[index] = true;
    });

    try {
      final mediaPaths = widget.post.allMediaPaths;
      if (index >= mediaPaths.length) return;
      
      final videoPath = mediaPaths[index];
      
      // Check if it's a network URL or local file
      if (_isNetworkUrl(videoPath)) {
        // Network video URL from Firebase Storage
        _videoControllers[index] = VideoPlayerController.network(videoPath);
      } else {
        // Local file path
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
    return _chewieControllers.values.any((controller) => 
      controller != null && controller!.videoPlayerController.value.isPlaying
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final post = widget.post;
    final bool hasMedia = post.hasMedia;
    return Container(
      height: hasMedia
          ? (context.isLargeScreen
              ? MediaQuery.of(context).size.height * 0.6
              : context.isMediumScreen
                  ? MediaQuery.of(context).size.height * 0.5
                  : MediaQuery.of(context).size.height * 0.6)
          : null,
      constraints: hasMedia ? null : const BoxConstraints(minHeight: 200),
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
        mainAxisSize: hasMedia ? MainAxisSize.max : MainAxisSize.min,
        children: [
//          Header
          Container(
            width: double.infinity,
            color: Colors.transparent,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: _buildProfileAvatar(post),
              ),
              title: Text(
                post.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              subtitle: Text(post.timeAgo
                    , style: const TextStyle(fontWeight: FontWeight.bold,color: AppColors.primary),
              ),
              trailing: _isOwnPost
                  ? PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: AppColors.white,
                        size: 24,
                      ),
                      color: AppColors.screenBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      ),
                      onSelected: (value) {
                        if (value == 'edit' && widget.onEditPost != null) {
                          widget.onEditPost!(widget.post);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(), // Hide for other users' posts
            ),
          ),

          // Post Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.postContentPaddingHorizontal,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                post.content,
                style: const TextStyle(color: AppColors.black),
                textAlign: TextAlign.left,
                maxLines: hasMedia ? null : 5,
                overflow: hasMedia ? null : TextOverflow.ellipsis,
              ),
            ),
          ),
          // Post URL (when user attached a link)
          if (post.postUrl != null && post.postUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.postContentPaddingHorizontal,
              ),
              child: InkWell(
                onTap: () async {
                  String urlString = post.postUrl!.trim();
                  if (urlString.isEmpty) return;
                  if (!urlString.contains(RegExp(r'^https?://', caseSensitive: false))) {
                    urlString = 'https://$urlString';
                  }
                  final uri = Uri.tryParse(urlString);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 18,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.postUrl!,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.reactionIconSpacing),

          if (hasMedia) ...[
            Expanded(
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
          ] else ...[
            const SizedBox(height: AppDimensions.paddingL),
            _buildNoMediaLikeCommentRow(context, post),
          ],

          const SizedBox(height: AppDimensions.paddingL),

          if (hasMedia) ...[
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
    final arguments = widget.collectionName != null
        ? {'post': post, 'collectionName': widget.collectionName}
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

  Widget _buildNoMediaLikeCommentRow(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.postContentPaddingHorizontal),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
          if (_showReactions)
            Positioned(
              left: 0,
              bottom: 44,
              child: _buildReactionsPopup(),
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
        placeholder: (context, url) => Container(
          color: AppColors.onSurfaceVariant.withOpacity(0.3),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
            ),
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
      
      return _buildImageWidget(mediaPath);
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
      return _buildImageWidget(mediaPath);
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
      return Chewie(controller: _chewieControllers[index]!);
    } else {
      // Show thumbnail with play button - lazy load video on tap
      return GestureDetector(
        onTap: () => _initializeVideo(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background placeholder/thumbnail
            _buildVideoThumbnail(index),
            // Dark overlay
            Container(
              color: AppColors.black.withOpacity(0.3),
            ),
            // Loading indicator or play button
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

  /// Build profile avatar with network image and asset fallback
  Widget _buildProfileAvatar(PostModel post) {
    if (kDebugMode) {
      print('🖼️ Building profile avatar for post: ${post.postId}');
      print('   - userPhotoUrl: ${post.userPhotoUrl}');
      print('   - userId: ${post.userId}');
      print('   - username: ${post.username}');
    }

    // If we have a valid userPhotoUrl, use it with a custom widget that handles errors
    if (post.userPhotoUrl != null && post.userPhotoUrl!.isNotEmpty) {
      return _NetworkImageAvatar(
        imageUrl: post.userPhotoUrl!,
        fallbackAsset: AppAssets.profile,
      );
    }

    // Fallback to asset image if no userPhotoUrl
    return CircleAvatar(
      backgroundColor: AppColors.primary,
      backgroundImage: const AssetImage(AppAssets.profile),
    );
  }































/// Custom widget to handle network image with proper error fallback
class _NetworkImageAvatar extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;

  const _NetworkImageAvatar({
    required this.imageUrl,
    required this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.primary,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) =>
              Container(
                color: AppColors.primary,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
          errorWidget: (context, url, error) {
            // Fallback to asset image if network image fails
            if (kDebugMode) {
              print('❌ Error loading network image: $error');
              print('   - URL: $imageUrl');
            }
            return Image.asset(
              fallbackAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            );
          },
        ),
      ),
    );
  }
}
