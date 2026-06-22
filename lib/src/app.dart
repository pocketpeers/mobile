import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_motion.dart';
import 'core/app_theme.dart';
import 'data/models.dart';
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
  final initialLocation = !_isMinSplashTimePassed
      ? '/splash'
      : isSignedIn
          ? '/dashboard'
          : '/auth';

  if (!_isMinSplashTimePassed) {
    Future.delayed(const Duration(seconds: 2), () {
      _isMinSplashTimePassed = true;
      // Esto fuerza a GoRouter a reevaluar las redirecciones cuando termine el segundo
      ref.invalidateSelf();
    });
  }

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/auth';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      if (!_isMinSplashTimePassed) {
        return isSplashRoute ? null : '/splash';
      }

      if (auth.isLoading) {
        return isAuthRoute ? null : '/auth';
      }
      if (onboarding.isLoading && isSignedIn) {
        return null;
      }
      if (!isSignedIn && !isAuthRoute) return '/auth';
      if (!isSignedIn && isSplashRoute) return '/auth';
      if (isSignedIn && isSplashRoute) {
        return onboarding.valueOrNull == false ? '/onboarding' : '/dashboard';
      }
      if (isSignedIn && isAuthRoute) return '/dashboard';
      if (isSignedIn && onboarding.valueOrNull == false && !isOnboardingRoute) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => appTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => appTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => appTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/groups',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const GroupsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => appTransitionPage(
                  key: state.pageKey,
                  child: const CreateGroupScreen(),
                ),
              ),
              GoRoute(
                path: ':groupId',
                pageBuilder: (context, state) => appTransitionPage(
                  key: state.pageKey,
                  child: GroupDetailScreen(
                    groupId: int.parse(state.pathParameters['groupId']!),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'members/:memberId',
                    pageBuilder: (context, state) => appTransitionPage(
                      key: state.pageKey,
                      child: PublicMemberProfileScreen(
                        groupId: int.parse(state.pathParameters['groupId']!),
                        memberId: int.parse(state.pathParameters['memberId']!),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'expenses/new',
                    pageBuilder: (context, state) => appTransitionPage(
                      key: state.pageKey,
                      child: CreateExpenseScreen(
                        groupId: int.parse(state.pathParameters['groupId']!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/payments/:paymentId',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: PaymentDetailScreen(
                paymentId: int.parse(state.pathParameters['paymentId']!),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _tabs = [
    _TabDestination('/dashboard', Icons.dashboard_outlined, 'Home'),
    _TabDestination('/groups', Icons.group_outlined, 'Grupos'),
    _TabDestination('/reports', Icons.pie_chart_outline, 'Reportes'),
    _TabDestination('/settings', Icons.settings_outlined, 'Ajustes'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _timer;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  var _polling = false;
  final _shownReminderIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollReminders());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFcm());
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _pollReminders(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeFcm() async {
    if (!mounted || !ref.read(remindersEnabledProvider)) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final reminderService = ref.read(reminderServiceProvider);
    final api = ref.read(apiProvider);
    try {
      await reminderService.registerDevice(api);
    } catch (error) {
      debugPrint('FCM registration failed: $error');
      return;
    }

    _tokenRefreshSubscription ??= reminderService.tokenRefreshes().listen(
          (token) => api.registerDeviceToken(token: token, platform: 'refresh'),
        );
    _foregroundSubscription ??= reminderService.foregroundMessages().listen(
          _showForegroundFcmReminder,
        );
    _openedSubscription ??= reminderService.openedMessages().listen(
          _openPaymentFromMessage,
        );

    final initialMessage = await reminderService.initialMessage();
    if (initialMessage != null) {
      _openPaymentFromMessage(initialMessage);
    }
  }

  void _showForegroundFcmReminder(RemoteMessage message) {
    if (!mounted) return;
    final notification = message.notification;
    final title = notification?.title ?? 'Recordatorio de pago';
    final body = notification?.body ?? '';
    final notificationId =
        int.tryParse(message.data['notificationId']?.toString() ?? '');
    final paymentId = int.tryParse(message.data['paymentId']?.toString() ?? '');
    if (notificationId != null) {
      _shownReminderIds.add(notificationId);
      ref.read(apiProvider).markNotificationRead(notificationId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        duration: const Duration(seconds: 8),
        action: paymentId == null
            ? null
            : SnackBarAction(
                label: 'Pagar',
                onPressed: () => context.push('/payments/$paymentId'),
              ),
      ),
    );
  }

  void _openPaymentFromMessage(RemoteMessage message) {
    final notificationId =
        int.tryParse(message.data['notificationId']?.toString() ?? '');
    if (notificationId != null) {
      _shownReminderIds.add(notificationId);
      ref.read(apiProvider).markNotificationRead(notificationId);
    }
    final paymentId = int.tryParse(message.data['paymentId']?.toString() ?? '');
    if (paymentId == null || !mounted) return;
    context.push('/payments/$paymentId');
  }

  Future<void> _pollReminders() async {
    if (_polling || !mounted || !ref.read(remindersEnabledProvider)) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    _polling = true;
    try {
      final reminders = await ref.read(apiProvider).getUnreadNotifications();
      PaymentReminder? nextReminder;
      for (final reminder in reminders) {
        if (!_shownReminderIds.contains(reminder.id)) {
          nextReminder = reminder;
          break;
        }
      }
      if (nextReminder == null || !mounted) return;

      _shownReminderIds.add(nextReminder.id);
      await ref.read(apiProvider).markNotificationRead(nextReminder.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${nextReminder.title}\n${nextReminder.body}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Pagar',
            onPressed: () =>
                context.push('/payments/${nextReminder?.paymentId}'),
          ),
        ),
      );
    } catch (_) {
      // Reminder polling should never interrupt the main app flow.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected =
        AppShell._tabs.indexWhere((tab) => location.startsWith(tab.path));
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
        child: SafeArea(child: widget.child),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) =>
            context.go(AppShell._tabs[index].path),
        destinations: [
          for (final tab in AppShell._tabs)
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
