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
  // Jackson serializa las fechas en ISO salvo que se le configure lo
  // contrario, en cuyo caso llegan como milisegundos desde epoch. Aceptar las
  // dos formas evita que un cambio de configuracion del backend vacie las
  // fechas de la app sin que nadie se entere.
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
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
    required this.username,
    required this.fullName,
    required this.phoneNumber,
    required this.photo,
    required this.email,
    required this.userId,
    this.documentType,
    this.documentNumber,
  });

  final int id;
  final String username;
  final String fullName;
  final String phoneNumber;
  final String photo;
  final String email;
  final int userId;

  /// Documento de identidad. Nulo en las cuentas creadas antes de pedirlo, y
  /// solo llega en el perfil propio: los endpoints que sirven perfiles ajenos
  /// no lo incluyen a proposito.
  final String? documentType;
  final String? documentNumber;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        id: _toInt(json['id']),
        username: json['username']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        userId: _toInt(json['userId']),
        documentType: json['documentType']?.toString(),
        documentNumber: json['documentNumber']?.toString(),
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

/// Declaracion jurada que hay que firmar para entrar a un grupo.
///
/// El texto lo arma el servidor con el nombre, el DNI y el grupo ya puestos;
/// la aplicacion solo lo muestra y devuelve la version aceptada.
class MembershipDeclaration {
  const MembershipDeclaration({required this.version, required this.text});

  final String version;
  final String text;

  factory MembershipDeclaration.fromJson(Map<String, Object?> json) =>
      MembershipDeclaration(
        version: json['version']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
      );
}

/// Una declaracion jurada ya firmada. El PDF se descarga aparte.
class SignedDeclaration {
  const SignedDeclaration({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.currentGroupName,
    required this.userId,
    required this.fullName,
    required this.version,
    this.acceptedAt,
  });

  final int id;
  final int groupId;

  /// Nombre del grupo cuando se firmo: es el que figura en el PDF.
  final String groupName;

  /// Nombre actual, o null si el grupo ya no existe.
  final String? currentGroupName;
  final int userId;
  final String fullName;
  final String version;
  final DateTime? acceptedAt;

  /// Nombre a mostrar: el actual si el grupo sigue existiendo.
  String get displayGroupName => currentGroupName ?? groupName;

  /// Si el grupo cambio de nombre despues de la firma.
  bool get groupWasRenamed =>
      currentGroupName != null && currentGroupName != groupName;

  factory SignedDeclaration.fromJson(Map<String, Object?> json) =>
      SignedDeclaration(
        id: _toInt(json['id']),
        groupId: _toInt(json['groupId']),
        groupName: json['groupName']?.toString() ?? '',
        currentGroupName: json['currentGroupName']?.toString(),
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? '',
        version: json['declarationVersion']?.toString() ?? '',
        acceptedAt: _toDate(json['acceptedAt'])?.toLocal(),
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
    required this.active,
    required this.blockchainHash,
    this.dueDate,
    this.anchoredAt,
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
  final int active;
  final String blockchainHash;

  /// Cuándo el gasto quedó escrito en la cadena. Nulo mientras no lo esté.
  final DateTime? anchoredAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => active == 1;

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
        active: _toInt(json['active'] ?? 1),
        blockchainHash: json['blockchainHash']?.toString() ?? '',
        anchoredAt: _toDate(json['anchoredAt']),
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
    required this.blockchainHash,
    required this.evidencePhotos,
    this.anchoredAt,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
  });

  final int id;
  final String description;
  final double amount;
  final double amountPaid;
  final String status;
  final bool confirmed;
  final int userId;
  final int expenseId;
  final String blockchainHash;
  final List<String> evidencePhotos;

  /// Cuando la operacion quedo escrita en la cadena.
  ///
  /// Va siempre con [blockchainHash]: los dos salen del mismo eslabon, asi que
  /// si hay hash hay fecha. Es la que acompaña al hash, porque un comprobante
  /// sin el momento al que corresponde no prueba gran cosa.
  final DateTime? anchoredAt;

  /// Cuando se registro el pago en la aplicacion.
  final DateTime? createdAt;

  final DateTime? updatedAt;

  /// Cuando el usuario declara haber pagado. Nulo mientras no abone nada.
  final DateTime? paidAt;

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
        blockchainHash: json['blockchainHash']?.toString() ?? '',
        anchoredAt: _toDate(json['anchoredAt']),
        createdAt: _toDate(json['createdAt']),
        updatedAt: _toDate(json['updatedAt']),
        paidAt: _toDate(json['paidAt']),
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
    required this.issuerRuc,
    required this.amount,
    required this.imagePath,
    required this.dataFields,
    this.issueDate,
    this.duplicate = false,
    this.duplicateMessage,
    this.duplicateOfExpenseId,
  });

  final String name;
  final String receiptNumber;

  /// RUC del emisor leido por el OCR. Viaja de vuelta al registrar el
  /// comprobante porque, junto con la serie-numero, es la llave con que el
  /// backend detecta una boleta ya usada en otro gasto.
  final String issuerRuc;
  final double amount;
  final DateTime? issueDate;
  final String imagePath;
  final Map<String, Object?> dataFields;

  /// Si esta boleta ya respalda otro gasto.
  ///
  /// El backend lo resuelve al leer la imagen, que es el ultimo momento en que
  /// avisar sirve de algo: el paso siguiente crea el gasto y reparte los pagos
  /// entre el grupo, y deshacer eso ya no es cosa de un boton.
  final bool duplicate;

  /// Texto del backend, que nombra el gasto donde ya esta registrada.
  final String? duplicateMessage;
  final int? duplicateOfExpenseId;

  factory ReceiptOcr.fromJson(Map<String, Object?> json) => ReceiptOcr(
        name: json['name']?.toString() ?? '',
        receiptNumber: json['receiptNumber']?.toString() ?? '',
        issuerRuc: json['issuerRuc']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        issueDate: _toDate(json['issueDate']),
        imagePath: json['imagePath']?.toString() ?? '',
        dataFields:
            Map<String, Object?>.from((json['dataFields'] as Map?) ?? const {}),
        duplicate: json['duplicate'] == true,
        duplicateMessage: json['duplicateMessage']?.toString(),
        duplicateOfExpenseId: json['duplicateOfExpenseId'] == null
            ? null
            : _toInt(json['duplicateOfExpenseId']),
      );
}

