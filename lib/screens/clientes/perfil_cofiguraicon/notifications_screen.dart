import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../ui/palette.dart';

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
        s.authorizationStatus == AuthorizationStatus.provisional) return true;

    final r = await fm.requestPermission(alert: true, badge: true, sound: true);
    if (r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional) return true;

    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permisos de notificación',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Para recibir notificaciones, habilítalas en Ajustes del dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.kAccent),
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
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
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Palette.kPrimary,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Palette.kSurface,
            border: Border(bottom: BorderSide(color: Palette.kBorder, width: 1)),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Palette.kAccent, Palette.kAccentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Palette.kAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controla tus notificaciones',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Elige qué quieres recibir. Puedes cambiarlo cuando quieras.',
                  style: TextStyle(color: Palette.kMuted, fontSize: 12, height: 1.4),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.kPrimary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kPrimary.withOpacity(0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Palette.kPrimary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las notificaciones push no están disponibles en iOS por ahora.',
              style: TextStyle(color: Palette.kPrimary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Switch card ───────────────────────────────────────────────────
  Widget _buildSwitchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.local_offer_rounded,
            iconColor: Palette.kAccent,
            title: 'Promociones y ofertas',
            subtitle: 'Novedades de locales, descuentos y 2x1',
            value: _promos,
            onChanged: _isPush ? (v) => setState(() => _promos = v) : null,
          ),
          const Divider(height: 1, color: Palette.kBorder, indent: 56),
          _SwitchTile(
            icon: Icons.campaign_rounded,
            iconColor: Palette.kPrimary,
            title: 'Alertas importantes',
            subtitle: 'Mensajes de seguridad y avisos del sistema',
            value: _alertas,
            onChanged: _isPush ? (v) => setState(() => _alertas = v) : null,
          ),
        ],
      ),
    );
  }

  // ── Preview card ──────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.preview_rounded,
                  color: Palette.kAccent,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Vista previa',
                style: TextStyle(
                  color: Palette.kTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.kBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Palette.kAccent, Palette.kAccentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_activity_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enjoy',
                            style: TextStyle(
                              color: Palette.kTitle,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'ahora',
                            style: TextStyle(color: Palette.kMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        '🎉 20% OFF en tu cafetería favorita hoy.',
                        style: TextStyle(
                          color: Palette.kMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
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
    return GestureDetector(
      onTap: enabled ? _save : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Palette.kBorder,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Palette.kAccent.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color: enabled ? Colors.white : Palette.kMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Guardar preferencias',
                    style: TextStyle(
                      color: enabled ? Colors.white : Palette.kMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Switch tile ────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: disabled
                  ? Palette.kField
                  : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: disabled ? Palette.kMuted : iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: disabled ? Palette.kMuted : Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: iconColor,
            inactiveThumbColor: Palette.kBorder,
            inactiveTrackColor: Palette.kField,
          ),
        ],
      ),
    );
  }
}
