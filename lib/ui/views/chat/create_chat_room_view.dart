import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../core/utils/backbutton.dart';
import 'create_chat_room_view_model.dart';
import 'package:share_plus/share_plus.dart';

class CreateChatRoomView extends BaseView<CreateChatRoomViewModel> {
  const CreateChatRoomView({super.key});

  @override
  CreateChatRoomViewModel createViewModel() => CreateChatRoomViewModel();

  @override
  Widget buildView(BuildContext context, CreateChatRoomViewModel viewModel) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFC2E95),
              child: _buildAppBar(context),
            ),
            Expanded(child: _buildContent(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          const Expanded(
            child: ResponsiveTextWidget(
              AppStrings.createChatRoom,
              textAlign: TextAlign.center,
              textType: TextType.title,
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildTitleSection(context, viewModel),
          const SizedBox(height: 20),
          _buildContactsHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildContactsList(context, viewModel)),
          const SizedBox(height: 20),
          _buildSaveButton(context, viewModel),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTitleSection(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.grey200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group, color: AppColors.black, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: viewModel.titleController,
              style: const TextStyle(color: AppColors.black),
              decoration: const InputDecoration(
                hintText: AppStrings.addTitle,
                hintStyle: TextStyle(color: AppColors.grey600),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(left: 8), // 👈 left padding
              ),
              cursorColor: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsHeader() {
    return const ResponsiveTextWidget(
      AppStrings.peopleFromContacts,
      textType: TextType.body, //_OLD_STYLE_
      color: AppColors.black,
      fontWeight: FontWeight.w500,
    );
  }

  Widget _buildContactsList(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.black),
      );
    }

    return ListView(
      children: [
        // Festival contacts
        ...viewModel.festivalContactData.map(
          (contactData) =>
              _buildContactItem(context, viewModel, contactData, true),
        ),

        // Non-festival contacts
        ...viewModel.nonFestivalContactData.map(
          (contactData) =>
              _buildContactItem(context, viewModel, contactData, false),
        ),
      ],
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
    Map<String, dynamic> contactData,
    bool isFestivalContact,
  ) {
    final contactId = contactData['id'] ?? '';
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
                  isFestivalContact ? AppStrings.iAmUsingLuna : phoneNumber,
                  textType: TextType.body, //_OLD_STYLE_
                  color:
                      isFestivalContact ? AppColors.grey600 : AppColors.grey700,
                ),
              ],
            ),
          ),
          if (isFestivalContact)
            _buildSelectionButton(context, viewModel, contactId)
          else
            _buildInviteButton(context, viewModel, displayName, phoneNumber),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final colors = [
      AppColors.avatarPurple,
      AppColors.avatarOrange,
      AppColors.avatarGrey,
      AppColors.avatarYellow,
      AppColors.avatarBlue,
      AppColors.avatarPink,
    ];

    final colorIndex = name.hashCode % colors.length;
    final color = colors[colorIndex];

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
    CreateChatRoomViewModel viewModel,
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
        child:
            isSelected
                ? const Icon(Icons.check, color: AppColors.black, size: 16)
                : null,
      ),
    );
  }

  Widget _buildInviteButton(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
    String name,
    String phoneNumber,
  ) {
    return GestureDetector(
      onTap: () => viewModel.inviteContact(name, phoneNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error),
        ),
        child: const ResponsiveTextWidget(
          AppStrings.invite,
          textType: TextType.caption,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          final festival = context.read<FestivalProvider>().selectedFestival;
          viewModel.createChatRoom(
            festivalId: festival?.id.toString(),
            festivalTitle: festival?.title,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const ResponsiveTextWidget(
          AppStrings.save,
          textType: TextType.body,
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
