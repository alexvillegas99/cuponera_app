// lib/services/registration_api.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RegistrationApi {
  RegistrationApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl = dotenv.env['API_URL'] ?? '';

  Uri _uri(String path, [Map<String, dynamic>? qp]) {
    final u = Uri.parse('$baseUrl$path');
    return (qp == null) ? u : u.replace(queryParameters: qp.map(
      (k, v) => MapEntry(k, v?.toString()),
    ));
  }

  Map<String, String> get _headersJson => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// ──────────────────────────────────────────────────────────────────────────
  /// Helpers
  /// ──────────────────────────────────────────────────────────────────────────
String _extractMessage(String body) {
  if (body.isEmpty) return 'Error inesperado';
  try {
    final decoded = jsonDecode(body);

    // Caso raíz: objeto
    if (decoded is Map) {
      // 1) Intentar en "message" (puede ser String | List | Map)
      final m = decoded['message'];
      final fromMessage = _normalizeMessage(m);
      if (fromMessage != null && fromMessage.isNotEmpty) return fromMessage;

      // 2) class-validator: { errors: [{ constraints: {...} }, ...] }
      if (decoded['errors'] is List) {
        final errors = decoded['errors'] as List;
        final msgs = <String>[];
        for (final e in errors) {
          if (e is Map && e['constraints'] is Map) {
            (e['constraints'] as Map).values.forEach((v) {
              if (v != null) msgs.add(v.toString());
            });
          }
        }
        if (msgs.isNotEmpty) return msgs.toSet().join(' • ');
      }

      // 3) Otras claves comunes
      for (final k in ['error', 'detail', 'description', 'error_description']) {
        final v = decoded[k];
        final s = _normalizeMessage(v);
        if (s != null && s.isNotEmpty) return s;
      }
    }

    // Si no es Map o no se pudo extraer nada legible:
    return body;
  } catch (_) {
    // Si no parsea JSON, devolvemos el body tal cual (o un fallback si viene vacío)
    return body.isEmpty ? 'Error inesperado' : body;
  }
}

/// Normaliza distintos formatos de "mensaje"
String? _normalizeMessage(dynamic m) {
  if (m == null) return null;

  // String directo
  if (m is String) return m;

  // Lista: puede contener strings y/o maps con message
  if (m is List) {
    final msgs = m
        .map((e) => _normalizeMessage(e) ?? e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toSet() // quita duplicados
        .toList();
    return msgs.join(' • ');
  }

  // Map: buscar claves típicas (incluye el caso message.message)
  if (m is Map) {
    for (final k in ['message', 'msg', 'error', 'detail', 'description']) {
      final v = m[k];
      final s = _normalizeMessage(v);
      if (s != null && s.isNotEmpty) return s;
    }
    // si no hay ninguna de las claves, como último recurso:
    return m.toString();
  }

  // cualquier otro tipo
  return m.toString();
}


  T _parseJson<T>(http.Response resp) {
    try {
      return jsonDecode(resp.body) as T;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor.');
    }
  }

  bool _is2xx(int code) => code >= 200 && code < 300;

  /// ──────────────────────────────────────────────────────────────────────────
  /// API
  /// ──────────────────────────────────────────────────────────────────────────

  /// POST /clientes  → crea cliente
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> dto) async {
    final resp = await _client.post(
      _uri('/clientes'),
      headers: _headersJson,
      body: jsonEncode(dto),
    );

    if (_is2xx(resp.statusCode)) {
      return _parseJson<Map<String, dynamic>>(resp);
    }
   
    print('responseeeee $resp');
    throw Exception(_extractMessage(resp.body));
  }

   Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// POST /empresas/solicitudes  → enviar solicitud de empresa
  Future<void> enviarSolicitudEmpresa(Map<String, dynamic> dto) async {
    final uri = Uri.parse('$baseUrl/empresas/solicitudes');
    final resp = await http.post(uri, headers: _headers, body: jsonEncode(dto));

    if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) return;

    if (resp.statusCode == 409) {
      // Conflicto por email ya registrado en solicitudes
      throw Exception(_extractMessage(resp.body).isEmpty
          ? 'Ya existe una solicitud con este correo.'
          : _extractMessage(resp.body));
    }

    throw Exception('Error ${resp.statusCode}: ${_extractMessage(resp.body)}');
  }

  /// GET /clientes/check-email?email=...  → true si está disponible
  Future<bool> checkEmailAvailable(String email) async {
    final resp = await _client.get(
      _uri('/clientes/check-email', {'email': email}),
      headers: {'Accept': 'application/json'},
    );

    // Convenciones soportadas:
    // 200 => { available: true|false }
    // 201 => { available: true } (por si tu backend retorna 201)
    // 409 => ya existe => available=false
    // 404 => no existe => available=true
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      try {
        final data = jsonDecode(resp.body);
        if (data is Map && data['available'] is bool) {
          return data['available'] as bool;
        }
        // Si el backend devolvió algo no estándar, asumimos NO disponible
        return false;
      } catch (_) {
        return false;
      }
    }
    if (resp.statusCode == 409) return false;
    if (resp.statusCode == 404) return true;

    // Otros códigos → error explícito con mensaje del backend
    throw Exception(_extractMessage(resp.body));
  }

  /// (Opcional) POST /clientes/recovery  → iniciar flujo de recuperación
  /// La dejo aquí por si quieres reutilizarla desde esta clase.
  Future<void> startRecovery(String email) async {
    final resp = await _client.post(
      _uri('/clientes/recovery'),
      headers: _headersJson,
      body: jsonEncode({'email': email}),
    );
    if (!_is2xx(resp.statusCode)) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  void dispose() {
    _client.close();
  }
}
