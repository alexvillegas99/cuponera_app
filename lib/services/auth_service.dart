import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enjoy/main.dart' show isPushEnabled;
import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

/// Cuenta guardada para cambio rápido / sesiones recordadas (estilo Facebook).
class SavedAccount {
  final String id;
  final String kind; // 'CLIENTE' | 'USUARIO'
  final String rol;
  final String email;
  final String displayName;
  final String accessToken;
  final Map<String, dynamic> user;
  final String lastLogin;

  SavedAccount({
    required this.id,
    required this.kind,
    required this.rol,
    required this.email,
    required this.displayName,
    required this.accessToken,
    required this.user,
    required this.lastLogin,
  });

  bool get isCliente => kind.toUpperCase() == 'CLIENTE';

  /// Etiqueta de tipo para mostrar al usuario.
  String get tipoLabel {
    if (isCliente) return 'Cliente';
    switch (rol.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'admin-local':
        return 'Admin local';
      case 'staff':
        return 'Staff';
      default:
        return 'Empresa';
    }
  }

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        id: (j['id'] ?? '').toString(),
        kind: (j['kind'] ?? 'USUARIO').toString(),
        rol: (j['rol'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        displayName: (j['displayName'] ?? '').toString(),
        accessToken: (j['accessToken'] ?? '').toString(),
        user: (j['user'] is Map)
            ? Map<String, dynamic>.from(j['user'] as Map)
            : <String, dynamic>{},
        lastLogin: (j['lastLogin'] ?? '').toString(),
      );
}

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  MyFirebaseMessagingService? myFirebaseService;

  // Claves del almacén multi-cuenta.
  static const _kAccounts = 'accounts_v1';
  static const _kCurrentAccount = 'current_account_id';

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

        // Topics de segmentación (broadcast por provincia/ciudad/categoría).
        _suscribirTopicsCliente(user);

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

  /// Suscribe al cliente a topics FCM jerárquicos para que pueda recibir
  /// broadcasts segmentados:
  ///   - `all_clientes` → mensajes globales
  ///   - `prov_<slug>` → mensajes por provincia (ej. `prov_tungurahua`)
  ///   - `ciudad_<id>` → mensajes por ciudad
  /// Llamado en login y al actualizar el perfil. Es idempotente.
  void _suscribirTopicsCliente(Map<String, dynamic> user) {
    try {
      myFirebaseService?.subscribeToTopic('all_clientes');
      final slug = user['provinciaSlug']?.toString();
      if (slug != null && slug.isNotEmpty) {
        myFirebaseService?.subscribeToTopic('prov_$slug');
      }
      final ciudadId = user['ciudad']?.toString();
      if (ciudadId != null && ciudadId.isNotEmpty) {
        myFirebaseService?.subscribeToTopic('ciudad_$ciudadId');
      }
    } catch (e) {
      debugPrint('Error suscribiendo a topics cliente: $e');
    }
  }

