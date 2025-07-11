import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class MyFirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  MyFirebaseMessagingService() {
    print("🔥 Inicializando servicio de notificaciones");
  }

  /// 🔥 **Inicializar servicio de notificaciones**
  Future<void> initNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _abrirEnlace(response.payload!);
        }
      },
    );

    // 🔥 Crear canal de notificación para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID del canal
      'Notificaciones Importantes', // Nombre del canal
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ✅ **Verificar permisos cada vez que la app inicia**
    await checkPermissions();

    // ✅ Suscripción a un tema y obtener token
    await subscribeToTopic("all");
    await getToken();

    // 🔥 Escuchar notificaciones en diferentes estados
    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }



//Suscribir a actualizacion suscripcion _id del usuario

  Future<void> subscribeToTopicNuevo(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print("📌 Suscrito al tema '$topic'");
  }

  //Desuscribir a actualizacion suscripcion _id del usuario
  Future<void> unsubscribeFromTopicNuevo(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print("📌 Desuscrito al tema '$topic'");
  }
  


  /// 📌 **Verificar permisos y solicitarlos si fueron denegados**
  Future<void> checkPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Ya tienes permisos de notificación.');
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Permisos denegados, volviendo a solicitar...');
      await _solicitarPermisos();
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ Permisos provisionales otorgados.');
    } else {
      print('🔔 Permisos aún no solicitados, pidiendo ahora...');
      await _solicitarPermisos();
    }
  }

  /// 📌 **Solicitar permisos de notificación**
  Future<void> _solicitarPermisos() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 Permisos concedidos');
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Permisos denegados nuevamente. Considera redirigir al usuario a configuración.');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print("📌 Suscrito al tema '$topic'");
  }

  Future<void> getToken() async {
    String? token = await _firebaseMessaging.getToken();
    print("🔥 Token FCM: $token");
  }

  /// 📩 **Manejo de notificaciones en primer plano**
  void _onMessage(RemoteMessage message) {
    print("📩 Notificación en primer plano: ${message.notification?.title}");
    _showNotification(message);
  }

  /// 📩 **Manejo cuando se abre una notificación**
  void _onMessageOpened(RemoteMessage message) {
    print("📩 Notificación abierta: ${message.notification?.title}");
    
    String? url = message.data['link'];
    if (url != null && url.isNotEmpty) {
      _abrirEnlace(url);
    }
  }

  /// 🔹 **Abrir un enlace en el navegador**
  void _abrirEnlace(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print("❌ No se pudo abrir la URL: $url");
    }
  }

  /// 📩 **Manejo de notificaciones en segundo plano**
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("📩 Mensaje en segundo plano: ${message.notification?.title}");
  }

  /// 🔔 **Mostrar notificación localmente**
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // ID del canal
      'Notificaciones Importantes', // Nombre del canal
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // ID de la notificación
      message.notification?.title ?? "Sin título",
      message.notification?.body ?? "Sin contenido",
      platformChannelSpecifics,
      payload: message.data['link'], // Pasamos el link como payload
    );
  }
}
