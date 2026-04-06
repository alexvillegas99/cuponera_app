// lib/services/ciudades_service.dart
import 'package:flutter/material.dart';
import 'package:enjoy/services/core/api_client.dart';
import '../models/ciudad.dart';

class CiudadesService {
 Future<List<Ciudad>> getParaPromos() async {
  final path = '/ciudades/promociones';

  debugPrint('🌐 [GET] $path');

  try {
    final resp = await ApiClient.instance.get(path);

    debugPrint('📡 [STATUS] ${resp.statusCode}');
    debugPrint('📦 [BODY] ${resp.data}');

    if (resp.statusCode != 200) {
      debugPrint('❌ Error en respuesta');
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    }

    final List data = resp.data as List;

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
