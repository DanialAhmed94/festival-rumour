import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/post_data_service.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../homeview/widgets/post_widget.dart';
import '../Profile/profile_viewmodel.dart';
import 'posts_view_model.dart';

class PostsView extends BaseView<PostsViewModel> {
  final VoidCallback? onBack;
  const PostsView({super.key, this.onBack});

  @override
  PostsViewModel createViewModel() => PostsViewModel();

  @override
  Widget buildView(BuildContext context, PostsViewModel viewModel) {
    // Initialize with posts data from arguments if provided, otherwise check PostDataService
    // Must use addPostFrameCallback to avoid calling notifyListeners() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only initialize if not already initialized
      if (viewModel.posts.isNotEmpty) {
        if (kDebugMode) {
          print('📥 PostsView: Already initialized with ${viewModel.posts.length} posts');
        }
        return;
      }
      
      List<Map<String, dynamic>>? postsData;
      String? collectionName;
      
      // Try to get data from arguments first
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        postsData = args['posts'] as List<Map<String, dynamic>>?;
        collectionName = args['collectionName'] as String?;
        if (kDebugMode) {
          print('📥 PostsView: Got data from arguments (${postsData?.length ?? 0} posts)');
        }
      } else {
        // Try PostDataService (when using sub-navigation)
        try {
          final postDataService = locator<PostDataService>();
          postsData = postDataService.getPostData();
          collectionName = postDataService.getCollectionName();
          if (kDebugMode) {
            print('📥 PostsView: Got data from PostDataService (${postsData?.length ?? 0} posts)');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not access PostDataService: $e');
          }
        }
      }
      
