import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
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
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const ResponsiveTextWidget(
          AppStrings.settings,
          textType: TextType.title,
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimary,
        ),
        actions: [
          GestureDetector(
            onTap: viewModel.goToSubscription,
            child: Container(
              margin: const EdgeInsets.only(right: AppDimensions.paddingM),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent, // ✅ Changed button color to black
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: const ResponsiveTextWidget(
                AppStrings.proLabel,
                textType: TextType.caption,
                color: AppColors.onPrimary, // ✅ White text on black background
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
          horizontal: context.isSmallScreen 
              ? AppDimensions.paddingM
              : context.isMediumScreen 
                  ? AppDimensions.paddingL
                  : AppDimensions.paddingXL,
          vertical: context.isSmallScreen 
              ? AppDimensions.paddingS
              : context.isMediumScreen 
                  ? AppDimensions.paddingM
                  : AppDimensions.paddingL
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              onChanged: (value) => _showPrivacyUpgradeDialog(context, viewModel),
            ),
            _buildTile(
              icon: Icons.military_tech_outlined,
              iconColor: AppColors.orange,
              title: AppStrings.badges,
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: AppDimensions.iconS, color: AppColors.grey600),
              onTap: () => _showBadgesDialog(context),
            ),
            _buildTile(
              icon: Icons.leaderboard_outlined,
              iconColor: AppColors.brown,
              title: AppStrings.leaderBoard,
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: AppDimensions.iconS, color: AppColors.grey600),
              onTap: viewModel.openLeaderboard,
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
          ]
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
      contentPadding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceXS),
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
      contentPadding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceXS),
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
      subtitle: subtitle != null
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
          backgroundColor: AppColors.primary,
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(
              context.isSmallScreen 
                  ? AppDimensions.paddingM
                  : context.isMediumScreen 
                      ? AppDimensions.paddingL
                      : AppDimensions.paddingXL
            ),
            constraints: BoxConstraints(
              maxWidth: context.isSmallScreen 
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
          Center( // 👈 icon stays centered
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
  void _showLogoutConfirmation(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.primary,
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
              onPressed: () {
                Navigator.pop(dialogContext);
                viewModel.logout();
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
  void _showDeleteAccountConfirmation(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.primary,
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
              onPressed: () {
                Navigator.pop(dialogContext);
                viewModel.deleteAccount();
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
  void _showPrivacyUpgradeDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          backgroundColor: AppColors.primary,
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
          backgroundColor: AppColors.primary,
          child: Container(
            padding: EdgeInsets.all(
              context.isSmallScreen 
                  ? AppDimensions.paddingM
                  : context.isMediumScreen 
                      ? AppDimensions.paddingL
                      : AppDimensions.paddingXL
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
                            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
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
