import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/pocketpeers_api.dart';

class NotificationsPermissionDeniedException implements Exception {
  const NotificationsPermissionDeniedException();

  @override
  String toString() => 'Permiso de notificaciones denegado';
}

class ReminderService {
  ReminderService({FirebaseMessaging? messaging}) : _messaging = messaging;

  FirebaseMessaging? _messaging;
  var _initialized = false;

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
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
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

  Future<void> showDueReminder({
    required int id,
    required String title,
    required String body,
  }) async {}

  String get _platformLabel {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }
}
