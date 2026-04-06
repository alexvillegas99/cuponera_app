import 'package:enjoy/services/core/api_client.dart';

class SolicitudCuponeraService {
  static Future<bool> enviar(Map<String, dynamic> dto) async {
    try {
      final resp = await ApiClient.instance.post(
        '/solicitudes-cuponera',
        data: dto,
      );
      return resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> misSolicitudes(String clienteId) async {
    try {
      final resp = await ApiClient.instance.get('/solicitudes-cuponera/cliente/$clienteId');
      if (resp.statusCode == 200) return resp.data as List<dynamic>;
    } catch (_) {}
    return [];
  }
}
