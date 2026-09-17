import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_service.dart';
import '../data/calculations.dart';
import '../data/models.dart';
import '../data/pocketpeers_api.dart';

final apiProvider = Provider<PocketPeersApi>((ref) => PocketPeersApi());
final reminderServiceProvider =
    Provider<ReminderService>((ref) => ReminderService());
final remindersEnabledProvider = StateProvider<bool>((ref) => false);
final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.read(apiProvider).isOnboardingCompleted();
});

/// Marca que la ultima sesion se cerro porque el token vencio.
///
/// La pantalla de acceso la lee para explicar por que se cerro la sesion. Sin
/// esto, al usuario lo devuelve al login sin ninguna razon aparente.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

/// Escucha los rechazos por token vencido y cierra la sesion.
///
/// Se activa una sola vez, desde la raiz de la aplicacion. El interceptor ya
/// borro las credenciales guardadas; recargar el controlador hace que el estado
/// pase a null y el enrutador redirija al acceso por su cuenta.
final sessionExpiryWatcherProvider = Provider<void>((ref) {
  final api = ref.watch(apiProvider);
  final subscription = api.onSessionExpired.listen((_) {
    ref.read(sessionExpiredProvider.notifier).state = true;
    ref.invalidate(authControllerProvider);
  });
  ref.onDispose(subscription.cancel);
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  PocketPeersApi get _api => ref.read(apiProvider);

  @override
  // Session restoration is the source used by routing, API calls and screen
  // providers to decide whether user-scoped data can be loaded.
  Future<AuthSession?> build() => _api.restoreSession();

  Future<void> signIn(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.signIn(username, password));
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      await _api.signUp(
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        email: email,
      );
      return _api.signIn(username, password);
    });
  }

  Future<void> signOut() async {
    await _api.signOut();
    // Salir por decision propia nunca debe mostrar "tu sesion expiro": si el
    // aviso quedo levantado de un vencimiento anterior, se baja aqui.
    ref.read(sessionExpiredProvider.notifier).state = false;
    state = const AsyncData(null);
  }

  void clearAuthError() {
    if (state.hasError) {
      state = const AsyncData(null);
    }
  }

  Future<void> completeOnboarding() async {
    await _api.completeOnboarding();
    ref.invalidate(onboardingCompletedProvider);
  }
}

final profileProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiProvider).getMyProfile();
});

/// Historial de notificaciones, leidas y no leidas.
///
/// Se pide solo la primera pagina: alcanza para la pantalla y evita traer
/// meses de historial que nadie va a desplazar.
final notificationHistoryProvider =
    FutureProvider<List<PaymentReminder>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiProvider).getNotificationHistory();
});

/// Cantidad de notificaciones sin leer, para el indicador del panel.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiProvider).getUnreadNotificationCount();
});

final groupsProvider = FutureProvider<List<Group>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) return const [];
  return ref.read(apiProvider).getGroupsByUserId(session.id);
});

