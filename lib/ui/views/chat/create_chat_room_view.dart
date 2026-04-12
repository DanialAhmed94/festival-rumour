import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/festival_provider.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import 'create_chat_room_view_model.dart';

class CreateChatRoomView extends BaseView<CreateChatRoomViewModel> {
  const CreateChatRoomView({super.key});

  @override
  CreateChatRoomViewModel createViewModel() => CreateChatRoomViewModel();

  @override
  Widget buildView(BuildContext context, CreateChatRoomViewModel viewModel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          !viewModel.searchFocusNode.hasFocus &&
          viewModel.searchQuery.isEmpty) {
        viewModel.searchFocusNode.requestFocus();
      }
    });

    return GestureDetector(
      onTap: () => viewModel.unfocusSearch(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.screenBackground,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: _buildAppBar(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildTitleSection(context, viewModel),
                      const SizedBox(height: 16),
                      if (viewModel.selectedUsers.isNotEmpty) ...[
                        _buildSelectedChips(context, viewModel),
                        const SizedBox(height: 12),
                      ],
                      const ResponsiveTextWidget(
                        'Search members',
                        textType: TextType.body,
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      const SizedBox(height: 8),
                      _buildSearchBar(context, viewModel),
                      const SizedBox(height: 8),
                      Expanded(child: _buildSearchBody(context, viewModel)),
                      const SizedBox(height: 16),
                      _buildSaveButton(context, viewModel),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
          CustomBackButton(onTap: () => Navigator.pop(context)),
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
          const SizedBox(width: 48),
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
                contentPadding: EdgeInsets.only(left: 8),
              ),
              cursorColor: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.selectedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final u = viewModel.selectedUsers[index];
          final name = u['displayName'] as String? ?? AppStrings.unknown;
          final id = u['userId'] as String? ?? '';
          return Chip(
            label: Text(
              name,
              style: const TextStyle(fontSize: 13, color: AppColors.black),
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted:
                id.isEmpty ? null : () => viewModel.removeSelectedUser(id),
            backgroundColor: AppColors.grey200,
            side: const BorderSide(color: AppColors.grey300),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      height: context.getConditionalButtonSize(),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
      ),
      child: Row(
        children: [
          SizedBox(width: context.getConditionalSpacing()),
          Icon(
            Icons.search,
            color: AppColors.black54,
            size: context.getConditionalIconSize(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          Expanded(
            child: TextField(
              controller: viewModel.searchController,
              focusNode: viewModel.searchFocusNode,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                hintStyle: TextStyle(
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w600,
                  fontSize: context.getConditionalSubFont(),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
                fontSize: context.getConditionalSubFont(),
              ),
              cursorColor: AppColors.black,
              onChanged: viewModel.searchUsers,
              onSubmitted: (_) => viewModel.unfocusSearch(),
              textInputAction: TextInputAction.search,
            ),
          ),
          SizedBox(
            width: context.getConditionalIconSize(),
            child:
                viewModel.searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.black54,
                        size: context.getConditionalIconSize(),
                      ),
                      onPressed: () {
                        viewModel.clearSearch();
                        FocusScope.of(context).unfocus();
                      },
                    )
                    : const SizedBox.shrink(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
        ],
      ),
    );
  }

  Widget _buildSearchBody(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    if (viewModel.busy) {
      return const Center(child: LoadingWidget(color: AppColors.black));
    }

    if (viewModel.searchQuery.isEmpty) {
      if (viewModel.hasRecentSearches) {
        return _buildRecentSearches(context, viewModel);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.black54),
            SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'Search for users by name, email, or phone',
              textType: TextType.body,
              fontSize: context.getConditionalSubFont(),
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (viewModel.hasNoResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: AppColors.black54),
            SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'No users found',
              textType: TextType.body,
              fontSize: context.getConditionalSubFont(),
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDimensions.spaceXS),
            ResponsiveTextWidget(
              'Try a different search term',
              textType: TextType.caption,
              fontSize: context.getConditionalFont(),
              color: AppColors.black,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: viewModel.searchResults.length,
      separatorBuilder:
          (_, __) => Divider(
            height: 1,
            color: AppColors.grey300,
            indent: AppDimensions.spaceXL * 2,
          ),
      itemBuilder: (context, index) {
        final user = viewModel.searchResults[index];
        return _buildUserRow(context, viewModel, user);
      },
    );
  }

  Widget _buildUserRow(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
    Map<String, dynamic> user,
  ) {
    final userId = user['userId'] as String;
    final displayName = user['displayName'] as String? ?? 'Unknown User';
    final photoUrl = user['photoUrl'] as String?;
    final email = user['email'] as String? ?? '';
    final selected = viewModel.isUserSelected(userId);

    return Material(
      color: AppColors.grey200,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: InkWell(
        onTap: () => viewModel.toggleUserSelection(user),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(
              color: AppColors.grey300,
              width: AppDimensions.dividerThickness,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: context.getConditionalIconSize() * 0.9,
                backgroundColor: AppColors.grey300,
                backgroundImage:
                    photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                child:
                    photoUrl == null || photoUrl.isEmpty
                        ? Icon(
                          Icons.person,
                          color: AppColors.black,
                          size: context.getConditionalIconSize(),
                        )
                        : null,
              ),
              SizedBox(width: context.getConditionalSpacing()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveTextWidget(
                      displayName,
                      textType: TextType.body,
                      fontSize: context.getConditionalSubFont(),
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      SizedBox(height: AppDimensions.spaceXS),
                      ResponsiveTextWidget(
                        email,
                        textType: TextType.caption,
                        fontSize: context.getConditionalSubFont() * 0.9,
                        color: AppColors.grey600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _buildCheckbox(selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(bool selected) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.grey400,
          width: 2,
        ),
      ),
      child:
          selected
              ? const Icon(Icons.check, color: AppColors.black, size: 16)
              : null,
    );
  }

  Widget _buildRecentSearches(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ResponsiveTextWidget(
                'Recent Searches',
                textType: TextType.title,
                fontSize: context.getConditionalSubFont(),
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
              if (viewModel.recentSearches.isNotEmpty)
                InkWell(
                  onTap: () => viewModel.clearRecentSearches(),
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spaceXS),
                    child: ResponsiveTextWidget(
                      'Clear',
                      textType: TextType.caption,
                      fontSize: context.getConditionalFont(),
                      color: AppColors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...viewModel.recentSearches.map(
          (q) => _buildRecentItem(context, viewModel, q),
        ),
      ],
    );
  }

  Widget _buildRecentItem(
    BuildContext context,
    CreateChatRoomViewModel viewModel,
    String query,
  ) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        viewModel.searchFromRecent(query);
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: AppColors.grey200,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: AppColors.grey300,
            width: AppDimensions.dividerThickness,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: AppColors.black54,
              size: context.getConditionalIconSize() * 0.8,
            ),
            SizedBox(width: context.getConditionalSpacing()),
            Expanded(
              child: ResponsiveTextWidget(
                query,
                textType: TextType.body,
                fontSize: context.getConditionalSubFont(),
                color: AppColors.black,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.black,
              size: context.getConditionalIconSize() * 0.6,
            ),
          ],
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
        onPressed:
            viewModel.isLoading
                ? null
                : () {
                  final festival =
                      context.read<FestivalProvider>().selectedFestival;
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
        child:
            viewModel.isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.black,
                  ),
                )
                : const ResponsiveTextWidget(
                  AppStrings.save,
                  textType: TextType.body,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
      ),
    );
  }
}
