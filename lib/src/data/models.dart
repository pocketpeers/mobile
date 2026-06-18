import 'dart:math';

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _toDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Map) {
    return _toDate(value['dueDate'] ??
        value['date'] ??
        value['value'] ??
        value['createdAt'] ??
        value['updatedAt']);
  }
  if (value is List) {
    if (value.length >= 3) {
      final year = _toInt(value[0]);
      final month = _toInt(value[1]);
      final day = _toInt(value[2]);
      if (year > 0 && month > 0 && day > 0) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }
  return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
}

class AuthSession {
  const AuthSession({
    required this.id,
    required this.username,
    required this.token,
  });

  final int id;
  final String username;
  final String token;

  factory AuthSession.fromJson(Map<String, Object?> json) => AuthSession(
        id: _toInt(json['id']),
        username: json['username']?.toString() ?? '',
        token: json['token']?.toString() ?? '',
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.photo,
    required this.email,
    required this.userId,
  });

  final int id;
  final String fullName;
  final String phoneNumber;
  final String photo;
  final String email;
  final int userId;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        id: _toInt(json['id']),
        fullName: json['fullName']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        userId: _toInt(json['userId']),
      );
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.groupPhoto,
    required this.adminId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final String groupPhoto;
  final int adminId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Group.fromJson(Map<String, Object?> json) => Group(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        groupPhoto: json['groupPhoto']?.toString() ?? '',
        adminId: _toInt(json['adminId']),
        createdAt: _toDate(json['createdAt']),
        updatedAt: _toDate(json['updatedAt']),
      );
}

class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.fullName,
    required this.photo,
    required this.role,
    this.joinedAt,
  });

  final int groupId;
  final int userId;
  final String fullName;
  final String photo;
  final String role;
  final DateTime? joinedAt;

  factory GroupMember.fromJson(Map<String, Object?> json) => GroupMember(
        groupId: _toInt(json['groupId']),
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? 'Usuario ${json['userId']}',
        photo: json['photo']?.toString() ?? '',
        role: json['role']?.toString() ?? 'MEMBER',
        joinedAt: _toDate(json['joinedAt']),
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.userId,
    required this.groupId,
    required this.remainingAmount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final double amount;
  final int userId;
  final int groupId;
  final DateTime? dueDate;
  final double remainingAmount;
  final double paidAmount;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Expense.fromJson(Map<String, Object?> json) => Expense(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        userId: _toInt(json['userId']),
        groupId: _toInt(json['groupId']),
        dueDate: _toDate(json['dueDate']),
        remainingAmount: _toDouble(json['remainingAmount']),
        paidAmount: _toDouble(json['paidAmount']),
        status: json['status']?.toString() ?? 'PENDING',
        createdAt: _toDate(json['createdAt']),
        updatedAt: _toDate(json['updatedAt']),
      );
}

class Payment {
  const Payment({
    required this.id,
    required this.description,
    required this.amount,
    required this.amountPaid,
    required this.status,
    required this.confirmed,
    required this.userId,
    required this.expenseId,
    required this.evidencePhotos,
  });

  final int id;
  final String description;
  final double amount;
  final double amountPaid;
  final String status;
  final bool confirmed;
  final int userId;
  final int expenseId;
  final List<String> evidencePhotos;

  double get remaining => max(0, amount - amountPaid);

