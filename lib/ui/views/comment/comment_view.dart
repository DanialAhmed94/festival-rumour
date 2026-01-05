import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../homeview/post_model.dart';
import 'comment_viewmodel.dart';
import 'comment_model.dart';

class CommentView extends BaseView<CommentViewModel> {
  final dynamic post; // PostModel passed from navigation
  final String? collectionName; // Optional collection name (for festival-specific posts)
  
  const CommentView({super.key, this.post, this.collectionName});

  @override
  CommentViewModel createViewModel() {
    final viewModel = CommentViewModel();
    viewModel.initialize(
      post is PostModel ? post : null,
      collectionName: collectionName,
    );
    return viewModel;
  }

  @override
  Widget buildView(BuildContext context, CommentViewModel viewModel) {
    return Scaffold(
      body: Stack(
        children: [
          /// 🔹 Fullscreen background image (const to prevent rebuilds)
          Positioned.fill(
            child: Image.asset(
              AppAssets.bottomsheet,
              fit: BoxFit.cover,
            ),
          ),

          /// 🔹 Dark overlay for readability
          Positioned.fill(
            child: Container(color: AppColors.black.withOpacity(0.35)),
          ),

          /// 🔹 Main content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, viewModel),
                // Comments list
                Expanded(
                  child: Consumer<CommentViewModel>(
                    builder: (context, viewModel, child) {
                      return _buildCommentsList(context, viewModel);
                    },
                  ),
                ),
                // Comment input area - hide when replying
                Selector<CommentViewModel, bool>(
                  selector: (context, vm) {
                    // Check if user is NOT replying to any comment
                    return !vm.comments.any((c) => vm.isReplyingTo(c.commentId));
                  },
                  builder: (context, isNotReplying, child) {
                    if (!isNotReplying) {
                      return const SizedBox.shrink(); // Hide completely when replying
                    }
                    return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  margin: EdgeInsets.only(top: AppDimensions.spaceM),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withOpacity(0.3),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingL),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Text input field
                          Flexible(
                            child: Builder(
                              builder: (context) {
                                // Calculate maxLines based on available height
                                final availableHeight = MediaQuery.of(context).size.height * 0.3 - (AppDimensions.paddingL * 2) - 48;
                                final lineHeight = AppDimensions.textL * 1.4; // Approximate line height (fontSize * line height multiplier)
                                final calculatedMaxLines = (availableHeight / lineHeight).floor().clamp(1, 10); // Min 1, Max 10 lines
                                
                                return Selector<CommentViewModel, bool>(
                                  selector: (context, vm) {
                                    // Check if user is NOT replying to any comment
                                    // If isReplyingTo returns true for any comment, user is replying
                                    return !vm.comments.any((c) => vm.isReplyingTo(c.commentId));
                                  },
                                  builder: (context, isNotReplying, child) {
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: availableHeight,
                          ),
                          child: TextField(
                            controller: viewModel.commentController,
                                        enabled: isNotReplying,
                                        maxLines: calculatedMaxLines,
                            minLines: 1,
                            textAlignVertical: TextAlignVertical.top,
                                        decoration: InputDecoration(
                              hintText: AppStrings.commentHint,
                                          hintStyle: TextStyle(
                                            color: isNotReplying 
                                                ? AppColors.white.withOpacity(0.7)
                                                : AppColors.white.withOpacity(0.35),
                                          ),
                              border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: AppDimensions.paddingS,
                                            vertical: AppDimensions.spaceM,
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: isNotReplying 
                                              ? AppColors.white 
                                              : AppColors.white.withOpacity(0.5),
                              fontSize: AppDimensions.textL,
                                          height: 1.4, // Line height multiplier
                                        ),
                                        // TextField will scroll internally when maxLines is reached
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceM),
                          // Post button
                          Selector<CommentViewModel, bool>(
                            selector: (context, viewModel) {
                              final isReplying = viewModel.comments.any((c) => viewModel.isReplyingTo(c.commentId));
                              return viewModel.canPostComment && !viewModel.isLoading && !isReplying;
                            },
                            builder: (context, canPost, child) {
                              final viewModel = Provider.of<CommentViewModel>(context, listen: false);
                              return ElevatedButton(
                                onPressed: canPost ? viewModel.postComment : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.black,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppDimensions.paddingL,
                                    vertical: AppDimensions.spaceM,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                child: const ResponsiveTextWidget(
                                  AppStrings.post,
                                  textType: TextType.caption,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                      ),
                    ],
                  ),
                    ),
                  ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, CommentViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.spaceS),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.white, size: 24),
            onPressed: viewModel.closeCommentView,
          ),
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.comments,
              textAlign: TextAlign.center,
              textType: TextType.title,
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Placeholder to maintain spacing (same width as IconButton)
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildToolbarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: AppColors.grey600,
        size: 24,
      ),
    );
  }

  Widget _buildToolbarText(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ResponsiveTextWidget(
        text,
        textType: TextType.body,
        color: AppColors.grey600,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBottomButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceM, vertical: AppDimensions.spaceS),
        decoration: BoxDecoration(
          color: AppColors.grey700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ResponsiveTextWidget(
          text,
          textType: TextType.body,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context, CommentViewModel viewModel) {
    if (viewModel.isLoading && viewModel.comments.isEmpty) {
      return const LoadingWidget(message: 'Loading comments...');
    }

    if (viewModel.comments.isEmpty && !viewModel.isLoading) {
      return Center(
        child: ResponsiveTextWidget(
          'No comments yet. Be the first to comment!',
          textType: TextType.body,
          color: AppColors.white,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: viewModel.scrollController, // Add scroll controller
      padding: EdgeInsets.only(
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        top: AppDimensions.paddingM,
        bottom: AppDimensions.paddingXL, // Extra bottom padding to prevent overlap with input area
      ),
      itemCount: viewModel.comments.length + 1, // Always add 1 for load more button or "no more comments" message
      itemBuilder: (context, index) {
        // Show load more button or "no more comments" message at the end
        if (index == viewModel.comments.length) {
          return _buildLoadMoreButton(context, viewModel);
        }

        final comment = viewModel.comments[index];
        return _buildCommentItem(context, comment);
      },
    );
  }

  Widget _buildLoadMoreButton(BuildContext context, CommentViewModel viewModel) {
    // Show "No more comments" message if we've loaded all comments
    if (!viewModel.hasMoreComments && !viewModel.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingL,
        ),
        child: Center(
          child: ResponsiveTextWidget(
            'No more comments available',
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

    // Show "Load More" button if there are more comments
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingL,
      ),
      child: Center(
        child: ElevatedButton(
          onPressed: viewModel.loadMoreComments,
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

  Widget _buildCommentItem(BuildContext context, CommentModel comment, {Key? key}) {
    // Use RepaintBoundary to isolate repaints and improve performance
    return RepaintBoundary(
      key: key, // Use key for better Flutter diffing
      child: Consumer<CommentViewModel>(
        builder: (context, viewModel, child) {
          final replies = viewModel.getReplies(comment.commentId ?? '');
          final isExpanded = viewModel.areRepliesExpanded(comment.commentId ?? '');
          final replyCount = viewModel.getReplyCount(comment.commentId ?? '');
          final isReplying = viewModel.isReplyingTo(comment.commentId);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main comment
              Container(
                margin: EdgeInsets.only(bottom: AppDimensions.spaceS),
      padding: EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture
          _buildCommentProfileAvatar(comment),
          const SizedBox(width: AppDimensions.spaceM),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ResponsiveTextWidget(
                      comment.username,
                      textType: TextType.body,
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(width: AppDimensions.spaceS),
                    ResponsiveTextWidget(
                      comment.timeAgo,
                      textType: TextType.caption,
                      color: AppColors.grey600,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceXS),
                ResponsiveTextWidget(
                  comment.content,
                  textType: TextType.body,
                  color: AppColors.white,
                ),
              ],
            ),
          ),
        ],
                    ),
                    const SizedBox(height: AppDimensions.spaceS),
                    // Reply button and reply count
                    Row(
                      children: [
                        // Reply button
                        GestureDetector(
                          onTap: () {
                            if (isReplying) {
                              viewModel.cancelReplying();
                            } else {
                              viewModel.startReplying(comment.commentId ?? '');
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDimensions.paddingM,
                              vertical: AppDimensions.spaceXS,
                            ),
                            decoration: BoxDecoration(
                              color: isReplying 
                                  ? AppColors.accent.withOpacity(0.3)
                                  : AppColors.onPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 16,
                                  color: isReplying ? AppColors.accent : AppColors.white,
                                ),
                                const SizedBox(width: AppDimensions.spaceXS),
                                ResponsiveTextWidget(
                                  isReplying ? 'Cancel' : 'Reply',
                                  textType: TextType.caption,
                                  color: isReplying ? AppColors.accent : AppColors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Reply count and toggle
                        if (replyCount > 0) ...[
                          const SizedBox(width: AppDimensions.spaceM),
                          GestureDetector(
                            onTap: () => viewModel.toggleReplies(comment.commentId ?? ''),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingM,
                                vertical: AppDimensions.spaceXS,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ResponsiveTextWidget(
                                    '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                    textType: TextType.caption,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  const SizedBox(width: AppDimensions.spaceXS),
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    size: 16,
                                    color: AppColors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Reply input field (when replying)
              if (isReplying)
                _buildReplyInput(context, viewModel, comment.commentId ?? ''),
              
              // Replies list (nested/threaded view)
              if (isExpanded && replies.isNotEmpty)
                _buildRepliesList(context, viewModel, comment.commentId ?? '', replies),
            ],
          );
        },
      ),
    );
  }
  
  /// Build reply input field
  Widget _buildReplyInput(BuildContext context, CommentViewModel viewModel, String parentCommentId) {
    return Container(
      margin: EdgeInsets.only(
        left: AppDimensions.paddingXL, // Indent to show it's a reply
        bottom: AppDimensions.spaceM,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: viewModel.replyController,
            maxLines: 3,
            minLines: 1,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Write a reply...',
              hintStyle: TextStyle(color: AppColors.white.withOpacity(0.7)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.spaceM,
              ),
            ),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: AppDimensions.textM,
            ),
            onChanged: (_) => viewModel.notifyListeners(),
          ),
          const SizedBox(height: AppDimensions.spaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: TextButton(
                onPressed: () => viewModel.cancelReplying(),
                child: const ResponsiveTextWidget(
                  'Cancel',
                  textType: TextType.caption,
                  color: AppColors.grey600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceS),
              Selector<CommentViewModel, bool>(
                selector: (context, vm) => vm.canPostReply(),
                builder: (context, canPost, child) {
                  return Flexible(
                    fit: FlexFit.loose,
                    child: ElevatedButton(
                    onPressed: canPost
                        ? () => viewModel.postReply(parentCommentId)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.spaceXS,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      ),
                    ),
                    child: const ResponsiveTextWidget(
                      'Reply',
                      textType: TextType.caption,
                      fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Build replies list (nested/threaded view like group chat)
  Widget _buildRepliesList(
    BuildContext context,
    CommentViewModel viewModel,
    String parentCommentId,
    List<CommentModel> replies,
  ) {
    return Container(
      margin: EdgeInsets.only(
        left: AppDimensions.paddingXL, // Indent to show nesting
        bottom: AppDimensions.spaceM,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.accent.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: replies.map((reply) {
          return Container(
            margin: EdgeInsets.only(
              left: AppDimensions.paddingM,
              bottom: AppDimensions.spaceS,
            ),
            padding: EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Smaller avatar for replies
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: ClipOval(
                    child: reply.userPhotoUrl != null && reply.userPhotoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: reply.userPhotoUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.accent,
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              AppAssets.profile,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Image.asset(
                            AppAssets.profile,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceS),
                // Reply content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ResponsiveTextWidget(
                            reply.username,
                            textType: TextType.caption,
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(width: AppDimensions.spaceXS),
                          ResponsiveTextWidget(
                            reply.timeAgo,
                            textType: TextType.caption,
                            color: AppColors.grey600,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceXS / 2),
                      ResponsiveTextWidget(
                        reply.content,
                        textType: TextType.body,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build profile avatar for comment with network image and asset fallback
  /// Uses CachedNetworkImage for better performance and caching
  Widget _buildCommentProfileAvatar(CommentModel comment) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary,
      child: ClipOval(
        child: comment.userPhotoUrl != null && comment.userPhotoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: comment.userPhotoUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                errorWidget: (context, url, error) {
                  // Fallback to asset image if network image fails
                  return Image.asset(
                    AppAssets.profile,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
              )
            : Image.asset(
                AppAssets.profile,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }
}
