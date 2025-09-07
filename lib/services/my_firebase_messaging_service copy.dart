// my_firebase_messaging_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// (Opcional) si deseas abrir ajustes del sistema:
import 'package:permission_handler/permission_handler.dart'; // add en pubspec

class MyFirebaseMessagingService {
  static const _kTopicsPrefs = 'notif_topics_current_v1';

  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  /// Llama esto en el arranque de la app
  Future<void> init() async {
    // Android 13+: recuerda agregar <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    await _fm.setAutoInitEnabled(true);

    // Handlers (ya los tienes en tu otra clase si deseas mantenerlos)
    FirebaseMessaging.onMessage.listen((m) {});
    FirebaseMessaging.onMessageOpenedApp.listen((m) {});
  }

  /// Pide permisos si hace falta; si siguen denegados, ofrece abrir ajustes
  Future<bool> ensurePermissions(BuildContext context) async {
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

    // Sigue denegado -> sugerir abrir ajustes
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permisos de notificación'),
          content: const Text(
              'Para recibir notificaciones, habilita los permisos en Ajustes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings(); // permission_handler
              },
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  /// Suscribir (si no está) y guardar
  Future<void> subscribe(String topic) async {
    if (topic.isEmpty) return;
    await _fm.subscribeToTopic(topic);
  }

  /// Desuscribir (si estaba) y guardar
  Future<void> unsubscribe(String topic) async {
    if (topic.isEmpty) return;
    await _fm.unsubscribeFromTopic(topic);
  }

  /// Helper: slug para ciudades -> sin espacios, minúsculas, sin acentos básicos
  String slug(String input) {
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

  /// Sincroniza topics según switches y ciudades seleccionadas.
  /// Retorna { subscribed: [...], unsubscribed: [...] } para logging.
  Future<Map<String, List<String>>> syncTopics({
    required bool promos,
    required bool alertas,
    required List<String> ciudades,
    bool alertasPorCiudad = false, // si quieres alertas por ciudad también
  }) async {
    // 1) Calcula los topics deseados:
    final desired = <String>{};

    if (promos) {
      desired.add('general'); // base para promociones
      for (final c in ciudades) {
        desired.add('ciudad-${slug(c)}');
      }
    }

    if (alertas) {
      desired.add('alertas'); // base para alertas globales
      if (alertasPorCiudad) {
        for (final c in ciudades) {
          desired.add('alertas-${slug(c)}');
        }
      }
    }

    // 2) Carga lista actual (última aplicada) desde SharedPreferences:
    final prefs = await SharedPreferences.getInstance();
    final currentJson = prefs.getString(_kTopicsPrefs);
    final current = currentJson != null
        ? (List<String>.from(jsonDecode(currentJson)))
        : <String>[];

    final currentSet = current.toSet();

    // 3) Diff: qué suscribir y qué desuscribir
    final toSubscribe = desired.difference(currentSet).toList();
    final toUnsubscribe = currentSet.difference(desired).toList();

    // 4) Aplica cambios
    for (final t in toSubscribe) {
      await subscribe(t);
    }
    for (final t in toUnsubscribe) {
      await unsubscribe(t);
    }

    // 5) Guarda nuevo estado
    await prefs.setString(_kTopicsPrefs, jsonEncode(desired.toList()));

    return {
      'subscribed': toSubscribe,
      'unsubscribed': toUnsubscribe,
    };
  }

  /// Opcional: obtener token para registrar en tu backend
  Future<String?> getToken() => _fm.getToken();
}
