// lib/services/ciudades_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ciudad.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CiudadesService {
  final String base = dotenv.env['API_URL'] ?? '';

  Future<List<Ciudad>> getParaPromos() async {
    final uri = Uri.parse('$base/ciudades/ciudades/filtro/promociones');
    final resp = await http.get(uri, headers: {'accept': '*/*'});

    if (resp.statusCode != 200) {
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }
    final List data = jsonDecode(resp.body) as List;
    return data.map((e) => Ciudad.fromJson(e as Map<String, dynamic>)).toList();
  }
}
