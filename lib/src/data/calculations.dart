import 'package:intl/intl.dart';

import 'models.dart';

List<SplitDraft> equalSplit({
  required double amount,
  required List<GroupMember> members,
}) {
  if (members.isEmpty) return const [];
  final share = double.parse((amount / members.length).toStringAsFixed(2));
  final drafts = <SplitDraft>[];
  var assigned = 0.0;
  for (final member in members) {
    final isLast = member == members.last;
    final value = isLast ? amount - assigned : share;
    assigned += value;
    drafts.add(
      SplitDraft(
        userId: member.userId,
        fullName: member.fullName,
        amount: double.parse(value.toStringAsFixed(2)),
      ),
    );
  }
  return drafts;
}

bool customSplitMatches(double amount, Iterable<double> shares) {
  final total = shares.fold<double>(0, (sum, item) => sum + item);
  return (total - amount).abs() < 0.01;
}

GroupSummary summarizeGroup({
  required List<GroupMember> members,
  required List<Expense> expenses,
  required List<Payment> payments,
}) {
  final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + item.amount);
  final totalPaid = payments.fold<double>(0, (sum, item) => sum + item.amountPaid);
  final totalPending = payments.fold<double>(0, (sum, item) => sum + item.remaining);
  final namesByUser = {for (final member in members) member.userId: member.fullName};
  final debtByUser = <int, double>{};
  for (final payment in payments) {
    debtByUser[payment.userId] = (debtByUser[payment.userId] ?? 0) + payment.remaining;
  }
  final debts = debtByUser.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) => DebtLine(
          userId: entry.key,
          name: namesByUser[entry.key] ?? 'Usuario ${entry.key}',
          amount: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return GroupSummary(
    totalExpenses: totalExpenses,
    totalPaid: totalPaid,
    totalPending: totalPending,
    completedPayments: payments.where((item) => item.remaining <= 0).length,
    pendingPayments: payments.where((item) => item.remaining > 0).length,
    debts: debts,
  );
}

DashboardSummary summarizeDashboard({
  required List<Expense> expenses,
  required List<Payment> outgoingPayments,
  required List<Payment> incomingPayments,
}) {
  final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + item.amount);
  final totalPaid = outgoingPayments.fold<double>(0, (sum, item) => sum + item.amountPaid);
  final incomingPending = incomingPayments.fold<double>(0, (sum, item) => sum + item.remaining);
  final outgoingPending = outgoingPayments.fold<double>(0, (sum, item) => sum + item.remaining);
  final totalPayments = outgoingPayments.length;
  final paidPayments = outgoingPayments.where((item) => item.remaining <= 0).length;
  final score = totalPayments == 0 ? 100 : ((paidPayments / totalPayments) * 100).round();

  final monthFormatter = DateFormat('yyyy-MM');
  final monthly = <String, double>{};
  for (final expense in expenses) {
    final date = expense.createdAt ?? expense.dueDate;
    if (date == null) continue;
    final month = monthFormatter.format(date);
    monthly[month] = (monthly[month] ?? 0) + expense.amount;
  }

  final recent = [...outgoingPayments, ...incomingPayments]
    ..sort((a, b) => b.id.compareTo(a.id));

  return DashboardSummary(
    balance: incomingPending - outgoingPending,
    totalExpenses: totalExpenses,
    totalPaid: totalPaid,
    totalPending: outgoingPending,
    score: score,
    monthlyExpenses: monthly,
    recentPayments: recent.take(8).toList(),
  );
}
