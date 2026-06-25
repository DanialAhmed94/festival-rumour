import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// "{count} / {goal} Friends Invited" label + progress bar.
/// Shared by the Invite screen (full) and the Profile screen (compact).
class ReferralProgressBar extends StatelessWidget {
  final int count;
  final int goal;
  final bool compact;
  final Color color;

  const ReferralProgressBar({
    super.key,
    required this.count,
    required this.goal,
    this.compact = false,
    this.color = const Color(0xFFFC2E95),
  });

  @override
  Widget build(BuildContext context) {
    final value = goal <= 0 ? 0.0 : (count / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.friendsInvited(count, goal),
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 6 : 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: compact ? 6 : 12,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
