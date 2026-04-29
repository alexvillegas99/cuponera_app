import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:enjoy/main.dart' show isPushEnabled;
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
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
          _guardarFcmTokenUsuario(userId);
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

  // ── Helpers para nonce (requerido por Apple Sign-In) ──────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ──────────────────────────────────────────────────────────────────────────
  /// Inicia sesión con Apple, autentica en Firebase y devuelve el Firebase ID Token.
  /// Solo disponible en iOS / macOS.
  Future<String?> _getAppleIdToken() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      debugPrint('🍎 [Apple] Solicitando credencial a Apple...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      debugPrint('🍎 [Apple] identityToken recibido: '
          '${appleCredential.identityToken != null ? 'OK (${appleCredential.identityToken!.length} chars)' : 'NULL'}');
      debugPrint('🍎 [Apple] userIdentifier: ${appleCredential.userIdentifier}');
      debugPrint('🍎 [Apple] email: ${appleCredential.email}');

      if (appleCredential.identityToken == null) {
        throw Exception('Apple no devolvió identityToken');
      }

      final credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
      );

      debugPrint('🍎 [Apple] Llamando FirebaseAuth.signInWithCredential...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('🍎 [Apple] Firebase user: ${userCredential.user?.uid}');

      final firebaseIdToken = await userCredential.user?.getIdToken(true);
      debugPrint('🍎 [Apple] firebaseIdToken: '
          '${firebaseIdToken != null ? 'OK (${firebaseIdToken.length} chars)' : 'NULL'}');
      return firebaseIdToken;
    } on FirebaseAuthException catch (e) {
      debugPrint('🍎 [Apple] FirebaseAuthException code=${e.code} message=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('🍎 [Apple] Error inesperado: $e');
      rethrow;
    }
  }

  /// Para clientes: si ya existe → navega a home_user.
  /// Si no existe → retorna los datos de Apple para pre-llenar el registro.
  Future<Map<String, dynamic>> loginClienteWithApple(BuildContext context) async {
    final idToken = await _getAppleIdToken();
    if (idToken == null) throw Exception('Inicio de sesión cancelado');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/apple/cliente'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    if (data['registered'] == true) {
      final accessToken = data['accessToken'] as String;
      final cliente = data['cliente'] as Map<String, dynamic>;
      final user = {...cliente, 'kind': 'CLIENTE'};
      await saveUserData(accessToken, user);
      final userId = user['_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        myFirebaseService?.subscribeToTopic(userId);
        _guardarFcmToken(userId);
      }
      if (context.mounted) context.go('/home_user');
      return {'registered': true};
    }

    return {'registered': false, ...data['appleData'] as Map<String, dynamic>};
  }

  /// Para usuarios/empresa: solo permite si ya existe la cuenta en el sistema.
  Future<void> loginUsuarioWithApple(BuildContext context) async {
    final idToken = await _getAppleIdToken();
    if (idToken == null) throw Exception('Inicio de sesión cancelado');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/apple/usuario'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final user = data['user'] as Map<String, dynamic>;
    user['kind'] = 'USUARIO';

    final userId = user['_id']?.toString();
    final usuarioCreacion = user['usuarioCreacion']?.toString();

    if (userId != null && userId.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(userId);
      _guardarFcmTokenUsuario(userId);
    }
    if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(usuarioCreacion);
    }

    await saveUserData(accessToken, user);
    if (context.mounted) context.go('/home');
  }

  // ──────────────────────────────────────────────────────────────────────────
  /// Inicia sesión con Google, autentica en Firebase y devuelve el Firebase ID Token.
  /// El backend usa `identitytoolkit.googleapis.com/v1/accounts:lookup` para validarlo,
  /// por lo que necesita el token de Firebase, no el de Google directamente.
  Future<String?> _getGoogleIdToken() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: Platform.isIOS
          ? '193436032832-vh14a827kih2btbbk9ck1t7ov8in9ovo.apps.googleusercontent.com'
          : null,
      serverClientId: '193436032832-fsvvca9fu0lqkacgmt1gc0dqef5ac44p.apps.googleusercontent.com',
    );
    await googleSignIn.signOut();
    final account = await googleSignIn.signIn();
    if (account == null) return null;
    final googleAuth = await account.authentication;

    // Crear credencial de Firebase con el token de Google
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    // Firmar en Firebase para obtener el Firebase ID Token
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCredential.user?.getIdToken(true);
    return firebaseIdToken;
  }

  /// Para clientes: si ya existe → navega a home_user y retorna `{'registered': true}`.
  /// Si no existe → retorna los datos de Google para pre-llenar el registro.
  Future<Map<String, dynamic>> loginClienteWithGoogle(BuildContext context) async {
    debugPrint('🔵 [Google] Obteniendo idToken...');
    final idToken = await _getGoogleIdToken();
    debugPrint('🔵 [Google] idToken: ${idToken != null ? 'OK (${idToken.length} chars)' : 'NULL'}');
    if (idToken == null) throw Exception('Inicio de sesión cancelado');

    debugPrint('🔵 [Google] Llamando backend: $baseUrl/auth/google/cliente');
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google/cliente'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    debugPrint('🔵 [Google] Respuesta: ${resp.statusCode} — ${resp.body}');
    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    debugPrint('🔵 [Google] registered: ${data['registered']}');

    if (data['registered'] == true) {
      final accessToken = data['accessToken'] as String;
      final cliente = data['cliente'] as Map<String, dynamic>;
      final user = {...cliente, 'kind': 'CLIENTE'};
      await saveUserData(accessToken, user);
      final userId = user['_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        myFirebaseService?.subscribeToTopic(userId);
        _guardarFcmToken(userId);
      }
      if (context.mounted) context.go('/home_user');
      return {'registered': true};
    }

    return {'registered': false, ...data['googleData'] as Map<String, dynamic>};
  }

  /// Para usuarios/empresa: solo permite si ya existe la cuenta en el sistema.
  Future<void> loginUsuarioWithGoogle(BuildContext context) async {
    final idToken = await _getGoogleIdToken();
    if (idToken == null) throw Exception('Inicio de sesión cancelado');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google/usuario'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final user = data['user'] as Map<String, dynamic>;
    user['kind'] = 'USUARIO';

    final userId = user['_id']?.toString();
    final usuarioCreacion = user['usuarioCreacion']?.toString();

    if (userId != null && userId.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(userId);
      _guardarFcmTokenUsuario(userId);
    }
    if (usuarioCreacion != null && usuarioCreacion.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(usuarioCreacion);
    }

    await saveUserData(accessToken, user);
    if (context.mounted) context.go('/home');
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

      await _storage.deleteAll(); // borra también guest_mode
    } catch (e) {
      debugPrint('Error logout: $e');
    }
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'accessToken')) != null;

  Future<void> deleteAccount() async {
    final token = await getToken();
    if (token == null) throw Exception('No hay sesión activa');

    final uri = Uri.parse('$baseUrl/clientes/me');
    final resp = await http.delete(
      uri,
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(_serverErrorMessage(resp));
    }

    await logout();
  }

  // ── Modo invitado ──
  Future<void> continueAsGuest() async {
    await _storage.write(key: 'guest_mode', value: 'true');
  }

  Future<bool> isGuest() async {
    return (await _storage.read(key: 'guest_mode')) == 'true';
  }

  Future<void> exitGuestMode() async {
    await _storage.delete(key: 'guest_mode');
  }

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

  /// Guarda el FCM token del cliente en el backend
  Future<void> _guardarFcmToken(String clienteId) async {
    await _enviarFcmToken('/clientes/$clienteId/fcm-token');
  }

  /// Guarda el FCM token del usuario (local/staff) en el backend
  Future<void> _guardarFcmTokenUsuario(String usuarioId) async {
    await _enviarFcmToken('/usuarios/$usuarioId/fcm-token');
  }

  Future<void> _enviarFcmToken(String path) async {
    if (!isPushEnabled) return;
    try {
      final fcmToken = await MyFirebaseMessagingService().getTokenWithRetry();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: _jsonHeaders,
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      debugPrint('✅ FCM token guardado: $path');
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar FCM token: $e');
    }
  }
}
