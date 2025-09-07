import 'dart:io';
import 'package:enjoy/config/router/app_router.dart';
import 'package:enjoy/services/favorites_service.dart';
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
 //comentario
void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  String initialRoute =
      await getInitialRoute(); // Espera la carga de la ruta guardada
  final router = buildRouter(initialRoute);

   await Firebase.initializeApp();

  // 🔥 Inicializar servicio de notificaciones
   await MyFirebaseMessagingService().initNotifications();
  await initializeDateFormatting('es', null); // Inicializa soporte para español
  runApp(
    MultiProvider(
     providers: [
      ChangeNotifierProvider(
        create: (_) {
          final s = FavoritesStore(FavoritosService());
          debugPrint('[BOOT] FavoritesStore creado. API_URL=${dotenv.env['API_URL']}');
          return s;
        },
      ),
    ],
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;

  const MyApp({Key? key, required this.router}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}
