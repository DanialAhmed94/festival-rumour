import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'chat_view_model.dart';
import 'chat_message_model.dart';

class ChatView extends BaseView<ChatViewModel> {
  final VoidCallback? onBack;
  const ChatView({super.key, this.onBack});

  @override
  ChatViewModel createViewModel() => ChatViewModel();

  @override
  void onViewModelReady(ChatViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Load private chat rooms when view is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadPrivateChatRooms();
    });
  }

  @override
  Widget buildView(BuildContext context, ChatViewModel viewModel) {
    // Initialize chat room if chatRoomId is provided and not already initialized
    // Only initialize if we're not already in a chat room (to prevent re-initialization after back button)
    if (viewModel.chatRoomId == null && !viewModel.isInChatRoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check to prevent race conditions
        if (viewModel.chatRoomId == null && !viewModel.isInChatRoom) {
          final chatRoomId =
              ModalRoute.of(context)?.settings.arguments as String?;
          if (chatRoomId != null && chatRoomId.isNotEmpty) {
            viewModel.initializeChatRoom(chatRoomId);
          }
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (onBack != null) {
          onBack!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            // Main content
            if (viewModel.isInChatRoom)
              _buildChatRoomView(context, viewModel)
            else
              _buildChatListView(context, viewModel),
          ],
        ),
        floatingActionButton:
            !viewModel.isInChatRoom && viewModel.selectedTab == 1
                ? FloatingActionButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.createChatRoom);
                  },
                  backgroundColor: AppColors.accent,
                  child: const Icon(Icons.chat, color: AppColors.black),
                )
                : null,
      ),
    );
  }

  Widget _buildChatListView(BuildContext context, ChatViewModel viewModel) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: _buildAppBar(context, viewModel),
        ),
        const SizedBox(height: AppDimensions.spaceM),
        Expanded(
          child: Column(
            children: [
              _buildSegmentedControl(context, viewModel),
              const SizedBox(height: AppDimensions.spaceL),
              Expanded(child: _buildChatRooms(context, viewModel)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatRoomView(BuildContext context, ChatViewModel viewModel) {
    return SafeArea(
      child: Column(
        children: [
          _buildChatRoomAppBar(context, viewModel),
          Expanded(child: _buildChatContent(context, viewModel)),
          _buildInputSection(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ChatViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFFC2E95)),
      child: Row(
        children: [
          CustomBackButton(
            onTap:
                onBack ??
                () {
                  // Navigate back to discover screen using ViewModel
                  viewModel.navigateBack(context);
                },
          ),
          Expanded(
            child: ResponsiveTextWidget(
              AppStrings.chatRooms,
              textAlign: TextAlign.center,
              textType: TextType.title,
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, ChatViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => viewModel.setSelectedTab(0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingS,
                  horizontal: AppDimensions.paddingM,
                ),
                decoration: BoxDecoration(
                  color:
                      viewModel.selectedTab == 0
                          ? AppColors.accent
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppAssets.public,
                      width: AppDimensions.iconS,
                      height: AppDimensions.iconS,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: AppDimensions.spaceS),
                    ResponsiveTextWidget(
                      AppStrings.public,
                      textType: TextType.body,
                      color:
                          viewModel.selectedTab == 0
                              ? AppColors.black
                              : AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => viewModel.setSelectedTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingS,
                  horizontal: AppDimensions.paddingM,
                ),
                decoration: BoxDecoration(
                  color:
                      viewModel.selectedTab == 1
                          ? AppColors.accent
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AppAssets.private,
                      width: AppDimensions.iconS,
                      height: AppDimensions.iconS,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: AppDimensions.spaceS),
                    ResponsiveTextWidget(
                      AppStrings.private,
                      textType: TextType.body,
                      color:
                          viewModel.selectedTab == 1
                              ? AppColors.black
                              : AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRooms(BuildContext context, ChatViewModel viewModel) {
    if (viewModel.selectedTab == 1) {
      // Private chat rooms
      return _buildPrivateChatList(context, viewModel);
    } else {
      // Public chat rooms - show grid view
      final publicChatRooms = viewModel.getPublicChatRooms(context);
      return GridView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingS,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 cards per row
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75, // Adjust height vs width ratio
        ),
        itemCount: publicChatRooms.length,
        itemBuilder: (context, index) {
          final room = publicChatRooms[index];
          return GestureDetector(
            onTap: () {
              // Get chat room ID from festival provider
              final festivalProvider = Provider.of<FestivalProvider>(
                context,
                listen: false,
              );
              final selectedFestival = festivalProvider.selectedFestival;

              if (selectedFestival != null) {
                // Generate chat room ID
                final chatRoomId = FirestoreService.getFestivalChatRoomId(
                  selectedFestival.id,
                  selectedFestival.title,
                );
                // Initialize chat room with ID
                viewModel.initializeChatRoom(chatRoomId);
              } else {
                // Fallback to old method if no festival selected
                viewModel.enterChatRoom(room);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                color: AppColors.onPrimary.withOpacity(0.3),
                border: Border.all(
                  color: AppColors.white.withOpacity(0.2),
                  width: AppDimensions.dividerThickness,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Image section
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.asset(
                        room['image'] ?? AppAssets.post,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  // Text section
                  Padding(
                    padding: EdgeInsets.all(AppDimensions.spaceS),
                    child: ResponsiveTextWidget(
                      room['name'] ?? AppStrings.lunaCommunityRoom,
                      textAlign: TextAlign.center,
                      textType: TextType.caption,
                      fontSize: AppDimensions.textM,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildPrivateChatList(BuildContext context, ChatViewModel viewModel) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cards per row
        crossAxisSpacing: 15,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75, // Adjust height vs width ratio
      ),
      itemCount: viewModel.privateChats.length,
      itemBuilder: (context, index) {
        final chat = viewModel.privateChats[index];
        return _buildPrivateChatItem(context, viewModel, chat);
      },
    );
  }

  Widget _buildPrivateChatItem(
    BuildContext context,
    ChatViewModel viewModel,
    Map<String, dynamic> chat,
  ) {
    final isCreatedByUser = viewModel.isChatRoomCreatedByUser(chat);

    return GestureDetector(
      onTap: () {
        // Navigate to private chat room using chatRoomId
        final chatRoomId = chat['chatRoomId'] as String?;
        if (chatRoomId != null && chatRoomId.isNotEmpty) {
          viewModel.initializeChatRoom(chatRoomId);
        } else {
          // Fallback to old method if no chatRoomId
          viewModel.enterChatRoom(chat);
        }
      },
      onLongPress:
          isCreatedByUser
              ? () {
                // Show delete confirmation dialog for groups created by user
                _showDeleteGroupDialog(context, viewModel, chat);
              }
              : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          color: AppColors.onPrimary.withOpacity(0.3),
          border: Border.all(
            // Different border color for created vs joined groups
            color:
                isCreatedByUser
                    ? AppColors.accent.withOpacity(0.5)
                    : AppColors.white.withOpacity(0.2),
            width: isCreatedByUser ? 2 : AppDimensions.dividerThickness,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon section - use different icons for created vs joined
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      // Different background color for created vs joined
                      color:
                          isCreatedByUser
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isCreatedByUser ? Icons.group_add : Icons.group,
                        color:
                            isCreatedByUser
                                ? AppColors.accent
                                : AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ),
                ),

                // Text section
                Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingS),
                  child: Column(
                    children: [
                      ResponsiveTextWidget(
                        chat['name'] ?? AppStrings.chatName,
                        textAlign: TextAlign.center,
                        fontSize: AppDimensions.textM,
                        textType: TextType.caption,
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chat['lastMessage'] != null &&
                          (chat['lastMessage'] as String).isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spaceXS),
                        ResponsiveTextWidget(
                          chat['lastMessage'] as String,
                          textAlign: TextAlign.center,
                          fontSize: AppDimensions.textS,
                          textType: TextType.caption,
                          color: AppColors.white.withOpacity(0.7),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Badge indicator in top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button for created groups
                  if (isCreatedByUser)
                    GestureDetector(
                      onTap:
                          () =>
                              _showDeleteGroupDialog(context, viewModel, chat),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  if (isCreatedByUser) const SizedBox(width: 4),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceXS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCreatedByUser
                              ? AppColors.accent
                              : AppColors.primary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCreatedByUser ? Icons.star : Icons.person_add,
                          size: 12,
                          color: AppColors.black,
                        ),
                        const SizedBox(width: 4),
                        ResponsiveTextWidget(
                          isCreatedByUser ? 'Created' : 'Joined',
                          textType: TextType.caption,
                          fontSize: 10,
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Column(
        children: [
          // Top row - two cards side by side
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  context,
                  AppStrings.lunaNews,
                  AppAssets.news,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.news),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceM),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String imagePath, {
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppDimensions.imageXXL,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.cover)),

              // Background layer at the bottom (30% height)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: AppDimensions.imageXXL * 0.3, // 30% of container height
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.6),
                  ),
                ),
              ),

              // Centered text within background layer
              Positioned(
                bottom: AppDimensions.paddingM,
                left: 0,
                right: 0,
                child: Center(
                  child: ResponsiveTextWidget(
                    title,
                    textType: TextType.heading,
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatRoomAppBar(BuildContext context, ChatViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(color: Color(0xFFFC2E95)),
      child: Row(
        children: [
          CustomBackButton(
            onTap: () {
              // Exit chat room and return to chat list view (public/private tabs)
              viewModel.exitChatRoom();
            },
          ),
          Expanded(
            child: Center(
              child: ResponsiveTextWidget(
                viewModel.currentChatRoom?['name'] ??
                    AppStrings.lunaCommunityRoom,
                textType: TextType.body,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Add a spacer to balance the back button
          const SizedBox(width: 48), // Same width as IconButton
          // IconButton(
          //   icon: const Icon(Icons.share, color: AppColors.white),
          //   onPressed: () {
          //     // Handle share action
          //   },
          // ),
          // IconButton(
          //   icon: const Icon(Icons.favorite_border, color: AppColors.white),
          //   onPressed: () {
          //     // Handle favorite action
          //   },
          // ),
          // IconButton(
          //   icon: const Icon(Icons.more_vert, color: AppColors.white),
          //   onPressed: () {
          //     // Handle more options
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildChatContent(BuildContext context, ChatViewModel viewModel) {
    if (viewModel.messages.isEmpty) {
      // Beautiful empty state - show centered message
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),

              // Title
              const ResponsiveTextWidget(
                'No messages yet',
                textType: TextType.title,
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceS),

              // Description
              const ResponsiveTextWidget(
                'Start the conversation by sending a message',
                textType: TextType.body,
                color: AppColors.black,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              // Decorative dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEmptyStateDot(),
                  const SizedBox(width: AppDimensions.spaceS),
                  _buildEmptyStateDot(isActive: true),
                  const SizedBox(width: AppDimensions.spaceS),
                  _buildEmptyStateDot(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Messages list
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

  /// Build a message bubble widget
  Widget _buildMessageBubble(
    BuildContext context,
    ChatViewModel viewModel,
    ChatMessageModel message,
  ) {
    // Check if message is from current user
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
              // User avatar (only for other users)
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.3),
                backgroundImage:
                    message.userPhotoUrl != null &&
                            message.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(message.userPhotoUrl!)
                        : null,
                child:
                    message.userPhotoUrl == null ||
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

            // Message bubble
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
              // User avatar (only for current user)
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.3),
                backgroundImage:
                    message.userPhotoUrl != null &&
                            message.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(message.userPhotoUrl!)
                        : null,
                child:
                    message.userPhotoUrl == null ||
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

  /// Build decorative dot for empty state
  Widget _buildEmptyStateDot({bool isActive = false}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
    );
  }

  /// Show delete options dialog
  void _showDeleteOptions(
    BuildContext context,
    ChatViewModel viewModel,
    ChatMessageModel message,
    bool isCurrentUser,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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

              // Delete for me option (always available)
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

              // Delete for everyone option (only for own messages)
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
                          backgroundColor:
                              success ? Colors.green.shade400 : Colors.red.shade200,
                        ),
                      );
                    }
                  },
                ),

              // Cancel option
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

  /// Show delete group confirmation dialog
  void _showDeleteGroupDialog(
    BuildContext context,
    ChatViewModel viewModel,
    Map<String, dynamic> chat,
  ) {
    final chatRoomId = chat['chatRoomId'] as String?;
    final chatName = chat['name'] as String? ?? 'this group';

    if (chatRoomId == null || chatRoomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to delete group',
            style: TextStyle(color: AppColors.black),
          ),
          backgroundColor: Colors.red.shade200,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          title: const ResponsiveTextWidget(
            'Delete Group',
            textType: TextType.title,
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          content: ResponsiveTextWidget(
            'Are you sure you want to delete "$chatName"? This will permanently delete the group and all messages. This action cannot be undone.',
            textType: TextType.body,
            color: AppColors.black,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ResponsiveTextWidget(
                'Cancel',
                textType: TextType.body,
                color: AppColors.black,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Show loading indicator
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      );
                    },
                  );
                }

                final success = await viewModel.deletePrivateChatRoom(
                  chatRoomId,
                );

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog

                  if (success) {
                    // Show toast-style snackbar with light green color
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Group deleted successfully',
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade400, // Light green
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Show error snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Failed to delete group',
                          style: TextStyle(color: AppColors.black),
                        ),
                        backgroundColor: Colors.red.shade200,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    );
                  }
                }
              },
              child: const ResponsiveTextWidget(
                'Delete',
                textType: TextType.body,
                color: AppColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputSection(BuildContext context, ChatViewModel viewModel) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        children: [
          // Input field row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: AppDimensions.imageS,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceM,
                  ),
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
                    onSubmitted: (_) => viewModel.sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingS),
              GestureDetector(
                onTap: () => viewModel.sendMessage(),
                child: Container(
                  width: AppDimensions.iconM,
                  height: AppDimensions.iconM,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: AppColors.black,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
