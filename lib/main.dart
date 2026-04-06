// main.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:enjoy/config/router/app_router.dart';
import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/favorites_service.dart';
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/state/favorites_store.dart';

// Conectividad
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// 🔥 Flag global
bool get isPushEnabled => !Platform.isIOS;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// ===== Handler top-level para mensajes en background =====
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (!isPushEnabled) return; // 🔴 bloqueo iOS
    await Firebase.initializeApp();
  } catch (e, st) {
    print('❌ BG handler error: $e\n$st');
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  /// 🔴 SOLO inicializa Firebase si NO es iOS
  if (isPushEnabled) {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    final notifService = MyFirebaseMessagingService();
    await notifService.initNotifications();
  }

  await initializeDateFormatting('es', null);

  final String initialRoute = await getInitialRoute();
  final GoRouter router = buildRouter(initialRoute);

  // Configurar cierre de sesión automático cuando el token expira
  ApiClient.onSessionExpired = () {
    AuthService().logout();
    router.go('/login');
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FavoritesStore(FavoritosService()),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityStore()..start()),
      ],
      child: RootApp(router: router),
    ),
  );
}
/// RootApp
class RootApp extends StatelessWidget {
  const RootApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
      builder: (context, child) {
        return Consumer<ConnectivityStore>(
          builder: (_, net, __) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}

/// ------------------------------
/// STORE DE CONECTIVIDAD
/// ------------------------------
class ConnectivityStore extends ChangeNotifier {
  final _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _poll;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void start() {
    _checkNow();
    _sub = _conn.onConnectivityChanged.listen((_) {
      _checkNow();
    });

    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkNow());
  }

  Future<void> checkNow() => _checkNow();

  Future<void> _checkNow() async {
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (hasInternet != _isOnline) {
      _isOnline = hasInternet;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}