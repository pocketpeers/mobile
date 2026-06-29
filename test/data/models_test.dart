import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/data/models.dart';

void main() {
  group('AuthSession', () {
    test('parses numeric strings and defaults missing values', () {
      final session = AuthSession.fromJson({
        'id': '7',
        'username': 'ana',
        'token': 'jwt-token',
      });

      expect(session.id, 7);
      expect(session.username, 'ana');
      expect(session.token, 'jwt-token');

      final empty = AuthSession.fromJson({});
      expect(empty.id, 0);
      expect(empty.username, '');
      expect(empty.token, '');
    });
  });

  group('Group', () {
    test('parses map dates and scalar fields', () {
      final group = Group.fromJson({
        'id': 1,
        'name': 'Casa',
        'description': 'Gastos compartidos',
        'groupPhoto': 'photo.png',
        'adminId': '3',
        'createdAt': {'date': '2026-06-25'},
        'updatedAt': [2026, 6, 26],
      });

      expect(group.id, 1);
      expect(group.name, 'Casa');
      expect(group.adminId, 3);
      expect(group.createdAt, DateTime(2026, 6, 25));
      expect(group.updatedAt, DateTime(2026, 6, 26));
    });
  });

  group('GroupMember', () {
    test('uses fallback full name and default role', () {
      final member = GroupMember.fromJson({
        'groupId': '2',
        'userId': 9,
        'joinedAt': '2026-06-25 10:30:00',
      });

      expect(member.groupId, 2);
      expect(member.userId, 9);
      expect(member.fullName, 'Usuario 9');
      expect(member.role, 'MEMBER');
      expect(member.joinedAt, DateTime(2026, 6, 25, 10, 30));
    });
  });

  group('Expense', () {
    test('parses active expenses and nested due date', () {
      final expense = Expense.fromJson({
        'id': '5',
        'name': 'Cena',
        'amount': '120.50',
        'userId': 1,
        'groupId': 2,
        'dueDate': {'dueDate': [2026, 7, 1]},
        'remainingAmount': '20.5',
        'paidAmount': 100,
        'status': 'PARTIAL',
        'active': 1,
        'blockchainHash': 'hash',
      });

      expect(expense.id, 5);
      expect(expense.amount, 120.5);
      expect(expense.dueDate, DateTime(2026, 7));
      expect(expense.remainingAmount, 20.5);
      expect(expense.paidAmount, 100);
      expect(expense.isActive, isTrue);
    });

    test('defaults active to true when missing', () {
      expect(Expense.fromJson({}).isActive, isTrue);
    });
  });

  group('Payment', () {
    test('parses evidence photos and clamps remaining at zero', () {
      final payment = Payment.fromJson({
        'id': 10,
        'description': 'Pago',
        'amount': 50,
        'amountPaid': 75,
        'status': 'COMPLETED',
        'confirmed': true,
        'userId': '4',
        'expenseId': '8',
        'blockchainHash': 'hash',
        'evidencePhotos': ['a.png', '', ' b.png '],
      });

      expect(payment.id, 10);
      expect(payment.confirmed, isTrue);
      expect(payment.remaining, 0);
      expect(payment.evidencePhotos, ['a.png', ' b.png ']);
    });
  });

  group('Nested PBL models', () {
    test('parses public profile with nested reputation and badges', () {
      final profile = PublicMemberProfile.fromJson({
        'userId': 1,
        'fullName': 'Ana Lopez',
        'photo': 'photo.png',
        'completedPaymentsInGroup': '6',
        'reputation': {
          'userId': 1,
          'score': '140',
          'level': 'Confiable',
        },
        'badges': [
          {
            'id': 2,
            'code': 'EARLY',
            'name': 'Pago temprano',
            'description': 'Pagos a tiempo',
            'iconUrl': 'icon.png',
            'unlocked': true,
            'unlockedAt': [2026, 6, 25],
          }
        ],
      });

      expect(profile.userId, 1);
      expect(profile.reputation.score, 140);
      expect(profile.badges, hasLength(1));
      expect(profile.badges.single.unlocked, isTrue);
      expect(profile.badges.single.unlockedAt, DateTime(2026, 6, 25));
      expect(profile.completedPaymentsInGroup, 6);
    });
  });
}
