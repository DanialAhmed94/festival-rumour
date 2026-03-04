import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/attended_festivals_tab.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/festivals_tab.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/followers_tab.dart';
import 'package:festival_rumour/ui/views/Profile/profilelist/widgets/following_tab.dart';
import 'package:festival_rumour/ui/views/festival/festival_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/backbutton.dart';
import '../../../../core/utils/base_view.dart';
import '../../../../shared/widgets/responsive_text_widget.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import 'profile_list_view_model.dart';

/// Called when user taps a festival in Favourite or Attended list: (context, festival).
typedef OnFestivalSelected = void Function(BuildContext context, FestivalModel festival);

class ProfileListView extends BaseView<ProfileListViewModel> {
  final int initialTab; // 0 = Followers, 1 = Following, 2 = Favourite Festivals, 3 = Attended festivals
  final String Username;
  final String? userId; // User ID whose followers/following we're viewing
  final VoidCallback? onBack;
  final OnFestivalSelected? onFestivalSelected;
  final GlobalKey _selectedTabKey = GlobalKey();

  ProfileListView({
    super.key,
    required this.initialTab,
    required this.Username,
    this.userId,
    this.onBack,
    this.onFestivalSelected,
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
  }

  @override
  Widget buildView(BuildContext context, ProfileListViewModel viewModel) {
    // Load festivals if festivals tab is selected and not loaded yet
    if (viewModel.currentTab == 2 && 
        !viewModel.hasLoadedFestivals && 
        !viewModel.isLoadingFestivals) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    // Load attended festivals if Attended tab is selected and not loaded yet
    if (viewModel.currentTab == 3 && 
        !viewModel.hasLoadedAttended && 
        !viewModel.isLoadingAttended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (viewModel.currentTab == 3 && 
            !viewModel.hasLoadedAttended && 
            !viewModel.isLoadingAttended) {
          if (kDebugMode) {
            print('🔄 [ProfileListView.buildView] Loading attended festivals for tab 3');
          }
          viewModel.loadAttendedFestivals();
        }
      });
    }

    // Scroll tab bar so the selected tab (opened from profile counter) is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedTabKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
    
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            /// 🔹 App Bar
            Container(
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
            ),

            const SizedBox(height: AppDimensions.paddingS),

            /// 🔹 Tabs Row — scroll so selected tab is visible when opened from profile counter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _buildTabButton(
                    key: initialTab == 0 ? _selectedTabKey : null,
                    label: AppStrings.followers,
                    isActive: viewModel.currentTab == 0,
                    onTap: () => viewModel.setTab(0),
                  ),
                  _buildTabButton(
                    key: initialTab == 1 ? _selectedTabKey : null,
                    label: AppStrings.following,
                    isActive: viewModel.currentTab == 1,
                    onTap: () => viewModel.setTab(1),
                  ),
                  _buildTabButton(
                    key: initialTab == 2 ? _selectedTabKey : null,
                    label: 'Favourite Festivals',
                    isActive: viewModel.currentTab == 2,
                    onTap: () {
                      viewModel.setTab(2);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (viewModel.currentTab == 2 && 
                            !viewModel.hasLoadedFestivals && 
                            !viewModel.isLoadingFestivals) {
                          viewModel.loadFavoriteFestivals(context);
                        }
                      });
                    },
                  ),
                  _buildTabButton(
                    key: initialTab == 3 ? _selectedTabKey : null,
                    label: 'Attended festivals',
                    isActive: viewModel.currentTab == 3,
                    onTap: () => viewModel.setTab(3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.paddingS),

            /// 🔹 Tab View
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildTabView(context, viewModel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView(BuildContext context, ProfileListViewModel viewModel) {
    final onFestivalTap = onFestivalSelected != null
        ? (BuildContext ctx, Map<String, dynamic> item) {
            final festival = FestivalModel.fromMap(item);
            onFestivalSelected!(ctx, festival);
          }
        : null;
    switch (viewModel.currentTab) {
      case 0:
        return FollowersTab(viewModel: viewModel);
      case 1:
        return FollowingTab(viewModel: viewModel);
      case 2:
        return FestivalsTab(viewModel: viewModel, onFestivalTap: onFestivalTap);
      case 3:
        return AttendedFestivalsTab(viewModel: viewModel, onFestivalTap: onFestivalTap);
      default:
        return FollowersTab(viewModel: viewModel);
    }
  }

  Widget _buildTabButton({
    Key? key,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXL, vertical: AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.grey200,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: ResponsiveTextWidget(
            label,
            textType: TextType.body,
              color: isActive ? AppColors.black : AppColors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
  }
}
