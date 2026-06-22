import 'package:enjoy/services/core/api_client.dart';

class ContratoEstado {
  final bool aceptado;
  final String? contratoUrl;
  final String? cedulaUrl;
  final String? contratoVersion;
  final String? contratoAceptadoEn;
  final List<String> datosFaltantes;
  final Map<String, dynamic> datosLocal;

  ContratoEstado({
    required this.aceptado,
    this.contratoUrl,
    this.cedulaUrl,
    this.contratoVersion,
    this.contratoAceptadoEn,
    this.datosFaltantes = const [],
    this.datosLocal = const {},
  });

  factory ContratoEstado.fromJson(Map<String, dynamic> j) {
    return ContratoEstado(
      aceptado: j['aceptado'] == true,
      contratoUrl: j['contratoUrl']?.toString(),
      cedulaUrl: j['cedulaUrl']?.toString(),
      contratoVersion: j['contratoVersion']?.toString(),
      contratoAceptadoEn: j['contratoAceptadoEn']?.toString(),
      datosFaltantes: (j['datosFaltantes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      datosLocal: j['datosLocal'] is Map
          ? Map<String, dynamic>.from(j['datosLocal'])
          : const {},
    );
  }
}

class ContratoService {
  Future<ContratoEstado> miEstado() async {
    final resp = await ApiClient.instance.get('/contratos/mi-estado');
    return ContratoEstado.fromJson(Map<String, dynamic>.from(resp.data));
  }

  Future<Map<String, String>> aceptar({
    required String cedulaBase64,
    required Map<String, String?> datosLocal,
    required bool aceptaTerminos,
  }) async {
    final resp = await ApiClient.instance.post('/contratos/aceptar', data: {
      'cedulaBase64': cedulaBase64,
      'datosLocal': datosLocal,
      'aceptaTerminos': aceptaTerminos,
    });
    final m = Map<String, dynamic>.from(resp.data);
    return {
      'contratoUrl': (m['contratoUrl'] ?? '').toString(),
      'cedulaUrl': (m['cedulaUrl'] ?? '').toString(),
    };
  }
}
