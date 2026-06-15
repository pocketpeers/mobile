import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config.dart';
import 'models.dart';

typedef JsonMap = Map<String, Object?>;

class PocketPeersApi {
  PocketPeersApi({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Accept': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: StorageKeys.authToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthSession?> restoreSession() async {
    final token = await _storage.read(key: StorageKeys.authToken);
    final id = int.tryParse(await _storage.read(key: StorageKeys.userId) ?? '');
    final username = await _storage.read(key: StorageKeys.username);
    if (token == null || id == null || username == null) return null;
    return AuthSession(id: id, username: username, token: token);
  }

  Future<AuthSession> signIn(String username, String password) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/authentication/sign-in',
      data: {'username': username, 'password': password},
    );
    final session = AuthSession.fromJson(response.data ?? {});
    await _persistSession(session);
    return session;
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
  }) async {
    await _dio.post<JsonMap>(
      '/api/v1/authentication/sign-up',
      data: {
        'username': username,
        'password': password,
        'roles': ['ROLE_USER'],
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'photo': '',
        'email': email,
      },
    );
  }

  Future<void> signOut() async {
    await _storage.delete(key: StorageKeys.authToken);
    await _storage.delete(key: StorageKeys.userId);
    await _storage.delete(key: StorageKeys.username);
  }

  Future<bool> isOnboardingCompleted() async {
    return await _storage.read(key: StorageKeys.onboardingCompleted) == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storage.write(key: StorageKeys.onboardingCompleted, value: 'true');
  }

  Future<void> _persistSession(AuthSession session) async {
    await _storage.write(key: StorageKeys.authToken, value: session.token);
    await _storage.write(key: StorageKeys.userId, value: session.id.toString());
    await _storage.write(key: StorageKeys.username, value: session.username);
  }

  Future<UserProfile> getMyProfile() async {
    final response = await _dio.get<JsonMap>('/api/v1/usersInformation/user');
    return UserProfile.fromJson(response.data ?? {});
  }

  Future<UserProfile> updateMyProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String photo,
    required String email,
  }) async {
    final response = await _dio.put<JsonMap>(
      '/api/v1/usersInformation/user',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'photo': photo,
        'email': email,
      },
    );
    return UserProfile.fromJson(response.data ?? {});
  }

  Future<List<Group>> getGroupsByUserId(int userId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/groups/user/$userId');
    return _list(response.data, Group.fromJson);
  }

  Future<List<Group>> searchGroups(String name) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/groups/search',
      queryParameters: {'name': name},
    );
    return _list(response.data, Group.fromJson);
  }

  Future<Group> getGroup(int groupId) async {
    final response = await _dio.get<JsonMap>('/api/v1/groups/$groupId');
    return Group.fromJson(response.data ?? {});
  }

  Future<Group> createGroup({
    required String name,
    required String description,
    required int adminId,
    String groupPhoto = '',
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/groups',
      data: {
        'name': name,
        'description': description,
        'groupPhoto': groupPhoto,
        'adminId': adminId,
      },
    );
    return Group.fromJson(response.data ?? {});
  }

  Future<String> generateInvitation(int groupId) async {
    final response = await _dio.post<String>('/api/v1/groups/$groupId/generate-invitation');
    return response.data ?? '';
  }

  Future<GroupMember> joinGroup({
    required int groupId,
    required int userId,
    required String token,
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/groups/$groupId/join',
      data: {'userId': userId, 'token': token},
    );
    return GroupMember.fromJson(response.data ?? {});
  }

  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/groups/$groupId/members');
    return _list(response.data, GroupMember.fromJson);
  }

  Future<List<Expense>> getExpensesByGroup(int groupId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/expenses/groupId/$groupId');
    return _list(response.data, Expense.fromJson);
  }

  Future<List<Expense>> getExpensesByUser(int userId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/expenses/userId/$userId');
    return _list(response.data, Expense.fromJson);
  }

  Future<List<Expense>> searchExpenses(String name) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/expenses/search',
      queryParameters: {'name': name},
    );
    return _list(response.data, Expense.fromJson);
  }

  Future<Expense> getExpense(int expenseId) async {
    final response = await _dio.get<JsonMap>('/api/v1/expenses/$expenseId');
    return Expense.fromJson(response.data ?? {});
  }

  Future<Expense> createExpense({
    required String name,
    required double amount,
    required int userId,
    required int groupId,
    required DateTime dueDate,
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/expenses',
      data: {
        'name': name,
        'amount': amount,
        'userId': userId,
        'groupId': groupId,
        'dueDate': dueDate.toIso8601String().split('T').first,
      },
    );
    return Expense.fromJson(response.data ?? {});
  }

  Future<Payment> createPayment({
    required String description,
    required double amount,
    required int userId,
    required int expenseId,
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/payments',
      data: {
        'description': description,
        'amount': amount,
        'userId': userId,
        'expenseId': expenseId,
      },
    );
    return Payment.fromJson(response.data ?? {});
  }

  Future<List<Payment>> getPaymentsByUser(int userId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/payments/userId/$userId');
    return _list(response.data, Payment.fromJson);
  }

  Future<List<Payment>> getIncomingPayments(int userId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/payments/incoming/$userId');
    return _list(response.data, Payment.fromJson);
  }

  Future<List<Payment>> getPaymentsByExpense(int expenseId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/payments/expenseId/$expenseId');
    return _list(response.data, Payment.fromJson);
  }

  Future<Payment> getPayment(int paymentId) async {
    final response = await _dio.get<JsonMap>('/api/v1/payments/$paymentId');
    return Payment.fromJson(response.data ?? {});
  }

  Future<void> makePayment({
    required int paymentId,
    required double amount,
    String photo = '',
  }) async {
    await _dio.post<JsonMap>(
      '/api/v1/payments/$paymentId/pay',
      data: {'amount': amount, 'photo': photo},
    );
  }

  Future<ImageUpload> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post<JsonMap>(
      '/api/v1/images',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ImageUpload.fromJson(response.data ?? {});
  }

  Future<Receipt> createExpenseReceipt({
    required int expenseId,
    required String name,
    required double amount,
    required DateTime issueDate,
    String receiptNumber = '',
    String imagePath = '',
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/receipts/expense',
      data: {
        'expenseId': expenseId,
        'name': name,
        'receiptNumber': receiptNumber,
        'amount': amount,
        'issueDate': issueDate.toIso8601String().split('T').first,
        'imagePath': imagePath,
      },
    );
    return Receipt.fromJson(response.data ?? {});
  }

  Future<List<Receipt>> getReceiptsByExpense(int expenseId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/receipts/expense/$expenseId');
    return _list(response.data, Receipt.fromJson);
  }

  Future<Map<String, Object?>> ocrFromImage(String imageId) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/ocr-receipt/from-image',
      data: {'imageId': imageId},
    );
    return response.data ?? {};
  }

  Future<Reputation> getReputation(int userId) async {
    final response = await _dio.get<JsonMap>('/api/v1/pbl/users/$userId/reputation');
    return Reputation.fromJson(response.data ?? {});
  }

  Future<List<ReputationEvent>> getReputationHistory(int userId, {int days = 90}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/pbl/users/$userId/history',
      queryParameters: {'days': days},
    );
    return _list(response.data, ReputationEvent.fromJson);
  }

  Future<List<PblBadge>> getBadges(int userId) async {
    final response = await _dio.get<List<dynamic>>('/api/v1/pbl/users/$userId/badges');
    return _list(response.data, PblBadge.fromJson);
  }

  Future<List<LeaderboardEntry>> getGroupLeaderboard({
    required int groupId,
    required int viewerUserId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/pbl/groups/$groupId/leaderboard',
      queryParameters: {'viewerUserId': viewerUserId},
    );
    return _list(response.data, LeaderboardEntry.fromJson);
  }

  Future<PublicMemberProfile> getPublicMemberProfile({
    required int groupId,
    required int memberId,
  }) async {
    final response = await _dio.get<JsonMap>(
      '/api/v1/pbl/groups/$groupId/members/$memberId/public-profile',
    );
    return PublicMemberProfile.fromJson(response.data ?? {});
  }
}

List<T> _list<T>(
  List<dynamic>? json,
  T Function(Map<String, Object?> json) builder,
) {
  return (json ?? const [])
      .whereType<Map>()
      .map((item) => builder(Map<String, Object?>.from(item)))
      .toList();
}
