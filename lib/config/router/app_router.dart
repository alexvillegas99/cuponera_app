import 'package:enjoy/screens/home_screen.dart';
import 'package:enjoy/screens/login_screen.dart';
import 'package:enjoy/screens/qr_result_screen.dart';
import 'package:enjoy/screens/qr_screen.dart';
import 'package:enjoy/screens/usuarios/home_user_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<String> getInitialRoute() async {
  final authService = AuthService();
  final hasToken = await authService.hasToken();

  if (!hasToken) {
    return '/login'; // Usuario no autenticado
  }

  return '/home_user';
}

GoRouter buildRouter(String initialRoute) {
  return GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0), // Aparece desde la derecha
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0), // Aparece desde la derecha
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/scanner',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: QrScanScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0), // Aparece desde la derecha
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/qr-result',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: QrResultScreen(qrData: state.extra as Map<String, dynamic>),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0), // Aparece desde la derecha
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
       GoRoute(
        path: '/home_user',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: PromotionsHomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0), // Aparece desde la derecha
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
    ],
  );

  
}
