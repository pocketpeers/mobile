import 'package:intl/intl.dart';

import 'models.dart';

List<SplitDraft> equalSplit({
  required double amount,
  required List<GroupMember> members,
}) {
  if (members.isEmpty) return const [];
  // Round each share to cents and put the rounding remainder on the last member
  // so the split always totals exactly the original expense amount.
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
        photo: member.photo,
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
  // Local summaries mirror backend business rules: only active expenses and
  // confirmed payment amounts contribute to paid totals.
  expenses = expenses.where((expense) => expense.isActive).toList();
  final totalExpenses =
      expenses.fold<double>(0, (sum, item) => sum + item.amount);
  final totalPaid =
      payments.fold<double>(0, (sum, item) => sum + _confirmedPaid(item));
  final totalPending =
      payments.fold<double>(0, (sum, item) => sum + _consideredRemaining(item));
  final namesByUser = {
    for (final member in members) member.userId: member.fullName
  };
  final debtByUser = <int, double>{};
  for (final payment in payments) {
    debtByUser[payment.userId] =
        (debtByUser[payment.userId] ?? 0) + _consideredRemaining(payment);
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
    completedPayments:
        payments.where((item) => item.confirmed && item.remaining <= 0).length,
    pendingPayments:
        payments.where((item) => !item.confirmed || item.remaining > 0).length,
    debts: debts,
  );
}

/// Resume el panel.
///
/// [expenses] son los gastos en los que la persona participa: los que creó y
/// aquellos donde le asignaron una cuota. Los dos grupos hacen falta, pero para
/// cosas distintas, y mezclarlos daría cifras falsas:
///
/// - **Los propios** alimentan «Total» y el gráfico mensual. Si contaran los
///   ajenos, el total sumaría el importe completo de un gasto del que la
///   persona solo debe una parte.
/// - **Todos** sirven para cruzar cada pago con su fecha de vencimiento, que
///   vive en el gasto. Sin los ajenos, una cuota que otro te asignó no tenía
///   dónde mirar su fecha y «Vence pronto» la descartaba en silencio.
DashboardSummary summarizeDashboard({
  required List<Expense> expenses,
  required List<Payment> outgoingPayments,
  required List<Payment> incomingPayments,
  required int userId,
}) {
  // Balance is a personal cash-flow view: incoming pending collections minus
  // outgoing pending obligations.
  expenses = expenses.where((expense) => expense.isActive).toList();
  final ownExpenses =
      expenses.where((expense) => expense.userId == userId).toList();
  final totalExpenses =
      ownExpenses.fold<double>(0, (sum, item) => sum + item.amount);
  final totalPaid = outgoingPayments.fold<double>(
      0, (sum, item) => sum + _confirmedPaid(item));
  final incomingPending = incomingPayments.fold<double>(
      0, (sum, item) => sum + _consideredRemaining(item));
  final outgoingPending = outgoingPayments.fold<double>(
      0, (sum, item) => sum + _consideredRemaining(item));
  final totalPayments = outgoingPayments.length;
  final paidPayments = outgoingPayments
      .where((item) => item.confirmed && item.remaining <= 0)
      .length;
  final score =
      totalPayments == 0 ? 100 : ((paidPayments / totalPayments) * 100).round();

  final monthFormatter = DateFormat('yyyy-MM');
  final monthly = <String, double>{};
  // Solo los propios: el grafico responde "cuanto he puesto yo cada mes".
  for (final expense in ownExpenses) {
    final date = expense.createdAt ?? expense.dueDate;
    if (date == null) continue;
    final month = monthFormatter.format(date);
    monthly[month] = (monthly[month] ?? 0) + expense.amount;
  }

  final recent = [...outgoingPayments, ...incomingPayments]
    ..sort((a, b) => b.id.compareTo(a.id));

  // Deudas propias con fecha, de la mas urgente a la mas lejana. Se cruza el
  // pago con su gasto porque la fecha de vencimiento vive en el gasto, y aqui
  // se usan TODOS los gastos —tambien los ajenos— porque justamente las cuotas
  // que otro te asigno son las que antes se perdian.
  final expenseById = {for (final expense in expenses) expense.id: expense};
  final upcoming = <UpcomingPayment>[];
  for (final payment in outgoingPayments) {
    if (_consideredRemaining(payment) <= 0) continue;
    final expense = expenseById[payment.expenseId];
    final dueDate = expense?.dueDate;
    if (expense == null || dueDate == null) continue;
    upcoming.add(UpcomingPayment(
      paymentId: payment.id,
      title: expense.name,
      remaining: _consideredRemaining(payment),
      dueDate: dueDate,
    ));
  }
  upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));

  return DashboardSummary(
    balance: incomingPending - outgoingPending,
    totalExpenses: totalExpenses,
    totalPaid: totalPaid,
    totalPending: outgoingPending,
    score: score,
    monthlyExpenses: monthly,
    recentPayments: recent.take(8).toList(),
    upcoming: upcoming,
  );
}

double _confirmedPaid(Payment payment) {
  return payment.confirmed ? payment.amountPaid : 0;
}

double _consideredRemaining(Payment payment) {
  return payment.amount - _confirmedPaid(payment);
}
