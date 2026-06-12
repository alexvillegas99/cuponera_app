import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Autenticación biométrica (huella / Face ID) para proteger el cambio de
/// cuenta y la restauración de sesiones guardadas.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// El dispositivo soporta biometría Y se puede consultar (hardware presente).
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// El usuario tiene al menos una biometría enrolada (huella/cara registrada).
  static Future<bool> hasEnrolled() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Disponible y enrolada (lista para usarse).
  static Future<bool> isReady() async {
    if (!await isAvailable()) return false;
    return hasEnrolled();
  }

  /// Lanza el prompt biométrico. Devuelve true si la verificación fue exitosa.
  static Future<bool> authenticate(
      [String reason = 'Verifica tu identidad para continuar']) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
