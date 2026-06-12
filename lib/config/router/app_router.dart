import 'package:enjoy/screens/chat/chat_conversacion_screen.dart';
import 'package:enjoy/screens/chat/chat_entry_screen.dart';
import 'package:enjoy/screens/clientes/notificacion_prefs_screen.dart';
import 'package:enjoy/screens/clientes/notificaciones_screen.dart';
import 'package:enjoy/screens/clientes/perfil_cofiguraicon/edit_profile_screen.dart';
import 'package:enjoy/screens/clientes/perfil_cofiguraicon/notifications_screen.dart';
import 'package:enjoy/screens/clientes/perfil_cofiguraicon/privacy_screen.dart';
import 'package:enjoy/screens/usuarios/home_screen.dart';
import 'package:enjoy/screens/login_screen.dart';
import 'package:enjoy/screens/usuarios/qr_result_screen.dart';
import 'package:enjoy/screens/usuarios/qr_screen.dart';
import 'package:enjoy/screens/recuperar_cuenta_screen.dart';
import 'package:enjoy/screens/register_cliente_screen.dart';
import 'package:enjoy/screens/restablecer_password_screen.dart';
import 'package:enjoy/screens/solicitud_empresa_screen.dart';
import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:enjoy/screens/clientes/home_user_screen.dart';
import 'package:enjoy/screens/account_picker_screen.dart';
import 'package:enjoy/screens/switching_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<String> getInitialRoute() async {
  final auth = AuthService();

  // 1) ¿Modo invitado?
  if (await auth.isGuest()) return '/home_guest';

  // 2) ¿Hay sesión activa con token?
  final hasToken = await auth.hasToken();
  if (hasToken) {
    // Refrescar token contra el back con timeout corto. Distinguimos
    // entre "rechazado" (logout) y "sin red" (entrar igual con cache):
    // así un back lento o offline NO deja a la app pegada en el splash.
    final status = await auth.renewTokenStatus(
      timeout: const Duration(seconds: 5),
    );
    if (status == TokenStatus.valid) return auth.getTargetHomeRoute();
    if (status == TokenStatus.unreachable) {
      // Entrar offline: el usuario ve datos cacheados. El próximo request
      // real intentará refrescar y, si el token está revocado, ApiClient
      // dispara onSessionExpired y mandamos a /login.
      return auth.getTargetHomeRoute();
    }
    // rejected: el back negó el token. Limpiamos sesión activa.
    await auth.logout();
  }

  // 3) Sin sesión activa: ¿hay cuentas guardadas? → selector estilo Facebook.
  if (await auth.hasSavedAccounts()) return '/cuentas';

  // 4) Nada guardado → login.
  return '/login';
}

/// Referencia global al router para navegar desde lugares sin context
/// (p.ej. handlers de FCM en background).
GoRouter? appRouter;

GoRouter buildRouter(String initialRoute) {
  final router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _slidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/cuentas',
        pageBuilder: (context, state) =>
            _slidePage(state, const AccountPickerScreen()),
      ),
      GoRoute(
        path: '/switching',
        pageBuilder: (context, state) =>
            _slidePage(state, const SwitchingScreen()),
      ),
      GoRoute(
        path: '/registro-cliente',
        pageBuilder: (context, state) => _slidePage(
          state,
          RegisterClienteScreen(
            googleData: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: '/solicitud-empresa',
        pageBuilder: (context, state) =>
            _slidePage(state, const SolicitudEmpresaScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _slidePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) =>
            _slidePage(state, const ChatEntryScreen()),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          ChatConversacionScreen(
            hiloId: state.pathParameters['id']!,
            esSoporte: state.uri.queryParameters['soporte'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/home_user',
        pageBuilder: (context, state) =>
            _slidePage(state, const PromotionsHomeScreen()),
      ),
      GoRoute(
        path: '/home_guest',
        pageBuilder: (context, state) =>
            _slidePage(state, const PromotionsHomeScreen(guestMode: true)),
      ),
      GoRoute(
        path: '/scanner',
        pageBuilder: (context, state) =>
            _slidePage(state, const QrScanScreen()),
      ),
      GoRoute(
        path: '/qr-result',
        pageBuilder: (context, state) => _slidePage(
          state,
          QrResultScreen(qrData: state.extra as Map<String, dynamic>),
        ),
      ),
      GoRoute(
        path: '/recuperar',
        pageBuilder: (context, state) => _slidePage(
          state,
          RecuperarCuentaScreen(initialEmpresa: state.extra == true),
        ),
      ),
      GoRoute(
        path: '/restablecer',
        pageBuilder: (context, state) =>
            _slidePage(state, const RestablecerPasswordScreen()),
      ),
       GoRoute(
        path: '/perfil/editar',
        pageBuilder: (context, state) => _slidePage(state, const EditContactWithOtpScreen()),
      ),
      GoRoute(
        path: '/perfil/notificaciones',
        pageBuilder: (context, state) => _slidePage(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/perfil/privacidad',
        pageBuilder: (context, state) => _slidePage(state, const PrivacyScreen()),
      ),
      GoRoute(
        path: '/notificaciones',
        pageBuilder: (context, state) =>
            _slidePage(state, const NotificacionesScreen()),
      ),
      GoRoute(
        path: '/notificaciones/preferencias',
        pageBuilder: (context, state) =>
            _slidePage(state, const NotificacionPrefsScreen()),
      ),
      // Deep-links de push notifications (recordatorios y reseñas).
      GoRoute(
        path: '/local/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          ComercioDetalleMiniScreen(usuarioId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/cupon/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          CuponDetalleScreen(cuponId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
  appRouter = router;
  return router;
}

/// Helper para transición deslizante desde la derecha
CustomTransitionPage _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}