  /// Registra un cliente y deja la sesión iniciada (auto-login).
  /// Funciona tanto con clave como con redes sociales (password nulo).
  Future<void> registerCliente(
    Map<String, dynamic> dto,
    BuildContext context,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/register/cliente');
    try {
      final resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(dto),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
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
          _guardarFcmToken(userId);
        }
        _suscribirTopicsCliente(user);

        if (context.mounted) {
          final ruta = await getTargetHomeRoute();
          context.go(ruta);
        }
      } else {
        throw Exception(_serverErrorMessage(resp));
      }
    } catch (e) {
      debugPrint('Error register cliente: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  /// Obtiene el identity token de Apple directamente (sin Firebase).
  /// Solo disponible en iOS / macOS.
  Future<String?> _getAppleIdToken() async {
    debugPrint('🍎 [Apple] Solicitando credencial a Apple...');
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    debugPrint('🍎 [Apple] Credencial recibida');
    debugPrint('🍎 [Apple] userIdentifier: ${appleCredential.userIdentifier}');
    debugPrint('🍎 [Apple] email: ${appleCredential.email ?? "(no incluido, ya fue compartido antes)"}');
    debugPrint('🍎 [Apple] givenName: ${appleCredential.givenName ?? "(vacío)"}');
    debugPrint('🍎 [Apple] familyName: ${appleCredential.familyName ?? "(vacío)"}');
    debugPrint('🍎 [Apple] identityToken: ${appleCredential.identityToken != null ? "OK (${appleCredential.identityToken!.length} chars)" : "NULL ❌"}');
    return appleCredential.identityToken;
  }

  /// Para clientes: si ya existe → navega a home_user.
  /// Si no existe → retorna los datos de Apple para pre-llenar el registro.
  Future<Map<String, dynamic>> loginClienteWithApple(BuildContext context) async {
    debugPrint('🍎 [Apple/Cliente] Iniciando login con Apple...');
    final idToken = await _getAppleIdToken();
    if (idToken == null) {
      debugPrint('🍎 [Apple/Cliente] ❌ identityToken nulo, login cancelado');
      throw Exception('Inicio de sesión cancelado');
    }
    debugPrint('🍎 [Apple/Cliente] Token obtenido, llamando backend: $baseUrl/auth/apple/cliente');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/apple/cliente'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    debugPrint('🍎 [Apple/Cliente] Respuesta backend: ${resp.statusCode}');
    debugPrint('🍎 [Apple/Cliente] Body: ${resp.body}');

    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    debugPrint('🍎 [Apple/Cliente] registered: ${data['registered']}');

    if (data['registered'] == true) {
      final accessToken = data['accessToken'] as String;
      final cliente = data['cliente'] as Map<String, dynamic>;
      final user = {...cliente, 'kind': 'CLIENTE'};
      await saveUserData(accessToken, user);
      final userId = user['_id']?.toString();
      debugPrint('🍎 [Apple/Cliente] ✅ Cliente existente, userId: $userId → navegando a /home_user');
      if (userId != null && userId.isNotEmpty) {
        myFirebaseService?.subscribeToTopic(userId);
        _guardarFcmToken(userId);
      }
      if (context.mounted) context.go('/home_user');
      return {'registered': true};
    }

    debugPrint('🍎 [Apple/Cliente] Cliente no registrado → redirigir a registro con datos: ${data['appleData']}');
    return {'registered': false, ...data['appleData'] as Map<String, dynamic>};
  }

  /// Para usuarios/empresa: solo permite si ya existe la cuenta en el sistema.
  Future<void> loginUsuarioWithApple(BuildContext context) async {
    debugPrint('🍎 [Apple/Usuario] Iniciando login con Apple...');
    final idToken = await _getAppleIdToken();
    if (idToken == null) {
      debugPrint('🍎 [Apple/Usuario] ❌ identityToken nulo, login cancelado');
      throw Exception('Inicio de sesión cancelado');
    }
    debugPrint('🍎 [Apple/Usuario] Token obtenido, llamando backend: $baseUrl/auth/apple/usuario');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/apple/usuario'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': idToken}),
    );

    debugPrint('🍎 [Apple/Usuario] Respuesta backend: ${resp.statusCode}');
    debugPrint('🍎 [Apple/Usuario] Body: ${resp.body}');

    if (resp.statusCode != 200) throw Exception(_serverErrorMessage(resp));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final user = data['user'] as Map<String, dynamic>;
    user['kind'] = 'USUARIO';

    final userId = user['_id']?.toString();
    final usuarioCreacion = user['usuarioCreacion']?.toString();
    debugPrint('🍎 [Apple/Usuario] ✅ Usuario autenticado, userId: $userId → navegando a /home');

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
  /// Inicia sesión con Google + Firebase y devuelve el Firebase ID Token y el
  /// correo (para validar el tipo de cuenta antes de entrar).
  Future<({String? idToken, String? email})> googleSignIn() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: Platform.isIOS
          ? '193436032832-vh14a827kih2btbbk9ck1t7ov8in9ovo.apps.googleusercontent.com'
          : null,
      serverClientId: '193436032832-fsvvca9fu0lqkacgmt1gc0dqef5ac44p.apps.googleusercontent.com',
    );
    await googleSignIn.signOut();
    final account = await googleSignIn.signIn();
    if (account == null) return (idToken: null, email: null);
    final googleAuth = await account.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCredential.user?.getIdToken(true);
    final email = userCredential.user?.email ?? account.email;
    return (idToken: firebaseIdToken, email: email);
  }

  /// Para clientes: si ya existe → navega a home_user y retorna `{'registered': true}`.
  /// Si no existe → retorna los datos de Google para pre-llenar el registro.
  /// [idToken] permite reusar un token ya obtenido (evita re-loguear en Google).
  Future<Map<String, dynamic>> loginClienteWithGoogle(BuildContext context,
      {String? idToken}) async {
    final token = idToken ?? (await googleSignIn()).idToken;
    if (token == null) throw Exception('Inicio de sesión cancelado');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google/cliente'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': token}),
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

    return {'registered': false, ...data['googleData'] as Map<String, dynamic>};
  }

  /// Para usuarios/empresa: solo permite si ya existe la cuenta en el sistema.
  Future<void> loginUsuarioWithGoogle(BuildContext context,
      {String? idToken}) async {
    final token = idToken ?? (await googleSignIn()).idToken;
    if (token == null) throw Exception('Inicio de sesión cancelado');

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/google/usuario'),
      headers: _jsonHeaders,
      body: jsonEncode({'idToken': token}),
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

  /// Consulta qué tipos de cuenta existen para un correo (login unificado).
  Future<({bool cliente, bool usuario})> checkAccountTypes(
      String correo) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/account-types'),
      headers: _jsonHeaders,
      body: jsonEncode({'correo': correo.trim()}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (
        cliente: data['cliente'] == true,
        usuario: data['usuario'] == true,
      );
    }
    throw Exception(_serverErrorMessage(resp));
  }

  /// Cambia a la cuenta "hermana" (mismo correo, otro tipo) con la sesión
  /// actual. El backend valida el token vigente y emite el token de la otra
  /// cuenta. Guarda la nueva sesión (y deja ambas registradas).
  Future<void> switchSibling() async {
    final token = await getToken();
    if (token == null) throw Exception('Sin sesión activa');
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/switch'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(_serverErrorMessage(resp));
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final newToken = data['accessToken'] as String?;
    final kind = (data['kind'] ?? 'USUARIO').toString();
    final raw = kind == 'CLIENTE' ? data['cliente'] : data['user'];
    if (newToken == null || raw is! Map) {
      throw Exception('Respuesta inválida del servidor');
    }
    final user = {...Map<String, dynamic>.from(raw), 'kind': kind};
    await saveUserData(newToken, user); // guarda + upsert (ambas quedan)
    final userId = user['_id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(userId);
    }
  }

  Future<void> saveUserData(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: jsonEncode(user));
    if (user['kind'] != null) {
      await _storage.write(key: 'kind', value: user['kind'].toString());
    }
    // Registra/actualiza la cuenta en el almacén multi-cuenta.
    await _upsertAccount(accessToken, user);
  }

  // ─────────────────────────── Multi-cuenta ───────────────────────────

  String _accountIdFor(Map<String, dynamic> user) {
    final kind = (user['kind'] ?? 'USUARIO').toString();
    final id =
        (user['_id'] ?? user['correo'] ?? user['email'] ?? '').toString();
    return '${kind}_$id';
  }

  String _displayNameFor(Map<String, dynamic> u) {
    final n = (u['nombres'] ?? u['nombre'] ?? '').toString().trim();
    final a = (u['apellidos'] ?? '').toString().trim();
    final full = '$n $a'.trim();
    if (full.isNotEmpty) return full;
    return (u['correo'] ?? u['email'] ?? 'Cuenta').toString();
  }

  Future<List<Map<String, dynamic>>> _readAccountsRaw() async {
    final raw = await _storage.read(key: _kAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _writeAccountsRaw(List<Map<String, dynamic>> accounts) async {
    await _storage.write(key: _kAccounts, value: jsonEncode(accounts));
  }

  Future<void> _upsertAccount(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    final id = _accountIdFor(user);
    final accounts = await _readAccountsRaw();
    final entry = <String, dynamic>{
      'id': id,
      'kind': (user['kind'] ?? 'USUARIO').toString(),
      'rol': (user['rol'] ?? '').toString(),
      'email': (user['correo'] ?? user['email'] ?? '').toString(),
      'displayName': _displayNameFor(user),
      'accessToken': accessToken,
      'user': user,
      'lastLogin': DateTime.now().toIso8601String(),
    };
    final idx = accounts.indexWhere((a) => a['id'] == id);
    if (idx >= 0) {
      accounts[idx] = entry;
    } else {
      accounts.add(entry);
    }
    await _writeAccountsRaw(accounts);
    await _storage.write(key: _kCurrentAccount, value: id);
  }

  /// Lista de cuentas guardadas (más reciente primero).
  Future<List<SavedAccount>> listAccounts() async {
    final raw = await _readAccountsRaw();
    final list = raw.map(SavedAccount.fromJson).toList();
    list.sort((a, b) => b.lastLogin.compareTo(a.lastLogin));
    return list;
  }

  Future<String?> currentAccountId() => _storage.read(key: _kCurrentAccount);

  /// Activa (sin red) la sesión de una cuenta guardada como la sesión actual.
  /// El llamador debería luego `renewToken()` para validar/refrescar.
  Future<bool> activateAccount(String id) async {
    final accounts = await _readAccountsRaw();
    final acc = accounts.firstWhere(
      (a) => a['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (acc.isEmpty) return false;
    final token = acc['accessToken']?.toString();
    final user = acc['user'];
    if (token == null || token.isEmpty || user is! Map) return false;

    final userMap = Map<String, dynamic>.from(user);
    await _storage.write(key: 'accessToken', value: token);
    await _storage.write(key: 'user', value: jsonEncode(userMap));
    await _storage.write(
        key: 'kind', value: (acc['kind'] ?? 'USUARIO').toString());
    await _storage.write(key: _kCurrentAccount, value: id);

    final userId = userMap['_id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      myFirebaseService?.subscribeToTopic(userId);
    }
    return true;
  }

  /// Elimina una cuenta de la lista de guardadas.
  Future<void> removeAccount(String id) async {
    final accounts = await _readAccountsRaw();
    accounts.removeWhere((a) => a['id'] == id);
    await _writeAccountsRaw(accounts);
  }

  Future<bool> hasSavedAccounts() async =>
      (await _readAccountsRaw()).isNotEmpty;

  Future<String?> getToken() => _storage.read(key: 'accessToken');

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: 'user');
    return raw != null ? jsonDecode(raw) : null;
  }

  Future<String?> getKind() => _storage.read(key: 'kind');

  /// Valida el token actual contra el back.
  ///
  /// Devuelve:
  /// - [TokenStatus.valid] si el back lo aceptó (y refrescó user+token en cache).
  /// - [TokenStatus.rejected] si el back lo rechazó (4xx / cuerpo vacío) →
  ///   el llamador debe hacer logout.
  /// - [TokenStatus.unreachable] si no hubo respuesta a tiempo (timeout, sin
  ///   red, 5xx). En este caso NO debemos hacer logout: la sesión sigue
  ///   válida y la app puede arrancar offline con datos cacheados.
  Future<TokenStatus> renewTokenStatus({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final token = await getToken();
    if (token == null) return TokenStatus.rejected;

    final uri = Uri.parse('$baseUrl/auth/refresh-token');

    try {
      final resp = await http
          .get(
            uri,
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
          )
          .timeout(timeout);

      if (resp.statusCode == 200) {
        try {
          final data = jsonDecode(resp.body);
          final newToken = data['token'];
          final user = data['user'];
          if (newToken == null || user == null) return TokenStatus.rejected;
          user['kind'] = user['kind'] ?? (await getKind()) ?? 'USUARIO';
          await saveUserData(newToken, user);
          return TokenStatus.valid;
        } catch (_) {
          return TokenStatus.rejected;
        }
      }
      // 4xx → token inválido → logout. 5xx → el back falla, no es culpa del
      // cliente: tratamos como unreachable para que el usuario entre igual.
      if (resp.statusCode >= 500) return TokenStatus.unreachable;
      return TokenStatus.rejected;
    } on TimeoutException {
      return TokenStatus.unreachable;
    } on SocketException {
      return TokenStatus.unreachable;
    } on http.ClientException {
      return TokenStatus.unreachable;
    } catch (_) {
      return TokenStatus.unreachable;
    }
  }

  /// Compatibilidad con código existente: true = válido, false = rechazado o
  /// sin red. Para distinguir esos dos casos usar [renewTokenStatus].
  Future<bool> renewToken() async {
    final status = await renewTokenStatus();
    return status == TokenStatus.valid;
  }

  /// Cierra la sesión activa.
  /// [keepSaved] = true mantiene la cuenta en la lista de cuentas guardadas
  /// (para reingreso rápido con biometría). false la elimina de la lista.
  /// La lista de OTRAS cuentas guardadas siempre se conserva.
  Future<void> logout({bool keepSaved = false}) async {
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

      if (!keepSaved) {
        final currentId = await currentAccountId();
        if (currentId != null) await removeAccount(currentId);
      }

      // Limpia solo la sesión ACTIVA; conserva la lista de cuentas guardadas.
      await _storage.delete(key: 'accessToken');
      await _storage.delete(key: 'user');
      await _storage.delete(key: 'kind');
      await _storage.delete(key: _kCurrentAccount);
      await _storage.delete(key: 'guest_mode');
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

  /// Cambia la foto de perfil del cliente (sube data URL base64 → S3 en backend).
  /// Devuelve la URL nueva y actualiza el storage local.
  Future<String?> updateAvatar(String fotoBase64) async {
    final token = await getToken();
    if (token == null) throw Exception('Sin sesión activa');
    final user = await getUser();
    final id = user?['_id'];
    if (id == null) throw Exception('Usuario no identificado');

    final resp = await http.put(
      Uri.parse('$baseUrl/clientes/me/$id'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({'fotoBase64': fotoBase64}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_serverErrorMessage(resp));
    }

    String? url;
    try {
      final data = jsonDecode(resp.body);
      if (data is Map) {
        url = (data['fotoUrl'] ?? data['avatarUrl'])?.toString();
      }
    } catch (_) {}

    if (user != null && url != null && url.isNotEmpty) {
      await saveUserData(token, {...user, 'fotoUrl': url, 'avatarUrl': url});
    }
    return url;
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
