import 'package:enjoy/screens/usuarios/home_screen.dart';
import 'package:enjoy/screens/login_screen.dart';
import 'package:enjoy/screens/usuarios/qr_result_screen.dart';
import 'package:enjoy/screens/usuarios/qr_screen.dart';
import 'package:enjoy/screens/recuperar_cuenta_screen.dart';
import 'package:enjoy/screens/register_cliente_screen.dart';
import 'package:enjoy/screens/restablecer_password_screen.dart';
import 'package:enjoy/screens/solicitud_empresa_screen.dart';
import 'package:enjoy/screens/clientes/home_user_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<String> getInitialRoute() async {
  final auth = AuthService();

  // 1) ¿Hay token?
  final hasToken = await auth.hasToken();
  if (!hasToken) return '/login';

  // 2) Intentar renovar (si falla, cerrar sesión y volver a login)
  final ok = await auth.renewToken();
  if (!ok) {
    await auth.logout();
    return '/login';
  }

  // 3) Decidir home por rol/kind
  return auth.getTargetHomeRoute();
}

GoRouter buildRouter(String initialRoute) {
  return GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _slidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/registro-cliente',
        pageBuilder: (context, state) =>
            _slidePage(state, const RegisterClienteScreen()),
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
        path: '/home_user',
        pageBuilder: (context, state) =>
            _slidePage(state, const PromotionsHomeScreen()),
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
        pageBuilder: (context, state) =>
            _slidePage(state, const RecuperarCuentaScreen()),
      ),
      GoRoute(
        path: '/restablecer',
        pageBuilder: (context, state) =>
            _slidePage(state, const RestablecerPasswordScreen()),
      ),
      
    ],
  );
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
