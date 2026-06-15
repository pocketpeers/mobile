import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/groups/group_screens.dart';
import 'features/operations/operation_screens.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/providers.dart';

bool _isMinSplashTimePassed = false;

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final onboarding = ref.watch(onboardingCompletedProvider);
  final isSignedIn = auth.valueOrNull != null;

  if (!_isMinSplashTimePassed) {
    Future.delayed(const Duration(seconds: 2), () {
      _isMinSplashTimePassed = true;
      // Esto fuerza a GoRouter a reevaluar las redirecciones cuando termine el segundo
      ref.invalidateSelf(); 
    });
  }

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/auth';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      if (!_isMinSplashTimePassed || auth.isLoading) {
        return isSplashRoute ? null : '/splash';
      }

      if (auth.isLoading) return isSplashRoute ? null : '/splash';
      if (onboarding.isLoading && isSignedIn) {
        return isSplashRoute ? null : '/splash';
      }
      if (!isSignedIn && !isAuthRoute) return '/auth';
      if (!isSignedIn && isSplashRoute) return '/auth';
      if (isSignedIn && isSplashRoute) {
        return onboarding.valueOrNull == false ? '/onboarding' : '/dashboard';
      }
      if (isSignedIn && isAuthRoute) return '/dashboard';
      if (isSignedIn &&
          onboarding.valueOrNull == false &&
          !isOnboardingRoute) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) => const GroupsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateGroupScreen(),
              ),
              GoRoute(
                path: ':groupId',
                builder: (context, state) => GroupDetailScreen(
                  groupId: int.parse(state.pathParameters['groupId']!),
                ),
                routes: [
                  GoRoute(
                    path: 'expenses/new',
                    builder: (context, state) => CreateExpenseScreen(
                      groupId: int.parse(state.pathParameters['groupId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/payments/:paymentId',
            builder: (context, state) => PaymentDetailScreen(
              paymentId: int.parse(state.pathParameters['paymentId']!),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class PocketPeersApp extends ConsumerWidget {
  const PocketPeersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'PocketPeers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _tabs = [
    _TabDestination('/dashboard', Icons.dashboard_outlined, 'Home'),
    _TabDestination('/groups', Icons.group_outlined, 'Grupos'),
    _TabDestination('/reports', Icons.pie_chart_outline, 'Reportes'),
    _TabDestination('/settings', Icons.settings_outlined, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _tabs.indexWhere((tab) => location.startsWith(tab.path));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [AppColors.darkBg, AppColors.darkSurface]
                : const [Color(0xFFFFFFFF), AppColors.mist],
          ),
        ),
        child: SafeArea(child: child),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _TabDestination {
  const _TabDestination(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
