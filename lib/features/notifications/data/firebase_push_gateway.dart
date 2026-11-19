import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/push_gateway.dart';

/// Canal de Android para las alertas (debe coincidir con `channel_id` de la
/// Edge Function `push`). Alta importancia: suena y aparece arriba.
const _channel = AndroidNotificationChannel(
  'alerts',
  'Alertas',
  description: 'Avisos importantes de la cuna y el colchón',
  importance: Importance.high,
);

/// FCM + notificaciones locales. Con la app cerrada o en segundo plano Android
/// muestra la notificación solo; con la app abierta la mostramos nosotros.
class FirebasePushGateway implements PushGateway {
  FirebasePushGateway._(this._messaging, this._local);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final _opened = StreamController<void>.broadcast();
  bool _launchedFromNotification = false;

  /// Inicializa Firebase. Devuelve `null` si no está configurado (sin
  /// google-services.json): la app funciona igual, sin push.
  static Future<FirebasePushGateway?> create() async {
    try {
      await Firebase.initializeApp();
    } on Object catch (e) {
      debugPrint('Push desactivado: Firebase no está configurado ($e)');
      return null;
    }
    final gateway = FirebasePushGateway._(
      FirebaseMessaging.instance,
      FlutterLocalNotificationsPlugin(),
    );
    await gateway._init();
    return gateway;
  }

  Future<void> _init() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _opened.add(null),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Con la app abierta FCM no muestra nada: lo mostramos como local.
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _opened.add(null));
    // La app se abrió tocando una notificación estando cerrada.
    _launchedFromNotification = await _messaging.getInitialMessage() != null;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      id: message.messageId.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['alert_id'] as String?,
    );
  }

  @override
  bool get isAvailable => true;

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    try {
      // getToken/onTokenRefresh están marcados obsoletos en firebase_messaging
      // 17 a favor de register()/onRegistered (Installation ID). Se mantienen
      // porque la Edge Function `push` envía al token de registro clásico
      // con la API HTTP v1, que sigue soportado.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } on Object catch (e) {
      debugPrint('No se pudo obtener el token FCM: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<void> get alertOpened async* {
    if (_launchedFromNotification) {
      _launchedFromNotification = false;
      yield null;
    }
    yield* _opened.stream;
  }
}
