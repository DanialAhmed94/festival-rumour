import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/referral_service.dart';

const Color _brand = Color(0xFFFC2E95);
const Color _goldDark = Color(0xFF9A5E06);
const String _giftAsset = 'assets/images/gift.png';
const String _friendsAsset = 'assets/svgs/friends_invited.svg';

/// One-time "Invite Friends" promo popup (matches the welcome-reward design).
Future<void> showInvitePromoDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => const InvitePromoDialog(),
  );
}

class InvitePromoDialog extends StatefulWidget {
  const InvitePromoDialog({super.key});

  @override
  State<InvitePromoDialog> createState() => _InvitePromoDialogState();
}

class _InvitePromoDialogState extends State<InvitePromoDialog> {
  final ReferralService _referral = locator<ReferralService>();
  final AuthService _auth = locator<AuthService>();

  ReferralInfo _info = ReferralInfo.empty;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.userUid;
    if (uid == null) return;
    var info = await _referral.getReferralData(uid);
    if (info.code == null || info.code!.isEmpty) {
      await _referral.getOrCreateCode();
      info = await _referral.getReferralData(uid);
    }
    if (mounted) setState(() => _info = info);
  }

  Future<void> _share() async {
    final code = _info.code;
    if (code == null || code.isEmpty) return;
    setState(() => _sharing = true);
    try {
      await Share.share(
        AppStrings.inviteShareMessage(_referral.buildInviteLink(code)),
        subject: AppStrings.inviteShareSubject,
      );
    } catch (_) {}
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _card(context),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.close, size: 22, color: Color(0xFF555555)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final count = _info.count;
    final goal = _info.goal;
    final progress = goal > 0 ? (count / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6DE), Color(0xFFFCEBC2)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gift hero
            Image.asset(
              _giftAsset,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('🎁', style: TextStyle(fontSize: 96)),
            ),
            const SizedBox(height: 12),
            // Headline
            const Text(
              'Invite Friends,',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222222),
              ),
            ),
            const Text(
              'Earn Your Pioneer Badge!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _brand,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.inviteSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            _badgeCard(),
            const SizedBox(height: 12),
            _progressCard(count, goal, progress),
            const SizedBox(height: 18),
            _shareButton(),
            const SizedBox(height: 12),
            Text(
              'More friends, more rewards! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B84B)),
      ),
      child: Row(
        children: [
          _goldBadgeTile(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.pioneerBadgeFull,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _goldDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Refer 25 friends to unlock\npremium features',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7A5207).withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gold rounded-square badge tile with a star and a small lock corner.
  Widget _goldBadgeTile() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD86B), Color(0xFFE0982A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33A9670A),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.star_rounded,
                color: Color(0xFFFFFDF2), size: 34),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 13, color: _brand),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(int count, int goal, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8B84B).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _peopleIcon(),
              const SizedBox(width: 8),
              Text(
                AppStrings.friendsInvited(count, goal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFEAD9A6),
              valueColor: const AlwaysStoppedAnimation<Color>(_brand),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleIcon() {
    // friends_invited.svg is ~164×128; constrain height and let width scale to
    // keep the aspect ratio (no distortion).
    return SvgPicture.asset(
      _friendsAsset,
      height: 22,
      placeholderBuilder: (_) =>
          const Icon(Icons.group, color: _brand, size: 22),
    );
  }

  Widget _shareButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.ios_share, color: Colors.white, size: 22),
        label: const Text(
          'SHARE YOUR CODE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
