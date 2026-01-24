import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/router/app_router.dart';
import '../profile_list_view_model.dart';

class FollowingTab extends StatelessWidget {
  final ProfileListViewModel viewModel;
  const FollowingTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical:AppDimensions.paddingS),
          child: TextField(
            style: const TextStyle(color: AppColors.black),
            cursorColor: AppColors.black,
            decoration: InputDecoration(
              hintText: AppStrings.searchFollowing,
              hintStyle: const TextStyle(color: AppColors.grey600),
              prefixIcon: const Icon(Icons.search, color: AppColors.black54),
              filled: true,
              fillColor: AppColors.grey200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
                borderSide: const BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            onChanged: viewModel.searchFollowing,
          ),
        ),
        Expanded(
          child: viewModel.following.isEmpty && !viewModel.isLoadingInitialFollowing
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingXL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 64,
                          color: AppColors.black54,
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        ResponsiveText(
                          'Not following anyone yet',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: AppDimensions.textL,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : viewModel.isLoadingInitialFollowing
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.black),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                      itemCount: viewModel.following.length + (viewModel.hasMoreFollowing ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Load more indicator
                        if (index == viewModel.following.length) {
                          if (viewModel.isLoadingMoreFollowing) {
                            return const Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingM),
                              child: Center(child: CircularProgressIndicator(color: AppColors.black)),
                            );
                          }
                          // Trigger load more when reaching the end
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            viewModel.loadFollowing(loadMore: true);
                          });
                          return const SizedBox.shrink();
                        }

                    final following = viewModel.following[index];
              final photoUrl = following['photoUrl'] as String? ?? following['image'] as String? ?? '';
              return Container(
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
                    CircleAvatar(
                      radius: AppDimensions.avatarS,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: photoUrl.isEmpty
                          ? Image.asset(
                              AppAssets.profile,
                              width: AppDimensions.avatarS * 2,
                              height: AppDimensions.avatarS * 2,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppDimensions.paddingXS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveText(
                            following['name'] ?? 'Unknown User',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: AppDimensions.textL,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceXS),
                          ResponsiveText(
                            following['username'] ?? '',
                            style: const TextStyle(
                              color: AppColors.grey600,
                              fontSize: AppDimensions.textM,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to chat view
                        Navigator.pushNamed(context, AppRoutes.chat);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size(0, AppDimensions.buttonHeightM),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const ResponsiveText(
                        'Message',
                        style: TextStyle(
                          fontSize: AppDimensions.textM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceS),
                    PopupMenuButton<String>(
                      color: AppColors.white,
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.black,
                      ),
                      onSelected: (value) async {
                        if (value == 'unfollow') {
                          await viewModel.unfollowUser(following);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'unfollow',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove,
                                color: AppColors.red,
                                size: AppDimensions.iconS,
                              ),
                              SizedBox(width: AppDimensions.spaceS),
                              ResponsiveText(
                                AppStrings.unfollow,
                                style: TextStyle(
                                  color: AppColors.red,
                                  fontSize: AppDimensions.textM,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
