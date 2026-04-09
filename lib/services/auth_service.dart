import 'dart:convert';
import 'dart:io';

import 'package:enjoy/main.dart' show isPushEnabled;
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  MyFirebaseMessagingService? myFirebaseService;

  AuthService() {
    if (isPushEnabled) {
      myFirebaseService = MyFirebaseMessagingService();
    }
  }

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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

        user['kind'] = user['kind'] ?? 'USUARIO';

        final userId = user['_id']?.toString();
        final usuarioCreacion = user['usuarioCreacion']?.toString();

        if (userId != null && userId.isNotEmpty) {
          myFirebaseService?.subscribeToTopic(userId);
        }

        if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
          myFirebaseService?.subscribeToTopic(usuarioCreacion);
        }

        await saveUserData(accessToken, user);

        final ruta = await getTargetHomeRoute();
        context.go(ruta);
      } else {
        throw Exception(_serverErrorMessage(resp));
      }
    } catch (e) {
      debugPrint('Error login usuario: $e');
      rethrow;
    }
  }

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

        final user = {...cliente, 'kind': 'CLIENTE'};

        await saveUserData(accessToken, user);

        final userId = user['_id']?.toString();

        if (userId != null && userId.isNotEmpty) {
          myFirebaseService?.subscribeToTopic(userId);
          // Guardar FCM token en el backend para notificaciones personalizadas
          _guardarFcmToken(userId);
        }

        final ruta = await getTargetHomeRoute();
        context.go(ruta);
      } else {
        throw Exception(_serverErrorMessage(resp));
      }
    } catch (e) {
      debugPrint('Error login cliente: $e');
      rethrow;
    }
  }

  Future<void> loginEmpresa(
    String email,
    String password,
    BuildContext context,
  ) => login(email, password, context);

  Future<void> saveUserData(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: jsonEncode(user));
    if (user['kind'] != null) {
      await _storage.write(key: 'kind', value: user['kind'].toString());
    }
  }

  Future<String?> getToken() => _storage.read(key: 'accessToken');

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: 'user');
    return raw != null ? jsonDecode(raw) : null;
  }

  Future<String?> getKind() => _storage.read(key: 'kind');

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
        final data = jsonDecode(resp.body);
        final newToken = data['token'];
        final user = data['user'];

        if (newToken == null || user == null) return false;

        user['kind'] = user['kind'] ?? (await getKind()) ?? 'USUARIO';

        await saveUserData(newToken, user);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final user = await getUser();
      final userId = user?['_id']?.toString();
      final usuarioCreacion = user?['usuarioCreacion']?.toString();

      if (userId != null && userId.isNotEmpty) {
        myFirebaseService?.unsubscribeFromTopic(userId);
      }

      if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
        myFirebaseService?.unsubscribeFromTopic(usuarioCreacion);
      }

      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error logout: $e');
    }
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'accessToken')) != null;

  String _serverErrorMessage(http.Response resp) {
    try {
      final data = jsonDecode(resp.body);
      return data['message'] ?? 'Error ${resp.statusCode}';
    } catch (_) {
      return 'Error ${resp.statusCode}';
    }
  }

  bool _isClienteRole(Map<String, dynamic>? user) {
    if (user == null) return false;
    final rol = (user['rol'] ?? '').toString().toLowerCase();
    final kind = (user['kind'] ?? '').toString().toUpperCase();
    return rol == 'cliente' || kind == 'CLIENTE';
  }

  Future<String> getTargetHomeRoute() async {
    final user = await getUser();
    return _isClienteRole(user) ? '/home_user' : '/home';
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
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': newPassword}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(resp.body);
    }
  }

  Future<void> startRecovery(String email) async {
    final resp = await _client.post(
      _uri('/clientes/recovery'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(resp.body);
    }
  }

  Future<void> completeRecovery(String code, String newPassword) async {
    final uri = Uri.parse('$baseUrl/auth/recover/complete');

    final resp = await http.post(
      uri,
      headers: _jsonHeaders,
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
    final id = user?['_id'];

    final uri = Uri.parse('$baseUrl/clientes/me/$id');

    final resp = await http.put(
      uri,
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
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

    // actualizar storage local
    final updated = {...?user};
    updated['apellidos'] = apellidos;
    updated['nombres'] = nombres;
    updated['correo'] = correo;
    updated['telefono'] = telefono;

    await saveUserData(token, updated);
  }

  /// Guarda el FCM token del cliente en el backend para notificaciones personalizadas
  Future<void> _guardarFcmToken(String clienteId) async {
    if (!isPushEnabled) return;
    try {
      final fcmToken = await MyFirebaseMessagingService().getTokenWithRetry();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await http.patch(
        Uri.parse('$baseUrl/clientes/$clienteId/fcm-token'),
        headers: _jsonHeaders,
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      debugPrint('✅ FCM token guardado para cliente $clienteId');
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar FCM token: $e');
    }
  }
}
