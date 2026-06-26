import 'package:flutter/material.dart';

import '../data/models.dart';
import 'app_theme.dart';

IconData badgeIconForCode(String code) {
  switch (code.toUpperCase()) {
    case 'FIRST_PAYMENT':
      return Icons.payments_outlined;
    case 'STREAK_3':
    case 'STREAK_10':
    case 'STREAK_50':
    case 'STREAK_100':
      return Icons.local_fire_department_outlined;
    case 'EARLY_BIRD':
      return Icons.wb_twilight_outlined;
    case 'GROUP_FOUNDER':
      return Icons.groups_2_outlined;
    case 'JUST_IN_TIME':
      return Icons.timer_outlined;
    case 'PARTIAL_EFFORT':
      return Icons.trending_up_outlined;
    case 'ZERO_DEBT':
      return Icons.account_balance_wallet_outlined;
    case 'SILVER_LEVEL':
      return Icons.workspace_premium_outlined;
    case 'GOLD_LEVEL':
      return Icons.emoji_events_outlined;
    default:
      return Icons.military_tech_outlined;
  }
}

Color badgeColorForCode(BuildContext context, String code) {
  final isDark = context.isDarkMode;
  switch (code.toUpperCase()) {
    case 'STREAK_3':
    case 'STREAK_10':
    case 'STREAK_50':
    case 'STREAK_100':
      return isDark ? Colors.deepOrangeAccent.shade100 : Colors.deepOrange;
    case 'EARLY_BIRD':
      return isDark ? Colors.amberAccent.shade100 : Colors.amber.shade800;
    case 'GROUP_FOUNDER':
      return context.primaryIconColor;
    case 'JUST_IN_TIME':
      return isDark ? Colors.purpleAccent.shade100 : Colors.purple;
    case 'PARTIAL_EFFORT':
      return isDark ? Colors.lightGreenAccent.shade100 : AppColors.green;
    case 'ZERO_DEBT':
      return isDark ? Colors.tealAccent.shade100 : Colors.teal.shade700;
    case 'SILVER_LEVEL':
      return isDark ? Colors.blueGrey.shade100 : Colors.blueGrey.shade600;
    case 'GOLD_LEVEL':
      return isDark ? Colors.yellowAccent.shade100 : Colors.amber.shade700;
    case 'FIRST_PAYMENT':
    default:
      return context.successIconColor;
  }
}

class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    required this.badge,
    this.compact = false,
    super.key,
  });

  final PblBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final code = badge.code;
    final unlocked = badge.unlocked;
    final accentColor = badgeColorForCode(context, code);
    final lockedColor =
        context.isDarkMode ? Colors.white54 : Colors.grey.shade600;
    final color = unlocked ? accentColor : lockedColor;
    final borderColor = unlocked ? accentColor : Colors.grey.shade300;
    final title = badge.name;
    final description = badge.description;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: unlocked
            ? accentColor.withOpacity(context.isDarkMode ? 0.16 : 0.09)
            : Colors.grey.withOpacity(context.isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(unlocked ? 0.8 : 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: compact ? 58 : 68,
                  height: compact ? 58 : 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unlocked
                        ? RadialGradient(
                            colors: [
                              accentColor.withOpacity(0.28),
                              accentColor.withOpacity(0.08),
                            ],
                          )
                        : null,
                    color: unlocked ? null : Colors.grey.withOpacity(0.12),
                    border:
                        Border.all(color: color.withOpacity(0.55), width: 2),
                  ),
                ),
                Positioned(
                  bottom: compact ? -9 : -10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MedalRibbon(color: color.withOpacity(0.82), left: true),
                      const SizedBox(width: 10),
                      _MedalRibbon(color: color.withOpacity(0.82)),
                    ],
                  ),
                ),
                Icon(
                  badgeIconForCode(code),
                  color: color,
                  size: compact ? 31 : 38,
                ),
                if (unlocked)
                  Positioned(
                    right: compact ? -2 : -4,
                    top: compact ? -2 : -4,
                    child: Container(
                      width: compact ? 20 : 22,
                      height: compact ? 20 : 22,
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? AppColors.darkSurface
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor),
                      ),
                      child: Icon(
                        Icons.check,
                        size: compact ? 13 : 14,
                        color: accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: compact ? 16 : 18),
          Text(
            title,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked && badge.unlockedAt != null
                ? 'Desbloqueado'
                : description,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: unlocked
                      ? Theme.of(context).colorScheme.onSurface
                      : lockedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalRibbon extends StatelessWidget {
  const _MedalRibbon({required this.color, this.left = false});

  final Color color;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: left ? 0.32 : -0.32,
      child: Container(
        width: 10,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(3),
          ),
        ),
      ),
    );
  }
}