final groupProvider = FutureProvider.family<Group, int>((ref, groupId) {
  return ref.read(apiProvider).getGroup(groupId);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, int>((ref, groupId) {
  return ref.read(apiProvider).getGroupMembers(groupId);
});

final groupExpensesProvider =
    FutureProvider.family<List<Expense>, int>((ref, groupId) {
  return ref.read(apiProvider).getExpensesByGroup(groupId);
});

final expenseProvider = FutureProvider.family<Expense, int>((ref, expenseId) {
  return ref.read(apiProvider).getExpense(expenseId);
});

final expensePaymentsProvider =
    FutureProvider.family<List<Payment>, int>((ref, expenseId) {
  return ref.read(apiProvider).getPaymentsByExpense(expenseId);
});

/// Recibos adjuntos a un gasto.
///
/// El recibo se escanea al crear el gasto y hasta ahora solo lo veia quien lo
/// cargo. Quienes quedan con una deuda del gasto necesitan poder revisar el
/// comprobante para saber que estan pagando.
final expenseReceiptsProvider =
    FutureProvider.family<List<Receipt>, int>((ref, expenseId) {
  return ref.read(apiProvider).getReceiptsByExpense(expenseId);
});

final allGroupPaymentsProvider =
    FutureProvider.family<List<Payment>, int>((ref, groupId) {
  // Una peticion. Antes se recorrian los gastos pidiendo los pagos de cada uno
  // con un await dentro del bucle, de modo que el costo crecia con el numero de
  // gastos y ademas iba en serie: cada peticion esperaba a la anterior.
  return ref.read(apiProvider).getPaymentsByGroup(groupId);
});

final groupSummaryProvider =
    FutureProvider.family<GroupSummary, int>((ref, groupId) async {
  // Las tres en paralelo. Encadenarlas con awaits sucesivos sumaba tres viajes
  // de ida y vuelta para datos que no dependen entre si; ahora que los pagos ya
  // no salen de los gastos, nada obliga a esperar.
  final results = await Future.wait([
    ref.watch(groupMembersProvider(groupId).future),
    ref.watch(groupExpensesProvider(groupId).future),
    ref.watch(allGroupPaymentsProvider(groupId).future),
  ]);

  return summarizeGroup(
    members: results[0] as List<GroupMember>,
    expenses: results[1] as List<Expense>,
    payments: results[2] as List<Payment>,
  );
});

final paymentProvider = FutureProvider.family<Payment, int>((ref, paymentId) {
  ref.watch(authControllerProvider);
  return ref.read(apiProvider).getPayment(paymentId);
});

final reputationProvider =
    FutureProvider.family<Reputation, int>((ref, userId) {
  return ref.read(apiProvider).getReputation(userId);
});

final reputationHistoryProvider =
    FutureProvider.family<List<ReputationEvent>, int>((ref, userId) {
  return ref.read(apiProvider).getReputationHistory(userId);
});

final badgesProvider =
    FutureProvider.family<List<PblBadge>, int>((ref, userId) {
  return ref.read(apiProvider).getBadges(userId);
});

final myReputationProvider = FutureProvider<Reputation?>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) return null;
  return ref.read(apiProvider).getReputation(session.id);
});

final myBadgesProvider = FutureProvider<List<PblBadge>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) return const [];
  return ref.read(apiProvider).getBadges(session.id);
});

final myReputationHistoryProvider =
    FutureProvider<List<ReputationEvent>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) return const [];
  return ref.read(apiProvider).getReputationHistory(session.id);
});

final groupLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, int>((ref, groupId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) return const [];
  return ref.read(apiProvider).getGroupLeaderboard(
        groupId: groupId,
        viewerUserId: session.id,
      );
});

final overdueMembersProvider =
    FutureProvider.family<List<OverdueMember>, int>((ref, groupId) {
  return ref.read(apiProvider).getOverdueMembers(groupId);
});

final overdueMemberDebtsProvider = FutureProvider.family<
    List<OverduePaymentDebt>, ({int groupId, int memberId})>((ref, args) {
  return ref.read(apiProvider).getOverdueMemberDebts(
        groupId: args.groupId,
        memberId: args.memberId,
      );
});

final publicMemberProfileProvider =
    FutureProvider.family<PublicMemberProfile, ({int groupId, int memberId})>(
        (ref, args) {
  return ref.read(apiProvider).getPublicMemberProfile(
        groupId: args.groupId,
        memberId: args.memberId,
      );
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const DashboardSummary(
      balance: 0,
      totalExpenses: 0,
      totalPaid: 0,
      totalPending: 0,
      score: 100,
      monthlyExpenses: {},
      recentPayments: [],
    );
  }
  // Dashboard data mixes outgoing debts with incoming collections, so all
  // three datasets are fetched before applying local presentation calculations.
  final expenses = await ref.read(apiProvider).getExpensesByUser(session.id);
  final outgoing = await ref.read(apiProvider).getPaymentsByUser(session.id);
  final incoming = await ref.read(apiProvider).getIncomingPayments(session.id);
  return summarizeDashboard(
    expenses: expenses,
    outgoingPayments: outgoing,
    incomingPayments: incoming,
  );
});

void invalidateGroup(WidgetRef ref, int groupId) {
  // Group mutations affect expenses, payments, rankings and dashboard totals.
  // Invalidating this bundle keeps screens consistent after one write action.
  ref.invalidate(groupsProvider);
  ref.invalidate(groupProvider(groupId));
  ref.invalidate(groupMembersProvider(groupId));
  ref.invalidate(groupExpensesProvider(groupId));
  ref.invalidate(allGroupPaymentsProvider(groupId));
  ref.invalidate(groupSummaryProvider(groupId));
  ref.invalidate(groupLeaderboardProvider(groupId));
  ref.invalidate(overdueMembersProvider(groupId));
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(myReputationProvider);
  ref.invalidate(myBadgesProvider);
  ref.invalidate(myReputationHistoryProvider);
}
