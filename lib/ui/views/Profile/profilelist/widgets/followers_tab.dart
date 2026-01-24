import 'package:festival_rumour/shared/widgets/responsive_widget.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/router/app_router.dart';
import '../profile_list_view_model.dart';

class FollowersTab extends StatelessWidget {
  final ProfileListViewModel viewModel;
  const FollowersTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🔹 Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
          child: TextField(
            style: const TextStyle(color: AppColors.black),
            cursorColor: AppColors.black,
            decoration: InputDecoration(
              hintText: AppStrings.searchFollowers,
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
            onChanged: viewModel.searchFollowers,
          ),
        ),

        /// 🔹 List
        Expanded(
          child: viewModel.followers.isEmpty && !viewModel.isLoadingInitialFollowers
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingXL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.black54,
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        ResponsiveText(
                          'No followers yet',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: AppDimensions.textL,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : viewModel.isLoadingInitialFollowers
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.black),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                      itemCount: viewModel.followers.length + (viewModel.hasMoreFollowers ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Load more indicator
                        if (index == viewModel.followers.length) {
                          if (viewModel.isLoadingMoreFollowers) {
                            return const Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingM),
                              child: Center(child: CircularProgressIndicator(color: AppColors.black)),
                            );
                          }
                          // Trigger load more when reaching the end
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            viewModel.loadFollowers(loadMore: true);
                          });
                          return const SizedBox.shrink();
                        }

                    final follower = viewModel.followers[index];
              final photoUrl = follower['photoUrl'] as String? ?? follower['image'] as String? ?? '';
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
                            follower['name'] ?? 'Unknown User',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: AppDimensions.textL,
                            //  fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceXS),
                          ResponsiveText(
                            follower['username'] ?? '',
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
                        // Remove user from followers list
                        viewModel.removeFollower(follower);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                        minimumSize: Size(0, AppDimensions.buttonHeightM),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                        ),
                      ),
                      child: const ResponsiveText(
                        'Unfollow',
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
                      onSelected: (value) {
                        if (value == 'Message') {
                          // Navigate to chat view
                          Navigator.pushNamed(context, AppRoutes.chat);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'Message',
                          child: ResponsiveText(
                            'Message',
                            style: TextStyle(
                              fontSize: AppDimensions.textM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
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
