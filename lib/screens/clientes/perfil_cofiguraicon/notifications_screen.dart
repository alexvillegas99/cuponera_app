import 'dart:convert';

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
  // Keys para switches
  static const _kNotifPromos = 'notif_promos_v1';
  static const _kNotifAlertas = 'notif_alertas_v1';

  // Key para guardar el "estado actual" de topics aplicados (para diff)
  static const _kTopicsPrefs = 'notif_topics_current_v1';

  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  bool _promos = true;
  bool _alertas = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _promos = p.getBool(_kNotifPromos) ?? true;
      _alertas = p.getBool(_kNotifAlertas) ?? true;
    });
  }

  // TODO: reemplazar por tu fuente real (perfil del usuario, API, prefs, etc.)
  // Devuelve la lista de ciudades que el usuario tiene seleccionadas.
  Future<List<String>> _getSelectedCities() async {
    // Ejemplo: léelo de prefs si lo guardas ahí:
    // final p = await SharedPreferences.getInstance();
    // return p.getStringList('user_selected_cities') ?? ['Ambato'];
    return ['Ambato'];
  }

  /// ------------------ PERMISOS ------------------

  /// Pide permisos si hace falta; si siguen denegados, ofrece abrir ajustes.
  Future<bool> _ensurePermissions(BuildContext context) async {
    final settings = await _fm.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    final req = await _fm.requestPermission(alert: true, badge: true, sound: true);

    if (req.authorizationStatus == AuthorizationStatus.authorized ||
        req.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permisos de notificación'),
        content: const Text('Para recibir notificaciones, habilítalas en Ajustes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
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

  /// ------------------ TOPICS ------------------

  Future<void> _subscribe(String topic) => _fm.subscribeToTopic(topic);
  Future<void> _unsubscribe(String topic) => _fm.unsubscribeFromTopic(topic);

  /// slug básico para ciudades (minúsculas, sin acentos, reemplazo por '-')
  String _slug(String input) {
    final lower = input.trim().toLowerCase();
    final replaced = lower
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return replaced;
  }

  /// Calcula diff y se suscribe/desuscribe. Guarda el estado final en prefs.
  ///
  /// Convenciones:
  /// - Promos ON  -> topics: 'general' + 'ciudad-<slug(ciudad)>' por cada ciudad
  /// - Alertas ON -> topic:  'alertas' (global). Si quisieras por ciudad, puedes añadir 'alertas-<slug>'
  Future<Map<String, List<String>>> _syncTopics({
    required bool promos,
    required bool alertas,
    required List<String> ciudades,
    bool alertasPorCiudad = false,
  }) async {
    // 1) Construye set deseado
    final desired = <String>{};

    if (promos) {
      desired.add('general');
      for (final c in ciudades) {
        desired.add(_slug(c));
      }
    }

    if (alertas) {
      desired.add('alertas');
      if (alertasPorCiudad) {
        for (final c in ciudades) {
          desired.add(_slug(c));
        }
      }
    }

    // 2) Carga estado actual desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentJson = prefs.getString(_kTopicsPrefs);
    final current = currentJson != null ? List<String>.from(jsonDecode(currentJson)) : <String>[];
    final currentSet = current.toSet();

    // 3) Diff
    print(desired);
    print('desired');
    final toSubscribe = desired.difference(currentSet).toList();
    final toUnsubscribe = currentSet.difference(desired).toList();

    // 4) Aplica cambios
    for (final t in toSubscribe) {
      await _subscribe(t);
    }
    for (final t in toUnsubscribe) {
      await _unsubscribe(t);
    }

    // 5) Guarda nuevo estado
    await prefs.setString(_kTopicsPrefs, jsonEncode(desired.toList()));

    return {'subscribed': toSubscribe, 'unsubscribed': toUnsubscribe};
  }

  /// ------------------ GUARDAR ------------------

  Future<void> _save() async {
    setState(() => _saving = true);

    // 1) Permisos de notificación
    final allowed = await _ensurePermissions(context);
    if (!allowed) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa los permisos para recibir notificaciones')),
      );
      return;
    }

    // 2) Guardar switches
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifPromos, _promos);
    await p.setBool(_kNotifAlertas, _alertas);

    // 3) Sincronizar topics
    final ciudades = await _getSelectedCities();
    final result = await _syncTopics(
      promos: _promos,
      alertas: _alertas,
      ciudades: ciudades,
      alertasPorCiudad: false, // pon true si quieres alertas por ciudad también
    );

    if (!mounted) return;
    setState(() => _saving = false);

    // 4) Feedback
    final subs = (result['subscribed'] ?? []).join(', ');
    final unsubs = (result['unsubscribed'] ?? []).join(', ');
    final msg = [
      if (subs.isNotEmpty) 'Suscrito: $subs',
      if (unsubs.isNotEmpty) 'Desuscrito: $unsubs',
      if (subs.isEmpty && unsubs.isEmpty) 'Sin cambios'
    ].join(' · ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preferencias guardadas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Notificaciones'),
         backgroundColor: Palette.kAccent,
        foregroundColor: Palette.kBg,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Intro
          _InfoCard(
            icon: Icons.notifications_active_outlined,
            title: 'Controla tus notificaciones',
            subtitle:
                'Elige qué quieres recibir. Puedes cambiarlo cuando quieras.',
          ),
          const SizedBox(height: 16),

          // Card de switches
          Container(
            decoration: BoxDecoration(
              color: Palette.kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.kBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(0.04),
                ),
              ],
            ),
            child: Column(
              children: [
                _SwitchRow(
                  leadingIcon: Icons.local_offer_outlined,
                  title: 'Promociones y ofertas',
                  subtitle: 'Novedades de locales, descuentos y 2x1',
                  value: _promos,
                  onChanged: (v) => setState(() => _promos = v),
                ),
                const Divider(height: 1, color: Palette.kBorder),
                _SwitchRow(
                  leadingIcon: Icons.announcement_outlined,
                  title: 'Alertas importantes',
                  subtitle: 'Mensajes de seguridad y avisos del sistema',
                  value: _alertas,
                  onChanged: (v) => setState(() => _alertas = v),
                ),
              ],
            ),
          ),

          // Vista previa (opcional)
          const SizedBox(height: 18),
          if (_promos)
            const _PreviewCard(
              title: 'Ejemplo de promoción',
              body: '🎉 20% OFF en tu cafetería favorita hoy.',
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text('Guardar preferencias'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Palette.kField,
            child: Icon(leadingIcon, color: Palette.kAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Palette.kTitle,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Palette.kAccent,
            inactiveThumbColor: Palette.kBorder,
            inactiveTrackColor: Palette.kField,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Palette.kPrimary, Palette.kAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Palette.kSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin_outlined, color: Palette.kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Palette.kTitle,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: Palette.kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
