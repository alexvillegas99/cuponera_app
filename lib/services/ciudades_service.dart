// lib/services/ciudades_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/ciudad.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CiudadesService {
  final String base = dotenv.env['API_URL'] ?? '';

 Future<List<Ciudad>> getParaPromos() async {
  final uri = Uri.parse('$base/ciudades/promociones');

  debugPrint('🌐 [GET] $uri');

  try {
    final resp = await http.get(uri, headers: {'accept': '*/*'});

    debugPrint('📡 [STATUS] ${resp.statusCode}');
    debugPrint('📦 [BODY] ${resp.body}');

    if (resp.statusCode != 200) {
      debugPrint('❌ Error en respuesta');
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }

    final List data = jsonDecode(resp.body) as List;

    debugPrint('✅ [PARSE] ciudades recibidas: ${data.length}');

    final ciudades = data
        .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
        .toList();

    debugPrint('🏙️ [MAP] ciudades mapeadas: ${ciudades.length}');

    return ciudades;
  } catch (e, st) {
    debugPrint('🔥 [ERROR] getParaPromos -> $e');
    debugPrint('$st');
    rethrow;
  }
}
}
