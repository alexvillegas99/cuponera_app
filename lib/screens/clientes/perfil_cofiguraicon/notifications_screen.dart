import 'dart:convert';
import 'dart:io';

import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kNotifPromos  = 'notif_promos_v1';
  static const _kNotifAlertas = 'notif_alertas_v1';
  static const _kTopicsPrefs  = 'notif_topics_current_v1';

  FirebaseMessaging? _fm;
  bool get _isPush => !Platform.isIOS;

  bool _promos  = true;
  bool _alertas = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) _fm = FirebaseMessaging.instance;
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _promos  = p.getBool(_kNotifPromos)  ?? true;
      _alertas = p.getBool(_kNotifAlertas) ?? true;
    });
  }

  Future<List<String>> _getSelectedCities() async => ['Ambato'];

  Future<bool> _ensurePermissions() async {
    if (!_isPush || _fm == null) return false;
    final fm = _fm!;
    final s = await fm.getNotificationSettings();
    if (s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    final r = await fm.requestPermission(alert: true, badge: true, sound: true);
    if (r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (ctx) {
        final dc = ctx.ec;
        return AlertDialog(
          backgroundColor: dc.surfaceTop,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Permisos de notificación',
              style: EnjoyTheme.heading(
                  size: 16, weight: FontWeight.w700, color: dc.text)),
          content: Text(
            'Para recibir notificaciones, habilítalas en Ajustes del dispositivo.',
            style: EnjoyTheme.body(size: 13, color: dc.textSoft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: EnjoyTheme.body(
                      size: 13, weight: FontWeight.w600, color: dc.textSoft)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dc.orange,
                foregroundColor: dc.onAccent,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Abrir ajustes'),
            ),
          ],
        );
      },
    );
    return false;
  }

  String _slug(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _syncTopics({
    required bool promos,
    required bool alertas,
    required List<String> ciudades,
  }) async {
    if (_fm == null) return;
    final desired = <String>{
      if (promos) 'general',
      if (promos) ...ciudades.map(_slug),
      if (alertas) 'alertas',
    };

    final prefs = await SharedPreferences.getInstance();
    final currentJson = prefs.getString(_kTopicsPrefs);
    final current = currentJson != null
        ? List<String>.from(jsonDecode(currentJson)).toSet()
        : <String>{};

    // Cada suscripción/desuscripción es independiente — un fallo no aborta las demás
    for (final t in desired.difference(current)) {
      try {
        await _fm!.subscribeToTopic(t);
      } catch (e) {
        debugPrint('[Notif] subscribeToTopic("$t") falló: $e');
      }
    }
    for (final t in current.difference(desired)) {
      try {
        await _fm!.unsubscribeFromTopic(t);
      } catch (e) {
        debugPrint('[Notif] unsubscribeFromTopic("$t") falló: $e');
      }
    }

    // Guardar el estado deseado igual, para que el próximo diff sea correcto
    await prefs.setString(_kTopicsPrefs, jsonEncode(desired.toList()));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final allowed = await _ensurePermissions();
    if (!allowed) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa los permisos para recibir notificaciones')),
      );
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifPromos, _promos);
    await p.setBool(_kNotifAlertas, _alertas);

    try {
      final ciudades = await _getSelectedCities();
      await _syncTopics(promos: _promos, alertas: _alertas, ciudades: ciudades);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preferencias guardadas'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('[Notif] _save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preferencias guardadas (topics pendientes de sync)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Notificaciones'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          // ── Header ───────────────────────────────────────────
          _buildHeader(),
          const SizedBox(height: 16),

          // ── iOS banner ────────────────────────────────────────
          if (!_isPush) ...[
            _buildIosBanner(),
            const SizedBox(height: 16),
          ],

          // ── Switches ─────────────────────────────────────────
          _buildSwitchCard(),
          const SizedBox(height: 16),

          // ── Preview notificación ──────────────────────────────
          if (_promos) ...[
            _buildPreviewCard(),
            const SizedBox(height: 16),
          ],

          // ── Botón guardar ─────────────────────────────────────
          _buildSaveButton(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final ec = context.ec;
    return GlassCard(
      child: Row(
        children: [
          const IconBox(Icons.notifications_rounded, accent: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controla tus notificaciones',
                  style: EnjoyTheme.heading(size: 15, color: ec.text),
                ),
                const SizedBox(height: 3),
                Text(
                  'Elige qué quieres recibir. Puedes cambiarlo cuando quieras.',
                  style:
                      EnjoyTheme.body(size: 12, color: ec.textSoft, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── iOS banner ────────────────────────────────────────────────────
  Widget _buildIosBanner() {
    final ec = context.ec;
    return GlassCard(
      color: ec.blue.withValues(alpha: .08),
      borderColor: ec.blue.withValues(alpha: .25),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: ec.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las notificaciones push no están disponibles en iOS por ahora.',
              style: EnjoyTheme.body(size: 12, color: ec.blue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Switch card ───────────────────────────────────────────────────
  Widget _buildSwitchCard() {
    return Column(
      children: [
        _SwitchTile(
          icon: Icons.local_offer_rounded,
          title: 'Promociones y ofertas',
          subtitle: 'Novedades de locales, descuentos y 2x1',
          value: _promos,
          onChanged: _isPush ? (v) => setState(() => _promos = v) : null,
        ),
        const SizedBox(height: 10),
        _SwitchTile(
          icon: Icons.campaign_rounded,
          title: 'Alertas importantes',
          subtitle: 'Mensajes de seguridad y avisos del sistema',
          value: _alertas,
          onChanged: _isPush ? (v) => setState(() => _alertas = v) : null,
        ),
      ],
    );
  }

  // ── Preview card ──────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final ec = context.ec;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(Icons.preview_rounded, size: 28, iconSize: 15),
              const SizedBox(width: 8),
              Text(
                'Vista previa',
                style: EnjoyTheme.heading(size: 13, color: ec.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ec.glassStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ec.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBox(Icons.local_activity_rounded,
                    accent: true, size: 36, radius: 10, iconSize: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enjoy',
                            style:
                                EnjoyTheme.heading(size: 13, color: ec.text),
                          ),
                          Text(
                            'ahora',
                            style: EnjoyTheme.body(
                                size: 11, color: ec.textMute),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '🎉 20% OFF en tu cafetería favorita hoy.',
                        style: EnjoyTheme.body(
                            size: 12, color: ec.textSoft, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────
  Widget _buildSaveButton() {
    final enabled = _isPush && !_saving;
    return EnjoyButton(
      label: 'Guardar preferencias',
      icon: _saving ? null : Icons.check_rounded,
      loading: _saving,
      onPressed: enabled ? _save : null,
    );
  }
}

// ── Switch tile ────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
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
      titleColor: disabled ? ec.textMute : ec.text,
      subtitle: subtitle,
      trailing: EnjoyToggle(value: value, onChanged: onChanged),
    );
  }
}
