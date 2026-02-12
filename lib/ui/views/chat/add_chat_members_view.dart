import 'package:flutter/material.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/utils/backbutton.dart';
import 'add_chat_members_view_model.dart';

class AddChatMembersView extends BaseView<AddChatMembersViewModel> {
  const AddChatMembersView({super.key});

  @override
  AddChatMembersViewModel createViewModel() => AddChatMembersViewModel();

  @override
  void onViewModelReady(AddChatMembersViewModel viewModel) {
    super.onViewModelReady(viewModel);
  }

  @override
  Widget buildView(BuildContext context, AddChatMembersViewModel viewModel) {
    if (viewModel.chatRoomId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final chatRoomId = args['chatRoomId'] as String?;
        final currentMemberIds = (args['currentMemberIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
        if (chatRoomId != null && chatRoomId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (viewModel.chatRoomId == null) {
              viewModel.setArgs(chatRoomId: chatRoomId, currentMemberIds: currentMemberIds);
            }
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            if (viewModel.errorMessage != null && viewModel.errorMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: Color(0xFFB00020), fontSize: 14),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ResponsiveTextWidget(
                  AppStrings.peopleFromContacts,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildContactsList(context, viewModel)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: viewModel.isLoading ? null : () => viewModel.addMembersToRoom(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: viewModel.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : const ResponsiveTextWidget(
                          'Add to room',
                          textType: TextType.body,
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFC2E95),
      child: ResponsivePadding(
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
            CustomBackButton(onTap: () => Navigator.pop(context)),
            SizedBox(width: context.getConditionalSpacing()),
            const Expanded(
              child: ResponsiveTextWidget(
                'Add members',
                textAlign: TextAlign.center,
                textType: TextType.title,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(BuildContext context, AddChatMembersViewModel viewModel) {
    final appContacts = viewModel.allContactsForDisplay;
    final nonAppContacts = viewModel.nonFestivalContactData;
    final totalCount = appContacts.length + nonAppContacts.length;

    if (totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ResponsiveTextWidget(
            viewModel.isLoading
                ? 'Loading...'
                : 'No contacts found. Grant contacts permission to see app users and invite others.',
            textType: TextType.body,
            color: AppColors.grey600,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < appContacts.length) {
          return _buildContactItem(context, viewModel, appContacts[index]);
        }
        final contactData = nonAppContacts[index - appContacts.length];
        return _buildNonAppContactItem(context, viewModel, contactData);
      },
    );
  }

  Widget _buildNonAppContactItem(
    BuildContext context,
    AddChatMembersViewModel viewModel,
    Map<String, dynamic> contactData,
  ) {
    final displayName = contactData['name'] ?? AppStrings.unknown;
    final phoneNumber = contactData['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          _buildAvatar(displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                ResponsiveTextWidget(
                  phoneNumber.isNotEmpty ? phoneNumber : 'No phone number',
                  textType: TextType.body,
                  color: AppColors.grey600,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => viewModel.inviteContact(displayName, phoneNumber),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.invite,
                textType: TextType.caption,
                color: AppColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    AddChatMembersViewModel viewModel,
    Map<String, dynamic> contactData,
  ) {
    final contactId = contactData['id'] ?? '';
    final displayName = contactData['name'] ?? AppStrings.unknown;
    final isAlreadyInRoom = contactData['isAlreadyInRoom'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlreadyInRoom ? AppColors.grey100.withOpacity(0.7) : AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          _buildAvatar(displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  displayName,
                  style: TextStyle(
                    color: isAlreadyInRoom ? AppColors.grey600 : AppColors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                ResponsiveTextWidget(
                  isAlreadyInRoom ? 'Already in room' : AppStrings.iAmUsingLuna,
                  textType: TextType.body,
                  color: AppColors.grey600,
                ),
              ],
            ),
          ),
          if (isAlreadyInRoom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const ResponsiveTextWidget(
                'In room',
                textType: TextType.caption,
                color: AppColors.grey600,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            _buildSelectionButton(context, viewModel, contactId),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    const colors = [
      AppColors.avatarPurple,
      AppColors.avatarOrange,
      AppColors.avatarGrey,
      AppColors.avatarYellow,
      AppColors.avatarBlue,
      AppColors.avatarPink,
    ];
    final color = colors[name.hashCode % colors.length];
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Center(
        child: ResponsiveTextWidget(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButton(
    BuildContext context,
    AddChatMembersViewModel viewModel,
    String contactId,
  ) {
    final isSelected = viewModel.isContactSelected(contactId);
    return GestureDetector(
      onTap: () => viewModel.toggleContactSelection(contactId),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.grey400,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: AppColors.black, size: 16)
            : null,
      ),
    );
  }
}
