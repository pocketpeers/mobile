import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_motion.dart';
import 'core/app_theme.dart';
import 'core/badge_visuals.dart';
import 'core/crew.dart';
import 'data/models.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/expenses/expense_screens.dart';
import 'features/groups/group_screens.dart';
import 'features/operations/operation_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/badges_screen.dart';
import 'features/settings/change_password_screen.dart';
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
      // Route access is driven by the restored auth session and onboarding
      // flag. Keeping this logic centralized avoids duplicated guards in every
      // screen.
      final isSplashRoute = state.matchedLocation == '/splash';
      final isForgotPasswordRoute = state.matchedLocation == '/forgot-password';
      // Recuperar la contraseña es, por definición, algo que se hace sin haber
      // podido iniciar sesión: esa ruta tiene que ser alcanzable sin sesión,
      // igual que la de acceso.
      final isAuthRoute =
          state.matchedLocation == '/auth' || isForgotPasswordRoute;
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
        path: '/forgot-password',
        pageBuilder: (context, state) => appTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => appTransitionPage(
          key: state.pageKey,
          // Abierto desde Ajustes es una consulta voluntaria, no el alta de un
          // usuario nuevo: cambia los textos y no vuelve a marcar el tutorial
          // como completado.
          child: OnboardingScreen(
            voluntary: state.uri.queryParameters['voluntary'] == 'true',
          ),
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
                    path: 'expenses',
                    pageBuilder: (context, state) => appTransitionPage(
                      key: state.pageKey,
                      child: GroupExpensesScreen(
                        groupId: int.parse(state.pathParameters['groupId']!),
                      ),
                    ),
                    routes: [
                      // 'new' va antes que ':expenseId' a proposito: go_router
                      // prueba las rutas en orden y sin esto /expenses/new
                      // entraria al detalle con un id que no existe.
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) => appTransitionPage(
                          key: state.pageKey,
                          child: CreateExpenseScreen(
                            groupId:
                                int.parse(state.pathParameters['groupId']!),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':expenseId',
                        pageBuilder: (context, state) => appTransitionPage(
                          key: state.pageKey,
                          child: ExpenseDetailScreen(
                            groupId:
                                int.parse(state.pathParameters['groupId']!),
                            expenseId:
                                int.parse(state.pathParameters['expenseId']!),
                          ),
                        ),
                      ),
                    ],
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
            path: '/notifications',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => appTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'password',
                pageBuilder: (context, state) => appTransitionPage(
                  key: state.pageKey,
                  child: const ChangePasswordScreen(),
                ),
              ),
              GoRoute(
                path: 'badges',
                pageBuilder: (context, state) => appTransitionPage(
                  key: state.pageKey,
                  child: const BadgesScreen(),
                ),
              ),
            ],
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
    // Deja escuchando el cierre de sesion por token vencido durante toda la
    // vida de la aplicacion.
    ref.watch(sessionExpiryWatcherProvider);
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
  StreamSubscription<Map<String, dynamic>>? _localTapSubscription;
  var _polling = false;
  final _shownReminderIds = <int>{};
  int? _knownBadgeUserId;
  Set<String>? _knownUnlockedBadgeCodes;

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
    _localTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeFcm() async {
    if (!mounted || !ref.read(remindersEnabledProvider)) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    // Device-token registration is tied to an authenticated session because the
    // backend stores tokens per user.
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
    // Taps on notifications drawn while the app was open arrive here instead of
    // through onMessageOpenedApp, which only fires for FCM-rendered ones.
    _localTapSubscription ??= reminderService.notificationTaps().listen(
          _openPaymentFromData,
        );

    final initialMessage = await reminderService.initialMessage();
    if (initialMessage != null) {
      _openPaymentFromMessage(initialMessage);
    }
  }

  Future<void> _showForegroundFcmReminder(RemoteMessage message) async {
    if (!mounted) return;
    final notificationId =
        int.tryParse(message.data['notificationId']?.toString() ?? '');
    if (notificationId != null) {
      // Recording it here also stops the polling fallback from surfacing the
      // same reminder a second time.
      _shownReminderIds.add(notificationId);
      ref.read(apiProvider).markNotificationRead(notificationId);
    }
    try {
      await ref.read(reminderServiceProvider).showRemoteMessage(message);
    } catch (error) {
      debugPrint('Foreground notification failed: $error');
    }
  }

  void _openPaymentFromMessage(RemoteMessage message) =>
      _openPaymentFromData(message.data);

  void _openPaymentFromData(Map<String, dynamic> data) {
    final notificationId =
        int.tryParse(data['notificationId']?.toString() ?? '');
    if (notificationId != null) {
      _shownReminderIds.add(notificationId);
      ref.read(apiProvider).markNotificationRead(notificationId);
    }
    final paymentId = int.tryParse(data['paymentId']?.toString() ?? '');
    if (paymentId == null || !mounted) return;
    context.push('/payments/$paymentId');
  }

  Future<void> _pollReminders() async {
    if (_polling || !mounted || !ref.read(remindersEnabledProvider)) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    // Polling is a fallback for devices without an active FCM delivery path.
    // The shown-id set prevents the same unread reminder from opening twice.
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

      // Rendered the same way as an FCM reminder so both delivery paths look
      // identical to the user.
      await ref.read(reminderServiceProvider).showDueReminder(
        id: nextReminder.id & 0x7fffffff,
        title: nextReminder.title,
        body: nextReminder.body,
        data: {
          'notificationId': '${nextReminder.id}',
          'paymentId': '${nextReminder.paymentId}',
          'expenseId': '${nextReminder.expenseId}',
          'groupId': '${nextReminder.groupId}',
          'type': nextReminder.type,
        },
      );
    } catch (_) {
      // Reminder polling should never interrupt the main app flow.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<PblBadge>>>(myBadgesProvider, (_, next) {
      // The first badge snapshot establishes the baseline. Only later changes
      // trigger achievement snackbars, so users are not spammed after login.
      final badges = next.valueOrNull;
      if (badges == null) return;
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session == null) {
        _knownBadgeUserId = null;
        _knownUnlockedBadgeCodes = null;
        return;
      }

      final unlocked = badges.where((badge) => badge.unlocked).toList();
      final unlockedCodes = unlocked.map((badge) => badge.code).toSet();
      if (_knownBadgeUserId != session.id || _knownUnlockedBadgeCodes == null) {
        _knownBadgeUserId = session.id;
        _knownUnlockedBadgeCodes = unlockedCodes;
        return;
      }

      final previousCodes = _knownUnlockedBadgeCodes!;
      final newBadges = unlocked
          .where((badge) => !previousCodes.contains(badge.code))
          .toList();
      _knownUnlockedBadgeCodes = unlockedCodes;
      if (newBadges.isEmpty || !mounted) return;

      for (var i = 0; i < newBadges.length; i++) {
        final badge = newBadges[i];
        Future.delayed(Duration(milliseconds: 380 * i), () {
          if (!mounted) return;
          showAchievementSnackBar(
            context,
            title: 'Badge desbloqueado',
            message: badge.name,
            icon: badgeIconForCode(badge.code),
            // Desbloquear una insignia es lo mas parecido a un premio que
            // tiene la app, y hasta ahora se anunciaba igual que guardar un
            // cambio. Salvador festeja porque las insignias cuelgan del score,
            // que es de lo que el habla en el tutorial.
            leading: const CrewCelebration.jumping(
              member: CrewMember.salvador,
            ),
          );
        });
      }
    });

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
