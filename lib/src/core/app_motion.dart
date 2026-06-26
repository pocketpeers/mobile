import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;
}

bool _disableAnimations(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

CustomTransitionPage<void> appTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.fast,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (_disableAnimations(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AppMotion.medium,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (_disableAnimations(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AnimatedSection extends StatelessWidget {
  const AnimatedSection({
    required this.child,
    this.index = 0,
    super.key,
  });

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_disableAnimations(context)) return child;
    final delay = Duration(milliseconds: 45 * index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium + delay,
      curve: AppMotion.curve,
      builder: (context, value, child) {
        final startOffset = index == 0 ? 10.0 : 16.0;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * startOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PulseIcon extends StatelessWidget {
  const PulseIcon({
    required this.icon,
    required this.color,
    super.key,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (_disableAnimations(context)) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(context.isDarkMode ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.84 + (value * 0.16),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(context.isDarkMode ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        );
      },
      child: Icon(icon, color: color),
    );
  }
}

void showAchievementSnackBar(
  BuildContext context, {
  required String title,
  String? message,
  IconData icon = Icons.emoji_events_outlined,
}) {
  final color = context.successIconColor;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          PulseIcon(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (message != null) Text(message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
