import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'settings_view_model.dart';

class SettingsView extends BaseView<SettingsViewModel> {
  final VoidCallback? onBack;
  const SettingsView({super.key, this.onBack});

  @override
  SettingsViewModel createViewModel() => SettingsViewModel();

  @override
  Widget buildView(BuildContext context, SettingsViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,

    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFC2E95),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingM,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (onBack != null) {
                      onBack!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 8),
                const ResponsiveTextWidget(
                  AppStrings.settings,
                  textType: TextType.title,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      context.isSmallScreen
                          ? AppDimensions.paddingM
                          : context.isMediumScreen
                          ? AppDimensions.paddingL
                          : AppDimensions.paddingXL,
                  vertical:
                      context.isSmallScreen
                          ? AppDimensions.paddingS
                          : context.isMediumScreen
                          ? AppDimensions.paddingM
                          : AppDimensions.paddingL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(context, viewModel),
                    const SizedBox(height: AppDimensions.paddingL),
                    /// 🔹 General Section
                    const ResponsiveTextWidget(
                      AppStrings.general,
                      textType: TextType.body,
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.textM,
                      color: AppColors.grey700,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),

                    _buildTile(
                      icon: Icons.person_outline,
                      iconColor: AppColors.amber,
                      title: AppStrings.editAccountDetails,
                      onTap: viewModel.editAccount,
                    ),
                    _buildSwitchTile(
                      icon: Icons.notifications_none,
                      iconColor: AppColors.teal,
                      title: AppStrings.notification,
                      value: viewModel.notifications,
                      onChanged: viewModel.toggleNotifications,
                      subtitle: AppStrings.enableOrDisableNotifications,
                    ),
                    _buildSwitchTile(
                      icon: Icons.lock_outline,
                      iconColor: AppColors.purple,
                      title: AppStrings.privacySettingsPro,
                      subtitle: AppStrings.includingAnonymousToggle,
                      value: viewModel.privacy,
                      onChanged:
                          (value) => _showPrivacyUpgradeDialog(context, viewModel),
                    ),
                    _buildTile(
                      icon: Icons.military_tech_outlined,
                      iconColor: AppColors.orange,
                      title: AppStrings.badges,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: AppDimensions.iconS,
                        color: AppColors.grey600,
                      ),
                      onTap: () => _showBadgesDialog(context),
                    ),
                    _buildTile(
                      icon: Icons.leaderboard_outlined,
                      iconColor: AppColors.brown,
                      title: AppStrings.leaderBoard,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: AppDimensions.iconS,
                        color: AppColors.grey600,
                      ),
                      onTap: viewModel.openLeaderboard,
                    ),
                    _buildTile(
                      icon: Icons.work_outline,
                      iconColor: AppColors.blue,
                      title: 'My Jobs',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: AppDimensions.iconS,
                        color: AppColors.grey600,
                      ),
                      onTap: viewModel.openMyJobs,
                    ),
                    _buildTile(
                      icon: Icons.add_business_outlined,
                      iconColor: AppColors.teal,
                      title: 'Create Job',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: AppDimensions.iconS,
                        color: AppColors.grey600,
                      ),
                      onTap: () => _showCreateJobBottomSheet(context),
                    ),
                    _buildTile(
                      icon: Icons.logout,
                      iconColor: AppColors.red,
                      title: AppStrings.logout,
                      titleColor: AppColors.red,
                      onTap: () => _showLogoutConfirmation(context, viewModel),
                    ),
                    _buildTile(
                      icon: Icons.delete_forever,
                      iconColor: AppColors.red,
                      title: AppStrings.deleteAccount,
                      titleColor: AppColors.red,
                      onTap: () => _showDeleteAccountConfirmation(context, viewModel),
                    ),

                    const SizedBox(height: AppDimensions.paddingL),

                    /// 🔹 Others Section
                    const ResponsiveTextWidget(
                      AppStrings.others,
                      textType: TextType.body,
                      fontWeight: FontWeight.bold,
                      fontSize: AppDimensions.textM,
                      color: AppColors.grey700,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    _buildTile(
                      icon: Icons.star_outline,
                      iconColor: AppColors.yellow,
                      title: AppStrings.rateUs,
                      onTap: () => _showRateAppDialog(context, viewModel),
                    ),
                    _buildTile(
                      icon: Icons.share_outlined,
                      iconColor: AppColors.blueAccent,
                      title: AppStrings.shareApp,
                      onTap: viewModel.shareApp,
                    ),
                    _buildTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: AppColors.pink,
                      title: AppStrings.privacyPolicy,
                      onTap: viewModel.openPrivacyPolicy,
                    ),
                    _buildTile(
                      icon: Icons.article_outlined,
                      iconColor: AppColors.deepOrange,
                      title: AppStrings.termsAndConditions,
                      onTap: viewModel.openTerms,
                    ),
                  ],
                ),
              ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, SettingsViewModel viewModel) {
    final photoUrl = viewModel.userPhotoUrl;
    final name = viewModel.userName ?? 'User';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: viewModel.navigateToProfile,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingM,
            horizontal: AppDimensions.paddingXS,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          placeholder: (_, __) => Icon(
                            Icons.person,
                            size: 32,
                            color: AppColors.grey600,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: 32,
                            color: AppColors.grey600,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.grey600,
                      ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: ResponsiveTextWidget(
                  name,
                  textType: TextType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey900,
                  fontSize: AppDimensions.textL,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: AppDimensions.iconS,
                color: AppColors.grey600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔸 Normal List Tile
  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceXS,
      ),
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.15),
        child: Icon(icon, color: iconColor),
      ),
      title: ResponsiveTextWidget(
        title,
        textType: TextType.body,
        color: titleColor ?? AppColors.grey900,
        fontWeight: FontWeight.w600,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// 🔸 Switch Tile
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spaceXS,
      ),
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.15),
        child: Icon(icon, color: iconColor),
      ),
      title: ResponsiveTextWidget(
        title,
        textType: TextType.body,
        color: AppColors.grey900,
        fontWeight: FontWeight.w600,
      ),
      subtitle:
          subtitle != null
              ? ResponsiveTextWidget(
                subtitle,
                textType: TextType.caption,
                color: AppColors.grey600,
              )
              : null,
      trailing: Switch(
        value: value,
        activeColor: Colors.black,
        onChanged: onChanged,
      ),
    );
  }

  void _showCreateJobBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.onPrimary.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    AppStrings.postJob,
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: AppDimensions.textL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildJobTile(
                image: AppAssets.job1,
                title: AppStrings.festivalGizzaJob,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.jobpost,
                    arguments: {'category': 'Festival Gizza'},
                  );
                },
              ),
              const Divider(color: AppColors.yellow, thickness: 1),
              const SizedBox(height: AppDimensions.spaceS),
              _buildJobTile(
                image: AppAssets.job2,
                title: AppStrings.festieHerosJob,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.jobpost,
                    arguments: {'category': 'Festie Heroes'},
                  );
                },
              ),
              const SizedBox(height: AppDimensions.paddingS),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobTile({
    required String image,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      image,
                      width: AppDimensions.imageM,
                      height: AppDimensions.imageM,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppDimensions.textL,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.yellow),
          ],
        ),
      ),
    );
  }

  void _showBadgesDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.screenBackground,
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(
              context.isSmallScreen
                  ? AppDimensions.paddingM
                  : context.isMediumScreen
                  ? AppDimensions.paddingL
                  : AppDimensions.paddingXL,
            ),
            constraints: BoxConstraints(
              maxWidth:
                  context.isSmallScreen
                      ? context.screenWidth * 0.9
                      : context.isMediumScreen
                      ? context.screenWidth * 0.7
                      : context.screenWidth * 0.5,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ResponsiveTextWidget(
                    AppStrings.badges,
                    textType: TextType.heading,
                    fontWeight: FontWeight.bold,
                    fontSize: AppDimensions.textL,
                    color: AppColors.onPrimary,
                  ),
                  const SizedBox(height: AppDimensions.paddingL),

                  // 🏅 Each badge item
                  _buildBadgeItem(
                    icon: Icons.emoji_events,
                    title: AppStrings.topRumourSpotter,
                    subtitle: AppStrings.topRumourSpotterDescription,
                    color: AppColors.orange,
                  ),
                  _buildBadgeItem(
                    icon: Icons.workspace_premium,
                    title: AppStrings.mediaMaster,
                    subtitle: AppStrings.mediaMasterDescription,
                    color: AppColors.purple,
                  ),
                  _buildBadgeItem(
                    icon: Icons.star,
                    title: AppStrings.crowdFavourite,
                    subtitle: AppStrings.crowdFavouriteDescription,
                    color: AppColors.amber,
                  ),

                  const SizedBox(height: AppDimensions.paddingM),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onPrimary,
                    ),
                    child: const ResponsiveTextWidget(
                      AppStrings.close,
                      textType: TextType.body,
                      fontSize: AppDimensions.textM,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgeItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 👈 text left-aligned
        children: [
          Center(
            // 👈 icon stays centered
            child: CircleAvatar(
              radius: AppDimensions.avatarM,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: AppDimensions.iconXXL),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          ResponsiveTextWidget(
            title,
            textAlign: TextAlign.left,
            textType: TextType.heading,
            fontSize: AppDimensions.textL,
            fontWeight: FontWeight.w800,
            color: AppColors.grey900,
          ),
          ResponsiveTextWidget(
            subtitle,
            textAlign: TextAlign.left,
            textType: TextType.caption,
            fontSize: AppDimensions.textM,
            fontWeight: FontWeight.w600,
            color: AppColors.grey600,
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.screenBackground,
          title: const ResponsiveTextWidget(
            'Confirm Logout',
            textType: TextType.heading,
            fontWeight: FontWeight.bold,
            fontSize: AppDimensions.textL,
            color: AppColors.onPrimary,
          ),
          content: const ResponsiveTextWidget(
            'Are you sure you want to logout?',
            textType: TextType.body,
            fontSize: AppDimensions.textM,
            color: AppColors.grey600,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ResponsiveTextWidget(
                'Cancel',
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.w600,
                color: AppColors.grey600,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 🔥 SHOW LOADER
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withOpacity(0.4),
                  builder:
                      (_) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                        ),
                      ),
                );

                try {
                  await viewModel.logout();
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },

              child: const ResponsiveTextWidget(
                AppStrings.confirm,
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.bold,
                color: AppColors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show delete account confirmation dialog
  void _showDeleteAccountConfirmation(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.screenBackground,
          title: const ResponsiveTextWidget(
            AppStrings.deleteAccount,
            textType: TextType.heading,
            fontWeight: FontWeight.bold,
            fontSize: AppDimensions.textL,
            color: AppColors.red,
          ),
          content: const ResponsiveTextWidget(
            AppStrings.deleteAccountWarning,
            textType: TextType.body,
            fontSize: AppDimensions.textM,
            color: AppColors.grey600,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ResponsiveTextWidget(
                AppStrings.cancel,
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.w600,
                color: AppColors.grey600,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 🔥 SHOW LOADER
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withOpacity(0.4),
                  builder:
                      (_) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                        ),
                      ),
                );

                try {
                  await viewModel.deleteAccount();
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const ResponsiveTextWidget(
                AppStrings.confirm,
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.bold,
                color: AppColors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show privacy upgrade dialog (paid feature)
  void _showPrivacyUpgradeDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.screenBackground,
          title: const ResponsiveTextWidget(
            'Premium Feature',
            textType: TextType.heading,
            fontWeight: FontWeight.bold,
            fontSize: AppDimensions.textL,
            color: AppColors.onPrimary,
          ),
          content: const ResponsiveTextWidget(
            'Privacy Settings Pro is a paid feature. Please upgrade your plan to access this feature.',
            textType: TextType.body,
            fontSize: AppDimensions.textM,
            color: AppColors.grey600,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const ResponsiveTextWidget(
                AppStrings.cancel,
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.w600,
                color: AppColors.grey600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                viewModel.goToSubscription();
              },
              child: const ResponsiveTextWidget(
                'Upgrade Plan',
                textType: TextType.body,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show rate app dialog
  void _showRateAppDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.screenBackground,
          child: Container(
            padding: EdgeInsets.all(
              context.isSmallScreen
                  ? AppDimensions.paddingM
                  : context.isMediumScreen
                  ? AppDimensions.paddingL
                  : AppDimensions.paddingXL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star icon
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),

                // Title
                const ResponsiveTextWidget(
                  'Enjoying Festival Rumour?',
                  textType: TextType.heading,
                  fontWeight: FontWeight.bold,
                  fontSize: AppDimensions.textL,
                  color: AppColors.onPrimary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingS),

                // Message
                const ResponsiveTextWidget(
                  'Your feedback helps us improve! Please rate us on the App Store.',
                  textType: TextType.body,
                  fontSize: AppDimensions.textM,
                  color: AppColors.grey600,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingL),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const ResponsiveTextWidget(
                          AppStrings.cancel,
                          textType: TextType.body,
                          fontSize: AppDimensions.textM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          viewModel.rateApp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingL,
                            vertical: AppDimensions.paddingM,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusM,
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, size: 20, color: Colors.black),
                            SizedBox(width: AppDimensions.spaceXS),
                            Flexible(
                              child: ResponsiveTextWidget(
                                'Rate Us',
                                textType: TextType.body,
                                fontSize: AppDimensions.textM,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
