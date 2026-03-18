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
import 'package:enjoy/services/favorites_service.dart';
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:enjoy/state/favorites_store.dart';

// Conectividad
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:enjoy/ui/palette.dart';

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
    await Firebase.initializeApp();
    if (kDebugMode) {
      // print('[BG] msgId=${message.messageId} data=${message.data}');
    }
  } catch (e, st) {
    // ignore: avoid_print
    print('❌ BG handler error: $e\n$st');
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final notifService = MyFirebaseMessagingService();
  await notifService.initNotifications();

  await initializeDateFormatting('es', null);

  // Construye router con tu ruta inicial
  final String initialRoute = await getInitialRoute();
  final GoRouter router = buildRouter(initialRoute);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FavoritesStore(FavoritosService()),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityStore()..start()),
      ],
      child: RootApp(router: router), // 👈 pásalo aquí (sin const)
    ),
  );
}

/// RootApp: un solo MaterialApp.router y en builder decides online/offline
class RootApp extends StatelessWidget {
  const RootApp({super.key, required this.router});

  final GoRouter router; // 👈 faltaba el nombre del campo

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      routerConfig: router, // 👈 usa el router que recibes
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
  StreamSubscription<List<ConnectivityResult>>? _sub; // <- lista en v6
  Timer? _poll;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void start() {
    _checkNow(); // estado inicial
    _sub = _conn.onConnectivityChanged.listen((List<ConnectivityResult> _) {
      // No usamos el detalle; validamos con ping real
      _checkNow();
    });
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkNow());
  }

  Future<void> checkNow() => _checkNow(); // expuesto para "Reintentar"

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
