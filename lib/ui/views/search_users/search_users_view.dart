import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/widgets/responsive_widget.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../core/constants/app_assets.dart';
import 'search_users_view_model.dart';

class SearchUsersView extends BaseView<SearchUsersViewModel> {
  final VoidCallback? onBack;
  const SearchUsersView({super.key, this.onBack});

  @override
  SearchUsersViewModel createViewModel() => SearchUsersViewModel();

  @override
  void onViewModelReady(SearchUsersViewModel viewModel) {
    super.onViewModelReady(viewModel);
    // Auto-focus will be handled in buildView
  }

  @override
  Widget buildView(BuildContext context, SearchUsersViewModel viewModel) {
    // Auto-focus search field when screen loads (only if route is current/visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && 
          ModalRoute.of(context)?.isCurrent == true &&
          !viewModel.searchFocusNode.hasFocus &&
          viewModel.searchQuery.isEmpty) {
        // Only auto-focus if:
        // 1. Context is mounted
        // 2. This route is currently active (not in background)
        // 3. Field doesn't already have focus
        // 4. Search query is empty (fresh state)
        viewModel.searchFocusNode.requestFocus();
      }
    });
    
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        viewModel.unfocusSearch();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              /// App Bar
              Container(
                width: double.infinity,
                color: const Color(0xFFFC2E95),
                child: _buildAppBar(context, viewModel),
              ),
              
              /// Search Bar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsivePadding.horizontal,
                  vertical: AppDimensions.spaceM,
                ),
                child: _buildSearchBar(context, viewModel),
              ),
              
              /// Search Results
              Expanded(
                child: _buildSearchResults(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- APP BAR ---------------- 
  Widget _buildAppBar(BuildContext context, SearchUsersViewModel viewModel) {
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
            onTap: () {
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          SizedBox(width: context.getConditionalSpacing()),
          Expanded(
            child: ResponsiveTextWidget(
              'Search Users',
              textType: TextType.title,
              fontSize: context.getConditionalMainFont(),
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  /// ---------------- SEARCH BAR ---------------- 
  Widget _buildSearchBar(BuildContext context, SearchUsersViewModel viewModel) {
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
          // Search icon
          Icon(
            Icons.search, 
            color: AppColors.black54, 
            size: context.getConditionalIconSize(),
          ),
          SizedBox(width: context.getConditionalSpacing()),
          // Search Field
          Expanded(
            child: TextField(
              controller: viewModel.searchController,
              focusNode: viewModel.searchFocusNode,
              textAlignVertical: TextAlignVertical.center,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w600,
                  fontSize: context.getConditionalSubFont(),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
                fontSize: context.getConditionalSubFont(),
              ),
              cursorColor: AppColors.black,
              onChanged: (value) {
                viewModel.searchUsers(value);
              },
              onSubmitted: (value) {
                viewModel.unfocusSearch();
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          // Search Clear Button
          SizedBox(
            width: context.getConditionalIconSize(),
            child: viewModel.searchQuery.isNotEmpty
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

  /// ---------------- SEARCH RESULTS ----------------
  Widget _buildSearchResults(BuildContext context, SearchUsersViewModel viewModel) {
    if (viewModel.busy) {
      return const Center(
        child: LoadingWidget(color: AppColors.black),
      );
    }

    if (viewModel.searchQuery.isEmpty) {
      // Show recent searches if available
      if (viewModel.hasRecentSearches) {
        return _buildRecentSearches(context, viewModel);
      }
      
      // Otherwise show empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.black54,
            ),
            SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'Search for users by name or email',
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
            Icon(
              Icons.person_off,
              size: 64,
              color: AppColors.black54,
            ),
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

    if (!viewModel.hasSearchResults) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Clear search results button
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsivePadding.horizontal,
            vertical: AppDimensions.spaceS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ResponsiveTextWidget(
                'Search Results',
                textType: TextType.title,
                fontSize: context.getConditionalSubFont(),
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
              InkWell(
                onTap: () {
                  viewModel.clearSearch();
                  FocusScope.of(context).unfocus();
                },
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.spaceXS),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.clear,
                        color: AppColors.black,
                        size: context.getConditionalIconSize() * 0.8,
                      ),
                      SizedBox(width: AppDimensions.spaceXS),
                      ResponsiveTextWidget(
                        'Clear',
                        textType: TextType.caption,
                        fontSize: context.getConditionalFont(),
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search results list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsivePadding.horizontal,
              vertical: AppDimensions.spaceS,
            ),
            itemCount: viewModel.searchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.grey300,
              indent: AppDimensions.spaceXL * 2,
            ),
            itemBuilder: (context, index) {
              final user = viewModel.searchResults[index];
              return _buildUserListItem(context, viewModel, user);
            },
          ),
        ),
      ],
    );
  }

  /// ---------------- USER LIST ITEM ----------------
  Widget _buildUserListItem(
    BuildContext context,
    SearchUsersViewModel viewModel,
    Map<String, dynamic> user,
  ) {
    final userId = user['userId'] as String;
    final displayName = user['displayName'] as String? ?? 'Unknown User';
    final photoUrl = user['photoUrl'] as String?;
    final email = user['email'] as String? ?? '';
    final bio = user['bio'] as String?;
    
    return InkWell(
      onTap: () async {
        // Dismiss keyboard immediately before navigation
        FocusScope.of(context).unfocus();
        viewModel.unfocusSearch();
        // Small delay to ensure keyboard is dismissed
        await Future.delayed(const Duration(milliseconds: 150));
        if (context.mounted) {
          viewModel.navigateToUserProfile(context, userId);
        }
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
            // User avatar
            CircleAvatar(
              radius: context.getConditionalIconSize() * 0.9,
              backgroundColor: AppColors.grey300,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: AppColors.black,
                      size: context.getConditionalIconSize(),
                    )
                  : null,
            ),
            SizedBox(width: context.getConditionalSpacing()),
            // User details
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
                  if (bio != null && bio.isNotEmpty) ...[
                    SizedBox(height: AppDimensions.spaceXS),
                    ResponsiveTextWidget(
                      bio,
                      textType: TextType.caption,
                      fontSize: context.getConditionalSubFont() * 0.85,
                      color: AppColors.grey600,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: context.getConditionalSpacing()),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.black,
              size: context.getConditionalIconSize() * 0.7,
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- RECENT SEARCHES ----------------
  Widget _buildRecentSearches(BuildContext context, SearchUsersViewModel viewModel) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsivePadding.horizontal,
        vertical: AppDimensions.spaceS,
      ),
      children: [
        // Header
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
                  onTap: () {
                    viewModel.clearRecentSearches();
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
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
        
        // Recent search items
        ...viewModel.recentSearches.map((searchQuery) => _buildRecentSearchItem(
          context,
          viewModel,
          searchQuery,
        )),
      ],
    );
  }

  /// ---------------- RECENT SEARCH ITEM ----------------
  Widget _buildRecentSearchItem(
    BuildContext context,
    SearchUsersViewModel viewModel,
    String searchQuery,
  ) {
    return InkWell(
      onTap: () {
        // Dismiss keyboard when tapping recent search
        FocusScope.of(context).unfocus();
        viewModel.searchFromRecent(searchQuery);
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
                searchQuery,
                textType: TextType.body,
                fontSize: context.getConditionalSubFont(),
                color: AppColors.black,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: context.getConditionalSpacing()),
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
}
