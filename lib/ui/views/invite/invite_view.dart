import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/pioneer_badge.dart';
import '../../../shared/widgets/referral_progress_bar.dart';
import 'invite_view_model.dart';

class InviteView extends BaseView<InviteViewModel> {
  const InviteView({super.key});

  static const Color _brand = Color(0xFFFC2E95);

  @override
  InviteViewModel createViewModel() => InviteViewModel();

  @override
  Widget buildView(BuildContext context, InviteViewModel viewModel) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: viewModel.isLoading && !viewModel.hasCode
                  ? const Center(child: CircularProgressIndicator(color: _brand))
                  : RefreshIndicator(
                      onRefresh: viewModel.refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: viewModel.hasCode
                            ? _content(context, viewModel)
                            : _retry(context, viewModel),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _brand,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            AppStrings.inviteFriendsTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, InviteViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.card_giftcard, size: 56, color: _brand),
        const SizedBox(height: 12),
        const Text(
          AppStrings.inviteHeadline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.inviteSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.grey600),
        ),
        const SizedBox(height: 24),

        // Reward showcase — unlocked card when earned, locked teaser otherwise.
        PioneerBadgeCard(earned: viewModel.isPioneer),
        const SizedBox(height: 20),

        ReferralProgressBar(
          count: viewModel.referralCount,
          goal: viewModel.referralGoal,
          color: _brand,
        ),
        const SizedBox(height: 28),

        _label(AppStrings.yourInviteCode),
        const SizedBox(height: 8),
        _codeBox(
          context,
          value: viewModel.referralCode ?? '',
          big: true,
          onCopy: () => viewModel.copyCode(context),
        ),
        const SizedBox(height: 16),

        _label(AppStrings.yourInviteLink),
        const SizedBox(height: 8),
        _codeBox(
          context,
          value: viewModel.inviteLink,
          big: false,
          onCopy: () => viewModel.copyLink(context),
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _shareButton(
              icon: Icons.chat,
              label: AppStrings.shareViaWhatsApp,
              color: const Color(0xFF25D366),
              onTap: viewModel.shareWhatsApp,
            ),
            _shareButton(
              icon: Icons.facebook,
              label: AppStrings.shareViaMessenger,
              color: const Color(0xFF0084FF),
              onTap: viewModel.shareMessenger,
            ),
            _shareButton(
              icon: Icons.copy,
              label: AppStrings.copyLink,
              color: AppColors.grey700,
              onTap: () => viewModel.copyLink(context),
            ),
            _shareButton(
              icon: Icons.ios_share,
              label: AppStrings.shareViaMore,
              color: _brand,
              onTap: viewModel.shareGeneric,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _retry(BuildContext context, InviteViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.wifi_off, size: 48, color: AppColors.grey600),
        const SizedBox(height: 12),
        const Text(
          "Couldn't load your invite code.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.grey700),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: viewModel.refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.grey600,
        ),
      );

  Widget _codeBox(
    BuildContext context, {
    required String value,
    required bool big,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: big ? 24 : 14,
                fontWeight: big ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: big ? 3 : 0,
                color: big ? _brand : AppColors.grey900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: _brand),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }

  Widget _shareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
