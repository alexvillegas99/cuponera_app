import 'package:dio/dio.dart';
import 'package:enjoy/services/core/api_client.dart';

class PagosService {
  /// Extrae un mensaje legible de un error de Dio
  static String mensajeError(Object e, {String fallback = 'Ocurrió un error. Intenta de nuevo.'}) {
    if (e is DioException) {
      // Sin conexión / timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'La solicitud tardó demasiado. Verifica tu conexión.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Sin conexión a internet. Verifica tu red.';
      }

      final status = e.response?.statusCode;
      if (status == 401) return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      if (status == 503) return 'Servicio no disponible. Intenta más tarde.';
      if (status == 500) return 'Error en el servidor. Intenta más tarde.';

      // Mensaje del backend: { "message": "...", ... }
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) {
          // Quitar prefijos técnicos y JSON embebido
          final limpio = msg
              .replaceAll(RegExp(r'Error al crear transacción:\s*'), '')
              .replaceAll(RegExp(r'Error al crear orden PayPal:\s*'), '')
              .replaceAll(RegExp(r'\{.*\}', dotAll: true), '')
              .trim();
          if (limpio.isNotEmpty) return limpio;
        }
      }
    }
    return fallback;
  }

  /// Métodos de pago activos
  static Future<Map<String, bool>> metodosPago() async {
    try {
      final resp = await ApiClient.instance.get('/pagos/metodos');
      return {
        'payphone': resp.data['payphone'] == true || resp.data['payphone'].toString() == 'true',
        'paypal': resp.data['paypal'] == true || resp.data['paypal'].toString() == 'true',
      };
    } catch (_) {
      return {'payphone': false, 'paypal': false};
    }
  }

  /// Crear transacción PayPhone
  /// Inicia pago PayPhone — retorna { formularioUrl, clientTransactionId }
  static Future<Map<String, dynamic>> iniciarPayPhone({
    required String clienteId,
    required String nombreCliente,
    required String emailCliente,
    String? telefonoCliente,
    required String cuponeraNombre,
    required String cuponeraPrecio,
  }) async {
    final resp = await ApiClient.instance.post('/pagos/payphone/iniciar', data: {
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'emailCliente': emailCliente,
      'telefonoCliente': telefonoCliente ?? '',
      'cuponeraNombre': cuponeraNombre,
      'cuponeraPrecio': cuponeraPrecio,
    });
    return Map<String, dynamic>.from(resp.data);
  }

  /// Crear orden PayPal
  static Future<Map<String, dynamic>> crearPayPal({
    required String clienteId,
    required String nombreCliente,
    required String emailCliente,
    required String cuponeraNombre,
    required String cuponeraPrecio,
    required String returnUrl,
    required String cancelUrl,
  }) async {
    final resp = await ApiClient.instance.post('/pagos/paypal/crear', data: {
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'emailCliente': emailCliente,
      'cuponeraNombre': cuponeraNombre,
      'cuponeraPrecio': cuponeraPrecio,
      'returnUrl': returnUrl,
      'cancelUrl': cancelUrl,
    });
    return Map<String, dynamic>.from(resp.data);
  }

  /// Capturar pago PayPal
  static Future<Map<String, dynamic>> capturarPayPal(String orderId) async {
    final resp = await ApiClient.instance.post('/pagos/paypal/capturar/$orderId');
    return Map<String, dynamic>.from(resp.data);
  }

  /// Consultar estado de un pago
  static Future<Map<String, dynamic>> consultarEstado(String clientTransactionId) async {
    final resp = await ApiClient.instance.get('/pagos/estado/$clientTransactionId');
    return Map<String, dynamic>.from(resp.data);
  }
}