/// Cuanto le falta al grupo para tener todo registrado en cadena.
///
/// Es lo que la pantalla de grupo consulta mientras espera los hashes. Antes
/// para saberlo recargaba la lista de gastos, la de pagos, el resumen y, por
/// cada gasto, el gasto y sus pagos: con diez gastos, veintitres peticiones
/// cada tres segundos. Aqui es una, y los datos de verdad se recargan una sola
/// vez cuando [pending] llega a cero.
class BlockchainStatus {
  const BlockchainStatus({
    required this.pendingExpenses,
    required this.pendingPayments,
    required this.pending,
  });

  final int pendingExpenses;
  final int pendingPayments;
  final int pending;

  bool get settled => pending == 0;

  factory BlockchainStatus.fromJson(Map<String, Object?> json) =>
      BlockchainStatus(
        pendingExpenses: _toInt(json['pendingExpenses']),
        pendingPayments: _toInt(json['pendingPayments']),
        pending: _toInt(json['pending']),
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
    this.read = false,
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

  /// Si el usuario ya la vio. El historial devuelve leidas y no leidas juntas,
  /// asi que la pantalla necesita distinguirlas.
  final bool read;

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
        read: json['read'] == true,
      );
}

class OverdueMember {
  const OverdueMember({
    required this.userId,
    required this.fullName,
    required this.photo,
    required this.overdueAmount,
    required this.maxDaysOverdue,
    required this.overduePaymentsCount,
    this.oldestDueDate,
  });

  final int userId;
  final String fullName;
  final String photo;
  final double overdueAmount;
  final DateTime? oldestDueDate;
  final int maxDaysOverdue;
  final int overduePaymentsCount;

  factory OverdueMember.fromJson(Map<String, Object?> json) => OverdueMember(
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        overdueAmount: _toDouble(json['overdueAmount']),
        oldestDueDate: _toDate(json['oldestDueDate']),
        maxDaysOverdue: _toInt(json['maxDaysOverdue']),
        overduePaymentsCount: _toInt(json['overduePaymentsCount']),
      );
}

class OverduePaymentDebt {
  const OverduePaymentDebt({
    required this.paymentId,
    required this.expenseId,
    required this.expenseName,
    required this.groupName,
    required this.amount,
    required this.amountPaid,
    required this.overdueAmount,
    required this.daysOverdue,
    required this.status,
    required this.confirmed,
    this.dueDate,
  });

  final int paymentId;
  final int expenseId;
  final String expenseName;
  final String groupName;
  final double amount;
  final double amountPaid;
  final double overdueAmount;
  final DateTime? dueDate;
  final int daysOverdue;
  final String status;
  final bool confirmed;

