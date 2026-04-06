// lib/services/compartidos_service.dart
import 'package:enjoy/services/core/api_client.dart';

enum CanalCompartir { whatsapp, sistema }

class CompartidosService {
  Future<void> registrar({
    required String clienteId,  // tu id de cliente logueado
    required String usuarioId,  // el admin-local del comercio
    required CanalCompartir canal,
    String? telefonoDestino,
    String? mensaje,
    String? origen,             // 'comercio' | 'cupon'
    String? origenId,
  }) async {
    final body = {
      'clienteId': clienteId,
      'usuarioId': usuarioId,
      'canal': canal.name,
      if (telefonoDestino != null && telefonoDestino.isNotEmpty) 'telefonoDestino': telefonoDestino,
      if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
      if (origen != null) 'origen': origen,
      if (origenId != null) 'origenId': origenId,
    };

    await ApiClient.instance.post('/compartidos', data: body);
  }
}
