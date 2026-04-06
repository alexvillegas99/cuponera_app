import 'package:enjoy/services/core/api_client.dart';

class PagosService {
  /// Métodos de pago activos
  static Future<Map<String, bool>> metodosPago() async {
    try {
      final resp = await ApiClient.instance.get('/pagos/metodos');
      return {
        'payphone': resp.data['payphone'] == true,
        'paypal': resp.data['paypal'] == true,
      };
    } catch (_) {
      return {'payphone': false, 'paypal': false};
    }
  }

  /// Crear transacción PayPhone
  static Future<Map<String, dynamic>> crearPayPhone({
    required String clienteId,
    required String nombreCliente,
    required String emailCliente,
    String? telefonoCliente,
    required String cuponeraNombre,
    required String cuponeraPrecio,
    required String responseUrl,
    required String cancellationUrl,
  }) async {
    final resp = await ApiClient.instance.post('/pagos/payphone/crear', data: {
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'emailCliente': emailCliente,
      'telefonoCliente': telefonoCliente ?? '',
      'cuponeraNombre': cuponeraNombre,
      'cuponeraPrecio': cuponeraPrecio,
      'responseUrl': responseUrl,
      'cancellationUrl': cancellationUrl,
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
