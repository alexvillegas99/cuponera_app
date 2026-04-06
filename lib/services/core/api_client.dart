import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cliente HTTP centralizado con interceptores de auth y manejo de 401.
///
/// Uso en servicios:
/// ```dart
/// final response = await ApiClient.instance.get('/cupones/...');
/// ```
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Callback global para cerrar sesión (se configura desde main/app)
  static VoidCallback? onSessionExpired;

  ApiClient._internal() {
    final baseUrl = dotenv.env['API_URL'] ?? '';

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Interceptor de autenticación
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[ApiClient] 401 - Sesión expirada');
          await _clearSession();
          onSessionExpired?.call();
        }
        handler.next(error);
      },
    ));
  }

  Future<void> _clearSession() async {
    await _storage.deleteAll();
  }

  // Atajos para los métodos HTTP más comunes
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return dio.patch(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }
}