      // Initialize if we have data
      if (postsData != null && postsData.isNotEmpty) {
        viewModel.initialize(postsData, collectionName: collectionName);
      } else {
        if (kDebugMode) {
          print('⚠️ No posts data available');
        }
      }
    });

    return Scaffold(
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

          /// 🔹 Main content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Consumer<PostsViewModel>(
                    builder: (context, vm, child) {
                      if (kDebugMode && vm.posts.isEmpty) {
                        print('📊 PostsView UI: posts list is empty (length: ${vm.posts.length})');
                      }
                      
                      return vm.posts.isEmpty
                          ? Center(
                              child: ResponsiveTextWidget(
                                'No posts to display',
                                color: AppColors.white,
                                fontSize: AppDimensions.textM,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceS),
                              itemCount: vm.posts.length,
                              itemBuilder: (context, index) {
                                final post = vm.posts[index];
                                return PostWidget(
                                  post: post,
                                  backgroundColor: AppColors.postPinkPurple50,
                                  collectionName: vm.collectionName,
                                  onReactionSelected: (emotion) {
                                    // Handle reaction selection
                                    if (post.postId != null) {
                                      vm.handleReactionSelected(post.postId!, emotion);
                                    }
                                  },
                                  onCommentsUpdated: () {
                                    // Refresh posts if needed
                                    vm.notifyListeners();
                                  },
                                  onDeletePost: (postId) {
                                    // Handle post deletion
                                    vm.deletePost(postId, context);
                                  },
                                );
                              },
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () {
          if (onBack != null) {
            onBack!(); // Navigate back to discover screen
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: const ResponsiveTextWidget(
        'Posts',
        textType: TextType.title,
        color: AppColors.white,
        fontWeight: FontWeight.w600,
      ),
      centerTitle: true,
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post, int index) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _showReactions = false;
        String? _selectedReaction;
        Color _reactionColor = AppColors.white;

        void _toggleReactions() {
          setState(() {
            _showReactions = !_showReactions;
          });
        }

        void _handleLike() {
          setState(() {
            post['likes'] = (post['likes'] ?? 0) + 1;
          });
        }

        void _handleComment() {
          Navigator.pushNamed(
            context,
            AppRoutes.comments, // 👈 Define this route
            arguments: post,    // optional: pass the post if needed
          );
          // Navigate to comments or handle comment action

        }

        void _handleReaction(String emoji) {
          setState(() {
            _selectedReaction = emoji;
            _reactionColor = (emoji == "👍") ? AppColors.blue : AppColors.black;
            _showReactions = false;
            post['likes'] = (post['likes'] ?? 0) + 1;
          });
        }

        return Container(
          height: context.screenHeight * 0.5,
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.postBackground.withOpacity(0.7),
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
            children: [
              // Header
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage(post['userImage'] ?? ''),
                ),
                title: ResponsiveTextWidget(
                  post['username'] ?? 'Unknown User',
                  textType: TextType.body,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
                subtitle: ResponsiveTextWidget(post['timeAgo'] ?? '2 hours ago'),
                trailing: const Icon(Icons.more_horiz),
              ),

              // Post Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.postContentPaddingHorizontal,
                ),
                child: ResponsiveTextWidget(
                  post['description'] ?? '',
                  textType: TextType.body,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.reactionIconSpacing),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.postBorderRadius),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: Image.asset(
                          post['image'] ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),

                      // Floating Likes/Comments
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _handleLike,
                              child: Container(
                                padding: const EdgeInsets.all(AppDimensions.spaceXS),
                                decoration: BoxDecoration(
                                  color: AppColors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                                ),
                                child: Row(
                                  children: [
                                    _selectedReaction == null
                                        ? const Icon(Icons.thumb_up, color: AppColors.white, size: AppDimensions.iconS)
                                        : ResponsiveTextWidget(
                                      _selectedReaction!,
                                      textType: TextType.body,
                                      color: _reactionColor,
                                    ),
                                    const SizedBox(width: AppDimensions.spaceXS),
                                    ResponsiveTextWidget("${post['likes'] ?? 0}",
                                        textType: TextType.caption,
                                        color: AppColors.white),
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
                                onTap: _handleComment,
                                child: Row(
                                  children: [
                                    const Icon(Icons.comment_outlined, color: AppColors.white, size: AppDimensions.iconS),
                                    const SizedBox(width: AppDimensions.spaceXS),
                                    ResponsiveTextWidget("${post['comments'] ?? 0}",
                                        textType: TextType.caption,
                                        color: AppColors.white),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Reactions Popup
                      if (_showReactions)
                        Positioned(
                          bottom: 60,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildEmojiReaction("👍", AppStrings.like, AppColors.blue, _handleReaction),
                                _buildEmojiReaction("❤️", AppStrings.love, AppColors.red, _handleReaction),
                                _buildEmojiReaction("😂", AppStrings.haha, AppColors.yellow, _handleReaction),
                                _buildEmojiReaction("😮", AppStrings.wow, AppColors.orange, _handleReaction),
                                _buildEmojiReaction("😢", AppStrings.sad, AppColors.blue, _handleReaction),
                                _buildEmojiReaction("😡", AppStrings.angry, AppColors.red, _handleReaction),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),

              // Reaction Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: AppColors.reactionLike, size: AppDimensions.reactionIconSize),
                  const SizedBox(width: AppDimensions.reactionIconSpacing),
                  const Icon(Icons.thumb_up, color: AppColors.reactionLove, size: AppDimensions.reactionIconSize),
                  const SizedBox(width: AppDimensions.reactionIconSpacing),
                  ResponsiveTextWidget("${post['likes'] ?? 0}", textType: TextType.caption, color: AppColors.white),
                  SizedBox(width: context.screenWidth * 0.3),
                  ResponsiveTextWidget("${post['comments'] ?? 0} ", textType: TextType.caption, color: AppColors.white),
                  const SizedBox(width: AppDimensions.reactionIconSpacing),
                  const ResponsiveTextWidget(AppStrings.comments, textType: TextType.caption, color: AppColors.white),
                ],
              ),
              const SizedBox(height: AppDimensions.reactionIconSpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceS),
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.white,
              size: AppDimensions.iconS,
            ),
            if (count != null && count > 0)
              ResponsiveTextWidget(
                _formatCount(count),
                textType: TextType.caption,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionEmoji(String emoji) {
    return GestureDetector(
      onTap: () {
        // Handle emoji reaction
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceS),
        decoration: BoxDecoration(
          color: AppColors.grey800,
          shape: BoxShape.circle,
        ),
        child: ResponsiveTextWidget(
          emoji,
          textType: TextType.caption,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildEmojiReaction(String emoji, String label, Color color, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(emoji),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceXS),
        child: ResponsiveTextWidget(
          emoji,
          textType: TextType.body,
          color: color,
        ),
      ),
    );
  }
}
