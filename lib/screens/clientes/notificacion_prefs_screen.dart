import 'package:enjoy/services/campanas_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class NotificacionPrefsScreen extends StatefulWidget {
  const NotificacionPrefsScreen({super.key});

  @override
  State<NotificacionPrefsScreen> createState() =>
      _NotificacionPrefsScreenState();
}

class _NotificacionPrefsScreenState extends State<NotificacionPrefsScreen> {
  final _svc = CampanasService();

  bool _loading = true;
  bool _push = true;
  bool _promociones = true;
  bool _nuevosLocales = true;
  bool _actualizaciones = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await _svc.getPrefs();
      if (!mounted) return;
      setState(() {
        _push = r['push'] != false;
        _promociones = r['promociones'] != false;
        _nuevosLocales = r['nuevosLocales'] != false;
        _actualizaciones = r['actualizaciones'] != false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.setPrefs({
        'push': _push,
        'promociones': _promociones,
        'nuevosLocales': _nuevosLocales,
        'actualizaciones': _actualizaciones,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas')),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Notificaciones'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Row(
                  children: [
                    const IconBox(Icons.notifications_active_rounded,
                        accent: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Preferencias',
                              style:
                                  EnjoyTheme.heading(size: 20, color: ec.text)),
                          const SizedBox(height: 2),
                          Text(
                            'Decide qué notificaciones quieres recibir. '
                            'Las que desactives igual aparecen aquí en la app, pero sin alerta.',
                            style:
                                EnjoyTheme.body(size: 12.5, color: ec.textMute),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Notificación push (master) ──
                GlassCard(
                  accent: _push,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notificación con sonido / banner',
                                style: EnjoyTheme.heading(
                                    size: 14.5, color: ec.text)),
                            const SizedBox(height: 4),
                            Text(
                              _push
                                  ? 'Recibirás avisos en tu pantalla y sonido al llegar una notificación.'
                                  : 'Las notificaciones llegan en silencio; igual las verás aquí.',
                              style: EnjoyTheme.body(
                                  size: 12, color: ec.textMute),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      EnjoyToggle(
                        value: _push,
                        onChanged: (v) => setState(() => _push = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 8),
                  child: FieldLabel('Categorías'),
                ),
                _prefTile(
                  ec,
                  icon: Icons.local_offer_rounded,
                  title: 'Promociones',
                  subtitle: 'Descuentos, 2x1, promos especiales.',
                  value: _promociones,
                  onChanged: (v) => setState(() => _promociones = v),
                ),
                const SizedBox(height: 10),
                _prefTile(
                  ec,
                  icon: Icons.storefront_rounded,
                  title: 'Nuevos locales',
                  subtitle:
                      'Cuando se sume un local nuevo a tu provincia/ciudad.',
                  value: _nuevosLocales,
                  onChanged: (v) => setState(() => _nuevosLocales = v),
                ),
                const SizedBox(height: 10),
                _prefTile(
                  ec,
                  icon: Icons.info_outline_rounded,
                  title: 'Actualizaciones',
                  subtitle: 'Avisos sobre tu cuenta, membresía y app.',
                  value: _actualizaciones,
                  onChanged: (v) => setState(() => _actualizaciones = v),
                ),
                const SizedBox(height: 24),

                EnjoyButton(
                  label: 'Guardar',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }

  Widget _prefTile(
    EnjoyColors ec, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconBox(icon, accent: value),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: EnjoyTheme.heading(size: 14, color: ec.text)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: EnjoyTheme.body(size: 12, color: ec.textMute)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          EnjoyToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
