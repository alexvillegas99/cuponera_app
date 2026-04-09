import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

// ============ BANDERAS DE PLATAFORMA ============
const bool kNotificacionesAndroid = true;
const bool kNotificacionesIOS = true;

/// ============ TOP-LEVEL BG HANDLER ============
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Platform.isIOS && !kNotificacionesIOS) return;
  if (Platform.isAndroid && !kNotificacionesAndroid) return;

  try {
    await Firebase.initializeApp();
    debugPrint('📩 [BG] ${message.messageId} ${message.notification?.title}');
  } catch (e, st) {/*  */
    debugPrint('❌ BG handler error: $e\n$st');
  }
}

/// ============ SERVICE ============
class MyFirebaseMessagingService {
  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _fln;

  static bool _bgRegistered = false;
  bool _initialized = false;

  Future<bool> initNotifications() async {
    if (Platform.isIOS && !kNotificacionesIOS) {
      debugPrint('🚫 FCM desactivado en iOS');
      return false;
    }
    if (Platform.isAndroid && !kNotificacionesAndroid) {
      debugPrint('🚫 FCM desactivado en Android');
      return false;
    }

    if (_initialized) return true;

    try {
      // --- init local notifications ---
      final fln = FlutterLocalNotificationsPlugin();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );

      await fln.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (resp) {
          final p = resp.payload;
          if (p != null && p.isNotEmpty) _abrirEnlace(p);
        },
      );

      _fln = fln;

      // --- canal Android ---
      if (!kIsWeb && Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'Notificaciones Importantes',
          importance: Importance.max,
        );

        await _fln!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // --- permisos (solo Android 13+) ---
      try {
        final perm = await _fm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔔 Permisos: ${perm.authorizationStatus}');
      } catch (e) {
        debugPrint('⚠️ requestPermission falló: $e');
      }

      // --- background handler ---
      if (!_bgRegistered) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
        _bgRegistered = true;
      }

      // --- listeners ---
      FirebaseMessaging.onMessage.listen(_safeOnMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_safeOnMessageOpened);

      final initialMsg = await _fm.getInitialMessage();
      if (initialMsg != null) _safeOnMessageOpened(initialMsg);

      // --- token ---
      await getTokenWithRetry();

      _fm.onTokenRefresh.listen((t) {
        debugPrint('🔄 FCM token refresh: $t');
      });

      // --- topic ---
      await subscribeToTopic('general');

      _initialized = true;
      return true;
    } catch (e, st) {
      debugPrint('❌ initNotifications error: $e\n$st');
      return false;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    if (Platform.isIOS && !kNotificacionesIOS) return;
    if (Platform.isAndroid && !kNotificacionesAndroid) return;

    try {
      await _fm.subscribeToTopic(topic);
      debugPrint("📌 Suscrito a '$topic'");
    } catch (e) {
      debugPrint("⚠️ No se pudo suscribir a '$topic': $e");
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (Platform.isIOS && !kNotificacionesIOS) return;
    if (Platform.isAndroid && !kNotificacionesAndroid) return;

    try {
      await _fm.unsubscribeFromTopic(topic);
      debugPrint("📌 Desuscrito de '$topic'");
    } catch (e) {
      debugPrint("⚠️ No se pudo desuscribir de '$topic': $e");
    }
  }

  Future<String?> getTokenWithRetry({int retries = 3}) async {
    if (Platform.isIOS && !kNotificacionesIOS) return null;
    if (Platform.isAndroid && !kNotificacionesAndroid) return null;

    String? token;

    for (var i = 0; i < retries; i++) {
      try {
        token = await _fm.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('🔥 FCM Token: $token');
          break;
        }
      } catch (e) {
        debugPrint('⚠️ getToken intento ${i + 1} falló: $e');
      }

      await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
    }

    return token;
  }

  void _safeOnMessage(RemoteMessage m) {
    debugPrint("📩 FG: ${m.notification?.title}");
    _showNotification(m);
  }

  void _safeOnMessageOpened(RemoteMessage m) {
    debugPrint("📩 OPENED: ${m.notification?.title}");

    final url = m.data['link']?.toString();
    if (url != null && url.isNotEmpty) _abrirEnlace(url);
  }

  Future<void> _showNotification(RemoteMessage message) async {
    if (_fln == null) return;

    const android = AndroidNotificationDetails(
      'high_importance_channel',
      'Notificaciones Importantes',
      importance: Importance.max,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();

    final details = const NotificationDetails(
      android: android,
      iOS: ios,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _fln!.show(
      id,
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? '',
      details,
      payload: message.data['link']?.toString(),
    );
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (!['http', 'https'].contains(uri.scheme)) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
} 