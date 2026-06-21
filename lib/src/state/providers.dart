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

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  PocketPeersApi get _api => ref.read(apiProvider);

  @override
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

final allGroupPaymentsProvider =
    FutureProvider.family<List<Payment>, int>((ref, groupId) async {
  final expenses = await ref.watch(groupExpensesProvider(groupId).future);
  final payments = <Payment>[];
  for (final expense in expenses) {
    payments
        .addAll(await ref.read(apiProvider).getPaymentsByExpense(expense.id));
  }
  return payments;
});

final groupSummaryProvider =
    FutureProvider.family<GroupSummary, int>((ref, groupId) async {
  final members = await ref.watch(groupMembersProvider(groupId).future);
  final expenses = await ref.watch(groupExpensesProvider(groupId).future);
  final payments = await ref.watch(allGroupPaymentsProvider(groupId).future);
  return summarizeGroup(
      members: members, expenses: expenses, payments: payments);
});

final paymentProvider = FutureProvider.family<Payment, int>((ref, paymentId) {
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
