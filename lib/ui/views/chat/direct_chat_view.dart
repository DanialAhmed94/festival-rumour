import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'chat_message_model.dart';
import 'chat_view_model.dart';

/// Dedicated 1:1 chat screen. Used when opening a DM from followers/following (not the chat room list).
/// Arguments: [chatRoomId] (String) or Map with 'chatRoomId' and optional 'otherUserName'.
class DirectChatView extends BaseView<ChatViewModel> {
  const DirectChatView({super.key});

  @override
  ChatViewModel createViewModel() => ChatViewModel();

  @override
  void onViewModelReady(ChatViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, ChatViewModel viewModel) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? chatRoomId;
    String? otherUserName;
    if (args is String) {
      chatRoomId = args;
    } else if (args is Map) {
      chatRoomId = args['chatRoomId'] as String?;
      otherUserName = args['otherUserName'] as String?;
    }

    if (chatRoomId != null &&
        chatRoomId.isNotEmpty &&
        viewModel.chatRoomId != chatRoomId &&
        !viewModel.isInChatRoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (viewModel.chatRoomId != chatRoomId) {
          viewModel.initializeChatRoom(chatRoomId);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, viewModel, otherUserName),
            Expanded(child: _buildChatContent(context, viewModel)),
            _buildInputSection(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ChatViewModel viewModel,
    String? otherUserName,
  ) {
    final title = otherUserName?.isNotEmpty == true
        ? otherUserName!
        : (viewModel.currentChatRoom?['name'] as String? ?? 'Chat');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFFC2E95)),
      child: Row(
        children: [
          CustomBackButton(onTap: () => Navigator.pop(context)),
          Expanded(
            child: ResponsiveTextWidget(
              title,
              textType: TextType.body,
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildChatContent(BuildContext context, ChatViewModel viewModel) {
    if (viewModel.busy && viewModel.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }
    if (viewModel.messages.isEmpty && !viewModel.busy) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              const ResponsiveTextWidget(
                'No messages yet',
                textType: TextType.title,
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceS),
              const ResponsiveTextWidget(
                'Start the conversation by sending a message',
                textType: TextType.body,
                color: AppColors.black,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: viewModel.scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        final message = viewModel.messages[index];
        return _buildMessageBubble(context, viewModel, message);
      },
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatViewModel viewModel,
    ChatMessageModel message,
  ) {
    final isCurrentUser = viewModel.isMessageFromCurrentUser(message);

    return GestureDetector(
      onLongPress: () {
        _showDeleteOptions(context, viewModel, message, isCurrentUser);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spaceM),
        child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.3),
              backgroundImage: message.userPhotoUrl != null &&
                      message.userPhotoUrl!.isNotEmpty
                  ? NetworkImage(message.userPhotoUrl!)
                  : null,
              child: message.userPhotoUrl == null ||
                      message.userPhotoUrl!.isEmpty
                  ? Text(
                      message.username.isNotEmpty
                          ? message.username[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppDimensions.spaceS),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spaceXS,
                      ),
                      child: ResponsiveTextWidget(
                        message.username,
                        textType: TextType.caption,
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ResponsiveTextWidget(
                    message.content,
                    textType: TextType.body,
                    fontSize: 14,
                    color: AppColors.black,
                  ),
                  if (message.isLocationMessage && message.lat != null && message.lng != null) ...[
                    const SizedBox(height: AppDimensions.spaceXS),
                    GestureDetector(
                      onTap: () => _openMap(message.lat!, message.lng!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 18, color: AppColors.accent),
                          const SizedBox(width: 6),
                          ResponsiveTextWidget(
                            'View on map',
                            textType: TextType.caption,
                            fontSize: 13,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceXS),
                  ResponsiveTextWidget(
                    message.timeAgo,
                    textType: TextType.caption,
                    fontSize: 10,
                    color: AppColors.grey600,
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: AppDimensions.spaceS),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.3),
              backgroundImage: message.userPhotoUrl != null &&
                      message.userPhotoUrl!.isNotEmpty
                  ? NetworkImage(message.userPhotoUrl!)
                  : null,
              child: message.userPhotoUrl == null ||
                      message.userPhotoUrl!.isEmpty
                  ? Text(
                      message.username.isNotEmpty
                          ? message.username[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps?q=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Show delete options bottom sheet (same as public chat room)
  void _showDeleteOptions(
    BuildContext context,
    ChatViewModel viewModel,
    ChatMessageModel message,
    bool isCurrentUser,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.screenBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spaceS,
                ),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.black,
                ),
                title: const ResponsiveTextWidget(
                  'Delete for me',
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
                onTap: () {
                  Navigator.pop(context);
                  viewModel.deleteMessageForMe(message.messageId ?? '');
                },
              ),
              if (isCurrentUser)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: AppColors.black,
                  ),
                  title: const ResponsiveTextWidget(
                    'Delete for everyone',
                    textType: TextType.body,
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final success = await viewModel.deleteMessageForEveryone(
                      message.messageId ?? '',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Message deleted for everyone'
                                : 'Failed to delete message',
                            style: const TextStyle(color: AppColors.black),
                          ),
                          backgroundColor: success
                              ? Colors.green.shade400
                              : Colors.red.shade200,
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.black),
                title: const ResponsiveTextWidget(
                  'Cancel',
                  textType: TextType.body,
                  color: AppColors.black,
                ),
                onTap: () => Navigator.pop(context),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSendMessage(
      BuildContext context, ChatViewModel viewModel) async {
    final success = await viewModel.sendMessage();
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Couldn\'t send. Please check your connection and try again.',
            style: TextStyle(color: AppColors.black),
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
  }

  Widget _buildInputSection(BuildContext context, ChatViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: AppDimensions.imageS,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceM),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              ),
              child: TextField(
                controller: viewModel.messageController,
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  hintText: AppStrings.typeSomething,
                  hintStyle: TextStyle(color: AppColors.grey600),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: AppColors.black),
                enabled: !viewModel.isSendingMessage,
                onSubmitted: (_) => _handleSendMessage(context, viewModel),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: viewModel.isSendingMessage
                  ? null
                  : () => _handleSendMessage(context, viewModel),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: viewModel.isSendingMessage
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFC2E95),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Color(0xFFFC2E95),
                        size: 28,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
