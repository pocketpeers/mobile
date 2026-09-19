import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

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
          // Every backend endpoint after login expects the JWT in this header.
          // The interceptor keeps individual API methods focused on payloads.
          final token = await _storage.read(key: StorageKeys.authToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // El token es un JWT con vencimiento: cuando caduca, todas las
          // pantallas empiezan a recibir 401 y antes se quedaban reintentando
          // sin fin. Detectarlo aquí, en un solo lugar, evita repetir la misma
          // comprobación en cada pantalla.
          if (_isSessionExpired(error)) {
            // Se limpia antes de avisar: quien escucha recarga la sesión, y si
            // el token siguiera guardado la restauraría como si nada.
            await _clearStoredSession();
            // Al cerrar sesión quedan peticiones en vuelo que también van a
            // fallar con 401. Sin esto, cada una repetiría el aviso.
            _suppressExpiryNotice = true;
            if (!_sessionExpired.isClosed) _sessionExpired.add(null);
          }
          handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  final _sessionExpired = StreamController<void>.broadcast();

  /// Emite cuando el backend rechaza el token por vencido.
  ///
  /// Es un stream y no un callback para que la capa de datos no tenga que
  /// conocer a Riverpod ni al enrutador: quien escuche decide qué hacer.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  void dispose() {
    _sessionExpired.close();
  }

  /// Silencia el aviso de vencimiento tras un cierre de sesión.
  ///
  /// Se levanta cuando el usuario cierra sesión a propósito y cuando ya se
  /// detectó un vencimiento. Vuelve a bajar al iniciar sesión de nuevo.
  var _suppressExpiryNotice = false;

  /// Distingue "tu sesión venció" de todo lo demás que también responde 401.
  ///
  /// Hay tres casos que no son vencimiento y que antes se confundían con uno:
  /// iniciar sesión con la contraseña equivocada, las peticiones que quedan en
  /// vuelo cuando el usuario cierra sesión por su cuenta, y cualquier llamada
  /// que sale sin token. Tratarlos como vencimiento hacía aparecer el aviso de
  /// "tu sesión expiró" en momentos donde no había expirado nada.
  bool _isSessionExpired(DioException error) {
    if (error.response?.statusCode != 401) return false;
    if (_suppressExpiryNotice) return false;

    // Una petición que salió sin credenciales no puede haber vencido: no las
    // llevaba. Es el caso de las pantallas que siguen activas justo después de
    // cerrar sesión.
    if (error.requestOptions.headers['Authorization'] == null) return false;

    final path = error.requestOptions.path;
    if (path.contains('/authentication/sign-in') ||
        path.contains('/authentication/sign-up') ||
        path.contains('/authentication/password-reset')) {
      return false;
    }
    return true;
  }

  Future<void> _clearStoredSession() async {
    await _storage.delete(key: StorageKeys.authToken);
    await _storage.delete(key: StorageKeys.userId);
    await _storage.delete(key: StorageKeys.username);
  }

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

  /// Cierre de sesion a peticion del usuario.
  ///
  /// Silencia el aviso de vencimiento: quien cierra sesion a proposito ya sabe
  /// por que salio, y las pantallas que sigan activas van a recibir 401 sin que
  /// eso signifique que algo caduco.
  Future<void> signOut() async {
    _suppressExpiryNotice = true;
    await _clearStoredSession();
  }

  /// Pide al backend que envíe un código de recuperación al correo.
  ///
  /// El backend responde igual exista o no la cuenta, así que esta llamada no
  /// puede usarse para averiguar qué correos están registrados. La pantalla debe
  /// mostrar el mismo mensaje en todos los casos.
  Future<void> requestPasswordReset(String email) async {
    await _dio.post<JsonMap>(
      '/api/v1/authentication/password-reset/request',
      data: {'email': email},
    );
  }

  /// Canjea el código recibido por correo por una contraseña nueva.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post<JsonMap>(
      '/api/v1/authentication/password-reset/confirm',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    );
  }

  /// Cambia la contraseña de la sesión activa. Requiere la contraseña actual.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put<JsonMap>(
      '/api/v1/authentication/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<bool> isOnboardingCompleted() async {
    return await _storage.read(key: StorageKeys.onboardingCompleted) == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storage.write(key: StorageKeys.onboardingCompleted, value: 'true');
  }

  Future<void> _persistSession(AuthSession session) async {
    // Hay sesion nueva: vuelve a tener sentido avisar si esta vence.
    _suppressExpiryNotice = false;
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
    final response =
        await _dio.get<List<dynamic>>('/api/v1/groups/user/$userId');
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

  Future<Group> updateGroup({
    required int groupId,
    required String name,
    required String description,
  }) async {
    final response = await _dio.put<JsonMap>(
      '/api/v1/groups/$groupId',
      data: {
        'name': name,
        'description': description,
      },
    );
    return Group.fromJson(response.data ?? {});
  }

  Future<Group> updateGroupImage({
    required int groupId,
    required String image,
  }) async {
    final response = await _dio.put<JsonMap>(
      '/api/v1/groups/$groupId/image',
      data: {'image': image},
    );
    return Group.fromJson(response.data ?? {});
  }

  Future<String> generateInvitation(int groupId) async {
    final response =
        await _dio.post<String>('/api/v1/groups/$groupId/generate-invitation');
    return response.data ?? '';
  }

  Future<GroupMember> joinGroup({
    required int userId,
    required String token,
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/groups/join',
      data: {'userId': userId, 'token': token},
    );
    return GroupMember.fromJson(response.data ?? {});
  }

  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/groups/$groupId/members');
    return _list(response.data, GroupMember.fromJson);
  }

  Future<List<Expense>> getExpensesByGroup(int groupId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/expenses/groupId/$groupId');
    // Cancelled expenses may still exist in the backend for audit purposes, but
    // the mobile app treats active expenses as the default working set.
    return _list(response.data, Expense.fromJson)
        .where((expense) => expense.isActive)
        .toList();
  }

  Future<List<Expense>> getExpensesByUser(int userId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/expenses/userId/$userId');
    return _list(response.data, Expense.fromJson)
        .where((expense) => expense.isActive)
        .toList();
  }

  /// Sondeo ligero: cuantos gastos y pagos del grupo faltan por registrarse.
  ///
  /// Sustituye a recargarlo todo para averiguar lo mismo. Con el temporizador
  /// de la pantalla de grupo corriendo cada tres segundos y varios usuarios a
  /// la vez, la diferencia entre una peticion y veintitres deja de ser un
  /// detalle.
  Future<BlockchainStatus> getGroupBlockchainStatus(int groupId) async {
    final response = await _dio.get<JsonMap>(
      '/api/v1/expenses/groupId/$groupId/blockchain-status',
    );
    return BlockchainStatus.fromJson(response.data ?? {});
  }

  Future<List<Expense>> searchExpenses(String name) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/expenses/search',
      queryParameters: {'name': name},
    );
    return _list(response.data, Expense.fromJson)
        .where((expense) => expense.isActive)
        .toList();
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

  Future<Expense> createExpenseWithPayments({
    required String name,
    required double amount,
    required int userId,
    required int groupId,
    required DateTime dueDate,
    required List<SplitDraft> splits,
  }) async {
    // This endpoint creates the expense and its member payment obligations in a
    // single backend transaction, which keeps the split UI from doing partial
    // writes if one member payment fails.
    final response = await _dio.post<JsonMap>(
      '/api/v1/expenses/with-payments',
      data: {
        'name': name,
        'amount': amount,
        'userId': userId,
        'groupId': groupId,
        'dueDate': dueDate.toIso8601String().split('T').first,
        'payments': [
          for (final split in splits.where((item) => item.amount > 0))
            {
              'description': '$name - ${split.fullName}',
              'amount': split.amount,
              'userId': split.userId,
            },
        ],
      },
    );
    final body = response.data ?? {};
    return Expense.fromJson(
      Map<String, Object?>.from((body['expense'] as Map?) ?? const {}),
    );
  }

  Future<void> cancelExpense(int expenseId) async {
    await _dio.delete<JsonMap>('/api/v1/expenses/$expenseId');
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
    final response =
        await _dio.get<List<dynamic>>('/api/v1/payments/userId/$userId');
    return _list(response.data, Payment.fromJson);
  }

  Future<List<Payment>> getIncomingPayments(int userId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/payments/incoming/$userId');
    return _list(response.data, Payment.fromJson);
  }

  Future<List<Payment>> getPaymentsByExpense(int expenseId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/payments/expenseId/$expenseId');
    return _list(response.data, Payment.fromJson);
  }

  /// Todos los pagos del grupo en una sola peticion.
  ///
  /// El resumen de grupo los juntaba recorriendo los gastos y pidiendo los
  /// pagos de cada uno, uno tras otro. El costo crecia con el numero de gastos
  /// y las peticiones iban encadenadas, asi que un grupo con veinte gastos
  /// hacia veinte viajes al servidor antes de dibujar nada.
  Future<List<Payment>> getPaymentsByGroup(int groupId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/payments/group/$groupId');
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

  Future<void> confirmPayment(int paymentId) async {
    await _dio.post<JsonMap>('/api/v1/payments/$paymentId/confirm');
  }

  Future<ImageUpload> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post<JsonMap>(
      '/api/v1/images',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        // El global de 20 s no alcanza para esto. Subir la foto es lo de
        // menos: al llegar, ImageServiceImpl la decodifica entera a memoria,
        // la reescala con interpolacion bicubica y la vuelve a codificar a
        // JPEG. En una maquina rapida eso ya tomo 10.8 s medidos; en el
        // servidor, con un solo vCPU compartido, es bastante mas.
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return ImageUpload.fromJson(response.data ?? {});
  }

  Future<Receipt> createExpenseReceipt({
    required int expenseId,
    required String name,
    required double amount,
    required DateTime issueDate,
    String receiptNumber = '',
    String issuerRuc = '',
    String imagePath = '',
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/receipts/expense',
      data: {
        'expenseId': expenseId,
        'name': name,
        'receiptNumber': receiptNumber,
        'issuerRuc': issuerRuc,
        'amount': amount,
        'issueDate': issueDate.toIso8601String().split('T').first,
        'imagePath': imagePath,
      },
    );
    return Receipt.fromJson(response.data ?? {});
  }

  Future<List<Receipt>> getReceiptsByExpense(int expenseId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/receipts/expense/$expenseId');
    return _list(response.data, Receipt.fromJson);
  }

  Future<ReceiptOcr> ocrFromImage(String imageId) async {
    // OCR can take longer than normal JSON requests because the backend calls
    // the OCR service and waits for receipt extraction.
    final response = await _dio.post<JsonMap>(
      '/api/v1/ocr-receipt/from-image',
      data: {'imageId': imageId},
      options: Options(
        // 5 minutos y no 3. Medido sobre una boleta real: reconstruir el
        // pipeline de PaddleOCR 6.7 s, la inferencia 14.6 s y dibujar los
        // recuadros 2 s, con 22 hilos disponibles. El Space de Hugging Face
        // corre con 2 vCPU, asi que ahi el mismo trabajo se estira, y si
        // estaba dormido hay que sumarle el despertar del contenedor.
        //
        // Los tres timeouts de la cadena van escalonados de adentro hacia
        // afuera: backend->OCR 300 s, Caddy->backend 330 s, y este 360 s.
        //
        // El orden importa. Si los tres cortaran a la vez, cuando el OCR se
        // pase del limite el movil abortaria por su cuenta en el mismo
        // instante en que el backend le esta mandando el error, y la persona
        // veria un fallo de red generico en vez de "el OCR tardo demasiado".
        // Dandole mas margen al de afuera, el error del servidor siempre
        // alcanza a llegar.
        receiveTimeout: const Duration(minutes: 6),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return ReceiptOcr.fromJson(response.data ?? {});
  }

  Future<List<PaymentReminder>> getUnreadNotifications() async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/notifications/unread');
    return _list(response.data, PaymentReminder.fromJson);
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _dio.post<JsonMap>('/api/v1/notifications/$notificationId/read');
  }

  /// Historial completo, leídas y no leídas, de la más reciente a la más antigua.
  ///
  /// Paginado porque la lista solo crece: el backend acota el tamaño máximo.
  Future<List<PaymentReminder>> getNotificationHistory({
    int page = 0,
    int size = 30,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    return _list(response.data, PaymentReminder.fromJson);
  }

  Future<int> getUnreadNotificationCount() async {
    final response =
        await _dio.get<JsonMap>('/api/v1/notifications/unread/count');
    final value = response.data?['unread'];
    return value is num ? value.toInt() : 0;
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post<JsonMap>('/api/v1/notifications/read-all');
  }

  Future<void> deleteNotification(int notificationId) async {
    await _dio.delete<JsonMap>('/api/v1/notifications/$notificationId');
  }

  /// Vacía las notificaciones ya leídas. Las pendientes se conservan, para que
  /// nadie pierda un aviso de vencimiento que todavía no vio.
  Future<void> deleteReadNotifications() async {
    await _dio.delete<JsonMap>('/api/v1/notifications/read');
  }

  Future<List<OverdueMember>> getOverdueMembers(int groupId) async {
    final response = await _dio
        .get<List<dynamic>>('/api/v1/groups/$groupId/overdue-members');
    return _list(response.data, OverdueMember.fromJson);
  }

  Future<List<OverduePaymentDebt>> getOverdueMemberDebts({
    required int groupId,
    required int memberId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/groups/$groupId/overdue-members/$memberId',
    );
    return _list(response.data, OverduePaymentDebt.fromJson);
  }

  Future<ManualOverdueReminder> sendManualOverdueReminder({
    required int groupId,
    required int memberId,
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/groups/$groupId/overdue-members/$memberId/reminder',
    );
    return ManualOverdueReminder.fromJson(response.data ?? {});
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _dio.post<JsonMap>(
      '/api/v1/notifications/device-tokens',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<JsonMap> sendTestNotification({
    String title = 'PocketPeers test',
    String body = 'Testing notifications from the mobile app',
  }) async {
    final response = await _dio.post<JsonMap>(
      '/api/v1/notifications/test',
      data: {'title': title, 'body': body},
    );
    return response.data ?? {};
  }

  Future<Reputation> getReputation(int userId) async {
    final response =
        await _dio.get<JsonMap>('/api/v1/pbl/users/$userId/reputation');
    return Reputation.fromJson(response.data ?? {});
  }

  Future<List<ReputationEvent>> getReputationHistory(int userId,
      {int days = 90}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/pbl/users/$userId/history',
      queryParameters: {'days': days},
    );
    return _list(response.data, ReputationEvent.fromJson);
  }

  Future<List<PblBadge>> getBadges(int userId) async {
    final response =
        await _dio.get<List<dynamic>>('/api/v1/pbl/users/$userId/badges');
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
  // Dio returns decoded dynamic JSON. This helper narrows list items to maps so
  // model factories receive a predictable shape.
  return (json ?? const [])
      .whereType<Map>()
      .map((item) => builder(Map<String, Object?>.from(item)))
      .toList();
}
