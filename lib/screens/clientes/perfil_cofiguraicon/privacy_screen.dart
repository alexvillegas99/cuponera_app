import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Privacidad'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          // Banner informativo
          GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBox(Icons.shield_outlined),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Por ahora no recopilamos datos personales ni usamos tu ubicación. '
                    'Cuando activemos estas funciones, podrás decidir aquí.',
                    style: EnjoyTheme.body(
                        size: 13, color: ec.textSoft, height: 1.45),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== Datos anónimos =====
          _PrivacyTile(
            icon: Icons.insights_rounded,
            title: 'Compartir datos anónimos (opcional)',
            subtitle: _featAnonEnabled
                ? 'Ayuda a mejorar la app compartiendo métricas anónimas'
                : 'No disponible aún',
            value: _featAnonEnabled ? _anonData : false,
            onChanged: _featAnonEnabled
                ? (v) => setState(() => _anonData = v)
                : null, // deshabilitado si no está activo
          ),
          const SizedBox(height: 10),

          // ===== Ubicación =====
          _PrivacyTile(
            icon: Icons.location_on_outlined,
            title: 'Usar ubicación para ofertas cercanas',
            subtitle: _featLocationEnabled
                ? 'Personaliza resultados según tu ubicación'
                : 'No disponible aún',
            value: _featLocationEnabled ? _location : false,
            onChanged: _featLocationEnabled
                ? (v) => setState(() => _location = v)
                : null,
          ),

          const SizedBox(height: 24),

          EnjoyButton(
            label: 'Guardar',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _openPolicy,
              child: Text(
                'Ver política de privacidad',
                style: EnjoyTheme.body(
                    size: 13, weight: FontWeight.w600, color: ec.orangeSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy tile ───────────────────────────────────────────────────────
class _PrivacyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PrivacyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final disabled = onChanged == null;
    return ListRowTile(
      leading: IconBox(icon, color: disabled ? ec.textMute : ec.orangeSoft),
      title: title,
      titleColor: disabled ? ec.textSoft : ec.text,
      subtitle: subtitle,
      trailing: EnjoyToggle(value: value, onChanged: onChanged),
    );
  }
}