  factory OverduePaymentDebt.fromJson(Map<String, Object?> json) =>
      OverduePaymentDebt(
        paymentId: _toInt(json['paymentId']),
        expenseId: _toInt(json['expenseId']),
        expenseName: json['expenseName']?.toString() ?? '',
        groupName: json['groupName']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        amountPaid: _toDouble(json['amountPaid']),
        overdueAmount: _toDouble(json['overdueAmount']),
        dueDate: _toDate(json['dueDate']),
        daysOverdue: _toInt(json['daysOverdue']),
        status: json['status']?.toString() ?? 'PENDING',
        confirmed: json['confirmed'] == true,
      );
}

class ManualOverdueReminder {
  const ManualOverdueReminder({
    required this.userId,
    required this.pushRemindersCreated,
    required this.emailSent,
    required this.message,
  });

  final int userId;
  final int pushRemindersCreated;
  final bool emailSent;
  final String message;

  factory ManualOverdueReminder.fromJson(Map<String, Object?> json) =>
      ManualOverdueReminder(
        userId: _toInt(json['userId']),
        pushRemindersCreated: _toInt(json['pushRemindersCreated']),
        emailSent: json['emailSent'] == true,
        message: json['message']?.toString() ?? '',
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
    this.nextLevel,
    this.peerScoreActive = false,
  });

  final int userId;
  final int score;
  final String level;
  final String levelDescription;

  /// Solo los puntos que faltan. No alcanza para saber si falta algo: el nivel
  /// tambien exige cumplir con varias personas, y con el puntaje ya cubierto
  /// esto vale 0 aunque el siguiente nivel siga lejos. Ver [nextLevel].
  final int pointsToNextLevel;
  final int onTimePaymentStreak;
  final int completedPayments;

  /// Todo lo que falta para el siguiente nivel. Null en el nivel maximo, o si
  /// el backend usa el motor anterior ([peerScoreActive] en falso).
  final NextLevelGoal? nextLevel;
  final bool peerScoreActive;

  factory Reputation.fromJson(Map<String, Object?> json) => Reputation(
        userId: _toInt(json['userId']),
        score: _toInt(json['score']),
        level: json['level']?.toString() ?? 'Nuevo',
        levelDescription: json['levelDescription']?.toString() ?? '',
        pointsToNextLevel: _toInt(json['pointsToNextLevel']),
        onTimePaymentStreak: _toInt(json['onTimePaymentStreak']),
        completedPayments: _toInt(json['completedPayments']),
        nextLevel: json['nextLevel'] is Map
            ? NextLevelGoal.fromJson(
                Map<String, Object?>.from(json['nextLevel'] as Map))
            : null,
        peerScoreActive: json['peerScoreActive'] == true,
      );
}

/// Que le falta a alguien para el siguiente nivel, segun el motor PeerScore.
class NextLevelGoal {
  const NextLevelGoal({
    required this.levelName,
    required this.missingScore,
    required this.missingCounterparties,
    required this.bandTooWide,
  });

  final String levelName;
  final double missingScore;

  /// Contrapartes efectivas que faltan: con cuantas personas distintas hay
  /// que cumplir, pesando cuanto se le pago a cada una.
  final double missingCounterparties;

  /// El sistema todavia no tiene historial suficiente para estar seguro.
  final bool bandTooWide;

  factory NextLevelGoal.fromJson(Map<String, Object?> json) => NextLevelGoal(
        levelName: json['levelName']?.toString() ?? '',
        missingScore: _toDouble(json['missingScore']),
        missingCounterparties: _toDouble(json['missingCounterparties']),
        bandTooWide: json['bandTooWide'] == true,
      );
}

/// Un punto de la evolucion del score.
///
/// No es un evento: es el score que el motor habria calculado en ese instante,
/// reconstruido por el backend. La distincion importa porque el score no se
/// acumula —se recalcula entero desde el historial— y por eso no se puede
/// dibujar sumando los puntos de cada evento, que es lo que hacia la version
/// anterior de esta grafica con el contador PBL.
class ScoreSeriesPoint {
  const ScoreSeriesPoint({
    required this.at,
    required this.score,
    required this.bandLow,
    required this.bandHigh,
    required this.level,
    required this.levelName,
  });

  final DateTime? at;
  final double score;

  /// Extremos de la banda de confianza: cuanta certeza hay detras del numero.
  final double bandLow;
  final double bandHigh;

  /// Nombre del enum del backend, estable para comparar.
  final String level;

  /// Nombre para mostrar, ya traducido por el backend.
  final String levelName;