  factory Payment.fromJson(Map<String, Object?> json) => Payment(
        id: _toInt(json['id']),
        description: json['description']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        amountPaid: _toDouble(json['amountPaid']),
        status: json['status']?.toString() ?? 'PENDING',
        confirmed: json['confirmed'] == true,
        userId: _toInt(json['userId']),
        expenseId: _toInt(json['expenseId']),
        evidencePhotos: ((json['evidencePhotos'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(),
      );
}

class Receipt {
  const Receipt({
    required this.id,
    required this.name,
    required this.receiptNumber,
    required this.amount,
    required this.imagePath,
    this.issueDate,
  });

  final int id;
  final String name;
  final String receiptNumber;
  final double amount;
  final DateTime? issueDate;
  final String imagePath;

  factory Receipt.fromJson(Map<String, Object?> json) => Receipt(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? '',
        receiptNumber: json['receiptNumber']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        issueDate: _toDate(json['issueDate']),
        imagePath: json['imagePath']?.toString() ?? '',
      );
}

class ReceiptOcr {
  const ReceiptOcr({
    required this.name,
    required this.receiptNumber,
    required this.amount,
    required this.imagePath,
    required this.dataFields,
    this.issueDate,
  });

  final String name;
  final String receiptNumber;
  final double amount;
  final DateTime? issueDate;
  final String imagePath;
  final Map<String, Object?> dataFields;

  factory ReceiptOcr.fromJson(Map<String, Object?> json) => ReceiptOcr(
        name: json['name']?.toString() ?? '',
        receiptNumber: json['receiptNumber']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        issueDate: _toDate(json['issueDate']),
        imagePath: json['imagePath']?.toString() ?? '',
        dataFields:
            Map<String, Object?>.from((json['dataFields'] as Map?) ?? const {}),
      );
}

class ImageUpload {
  const ImageUpload(this.imageId);

  final String imageId;

  factory ImageUpload.fromJson(Map<String, Object?> json) =>
      ImageUpload(json['imageId']?.toString() ?? '');
}

class PaymentReminder {
  const PaymentReminder({
    required this.id,
    required this.paymentId,
    required this.expenseId,
    required this.groupId,
    required this.groupName,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
  });

  final int id;
  final int paymentId;
  final int expenseId;
  final int groupId;
  final String groupName;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;

  factory PaymentReminder.fromJson(Map<String, Object?> json) =>
      PaymentReminder(
        id: _toInt(json['id']),
        paymentId: _toInt(json['paymentId']),
        expenseId: _toInt(json['expenseId']),
        groupId: _toInt(json['groupId']),
        groupName: json['groupName']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Recordatorio de pago',
        body: json['body']?.toString() ?? '',
        createdAt: _toDate(json['createdAt']),
      );
}

class Reputation {
  const Reputation({
    required this.userId,
    required this.score,
    required this.level,
    required this.levelDescription,
    required this.pointsToNextLevel,
    required this.onTimePaymentStreak,
    required this.completedPayments,
  });

  final int userId;
  final int score;
  final String level;
  final String levelDescription;
  final int pointsToNextLevel;
  final int onTimePaymentStreak;
  final int completedPayments;

  factory Reputation.fromJson(Map<String, Object?> json) => Reputation(
        userId: _toInt(json['userId']),
        score: _toInt(json['score']),
        level: json['level']?.toString() ?? 'Nuevo',
        levelDescription: json['levelDescription']?.toString() ?? '',
        pointsToNextLevel: _toInt(json['pointsToNextLevel']),
        onTimePaymentStreak: _toInt(json['onTimePaymentStreak']),
        completedPayments: _toInt(json['completedPayments']),
      );
}

class ReputationEvent {
  const ReputationEvent({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.paymentId,
    required this.type,
    required this.pointsDelta,
    required this.resultingScore,
    required this.description,
    this.occurredAt,
  });

  final int id;
  final int userId;
  final int groupId;
  final int paymentId;
  final String type;
  final int pointsDelta;
  final int resultingScore;
  final String description;
  final DateTime? occurredAt;

  factory ReputationEvent.fromJson(Map<String, Object?> json) =>
      ReputationEvent(
        id: _toInt(json['id']),
        userId: _toInt(json['userId']),
        groupId: _toInt(json['groupId']),
        paymentId: _toInt(json['paymentId']),
        type: json['type']?.toString() ?? '',
        pointsDelta: _toInt(json['pointsDelta']),
        resultingScore: _toInt(json['resultingScore']),
        description: json['description']?.toString() ?? '',
        occurredAt: _toDate(json['occurredAt']),
      );
}

class PblBadge {
  const PblBadge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.unlocked,
    this.unlockedAt,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String iconUrl;
  final bool unlocked;
  final DateTime? unlockedAt;

  factory PblBadge.fromJson(Map<String, Object?> json) => PblBadge(
        id: _toInt(json['id']),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        iconUrl: json['iconUrl']?.toString() ?? '',
        unlocked: json['unlocked'] == true,
        unlockedAt: _toDate(json['unlockedAt']),
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.fullName,
    required this.photo,
    required this.position,
    required this.score,
    required this.level,
    required this.unlockedBadges,
    required this.currentUser,
    required this.trend,
  });

  final int userId;
  final String fullName;
  final String photo;
  final int position;
  final int score;
  final String level;
  final int unlockedBadges;
  final bool currentUser;
  final String trend;

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) =>
      LeaderboardEntry(
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        position: _toInt(json['position']),
        score: _toInt(json['score']),
        level: json['level']?.toString() ?? 'Nuevo',
        unlockedBadges: _toInt(json['unlockedBadges']),
        currentUser: json['currentUser'] == true,
        trend: json['trend']?.toString() ?? 'STABLE',
      );
}

class PublicMemberProfile {
  const PublicMemberProfile({
    required this.userId,
    required this.fullName,
    required this.photo,
    required this.reputation,
    required this.badges,
    required this.completedPaymentsInGroup,
  });

  final int userId;
  final String fullName;
  final String photo;
  final Reputation reputation;
  final List<PblBadge> badges;
  final int completedPaymentsInGroup;

  factory PublicMemberProfile.fromJson(Map<String, Object?> json) =>
      PublicMemberProfile(
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        reputation: Reputation.fromJson(
          Map<String, Object?>.from((json['reputation'] as Map?) ?? const {}),
        ),
        badges: ((json['badges'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => PblBadge.fromJson(Map<String, Object?>.from(item)))
            .toList(),
        completedPaymentsInGroup: _toInt(json['completedPaymentsInGroup']),
      );
}

class SplitDraft {
  const SplitDraft({
    required this.userId,
    required this.fullName,
    required this.photo,
    required this.amount,
  });

  final int userId;
  final String fullName;
  final String photo;
  final double amount;
}

class GroupSummary {
  const GroupSummary({
    required this.totalExpenses,
    required this.totalPaid,
    required this.totalPending,
    required this.completedPayments,
    required this.pendingPayments,
    required this.debts,
  });

  final double totalExpenses;
  final double totalPaid;
  final double totalPending;
  final int completedPayments;
  final int pendingPayments;
  final List<DebtLine> debts;
}

class DebtLine {
  const DebtLine({
    required this.userId,
    required this.name,
    required this.amount,
  });

  final int userId;
  final String name;
  final double amount;
}

class DashboardSummary {
  const DashboardSummary({
    required this.balance,
    required this.totalExpenses,
    required this.totalPaid,
    required this.totalPending,
    required this.score,
    required this.monthlyExpenses,
    required this.recentPayments,
  });

  final double balance;
  final double totalExpenses;
  final double totalPaid;
  final double totalPending;
  final int score;
  final Map<String, double> monthlyExpenses;
  final List<Payment> recentPayments;
}
