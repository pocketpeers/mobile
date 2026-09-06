import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/pocketpeers_api.dart';

class NotificationsPermissionDeniedException implements Exception {
  const NotificationsPermissionDeniedException();

  @override
  String toString() => 'Permiso de notificaciones denegado';
}

class ReminderService {
  ReminderService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Must match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml. Reusing the same channel keeps foreground and
  /// background reminders visually identical and under one user-facing toggle.
  static const channelId = 'high_importance_channel';
  static const _channelName = 'Recordatorios de pago';
  static const _channelDescription =
      'Avisos de pagos pendientes, vencidos y confirmaciones de grupo.';

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final _taps = StreamController<Map<String, dynamic>>.broadcast();
  var _initialized = false;
  var _localInitialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    final messaging = _messaging ?? FirebaseMessaging.instance;
    _messaging = messaging;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw const NotificationsPermissionDeniedException();
    }
    // On iOS this is what draws the banner while the app is open. On Android it
    // has no effect, which is why foreground messages are rendered locally by
    // [showRemoteMessage].
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _ensureLocalNotifications();
    _initialized = true;
  }

  Future<String> registerDevice(PocketPeersApi api) async {
    await initialize();
    final token = await _messaging?.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase did not return a device token.');
    }
    await api.registerDeviceToken(
      token: token,
      platform: _platformLabel,
    );
    return token;
  }

  Stream<String> tokenRefreshes() =>
      _messaging?.onTokenRefresh ?? const Stream.empty();

  Stream<RemoteMessage> foregroundMessages() => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> openedMessages() =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> initialMessage() async =>
      _messaging?.getInitialMessage();

  /// Emits the `data` payload of a locally rendered notification when the user
  /// taps it, mirroring [openedMessages] for the foreground path.
  Stream<Map<String, dynamic>> notificationTaps() => _taps.stream;

  /// Renders an FCM message as a real system notification.
  ///
  /// Android drops the `notification` payload while the app is in the
  /// foreground, so it has to be drawn locally. iOS presents it natively via
  /// [FirebaseMessaging.setForegroundNotificationPresentationOptions], so
  /// drawing it again there would show the banner twice.
  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (!_rendersLocalNotifications) return;
    final notification = message.notification;
    await showDueReminder(
      id: _notificationIdFor(message),
      title: notification?.title ?? 'Recordatorio de pago',
      body: notification?.body ?? '',
      data: message.data,
    );
  }

  Future<void> showDueReminder({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (kIsWeb) return;
    await _ensureLocalNotifications();
    await _localNotifications.show(
      id: id,
      title: title,
      body: body.isEmpty ? null : body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          ticker: title,
          styleInformation:
              body.isEmpty ? null : BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data.isEmpty ? null : jsonEncode(data),
    );
  }

  Future<void> dispose() async {
    await _taps.close();
  }

  Future<void> _ensureLocalNotifications() async {
    if (_localInitialized || kIsWeb) return;
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // firebase_messaging already owns the permission prompt, so the local
        // plugin must not raise a second one.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _emitTap(response.payload),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    }

    // A foreground notification stays in the tray after the app is closed, so
    // it can still be what relaunched the app.
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _emitTap(launchDetails?.notificationResponse?.payload);
    }

    _localInitialized = true;
  }

  void _emitTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _taps.add(decoded.map((key, value) => MapEntry('$key', value)));
      }
    } catch (_) {
      // A malformed payload must never break notification handling.
    }
  }

  /// Reuses the backend reminder id so the same reminder replaces itself in the
  /// tray instead of stacking duplicates. Android notification ids are 32-bit.
  int _notificationIdFor(RemoteMessage message) {
    final parsed =
        int.tryParse(message.data['notificationId']?.toString() ?? '');
    if (parsed != null) return parsed & 0x7fffffff;
    return (message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch) &
        0x7fffffff;
  }

  bool get _rendersLocalNotifications =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get _platformLabel {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }
}
