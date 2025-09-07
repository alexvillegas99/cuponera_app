import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../ui/palette.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // ===== Feature flags (hoy en false) =====
  static const _featAnonEnabled = false;     // Aún no enviamos métricas
  static const _featLocationEnabled = false; // Aún no usamos ubicación

  // ===== Claves y versión de consentimiento =====
  static const _kConsentVersion = 1; // súbelo si cambias la política/uso
  static const _kConsentVersionKey = 'privacy_consent_version';
  static const _kAnonData = 'privacy_anon_data_v1';
  static const _kLocation = 'privacy_location_v1';

  bool _anonData = false;
  bool _location = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    // Si subiste versión de consentimiento, resetea flags
    final storedVersion = p.getInt(_kConsentVersionKey) ?? 0;
    if (storedVersion != _kConsentVersion) {
      await p.setInt(_kConsentVersionKey, _kConsentVersion);
      await p.remove(_kAnonData);
      await p.remove(_kLocation);
    }

    setState(() {
      _anonData = p.getBool(_kAnonData) ?? false;
      _location = p.getBool(_kLocation) ?? false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    // Guarda solo si la feature está habilitada
    if (_featAnonEnabled) await p.setBool(_kAnonData, _anonData);
    if (_featLocationEnabled) await p.setBool(_kLocation, _location);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferencias guardadas')),
    );
  }

  void _openPolicy() async {
    final uri = Uri.parse('https://tusitio.com/politica-privacidad'); // TODO
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Privacidad'),
        backgroundColor: Palette.kSurface,
        foregroundColor: Palette.kTitle,
        elevation: 0.5,
      ),
      body: ListView(
        children: [
          // Banner informativo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Por ahora no recopilamos datos personales ni usamos tu ubicación. '
              'Cuando activemos estas funciones, podrás decidir aquí.',
              style: TextStyle(color: Palette.kMuted),
            ),
          ),

          // ===== Datos anónimos =====
          SwitchListTile(
            title: const Text('Compartir datos anónimos (opcional)'),
            subtitle: Text(
              _featAnonEnabled
                  ? 'Ayuda a mejorar la app compartiendo métricas anónimas'
                  : 'No disponible aún',
              style: TextStyle(
                color: _featAnonEnabled ? Palette.kAccent : Palette.kMuted,
              ),
            ),
            value: _featAnonEnabled ? _anonData : false,
            onChanged: _featAnonEnabled
                ? (v) => setState(() => _anonData = v)
                : null, // deshabilitado si no está activo
          ),
          const Divider(height: 1, color: Palette.kBorder),

          // ===== Ubicación =====
          SwitchListTile(
            title: const Text('Usar ubicación para ofertas cercanas'),
            subtitle: Text(
              _featLocationEnabled
                  ? 'Personaliza resultados según tu ubicación'
                  : 'No disponible aún',
              style: TextStyle(
                color: _featLocationEnabled ? Palette.kField : Palette.kMuted,
              ),
            ),
            value: _featLocationEnabled ? _location : false,
            onChanged: _featLocationEnabled
                ? (v) => setState(() => _location = v)
                : null,
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ),
          TextButton(
            onPressed: _openPolicy,
            child: const Text('Ver política de privacidad'),
          ),
        ],
      ),
    );
  }
}
