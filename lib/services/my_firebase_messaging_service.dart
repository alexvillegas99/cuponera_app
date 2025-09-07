import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// ============ TOP-LEVEL BG HANDLER ============
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('📩 [BG] ${message.messageId} ${message.notification?.title}');
  } catch (e, st) {
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
    if (_initialized) return true; // evita doble init

    try {
      // --- init local notifications (ambas plataformas) ---
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
        try {
          const channel = AndroidNotificationChannel(
            'high_importance_channel',
            'Notificaciones Importantes',
            importance: Importance.max,
          );
          await _fln!
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(channel);
        } catch (e) {
          debugPrint('⚠️ No se pudo crear el canal Android: $e');
        }
      }

      // --- permisos (iOS y Android 13+) ---
      try {
        final perm = await _fm.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        debugPrint('🔔 Permisos: ${perm.authorizationStatus}');
      } catch (e) {
        debugPrint('⚠️ requestPermission falló: $e');
      }

      // banners en foreground (iOS)
      if (!kIsWeb && Platform.isIOS) {
        try {
          await _fm.setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true,
          );
        } catch (e) {
          debugPrint('⚠️ setForegroundNotificationPresentationOptions: $e');
        }
      }

      // --- background handler (idempotente) ---
      if (!_bgRegistered) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        _bgRegistered = true;
      }

      // --- listeners ---
      FirebaseMessaging.onMessage.listen(_safeOnMessage, onError: (e, st) {
        debugPrint('❌ onMessage error: $e\n$st');
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_safeOnMessageOpened, onError: (e, st) {
        debugPrint('❌ onMessageOpenedApp error: $e\n$st');
      });

      // mensaje inicial (app cold start)
      try {
        final initialMsg = await _fm.getInitialMessage();
        if (initialMsg != null) _safeOnMessageOpened(initialMsg);
      } catch (e) {
        debugPrint('⚠️ getInitialMessage error: $e');
      }

      // token + refresh con retry
      await getTokenWithRetry();
      _fm.onTokenRefresh.listen((t) {
        debugPrint('🔄 FCM token refresh: $t');
        // TODO: envíalo a tu backend
      }, onError: (e, st) {
        debugPrint('❌ onTokenRefresh error: $e\n$st');
      });

      // ejemplo: topic
      await subscribeToTopic('general');

      _initialized = true;
      return true;
    } catch (e, st) {
      debugPrint('❌ initNotifications error: $e\n$st');
      return false;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fm.subscribeToTopic(topic);
      debugPrint("📌 Suscrito a '$topic'");
    } catch (e) {
      debugPrint("⚠️ No se pudo suscribir a '$topic': $e");
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fm.unsubscribeFromTopic(topic);
      debugPrint("📌 Desuscrito de '$topic'");
    } catch (e) {
      debugPrint("⚠️ No se pudo desuscribir de '$topic': $e");
    }
  }

  Future<String?> getTokenWithRetry({int retries = 3}) async {
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

  // ---------------- safe handlers ----------------
  void _safeOnMessage(RemoteMessage m) {
    try {
      debugPrint("📩 FG: ${m.notification?.title}");
      _showNotification(m);
    } catch (e, st) {
      debugPrint('❌ _safeOnMessage error: $e\n$st');
    }
  }

  void _safeOnMessageOpened(RemoteMessage m) {
    try {
      debugPrint("📩 OPENED: ${m.notification?.title}");
      final url = m.data['link']?.toString();
      if (url != null && url.isNotEmpty) _abrirEnlace(url);
    } catch (e, st) {
      debugPrint('❌ _safeOnMessageOpened error: $e\n$st');
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    if (_fln == null) {
      debugPrint('⚠️ _fln no inicializado, skip notification');
      return;
    }
    try {
      // Android
      const android = AndroidNotificationDetails(
        'high_importance_channel',
        'Notificaciones Importantes',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      // iOS
      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = const NotificationDetails(android: android, iOS: ios);

      // usa un id variable para evitar colisiones
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _fln!.show(
        id,
        message.notification?.title ?? 'Notificación',
        message.notification?.body ?? '',
        details,
        payload: message.data['link']?.toString(),
      );
    } catch (e, st) {
      debugPrint('❌ _showNotification error: $e\n$st');
    }
  }

  Future<void> _abrirEnlace(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;

      // permite solo http/https para seguridad básica
      if (!['http', 'https'].contains(uri.scheme)) {
        debugPrint('⚠️ Esquema no permitido: ${uri.scheme}');
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('⚠️ No se pudo abrir la URL: $url');
      }
    } catch (e, st) {
      debugPrint('❌ _abrirEnlace error: $e\n$st');
    }
  }
}
