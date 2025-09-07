import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Reglas:
/// - Si el endpoint responde 200 => OK.
/// - Si responde JSON con {"maintenance": true} => Mantenimiento.
/// - Si responde 5xx / no conecta / timeout => DOWN.
class ServerHealthService {
  final Duration timeout;
  final String baseUrl;
  final String healthPath;

  ServerHealthService({
    Duration? timeout,
    String? baseUrl,
    String? healthPath,
  })  : timeout = timeout ?? const Duration(seconds: 5),
        baseUrl = baseUrl ?? (dotenv.env['API_URL'] ?? ''),
        healthPath = healthPath ?? '/healthz';

  Uri get _uri => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$healthPath');

  /// Devuelve:
  /// - ('ok', null)               => todo bien
  /// - ('maintenance', msg)       => el backend puso bandera de mantenimiento
  /// - ('down', 'razón')          => caído o error
  Future<(String, String?)> checkOnce() async {
    try {
      final resp = await http.get(_uri, headers: {'accept': 'application/json'}).timeout(timeout);

      if (resp.statusCode == 200) {
        if (resp.headers['content-type']?.contains('application/json') == true) {
          final body = jsonDecode(resp.body);
          if (body is Map && (body['maintenance'] == true || body['status'] == 'maintenance')) {
            final msg = (body['message'] as String?) ?? 'Estamos en mantenimiento.';
            return ('maintenance', msg);
          }
        }
        return ('ok', null);
      }

      // 503 o cualquier 5xx => trato como mantenimiento si viene JSON; caso contrario, down
      if (resp.statusCode >= 500) {
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && (body['maintenance'] == true || body['status'] == 'maintenance')) {
            final msg = (body['message'] as String?) ?? 'Estamos en mantenimiento.';
            return ('maintenance', msg);
          }
        } catch (_) {}
        return ('down', 'HTTP ${resp.statusCode}');
      }

      // 4xx: lo tratamos como down por simplicidad
      return ('down', 'HTTP ${resp.statusCode}');
    } catch (e) {
      return ('down', '$e');
    }
  }
}
