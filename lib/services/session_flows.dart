import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/biometric_service.dart';
import 'package:enjoy/services/prefetch_service.dart';
import 'package:enjoy/ui/enjoy.dart';

/// Flujos de sesión multi-cuenta: cambio de cuenta con biometría, hoja de
/// "mantener sesión guardada" al cerrar sesión, y mensajes cuando falta
/// biometría.
class SessionFlows {
  SessionFlows._();

  static final AuthService _auth = AuthService();

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Cambia a la cuenta [acc] exigiendo biometría. Renueva el token; si expiró,
  /// envía a login. Re-rutea al home correspondiente.
  static Future<void> switchAccount(
      BuildContext context, SavedAccount acc) async {
    if (!await BiometricService.isReady()) {
      if (context.mounted) await showBiometricRequiredSheet(context);
      return;
    }
    final ok = await BiometricService.authenticate(
        'Cambiar a la cuenta de ${acc.displayName}');
    if (!ok) return;

    await _auth.activateAccount(acc.id);
    final valid = await _auth.renewToken();
    if (!context.mounted) return;

    if (!valid) {
      _snack(context,
          'La sesión de ${acc.displayName} expiró. Inicia sesión de nuevo.');
      context.go('/login');
      return;
    }

    // Push silencioso a todos los devices del cliente avisando del cambio
    // de cuenta. Fire-and-forget — no bloquea la navegación.
    _auth.notificarSwitch(nombreCuenta: acc.displayName);

    // Pre-fetch del cliente recién activado: si es CLIENTE, refrescamos
    // su cache local en segundo plano para que funcione offline luego.
    // Best-effort: la navegación no espera por esto.
    final activeUser = await _auth.getUser();
    final activeId = activeUser?['_id']?.toString();
    final esCliente = (activeUser?['kind'] ?? '').toString().toUpperCase() ==
        'CLIENTE';
    if (esCliente && activeId != null && activeId.isNotEmpty) {
      PrefetchService.I.warmupCliente(activeId);
    }

    // Pasa por /switching para forzar la recarga del home (aunque sea la
    // misma ruta, p.ej. admin-local → admin).
    if (context.mounted) context.go('/switching');
  }

  /// Cambia directamente a la cuenta hermana (mismo correo, otro tipo) usando
  /// la sesión actual + biometría. No requiere contraseña.
  static Future<void> switchToSibling(BuildContext context) async {
    if (!await BiometricService.isReady()) {
      if (context.mounted) await showBiometricRequiredSheet(context);
      return;
    }
    final ok = await BiometricService.authenticate('Cambiar de cuenta');
    if (!ok) return;
    try {
      await _auth.switchSibling();
      if (!context.mounted) return;
      // Pasa por /switching para forzar la recarga del home destino.
      context.go('/switching');
    } catch (e) {
      if (context.mounted) {
        _snack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Cierra sesión preguntando si mantener la cuenta guardada para reingreso
  /// rápido. Luego va al selector de cuentas (si quedan) o a login.
  static Future<void> confirmLogout(BuildContext context) async {
    final keep = await _showKeepSessionSheet(context);
    if (keep == null) return; // canceló
    await _auth.logout(keepSaved: keep);
    if (!context.mounted) return;
    final hasSaved = await _auth.hasSavedAccounts();
    if (!context.mounted) return;
    context.go(hasSaved ? '/cuentas' : '/login');
  }

  // ── Hoja: ¿mantener sesión guardada? ──
  static Future<bool?> _showKeepSessionSheet(BuildContext context) {
    final ec = context.ec;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconBox(Icons.bookmark_added_rounded, accent: true, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('¿Mantener la sesión guardada?',
                        style: EnjoyTheme.heading(
                            size: 17, weight: FontWeight.w800, color: ec.text)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Si la guardas, podrás volver a entrar rápido con tu huella o '
                'Face ID sin escribir la contraseña.',
                style: EnjoyTheme.body(size: 14, height: 1.4, color: ec.textSoft),
              ),
              const SizedBox(height: 18),
              EnjoyButton(
                label: 'Sí, mantener guardada',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 10),
              EnjoyButton(
                label: 'No, cerrar del todo',
                variant: EnjoyButtonVariant.ghost,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hoja: necesitas activar biometría ──
  static Future<void> showBiometricRequiredSheet(BuildContext context) {
    final ec = context.ec;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconBox(Icons.fingerprint_rounded, accent: true, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Activa la biometría',
                        style: EnjoyTheme.heading(
                            size: 17, weight: FontWeight.w800, color: ec.text)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Para cambiar de cuenta y restaurar sesiones guardadas necesitas '
                'tener activada la huella o el Face ID, y darle permiso a Enjoy. '
                'Ábrelos en los ajustes y vuelve a intentarlo.',
                style: EnjoyTheme.body(size: 14, height: 1.45, color: ec.textSoft),
              ),
              const SizedBox(height: 18),
              EnjoyButton(
                label: 'Abrir ajustes',
                icon: Icons.settings_outlined,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
              ),
              const SizedBox(height: 10),
              EnjoyButton(
                label: 'Ahora no',
                variant: EnjoyButtonVariant.ghost,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
