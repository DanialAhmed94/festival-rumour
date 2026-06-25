import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/di/locator.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/viewmodels/base_view_model.dart';

class InviteViewModel extends BaseViewModel {
  final ReferralService _referralService = locator<ReferralService>();
  final AuthService _authService = locator<AuthService>();

  ReferralInfo _info = ReferralInfo.empty;

  String? get referralCode => _info.code;
  bool get hasCode => (_info.code != null && _info.code!.isNotEmpty);
  String get inviteLink => hasCode ? _referralService.buildInviteLink(_info.code!) : '';
  int get referralCount => _info.count;
  int get referralGoal => _info.goal;
  double get progress => _info.progress;
  bool get isPioneer => _info.isPioneer;

  String get _shareText => AppStrings.inviteShareMessage(inviteLink);

  @override
  void init() {
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.userUid;
    if (uid == null) return;
    await handleAsync(() async {
      _info = await _referralService.getReferralData(uid);
      // Generate a code on first visit, then re-read so the UI has it.
      if (!hasCode) {
        final code = await _referralService.getOrCreateCode();
        if (code != null) {
          _info = await _referralService.getReferralData(uid);
        }
      }
    });
  }

  /// Pull-to-refresh / retry hook.
  Future<void> refresh() => _load();

  Future<void> shareGeneric() async {
    if (!hasCode) return;
    try {
      await Share.share(_shareText, subject: AppStrings.inviteShareSubject);
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] shareGeneric error: $e');
    }
  }

  Future<void> shareWhatsApp() async {
    if (!hasCode) return;
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
    );
    await _launchOrShare(uri);
  }

  Future<void> shareMessenger() async {
    if (!hasCode) return;
    // Messenger deep links are unreliable; fall back to the system share sheet.
    final uri = Uri.parse(
      'fb-messenger://share/?link=${Uri.encodeComponent(inviteLink)}',
    );
    await _launchOrShare(uri);
  }

  Future<void> _launchOrShare(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (e) {
      if (kDebugMode) print('[REFERRAL] launch error: $e');
    }
    await shareGeneric();
  }

  Future<void> copyLink(BuildContext context) async {
    if (!hasCode) return;
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (context.mounted) {
      SnackbarUtil.showSuccessSnackBar(context, AppStrings.linkCopied);
    }
  }

  Future<void> copyCode(BuildContext context) async {
    if (!hasCode) return;
    await Clipboard.setData(ClipboardData(text: _info.code!));
    if (context.mounted) {
      SnackbarUtil.showSuccessSnackBar(context, AppStrings.codeCopied);
    }
  }
}
