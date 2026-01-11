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
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            /// Background
            Positioned.fill(
              child: Image.asset(
                AppAssets.bottomsheet,
                fit: BoxFit.cover,
              ),
            ),
            
            /// Content
            SafeArea(
              child: Column(
                children: [
                  /// Header with Search Bar
                  _buildHeader(context, viewModel),
                  
                  /// Search Results
                  Expanded(
                    child: _buildSearchResults(context, viewModel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- HEADER WITH SEARCH BAR ----------------
  Widget _buildHeader(BuildContext context, SearchUsersViewModel viewModel) {
    return Padding(
      padding: context.responsivePadding,
      child: Column(
        children: [
          /// Top Bar with Back Button and Title
          Row(
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
              ResponsiveTextWidget(
                'Search Users',
                textType: TextType.title,
                fontSize: context.getConditionalMainFont(),
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          
          SizedBox(height: AppDimensions.spaceM),
          
          /// Search Bar
          _buildSearchBar(context, viewModel),
        ],
      ),
    );
  }

  /// ---------------- SEARCH BAR ----------------
  Widget _buildSearchBar(BuildContext context, SearchUsersViewModel viewModel) {
    return Container(
      padding: context.responsivePadding,
      height: context.getConditionalButtonSize(),
      decoration: BoxDecoration(
        color: AppColors.onPrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
      ),
      child: Row(
        children: [
          SizedBox(width: context.getConditionalSpacing()),
          // Search icon
          Icon(
            Icons.search, 
            color: AppColors.onSurfaceVariant, 
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
                  color: AppColors.primary,
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
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: context.getConditionalSubFont(),
              ),
              cursorColor: AppColors.primary,
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
                      color: AppColors.primary, 
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
        child: LoadingWidget(),
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
              color: AppColors.white,
            ),
            SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'Search for users by name or email',
              textType: TextType.body,
              fontSize: context.getConditionalSubFont(),
              color: AppColors.white,
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
              color: AppColors.white,
            ),
            SizedBox(height: AppDimensions.spaceM),
            ResponsiveTextWidget(
              'No users found',
              textType: TextType.body,
              fontSize: context.getConditionalSubFont(),
              color: AppColors.white,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDimensions.spaceXS),
            ResponsiveTextWidget(
              'Try a different search term',
              textType: TextType.caption,
              fontSize: context.getConditionalFont(),
              color: AppColors.white,
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
                color: AppColors.white,
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
                        color: AppColors.white,
                        size: context.getConditionalIconSize() * 0.8,
                      ),
                      SizedBox(width: AppDimensions.spaceXS),
                      ResponsiveTextWidget(
                        'Clear',
                        textType: TextType.caption,
                        fontSize: context.getConditionalFont(),
                        color: AppColors.white,
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
              color: AppColors.white.withOpacity(0.2),
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppDimensions.spaceM,
          horizontal: AppDimensions.spaceS,
        ),
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: context.getConditionalIconSize() * 0.9,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: AppColors.primary,
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
                    color: AppColors.white,
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
                      color: AppColors.white.withOpacity(0.7),
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
                      color: AppColors.white.withOpacity(0.6),
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
              color: AppColors.white,
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
                color: AppColors.white,
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
                      color: AppColors.white,
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppDimensions.spaceM,
          horizontal: AppDimensions.spaceS,
        ),
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: AppColors.white.withOpacity(0.6),
              size: context.getConditionalIconSize() * 0.8,
            ),
            SizedBox(width: context.getConditionalSpacing()),
            Expanded(
              child: ResponsiveTextWidget(
                searchQuery,
                textType: TextType.body,
                fontSize: context.getConditionalSubFont(),
                color: AppColors.white,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: context.getConditionalSpacing()),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.white,
              size: context.getConditionalIconSize() * 0.6,
            ),
          ],
        ),
      ),
    );
  }
}
