import 'package:flutter/material.dart';

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

