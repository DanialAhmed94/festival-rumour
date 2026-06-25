import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// Circular gold-medallion "Pioneer" badge — composed in Flutter so it is
/// guaranteed to be a perfect circle (BoxShape.circle) with a round gold ring,
/// and always renders. Single source of truth for badge styling so it looks
/// identical on the Profile header, chat name rows, and the Invite screen.
///
/// Only render this when the badge is valid — callers gate on
/// `ReferralService.isPioneerBadgeValid(...)` (or the cached value from
/// `UserBadgeCacheService`). This widget does no validity check itself.
class PioneerBadge extends StatelessWidget {
  /// When true, shows only the medallion (for tight rows like chat sender names).
  final bool compact;
  final double size;

  const PioneerBadge({super.key, this.compact = false, this.size = 16});

  static const Color _goldDark = Color(0xFF9A5E06);

  @override
  Widget build(BuildContext context) {
    final medal = pioneerMedallion(size);
    if (compact) {
      return Tooltip(message: AppStrings.pioneerBadgeTooltip, child: medal);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8B84B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          medal,
          const SizedBox(width: 5),
          Text(
            AppStrings.pioneerBadgeName,
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w800,
              color: _goldDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular medallion graphic. Always a perfect circle with a gold ring.
Widget pioneerMedallion(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.25, -0.35),
        radius: 0.95,
        colors: [Color(0xFFFFF3C7), Color(0xFFF4B63C), Color(0xFFB87914)],
        stops: [0.0, 0.55, 1.0],
      ),
      border: Border.all(
        color: const Color(0xFFFFE9A6),
        width: size * 0.07,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33A9670A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.star_rounded,
      size: size * 0.62,
      color: const Color(0xFFFFFDF2),
    ),
  );
}

/// Larger badge "card" used to showcase the reward (Invite screen / Profile).
/// [earned] = true shows it unlocked with the premium-access message; false shows
/// a locked teaser explaining what the badge grants.
class PioneerBadgeCard extends StatelessWidget {
  final bool earned;

  const PioneerBadgeCard({super.key, required this.earned});

  static const Color _goldDark = Color(0xFF9A5E06);

  @override
  Widget build(BuildContext context) {
    final medal = pioneerMedallion(38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E2), Color(0xFFFDE8BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8B84B)),
      ),
      child: Row(
        children: [
          // Greyed/dimmed when still locked.
          earned
              ? medal
              : Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF9E9E9E),
                      BlendMode.saturation,
                    ),
                    child: medal,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.pioneerBadgeFull,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _goldDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      earned
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: 13,
                      color: _goldDark,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        earned
                            ? AppStrings.pioneerPremiumUnlocked
                            : AppStrings.pioneerPremiumTeaser,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A5207),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