  factory ScoreSeriesPoint.fromJson(Map<String, Object?> json) =>
      ScoreSeriesPoint(
        at: _toDate(json['at']),
        score: _toDouble(json['score']),
        bandLow: _toDouble(json['bandLow']),
        bandHigh: _toDouble(json['bandHigh']),
        level: json['level']?.toString() ?? '',
        levelName: json['levelName']?.toString() ?? '',
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
    this.username = '',
    required this.photo,
    required this.reputation,
    required this.badges,
    required this.completedPaymentsInGroup,
  });

  final int userId;
  final String fullName;

  /// Vacio si el backend todavia no lo manda.
  final String username;
  final String photo;
  final Reputation reputation;
  final List<PblBadge> badges;
  final int completedPaymentsInGroup;

  factory PublicMemberProfile.fromJson(Map<String, Object?> json) =>
      PublicMemberProfile(
        userId: _toInt(json['userId']),
        fullName: json['fullName']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
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
    this.upcoming = const [],
  });

  final double balance;
  final double totalExpenses;
  final double totalPaid;
  final double totalPending;
  final int score;
  final Map<String, double> monthlyExpenses;
  final List<Payment> recentPayments;

  /// Deudas propias con fecha, de la mas urgente a la mas lejana.
  final List<UpcomingPayment> upcoming;
}

/// Una deuda pendiente con su vencimiento.
///
/// El pago no trae la fecha: vive en el gasto. Se resuelve el cruce una sola vez
/// al armar el resumen, para que la pantalla no tenga que buscar el gasto de
/// cada pago mientras dibuja.
class UpcomingPayment {
  const UpcomingPayment({
    required this.paymentId,
    required this.title,
    required this.remaining,
    required this.dueDate,
  });

  final int paymentId;
  final String title;
  final double remaining;
  final DateTime dueDate;

  /// Dias que faltan. Negativo si ya paso la fecha.
  int daysLeft(DateTime now) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return due.difference(today).inDays;
  }

  bool isOverdue(DateTime now) => daysLeft(now) < 0;
}

/// Invitacion a un grupo por nombre de usuario, pendiente de respuesta.
class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupPhoto,
    required this.invitedUserId,
    required this.invitedUsername,
    required this.invitedFullName,
    required this.invitedPhoto,
    required this.invitedByUsername,
    required this.invitedByFullName,
    required this.expiresAt,
  });

  final int id;
  final int groupId;
  final String groupName;
  final String groupPhoto;
  final int invitedUserId;
  final String invitedUsername;
  final String invitedFullName;
  final String invitedPhoto;
  final String invitedByUsername;
  final String invitedByFullName;
  final DateTime? expiresAt;

  /// Quien invito, como se le muestra a la persona invitada.
  String get invitedByLabel => invitedByFullName.trim().isNotEmpty
      ? invitedByFullName.trim()
      : '@$invitedByUsername';

  factory GroupInvitation.fromJson(Map<String, Object?> json) =>
      GroupInvitation(
        id: _toInt(json['id']),
        groupId: _toInt(json['groupId']),
        groupName: json['groupName']?.toString() ?? '',
        groupPhoto: json['groupPhoto']?.toString() ?? '',
        invitedUserId: _toInt(json['invitedUserId']),
        invitedUsername: json['invitedUsername']?.toString() ?? '',
        invitedFullName: json['invitedFullName']?.toString() ?? '',
        invitedPhoto: json['invitedPhoto']?.toString() ?? '',
        invitedByUsername: json['invitedByUsername']?.toString() ?? '',
        invitedByFullName: json['invitedByFullName']?.toString() ?? '',
        expiresAt: _toDate(json['expiresAt']),
      );
}

/// Si a quien se busco se le puede invitar, y si no, por que.
enum InvitationAvailability {
  available,
  alreadyMember,
  alreadyInvited,
  recentlyRejected;

  static InvitationAvailability parse(Object? value) =>
      switch (value?.toString()) {
        'ALREADY_MEMBER' => alreadyMember,
        'ALREADY_INVITED' => alreadyInvited,
        'RECENTLY_REJECTED' => recentlyRejected,
        _ => available,
      };
}

/// La persona que el administrador esta por invitar, para confirmar quien es.
class InvitationCandidate {
  const InvitationCandidate({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.photo,
    required this.availability,
  });

  final int userId;
  final String username;
  final String fullName;
  final String photo;
  final InvitationAvailability availability;

  factory InvitationCandidate.fromJson(Map<String, Object?> json) =>
      InvitationCandidate(
        userId: _toInt(json['userId']),
        username: json['username']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        photo: json['photo']?.toString() ?? '',
        availability: InvitationAvailability.parse(json['availability']),
      );
}
