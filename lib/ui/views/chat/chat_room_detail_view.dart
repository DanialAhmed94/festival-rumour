import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_room_detail_view_model.dart';

class ChatRoomDetailView extends BaseView<ChatRoomDetailViewModel> {
  const ChatRoomDetailView({super.key});

  @override
  ChatRoomDetailViewModel createViewModel() => ChatRoomDetailViewModel();

  @override
  void onViewModelReady(ChatRoomDetailViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, ChatRoomDetailViewModel viewModel) {
    if (viewModel.chatRoomId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final chatRoomId = args is String ? args : (args is Map ? args['chatRoomId'] as String? : null);
      if (chatRoomId != null && chatRoomId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (viewModel.chatRoomId == null) {
            viewModel.setArgs(chatRoomId);
            viewModel.loadRoomDetail();
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFC2E95),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ResponsiveTextWidget(
          viewModel.roomName.isNotEmpty ? viewModel.roomName : 'Room info',
          textType: TextType.title,
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (viewModel.errorMessage != null && viewModel.errorMessage!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFB00020).withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB00020), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      viewModel.errorMessage!,
                      style: const TextStyle(color: Color(0xFFB00020), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: viewModel.isLoading && viewModel.members.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.black))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ResponsiveTextWidget(
                          'Room name',
                          textType: TextType.caption,
                          color: AppColors.grey600,
                        ),
                        const SizedBox(height: 4),
                        ResponsiveTextWidget(
                          viewModel.roomName,
                          textType: TextType.title,
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 12),
                        ResponsiveTextWidget(
                          '${viewModel.members.length} member${viewModel.members.length == 1 ? '' : 's'}',
                          textType: TextType.body,
                          color: AppColors.grey600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ResponsiveTextWidget(
                    'Members',
                    textType: TextType.title,
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 12),
                  if (viewModel.members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: ResponsiveTextWidget(
                        'No members',
                        textType: TextType.body,
                        color: AppColors.grey600,
                      ),
                    )
                  else
                    ...viewModel.members.map((member) => _buildMemberTile(context, viewModel, member)),
                  if (!viewModel.isCurrentUserCreator) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _confirmLeaveGroup(context, viewModel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB00020),
                          side: const BorderSide(color: Color(0xFFB00020), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Exit group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    ChatRoomDetailViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        title: const ResponsiveTextWidget(
          'Leave group',
          textType: TextType.title,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        content: const ResponsiveTextWidget(
          'Leave this chat room? You will no longer see messages here.',
          textType: TextType.body,
          color: AppColors.black,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              AppStrings.cancel,
              style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Color(0xFFB00020), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await viewModel.leaveRoom();
    if (context.mounted && success) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildMemberTile(
    BuildContext context,
    ChatRoomDetailViewModel viewModel,
    Map<String, dynamic> member,
  ) {
    final displayName = member['displayName'] as String? ?? AppStrings.unknown;
    final photoUrl = member['photoUrl'] as String?;
    final isCreator = member['isCreator'] as bool? ?? false;
    final userId = member['userId'] as String?;
    final isCurrentUser = userId == viewModel.currentUserId;
    final canRemove = viewModel.canRemoveMember(member);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          _buildAvatar(displayName, photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ResponsiveTextWidget(
                        isCurrentUser ? '$displayName (You)' : displayName,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCreator) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const ResponsiveTextWidget(
                          'Creator',
                          textType: TextType.caption,
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canRemove && userId != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmRemoveMember(context, viewModel, displayName, userId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB00020), width: 1.5),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        color: Color(0xFFB00020),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    ChatRoomDetailViewModel viewModel,
    String displayName,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.screenBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        title: const ResponsiveTextWidget(
          'Remove member',
          textType: TextType.title,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        content: ResponsiveTextWidget(
          'Remove $displayName from this chat room?',
          textType: TextType.body,
          color: AppColors.black,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              AppStrings.cancel,
              style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.remove,
              style: TextStyle(color: Color(0xFFB00020), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await viewModel.removeMember(userId);
    }
  }

  Widget _buildAvatar(String displayName, String? photoUrl) {
    const colors = [
      AppColors.avatarPurple,
      AppColors.avatarOrange,
      AppColors.avatarGrey,
      AppColors.avatarYellow,
      AppColors.avatarBlue,
      AppColors.avatarPink,
    ];
    final color = colors[displayName.hashCode % colors.length];

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 50,
            height: 50,
            color: color,
            child: Center(
              child: ResponsiveTextWidget(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _avatarPlaceholder(displayName, color),
        ),
      );
    }
    return _avatarPlaceholder(displayName, color);
  }

  Widget _avatarPlaceholder(String displayName, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.grey300),
      ),
      child: Center(
        child: ResponsiveTextWidget(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
