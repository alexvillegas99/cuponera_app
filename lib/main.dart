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
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/favorites_service.dart';
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:enjoy/state/theme_controller.dart';
import 'package:enjoy/ui/enjoy_theme.dart';

// Conectividad
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// 🔥 Flag global — usa las mismas banderas del servicio
bool get isPushEnabled {
  if (Platform.isAndroid) return kNotificacionesAndroid;
  if (Platform.isIOS) return kNotificacionesIOS;
  return false;
}

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
    if (!isPushEnabled) return;
    await Firebase.initializeApp();
  } catch (e, st) {
    print('❌ BG handler error: $e\n$st');
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Caché de imágenes más grande: evita que las imágenes se "recarguen" al
  // navegar entre pantallas (el default ~100MB/1000 se llenaba y las expulsaba).
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 2000; // entradas (default 1000)
  imageCache.maximumSizeBytes = 300 << 20; // 300 MB (default ~100 MB)

  await dotenv.load();

  // Warm-up del cache en disco (SharedPreferences). No bloquea si falla.
  unawaited(CacheService.I.init());

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

  // Safety net: si por cualquier razón getInitialRoute se cuelga (Secure
  // Storage roto, DNS atorado, etc.) NUNCA dejamos a la app pegada en el
  // splash. A los 10s asumimos que no hay sesión y vamos a /login.
  final String initialRoute = await getInitialRoute().timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      debugPrint('⚠️  getInitialRoute timeout — fallback a /login');
      return '/login';
    },
  );
  final GoRouter router = buildRouter(initialRoute);
  final ThemeController themeController = await ThemeController.load();

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
        ChangeNotifierProvider.value(value: themeController),
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
    final themeMode = context.watch<ThemeController>().mode;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: EnjoyTheme.light(),
      darkTheme: EnjoyTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Consumer<ConnectivityStore>(
          builder: (_, net, __) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (!net.isOnline)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _OfflineBanner(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Píldora compacta que se asoma desde la barra de estado cuando no hay red.
/// Se muestra sobre cualquier pantalla — el contenido sigue navegable porque
/// los servicios devuelven cache cuando el back no responde.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFB020).withValues(alpha: 0.55),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 14, color: Color(0xFFFFB020)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Modo offline — mostrando lo último cacheado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
