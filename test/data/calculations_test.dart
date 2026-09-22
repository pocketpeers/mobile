import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/data/calculations.dart';
import 'package:pocketpeers/src/data/models.dart';

void main() {
  group('equalSplit', () {
    test('returns empty list without members', () {
      expect(equalSplit(amount: 100, members: const []), isEmpty);
    });

    test('splits amount equally and assigns rounding remainder to last member', () {
      final drafts = equalSplit(
        amount: 100,
        members: const [
          GroupMember(
            groupId: 1,
            userId: 1,
            fullName: 'Ana',
            photo: 'a.png',
            role: 'MEMBER',
          ),
          GroupMember(
            groupId: 1,
            userId: 2,
            fullName: 'Luis',
            photo: 'l.png',
            role: 'MEMBER',
          ),
          GroupMember(
            groupId: 1,
            userId: 3,
            fullName: 'Mia',
            photo: 'm.png',
            role: 'MEMBER',
          ),
        ],
      );

      expect(drafts.map((draft) => draft.amount), [33.33, 33.33, 33.34]);
      expect(drafts.fold<double>(0, (sum, draft) => sum + draft.amount), 100);
    });
  });

  group('customSplitMatches', () {
    test('allows cent rounding tolerance', () {
      expect(customSplitMatches(100, [33.33, 33.33, 33.34]), isTrue);
      expect(customSplitMatches(100, [50, 49.98]), isFalse);
    });
  });

  group('summarizeGroup', () {
    test('summarizes active expenses, confirmed payments and debts by user', () {
      final summary = summarizeGroup(
        members: const [
          GroupMember(
            groupId: 1,
            userId: 1,
            fullName: 'Ana',
            photo: '',
            role: 'MEMBER',
          ),
          GroupMember(
            groupId: 1,
            userId: 2,
            fullName: 'Luis',
            photo: '',
            role: 'MEMBER',
          ),
        ],
        expenses: [
          expense(id: 1, amount: 100),
          expense(id: 2, amount: 999, active: 0),
        ],
        payments: const [
          Payment(
            id: 1,
            description: 'Ana',
            amount: 60,
            amountPaid: 60,
            status: 'COMPLETED',
            confirmed: true,
            userId: 1,
            expenseId: 1,
            blockchainHash: '',
            evidencePhotos: [],
          ),
          Payment(
            id: 2,
            description: 'Luis',
            amount: 40,
            amountPaid: 10,
            status: 'PARTIAL',
            confirmed: false,
            userId: 2,
            expenseId: 1,
            blockchainHash: '',
            evidencePhotos: [],
          ),
          Payment(
            id: 3,
            description: 'Invitado',
            amount: 25,
            amountPaid: 0,
            status: 'PENDING',
            confirmed: false,
            userId: 99,
            expenseId: 1,
            blockchainHash: '',
            evidencePhotos: [],
          ),
        ],
      );

      expect(summary.totalExpenses, 100);
      expect(summary.totalPaid, 60);
      expect(summary.totalPending, 65);
      expect(summary.completedPayments, 1);
      expect(summary.pendingPayments, 2);
      expect(summary.debts.map((debt) => debt.name), ['Luis', 'Usuario 99']);
      expect(summary.debts.map((debt) => debt.amount), [40, 25]);
    });
  });

  group('summarizeDashboard', () {
    test('builds balance, score, monthly totals and recent payments', () {
      final summary = summarizeDashboard(
        expenses: [
          expense(id: 1, amount: 100, createdAt: DateTime(2026, 6, 1)),
          expense(id: 2, amount: 50, createdAt: DateTime(2026, 6, 10)),
          expense(id: 3, amount: 999, active: 0),
        ],
        outgoingPayments: const [
          Payment(
            id: 1,
            description: 'Pagado',
            amount: 40,
            amountPaid: 40,
            status: 'COMPLETED',
            confirmed: true,
            userId: 1,
            expenseId: 1,
            blockchainHash: '',
            evidencePhotos: [],
          ),
          Payment(
            id: 3,
            description: 'Pendiente',
            amount: 30,
            amountPaid: 10,
            status: 'PARTIAL',
            confirmed: false,
            userId: 1,
            expenseId: 2,
            blockchainHash: '',
            evidencePhotos: [],
          ),
        ],
        incomingPayments: const [
          Payment(
            id: 2,
            description: 'Entrante',
            amount: 70,
            amountPaid: 20,
            status: 'PARTIAL',
            confirmed: false,
            userId: 2,
            expenseId: 1,
            blockchainHash: '',
            evidencePhotos: [],
          ),
        ],
        userId: 1,
      );

      expect(summary.totalExpenses, 150);
      expect(summary.totalPaid, 40);
      expect(summary.totalPending, 30);
      expect(summary.balance, 40);
      expect(summary.score, 50);
      expect(summary.monthlyExpenses, {'2026-06': 150});
      expect(summary.recentPayments.map((payment) => payment.id), [3, 2, 1]);
    });

    /// La cuota que te asigna otro tiene que aparecer en "Vence pronto".
    ///
    /// Es el fallo que se vio en campo: con un solo creador por grupo nunca
    /// pasaba, pero desde que cualquier integrante puede crear gastos, un
    /// deudor tiene cuotas en gastos ajenos. La app solo pedia los gastos
    /// propios, no encontraba el gasto del pago, y lo descartaba en silencio:
    /// la pantalla decia "No tienes pagos pendientes con fecha" teniendo uno
    /// que vencia al dia siguiente.
    test('an expense created by someone else still feeds upcoming payments', () {
      final summary = summarizeDashboard(
        expenses: [
          // Ajeno: lo creo el usuario 2 y a mi me toca una cuota.
          expense(id: 7, amount: 200, ownerId: 2),
        ],
        outgoingPayments: const [
          Payment(
            id: 9,
            description: 'Mi cuota',
            amount: 50,
            amountPaid: 0,
            status: 'PENDING',
            confirmed: false,
            userId: 1,
            expenseId: 7,
            blockchainHash: '',
            evidencePhotos: [],
          ),
        ],
        incomingPayments: const [],
        userId: 1,
      );

      expect(summary.upcoming.map((item) => item.paymentId), [9]);
      expect(summary.upcoming.single.remaining, 50);

      // Y el gasto ajeno no infla lo propio: se deben 50, no los 200 que costo.
      expect(summary.totalExpenses, 0);
      expect(summary.monthlyExpenses, isEmpty);
    });

    test('uses perfect score when there are no outgoing payments', () {
      final summary = summarizeDashboard(
        expenses: const [],
        outgoingPayments: const [],
        incomingPayments: const [],
        userId: 1,
      );

      expect(summary.score, 100);
    });
  });
}

Expense expense({
  required int id,
  required double amount,
  int active = 1,
  DateTime? createdAt,
  int ownerId = 1,
}) {
  return Expense(
    id: id,
    name: 'Gasto $id',
    amount: amount,
    userId: ownerId,
    groupId: 1,
    dueDate: DateTime(2026, 6, 30),
    remainingAmount: amount,
    paidAmount: 0,
    status: 'PENDING',
    active: active,
    blockchainHash: '',
    createdAt: createdAt,
  );
}
