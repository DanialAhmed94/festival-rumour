import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/organiser_invite_service.dart';

const Color _pink = Color(0xFFFC2E95);
final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Full-screen form shown when a searched festival isn't found: the user can
/// invite that festival's organiser to list it. [festivalName] is the searched
/// name (woven into the email subject + body along with the requester's name).
///
/// Implemented as a pushed route (not a dialog/bottom sheet) for maximum
/// reliability — a full screen always renders, regardless of overlay state.
class FestivalListingInviteView extends StatefulWidget {
  const FestivalListingInviteView({super.key, this.festivalName});

  final String? festivalName;

  @override
  State<FestivalListingInviteView> createState() =>
      _FestivalListingInviteViewState();
}

class _FestivalListingInviteViewState extends State<FestivalListingInviteView> {
  final TextEditingController _emailController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// The requesting user's display name (falls back to the email local part).
  String _inviterName() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return '';
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRe.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid organiser email.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await OrganiserInviteService.sendFestivalListingInvite(
      organiserEmail: email,
      festivalName: widget.festivalName,
      inviterName: _inviterName(),
    );

    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppStrings.festivalListingInviteSent
              : AppStrings.festivalListingInviteFailed,
        ),
      ),
    );
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final festival = (widget.festivalName ?? '').trim();
    final message = festival.isNotEmpty
        ? "We couldn't find \"$festival\". Send an invite to the festival "
            "organiser to list it in The Festival App."
        : AppStrings.festivalNotFoundMessage;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: _pink,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: const Text(
          AppStrings.festivalNotFoundInviteButton,
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _pink.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline, color: _pink, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.festivalNotFoundTitle,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.festivalNotFoundEmailLabel,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofocus: true,
                enabled: !_sending,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: AppStrings.tagFestivalOrganiserHint,
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _pink.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                ),
                cursorColor: _pink,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _pink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          AppStrings.sendInvite,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
