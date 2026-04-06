import 'package:enjoy/services/core/api_client.dart';

class HistoricoCuponService {
  /// POST /historico
  Future<Map<String, dynamic>> registrarEscaneo(
    Map<String, dynamic> dto,
  ) async {
    final resp = await ApiClient.instance.post('/historico', data: dto);

    if (resp.statusCode == 201) {
      return resp.data as Map<String, dynamic>;
    } else {
      throw Exception('Error al registrar escaneo: ${resp.data}');
    }
  }

  /// GET /historico
  Future<List<dynamic>> obtenerHistorialCompleto() async {
    final resp = await ApiClient.instance.get('/historico');

    if (resp.statusCode == 200) {
      return resp.data as List<dynamic>;
    } else {
      throw Exception('Error al obtener historial');
    }
  }

  /// GET /historico/buscar-por-fechas?inicio=YYYY-MM-DD&fin=YYYY-MM-DD&secuencial=123
  Future<List<dynamic>> buscarPorFechas({
    required DateTime inicio,
    required DateTime fin,
    int? secuencial,
  }) async {
    final queryParams = <String, dynamic>{
      'inicio': inicio.toIso8601String(),
      'fin': fin.toIso8601String(),
      if (secuencial != null) 'secuencial': secuencial.toString(),
    };

    final resp = await ApiClient.instance.get(
      '/historico/buscar-por-fechas',
      queryParameters: queryParams,
    );

    if (resp.statusCode == 200) {
      return resp.data as List<dynamic>;
    } else {
      throw Exception('No se encontraron registros en ese rango de fechas');
    }
  }

  /// GET /historico/get/usuario/:id
  Future<List<dynamic>> obtenerPorUsuario(String id) async {
    final resp = await ApiClient.instance.get('/historico/get/usuario/$id');

    if (resp.statusCode == 200) {
      return resp.data as List<dynamic>;
    } else {
      throw Exception('No se encontraron cupones para el usuario $id');
    }
  }

  Future<List<Map<String, dynamic>>> buscarDashboardPorUsuarioYFechas({
    required String id,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final path = '/historico/usuario/fechas/dashboard';
    print('URL: $path');
    final body = {
      'id': id,
      'fechaInicio': fechaInicio.toIso8601String().split('T')[0],
      'fechaFin': fechaFin.toIso8601String().split('T')[0],
    };

    final resp = await ApiClient.instance.post(path, data: body);
    print('Response status: ${resp.statusCode}');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    } else {
      throw Exception('No se encontraron datos para ese rango');
    }
  }

  /// POST /historico/validar/cupon/registro
  Future<Map<String, dynamic>> validarCuponPorId({
    required String id,
    required String usuarioId,
  }) async {
    final path = '/historico/validar/cupon/registro';
    print('url validar $path');
    final resp = await ApiClient.instance.post(
      path,
      data: {'id': id, 'usuarioId': usuarioId},
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return resp.data as Map<String, dynamic>;
    } else {
      throw Exception(
        'No se pudo validar el cupón: ${resp.statusCode} - ${resp.data}',
      );
    }
  }


}
