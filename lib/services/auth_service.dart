import 'dart:convert';

import 'package:enjoy/services/my_firebase_messaging_service%20copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  final myFirebaseService = MyFirebaseMessagingService();

  // ==========================
  // Helpers HTTP
  // ==========================
  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ==========================
  // LOGIN USUARIO
  // POST /auth/login  -> { accessToken, user }
  // ==========================
  Future<void> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    try {
      final resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'correo': email, 'clave': password}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (accessToken == null || user == null) {
          throw Exception('Respuesta inválida del servidor');
        }

        // Asegura kind en el user (para estrategia unificada en frontend)
        user['kind'] = user['kind'] ?? 'USUARIO';

        final userId = user?['_id']?.toString();
        final usuarioCreacion = user?['usuarioCreacion']?.toString();

        print('userId: $userId');
        print('usuarioCreacion: $usuarioCreacion');

        if (userId != null && userId.isNotEmpty) {
          print('🔔 suscribiendo al topic $userId');
          myFirebaseService.subscribe(userId);
        }

        if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
          print('🔔 suscribiendo al topic $usuarioCreacion');
          myFirebaseService.subscribe(usuarioCreacion);
        }

        await saveUserData(accessToken, user);

        final ruta = await getTargetHomeRoute();
        print('ruta usuario $ruta');
        context.go(ruta);
      } else {
        final msg = _serverErrorMessage(resp);
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('Error al iniciar sesión (usuario): $e');
      rethrow;
    }
  }

  // ==========================
  // LOGIN CLIENTE
  // POST /auth/login/cliente -> { accessToken, cliente }
  // Se guarda como 'user' para mantener compatibilidad
  // ==========================
  Future<void> loginCliente(
    String emailOrCedulaOrRuc,
    String password,
    BuildContext context,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/login/cliente');

    try {
      final resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'correo': emailOrCedulaOrRuc, 'clave': password}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final cliente = data['cliente'] as Map<String, dynamic>?;

        if (accessToken == null || cliente == null) {
          throw Exception('Respuesta inválida del servidor');
        }

        // Normalizamos a 'user' y seteamos kind
        final user = {...cliente, 'kind': 'CLIENTE'};
        print('userData $user');

        await saveUserData(accessToken, user);
        final userId = user?['_id']?.toString();
        print('userId: $userId');

        if (userId != null && userId.isNotEmpty) {
          print('🔔 suscribiendo al topic $userId');
          myFirebaseService.subscribe(userId);
        }

        final ruta = await getTargetHomeRoute();
        print('ruta cleuinte $ruta');
        context.go(ruta);
      } else {
        final msg = _serverErrorMessage(resp);
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('Error al iniciar sesión (cliente): $e');
      rethrow;
    }
  }

  // ==========================
  // LOGIN EMPRESA (si quieres derivarlo a /auth/login)
  // ==========================
  Future<void> loginEmpresa(
    String email,
    String password,
    BuildContext context,
  ) => login(email, password, context);

  // ==========================
  // STORAGE
  // ==========================
  Future<void> saveUserData(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: jsonEncode(user));
    // Guarda kind por separado para accesos rápidos
    if (user['kind'] != null) {
      await _storage.write(key: 'kind', value: user['kind'].toString());
    }
    debugPrint('Token guardado y user/kind almacenados correctamente.');
  }

  Future<String?> getToken() => _storage.read(key: 'accessToken');

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: 'user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String?> getKind() => _storage.read(key: 'kind');

  // ==========================
  // REFRESH TOKEN
  // GET /auth/refresh-token -> { user, token }
  // ==========================
  Future<bool> renewToken() async {
    final token = await getToken();
    if (token == null) return false;

    final uri = Uri.parse('$baseUrl/auth/refresh-token');

    try {
      final resp = await http.get(
        uri,
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (newToken == null || user == null) {
          debugPrint('Respuesta inválida al renovar token: ${resp.body}');
          return false;
        }

        // El backend ya inyecta kind en req.user (estrategia actualizada).
        // Aseguramos que exista por compatibilidad.
        user['kind'] = user['kind'] ?? (await getKind()) ?? 'USUARIO';

        await saveUserData(newToken, user);
        return true;
      } else {
        debugPrint(
          'Error al renovar token: ${resp.statusCode} -> ${resp.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error en renewToken(): $e');
      return false;
    }
  }

  // ==========================
  // LOGOUT
  // ==========================
  Future<void> logout() async {
    try {
      final user = await getUser();
      final userId = user?['_id']?.toString();
      final usuarioCreacion = user?['usuarioCreacion']?.toString();

      print('userId: $userId');
      print('usuarioCreacion: $usuarioCreacion');

      if (userId != null && userId.isNotEmpty) {
        print('🔔 desuscribiendo al topic $userId');
        myFirebaseService.unsubscribe(userId);
      }

      if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
        print('🔔 desuscribiendo al topic $usuarioCreacion');
        myFirebaseService.unsubscribe(usuarioCreacion);
      }

      await _storage.delete(key: 'accessToken');
      await _storage.delete(key: 'user');
      await _storage.delete(key: 'kind');
      debugPrint('Sesión cerrada. Datos eliminados. userId: $userId');
    } catch (e) {
      debugPrint('Error en logout: $e');
    }
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'accessToken')) != null;

  // ==========================
  // Utils
  // ==========================
  String _serverErrorMessage(http.Response resp) {
    try {
      final data = jsonDecode(resp.body);
      final msg = data is Map && data['message'] != null
          ? data['message']
          : null;
      return msg?.toString() ??
          'Error ${resp.statusCode} al procesar la solicitud';
    } catch (_) {
      return 'Error ${resp.statusCode} al procesar la solicitud';
    }
  }

  bool _isClienteRole(Map<String, dynamic>? user) {
    print('tipo usuario  $user');
    if (user == null) return false;
    final rol = (user['rol'] ?? '').toString().toLowerCase();
    final kind = (user['kind'] ?? '').toString().toUpperCase();
    return rol == 'cliente' || kind == 'CLIENTE';
  }

  /// Decide a qué home ir según el usuario guardado.
  Future<String> getTargetHomeRoute() async {
    final user = await getUser();
    final isCliente = _isClienteRole(user);
    print('¿Es cliente? $isCliente');

    // Si es cliente → /home_cliente, caso contrario → /home_user
    return isCliente ? '/home_user' : '/home';
  }

  Future<void> completeRecovery(String code, String newPassword) async {
    final uri = Uri.parse('$baseUrl/auth/recover/complete');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'code': code, 'newPassword': newPassword}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(_serverErrorMessage(resp));
    }
  }

  Future<void> updateContactInfo({
    required String nombres,
    required String apellidos,
    required String correo,
    required String telefono,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Sin token');
    }

    final user = await getUser();
    final kind = (user?['kind'] ?? 'USUARIO').toString();
    final id = user?['_id'];
    final uri = Uri.parse('$baseUrl/clientes/me/${id}');

    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'apellidos': apellidos,
        'nombres': nombres,
        'correo': correo,
        'telefono': telefono,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }

    // actualiza el storage local
    final u = {...?user};
    u['apellidos'] = apellidos;
    u['nombres'] = nombres;
    u['correo'] = correo;
    u['telefono'] = telefono;
    await saveUserData(token, u);
  }

  final _client = http.Client();
  Uri _uri(String path) => Uri.parse('$baseUrl$path');
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required bool isCliente,
  }) async {
    final path = isCliente ? '/clientes/reset' : '/usuarios/reset';
    final resp = await _client.patch(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': newPassword}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(_extractMessage(resp.body));
    }
    // Si quieres leer algún dato de confirmación del backend:
    // if (resp.body.isNotEmpty) jsonDecode(resp.body);
  }

  String _extractMessage(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map && map['message'] != null)
        return map['message'].toString();
    } catch (_) {}
    return body.isEmpty ? 'Error inesperado' : body;
  }

  Future<void> startRecovery(String email) async {
    final resp = await _client.post(
      _uri('/clientes/recovery'),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(_extractMessage(resp.body));
    }
  }
}
