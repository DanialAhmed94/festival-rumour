import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/festivals_tab.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/followers_tab.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/following_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/backbutton.dart';
import '../../../../core/utils/base_view.dart';
import '../../../../shared/widgets/responsive_text_widget.dart';
import 'profile_list_view_model.dart';


class ProfileListView extends BaseView<ProfileListViewModel> {
  final int initialTab; // 0 = Followers, 1 = Following, 2 = Festivals
  final String Username;
  final String? userId; // User ID whose followers/following we're viewing
  final VoidCallback? onBack;

  const ProfileListView({
    super.key,
    required this.initialTab,
    required this.Username,
    this.userId,
    this.onBack,
  });

  @override
  ProfileListViewModel createViewModel() => ProfileListViewModel();

  @override
  void onViewModelReady(ProfileListViewModel viewModel) {
    super.onViewModelReady(viewModel);
    if (kDebugMode) {
      print('🔍 [ProfileListView.onViewModelReady] Called');
      print('   userId from constructor: $userId');
      print('   initialTab: $initialTab');
      print('   Username: $Username');
    }
    viewModel.initialize(userId);
    viewModel.setTab(initialTab);
    
    // If festivals tab is selected initially, load festivals
    if (initialTab == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Use a small delay to ensure context is available
        Future.delayed(const Duration(milliseconds: 100), () {
          if (viewModel.currentTab == 2 && !viewModel.isLoadingFestivals) {
            // Get context from the view - we'll need to pass it
            // Actually, we need to do this in buildView where we have context
          }
        });
      });
    }
  }

  @override
  Widget buildView(BuildContext context, ProfileListViewModel viewModel) {
    // Load festivals if festivals tab is selected and not loaded yet
    // This handles both initial load (initialTab == 2) and when switching to festivals tab
    if (viewModel.currentTab == 2 && 
        !viewModel.hasLoadedFestivals && 
        !viewModel.isLoadingFestivals) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check conditions before loading to prevent race conditions
        if (viewModel.currentTab == 2 && 
            !viewModel.hasLoadedFestivals && 
            !viewModel.isLoadingFestivals) {
          if (kDebugMode) {
            print('🔄 [ProfileListView.buildView] Loading festivals for initialTab: $initialTab');
          }
          viewModel.loadFavoriteFestivals(context);
        }
      });
    }
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          /// 🔹 Background
          Positioned.fill(
            child: Image.asset(
              AppAssets.bottomsheet,
              fit: BoxFit.cover,
            ),
          ),

          /// 🔹 Foreground UI
          SafeArea(
            child: Column(
              children: [
                /// 🔹 App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingM),
                  child: Row(
                    children: [
                      CustomBackButton(onTap: () {
                        if (onBack != null) {
                          onBack!();
                        } else {
                          Navigator.pop(context);
                        }
                      }),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.white),
                        onPressed: () => viewModel.refreshList(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.paddingS),

                /// 🔹 Tabs Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: AppStrings.followers,
                        isActive: viewModel.currentTab == 0,
                        onTap: () => viewModel.setTab(0),
                      ),
                      _buildTabButton(
                        label: AppStrings.following,
                        isActive: viewModel.currentTab == 1,
                        onTap: () => viewModel.setTab(1),
                      ),
                      _buildTabButton(
                        label: AppStrings.festivals,
                        isActive: viewModel.currentTab == 2,
                        onTap: () {
                          viewModel.setTab(2);
                          // Load favorite festivals when festivals tab is selected
                          // Only load if not already loaded (prevents infinite loop on empty search results)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            viewModel.loadFavoriteFestivals(context);
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.paddingS),

                /// 🔹 Tab View
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildTabView(viewModel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(ProfileListViewModel viewModel) {
    switch (viewModel.currentTab) {
      case 0:
        return FollowersTab(viewModel: viewModel);
      case 1:
        return FollowingTab(viewModel: viewModel);
      case 2:
        return FestivalsTab(viewModel: viewModel);
      default:
        return FollowersTab(viewModel: viewModel);
    }
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXL, vertical: AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.onPrimary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: ResponsiveTextWidget(
            label,
            textType: TextType.body,
              color: isActive ? AppColors.onPrimary : AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
  }
}
