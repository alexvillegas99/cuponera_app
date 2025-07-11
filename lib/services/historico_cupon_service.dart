import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistoricoCuponService {
  final String _baseUrl = dotenv.env['API_URL'] ?? '';

  /// POST /historico
  Future<Map<String, dynamic>> registrarEscaneo(
    Map<String, dynamic> dto,
  ) async {
    final url = Uri.parse('$_baseUrl/historico');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al registrar escaneo: ${response.body}');
    }
  }

  /// GET /historico
  Future<List<dynamic>> obtenerHistorialCompleto() async {
    final url = Uri.parse('$_baseUrl/historico');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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
    final queryParams = {
      'inicio': inicio.toIso8601String(),
      'fin': fin.toIso8601String(),
      if (secuencial != null) 'secuencial': secuencial.toString(),
    };

    final uri = Uri.parse(
      '$_baseUrl/historico/buscar-por-fechas',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se encontraron registros en ese rango de fechas');
    }
  }

  /// GET /historico/get/usuario/:id
  Future<List<dynamic>> obtenerPorUsuario(String id) async {
    final url = Uri.parse('$_baseUrl/historico/get/usuario/$id');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se encontraron cupones para el usuario $id');
    }
  }

  Future<List<Map<String, dynamic>>> buscarDashboardPorUsuarioYFechas({
    required String id,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final url = Uri.parse('$_baseUrl/historico/usuario/fechas/dashboard');
    print('URL: $url');
    final body = jsonEncode({
      'id': id,
      'fechaInicio': fechaInicio.toIso8601String().split('T')[0],
      'fechaFin': fechaFin.toIso8601String().split('T')[0],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    print('Response status: ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('No se encontraron datos para ese rango');
    }
  }

  /// POST /historico/validar/cupon/registro
  Future<Map<String, dynamic>> validarCuponPorId({
    required String id,
    required String usuarioId,
  }) async {
    final url = Uri.parse('$_baseUrl/historico/validar/cupon/registro');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'usuarioId': usuarioId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'No se pudo validar el cupón: ${response.statusCode} - ${response.body}',
      );
    }
  }

  
}
