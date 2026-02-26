import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/exceptions/exception_mapper.dart';
import '../../../core/di/locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/chat_badge_service.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'chat_view_model.dart';

/// Screen that shows only the list of chats (WhatsApp-style).
/// Uses CachedNetworkImage for profile pictures and displays other user's photo/name.
class ChatListView extends BaseView<ChatViewModel> {
  const ChatListView({super.key});

  @override
  ChatViewModel createViewModel() => ChatViewModel();

  @override
  void onViewModelReady(ChatViewModel viewModel) {
    super.onViewModelReady(viewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadPrivateChatRooms();
      locator<ChatBadgeService>().loadFromStorage();
    });
  }

  @override
  Widget buildView(BuildContext context, ChatViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, viewModel),
            _buildSearchField(context, viewModel),
            Expanded(child: _buildChatList(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ChatViewModel viewModel) {
    final isSelectionMode = viewModel.isSelectionMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFFC2E95)),
      child: Row(
        children: [
          if (isSelectionMode)
            IconButton(
              onPressed: () => viewModel.exitSelectionMode(),
              icon: Icon(Icons.close, color: AppColors.white, size: AppDimensions.iconL),
              padding: context.responsivePadding,
              constraints: BoxConstraints(
                minWidth: context.getConditionalIconSize(),
                minHeight: context.getConditionalIconSize(),
              ),
            )
          else
            CustomBackButton(onTap: () => Navigator.pop(context)),
          Expanded(
            child: ResponsiveTextWidget(
              isSelectionMode
                  ? (viewModel.selectedCount == 0
                      ? 'Select chats'
                      : '${viewModel.selectedCount} selected')
                  : 'Festy Besties',
              textAlign: TextAlign.center,
              textType: TextType.title,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: context.getConditionalMainFont(),
            ),
          ),
          if (isSelectionMode)
            IconButton(
              onPressed: viewModel.selectedCount > 0
                  ? () => _showDeleteSelectedDialog(context, viewModel)
                  : null,
              icon: Icon(
                Icons.delete_outline,
                color: viewModel.selectedCount > 0
                    ? AppColors.white
                    : AppColors.white.withOpacity(0.54),
                size: AppDimensions.iconL,
              ),
              padding: context.responsivePadding,
              constraints: BoxConstraints(
                minWidth: context.getConditionalIconSize(),
                minHeight: context.getConditionalIconSize(),
              ),
            )
          else ...[
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.searchUsers);
              },
              icon: const Icon(
                Icons.search,
                color: AppColors.white,
                size: AppDimensions.iconL,
              ),
              padding: context.responsivePadding,
              constraints: BoxConstraints(
                minWidth: context.getConditionalIconSize(),
                minHeight: context.getConditionalIconSize(),
              ),
              tooltip: 'Search users',
            ),
            IconButton(
              onPressed: viewModel.privateChats.isEmpty
                  ? null
                  : () => viewModel.enterSelectionMode(),
              icon: Icon(
                Icons.checklist_rtl,
                color: viewModel.privateChats.isEmpty
                    ? AppColors.white.withOpacity(0.54)
                    : AppColors.white,
                size: AppDimensions.iconL,
              ),
              padding: context.responsivePadding,
              constraints: BoxConstraints(
                minWidth: context.getConditionalIconSize(),
                minHeight: context.getConditionalIconSize(),
              ),
              tooltip: 'Select chats',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, ChatViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: TextField(
        onChanged: viewModel.setChatSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search from chats',
          hintStyle: TextStyle(color: AppColors.grey600, fontSize: AppDimensions.textM),
          prefixIcon: Icon(Icons.search, color: AppColors.grey600, size: AppDimensions.iconM),
          suffixIcon: viewModel.chatSearchQuery.isNotEmpty
              ? IconButton(
                  onPressed: viewModel.clearChatSearch,
                  icon: Icon(Icons.clear, color: AppColors.grey600, size: AppDimensions.iconM),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                )
              : null,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            borderSide: BorderSide(color: AppColors.grey300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            borderSide: BorderSide(color: AppColors.grey300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            borderSide: const BorderSide(color: Color(0xFFFC2E95), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
        ),
        style: const TextStyle(color: AppColors.black, fontSize: 16),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, ChatViewModel viewModel) {
    if (viewModel.privateChats.isEmpty && !viewModel.busy) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.black54),
              const SizedBox(height: AppDimensions.paddingM),
              ResponsiveTextWidget(
                'No chats yet',
                textType: TextType.body,
                color: AppColors.black54,
                fontSize: AppDimensions.textL,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.busy && viewModel.privateChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.black),
            const SizedBox(height: AppDimensions.paddingM),
            ResponsiveTextWidget(
              'Loading chats...',
              textType: TextType.body,
              color: AppColors.grey600,
              fontSize: AppDimensions.textM,
            ),
          ],
        ),
      );
    }

    final filteredChats = viewModel.filteredPrivateChats;
    if (viewModel.chatSearchQuery.isNotEmpty && filteredChats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: AppColors.grey500),
              const SizedBox(height: AppDimensions.paddingM),
              ResponsiveTextWidget(
                'No chats match your search',
                textType: TextType.body,
                color: AppColors.grey600,
                fontSize: AppDimensions.textL,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      itemCount: filteredChats.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.paddingS),
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return _buildWhatsAppStyleTile(context, viewModel, chat);
      },
    );
  }

  /// WhatsApp-style row: avatar (cached) | name + last message | time + unread badge
  Widget _buildWhatsAppStyleTile(
    BuildContext context,
    ChatViewModel viewModel,
    Map<String, dynamic> chat,
  ) {
    final chatRoomId = chat['chatRoomId'] as String?;
    final name = chat['otherUserName'] as String? ??
        chat['name'] as String? ??
        AppStrings.chatName;
    final lastMessage = chat['lastMessage'] as String? ?? '';
    final timestamp = chat['timestamp'] as String? ?? '';
    final photoUrl = chat['otherUserPhotoUrl'] as String?;
    final badgeCount = chatRoomId != null
        ? locator<ChatBadgeService>().getBadgeCount(chatRoomId)
        : 0;
    final isCreatedByUser = chat['createdBy'] != null &&
        viewModel.isChatRoomCreatedByUser(chat);
    final isSelectionMode = viewModel.isSelectionMode;
    final isSelected = viewModel.isChatSelected(chatRoomId);

    return Material(
      color: isSelectionMode && isSelected
          ? AppColors.primary.withOpacity(0.08)
          : AppColors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      elevation: 0,
      child: InkWell(
        onTap: () {
          if (chatRoomId == null || chatRoomId.isEmpty) return;
          if (isSelectionMode) {
            viewModel.toggleChatSelection(chatRoomId);
          } else {
            Navigator.pushNamed(
              context,
              AppRoutes.directChat,
              arguments: <String, String?>{
                'chatRoomId': chatRoomId,
                'otherUserName': name,
              },
            );
          }
        },
        onLongPress: chatRoomId != null && chatRoomId.isNotEmpty
            ? () {
                if (isSelectionMode) {
                  viewModel.toggleChatSelection(chatRoomId);
                } else {
                  _showDeleteChatDialog(
                      context, viewModel, chatRoomId, name, isCreatedByUser);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) =>
                        viewModel.toggleChatSelection(chatRoomId),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              _buildCachedAvatar(photoUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ResponsiveTextWidget(
                            name,
                            textType: TextType.body,
                            color: AppColors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timestamp.isNotEmpty)
                          ResponsiveTextWidget(
                            timestamp,
                            textType: TextType.caption,
                            color: AppColors.grey600,
                            fontSize: 12,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: ResponsiveTextWidget(
                            lastMessage.isNotEmpty
                                ? lastMessage
                                : 'No messages yet',
                            textType: TextType.caption,
                            color: lastMessage.isNotEmpty
                                ? AppColors.grey600
                                : AppColors.grey500,
                            fontSize: 14,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  /// Skip loading URLs that look like post images (often 404 when used as profile).
  static bool _isLikelyInvalidProfileUrl(String url) {
    if (url.isEmpty) return true;
    final lower = url.toLowerCase();
    return lower.contains('post_images') || lower.contains('posts%2fpost_images');
  }

  Widget _buildCachedAvatar(String? photoUrl) {
    const double size = 52;
    final raw = photoUrl?.trim() ?? '';
    final url = _isLikelyInvalidProfileUrl(raw) ? '' : raw;
    final hasUrl = url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: size,
                  height: size,
                  color: AppColors.grey200,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _placeholderAvatar(size),
                cacheKey: url,
                maxWidthDiskCache: 200,
                maxHeightDiskCache: 200,
              )
            : _placeholderAvatar(size),
      ),
    );
  }

  Widget _placeholderAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.primary.withOpacity(0.1),
      child: Image.asset(
        AppAssets.profile,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  void _showDeleteSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.black),
        ),
        backgroundColor: Colors.red.shade200,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showDeleteChatDialog(
    BuildContext context,
    ChatViewModel viewModel,
    String chatRoomId,
    String chatName,
    bool isCreatedByUser,
  ) {
    if (!isCreatedByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You can only delete chat rooms you created.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool isDeleting = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: AppColors.screenBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            title: ResponsiveTextWidget(
              'Delete chat?',
              textType: TextType.title,
              color: AppColors.black,
              fontWeight: FontWeight.bold,
            ),
            content: ResponsiveTextWidget(
              'Remove "$chatName" from your chats? This cannot be undone.',
              textType: TextType.body,
              color: AppColors.black,
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: ResponsiveTextWidget(
                  AppStrings.cancel,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setState(() => isDeleting = true);
                        try {
                          final success = await viewModel.deletePrivateChatRoom(chatRoomId);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          if (success) {
                            _showDeleteSuccessSnackBar(context, 'Chat deleted successfully');
                          } else {
                            _showDeleteErrorSnackBar(context, 'Failed to delete chat');
                          }
                        } catch (e, st) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            final message = e is AppException
                                ? e.message
                                : ExceptionMapper.mapToAppException(e, st).message;
                            _showDeleteErrorSnackBar(context, message);
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFFB00020),
                          strokeWidth: 2,
                        ),
                      )
                    : ResponsiveTextWidget(
                        'Delete',
                        textType: TextType.body,
                        color: const Color(0xFFB00020),
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteSelectedDialog(
    BuildContext context,
    ChatViewModel viewModel,
  ) {
    final n = viewModel.selectedCount;
    if (n == 0) return;

    bool isDeleting = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: AppColors.screenBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            title: ResponsiveTextWidget(
              'Delete chats?',
              textType: TextType.title,
              color: AppColors.black,
              fontWeight: FontWeight.bold,
            ),
            content: ResponsiveTextWidget(
              n == 1
                  ? 'Delete this chat? This cannot be undone.'
                  : 'Delete $n chats? This cannot be undone. Only chats you created will be deleted.',
              textType: TextType.body,
              color: AppColors.black,
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: ResponsiveTextWidget(
                  AppStrings.cancel,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setState(() => isDeleting = true);
                        try {
                          final deleted = await viewModel.deleteSelectedChatRooms();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          if (deleted > 0) {
                            _showDeleteSuccessSnackBar(
                              context,
                              deleted == 1
                                  ? 'Chat deleted successfully'
                                  : '$deleted chats deleted successfully',
                            );
                          } else {
                            _showDeleteErrorSnackBar(
                              context,
                              'No chats could be deleted. You can only delete chats you created.',
                            );
                          }
                        } catch (e, st) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            final message = e is AppException
                                ? e.message
                                : ExceptionMapper.mapToAppException(e, st).message;
                            _showDeleteErrorSnackBar(context, message);
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFFB00020),
                          strokeWidth: 2,
                        ),
                      )
                    : ResponsiveTextWidget(
                        'Delete',
                        textType: TextType.body,
                        color: const Color(0xFFB00020),
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
