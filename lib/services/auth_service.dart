import 'package:enjoy/services/my_firebase_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final url = dotenv.env['API_URL'] ?? ''; // Reemplaza con tu URL

  // Función para iniciar sesión
  Future<void> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    final url = Uri.parse('${this.url}/auth/login');

    try {
      final response = await http.post(
        url,
        body: {'correo': email, 'clave': password},
      );
      print('Respuesta del servidor: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final accessToken = responseData['accessToken'];
        final user = responseData['user'];
        final role = user['rol'] ?? 'user';

        await saveUserData(accessToken, user);
        // await MyFirebaseMessagingService().subscribeToTopicNuevo(user['_id']);

        context.go('/home');
      } else {
        throw Exception('Correo o contraseña incorrectos');
      }
    } catch (e) {
      print('Error al iniciar sesión: $e');
      throw Exception('Error de conexión o datos inválidos');
    }
  }

  // Guardar el token y los datos del usuario
  Future<void> saveUserData(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: json.encode(user));

    // Verificar si los datos se guardaron correctamente
    final savedToken = await _storage.read(key: 'accessToken');
    final savedUser = await _storage.read(key: 'user');

    print('Token guardado: $savedToken');
    print('Usuario guardado: $savedUser');
  }

  // Obtener el token guardado
  Future<String?> getToken() async {
    return await _storage.read(key: 'accessToken');
  }

  // Obtener los datos del usuario guardados
  Future<Map<String, dynamic>?> getUser() async {
    final userString = await _storage.read(key: 'user');
    print('usuario guardado $userString');
    if (userString != null) {
      return json.decode(userString);
    }
    return null;
  }

  // Renovar el token
  Future<bool> renewToken() async {
    final token = await getToken();

    if (token == null) {
      return false; // No hay token guardado
    }

    final url = Uri.parse(
      '${this.url}/auth/refresh-token',
    ); // Reemplaza con tu URL
    print(url);
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // Envía el token actual
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newToken = responseData['token'];
        final user = responseData['user'];

        // Guardar el nuevo token y los datos del usuario
        await saveUserData(newToken, user);

        print('Token renovado: $newToken');
        print('Usuario actualizado: $user');

        return true; // Token renovado exitosamente
      } else {
        print('Error al renovar el token: ${response.statusCode}');
        print('Respuesta del servidor: ${response.body}');
        return false; // Error al renovar el token
      }
    } catch (e) {
      print('Error en la solicitud: $e');
      return false; // Error de red u otro error
    }
  }

  // Verificar si el usuario está autenticado
  /*   Future<bool> isUserAuthenticated() async {
    final token = await getToken();
    print('Token actualllllllllllllllllll: $token');
    if (token == null) {
      return false; // No hay token guardado
    }

    // Verificar si el token es válido (puedes hacer una solicitud al servidor)
    final url =
        Uri.parse('${this.url}/auth/refresh-token'); // Reemplaza con tu URL
    print(url);
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print('Respuesta del servidor: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final accessToken = responseData['token'];
        final user = responseData['user'];

        // Guardar en Secure Storage
        await saveUserData(accessToken, user);
        return true; // Token válido
        //ActualizarToken
      } else {
        return false; // Token inválido o caducado
      }
    } catch (e) {
      print('Error al validar el token: $e');
      return false; // Error de red u otro error
    }
  }
 */
  // Eliminar los datos de autenticación (logout)
  Future<void> logout() async {
    final user = await getUser();
    final userId = user!['_id'];

    await MyFirebaseMessagingService().unsubscribeFromTopicNuevo(userId);
    print('Eliminando datos de autenticación...');
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'user');
    print('Datos de autenticación eliminados');
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'accessToken');
    return token != null; // Retorna true si hay un token, false si no
  }
}
