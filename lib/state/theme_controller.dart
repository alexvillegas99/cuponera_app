import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el modo de tema (oscuro / claro / sistema) y lo persiste.
///
/// El sistema visual nace oscuro (la propuesta Premium Dark), por eso el
/// valor por defecto es [ThemeMode.dark]. El usuario puede alternar a claro
/// desde Perfil → preferencias.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode);

  static const _prefsKey = 'enjoy_theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// Crea el controller leyendo la preferencia almacenada (o `dark` por
  /// defecto). Pensado para llamarse una vez en `main()`.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    return ThemeController._(_decode(stored));
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(mode));
  }

  /// Alterna entre claro y oscuro (ignora "sistema" para el switch directo).
  Future<void> toggle() =>
      setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
