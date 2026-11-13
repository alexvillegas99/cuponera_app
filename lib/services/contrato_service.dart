import 'package:enjoy/services/core/api_client.dart';

class ContratoEstado {
  final bool aceptado;
  final String? contratoUrl;
  final String? cedulaUrl;
  final String? contratoVersion;
  final String? contratoAceptadoEn;
  final List<String> datosFaltantes;
  final int omisionesUsadas;
  final int omisionesRestantes;
  final Map<String, dynamic> datosLocal;

  ContratoEstado({
    required this.aceptado,
    this.contratoUrl,
    this.cedulaUrl,
    this.contratoVersion,
    this.contratoAceptadoEn,
    this.datosFaltantes = const [],
    this.omisionesUsadas = 0,
    this.omisionesRestantes = 0,
    this.datosLocal = const {},
  });

  factory ContratoEstado.fromJson(Map<String, dynamic> j) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

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
      omisionesUsadas: parseInt(j['omisionesUsadas']),
      omisionesRestantes: parseInt(j['omisionesRestantes']),
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

  /// Pide al back que genere un OTP y lo envíe por email.
  /// Devuelve `{email, expiraEn}` (email enmascarado).
  Future<Map<String, String>> solicitarOtp() async {
    final resp = await ApiClient.instance.post('/contratos/solicitar-otp');
    final m = Map<String, dynamic>.from(resp.data);
    return {
      'email': (m['email'] ?? '').toString(),
      'expiraEn': (m['expiraEn'] ?? '').toString(),
    };
  }

  /// Registra que el admin-local pulsó "Omitir por ahora". Devuelve el nuevo
  /// contador (`omisionesUsadas`) y las que le quedan (`omisionesRestantes`).
  Future<Map<String, int>> omitir() async {
    final resp = await ApiClient.instance.post('/contratos/omitir');
    final m = Map<String, dynamic>.from(resp.data);
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return {
      'omisionesUsadas': parseInt(m['omisionesUsadas']),
      'omisionesRestantes': parseInt(m['omisionesRestantes']),
    };
  }

  Future<Map<String, String>> aceptar({
    required String cedulaBase64,
    String? selfieBase64,
    required Map<String, String?> datosLocal,
    required bool aceptaTerminos,
    required String otp,
  }) async {
    final resp = await ApiClient.instance.post('/contratos/aceptar', data: {
      'cedulaBase64': cedulaBase64,
      if (selfieBase64 != null) 'selfieBase64': selfieBase64,
      'datosLocal': datosLocal,
      'aceptaTerminos': aceptaTerminos,
      'otp': otp,
    });
    final m = Map<String, dynamic>.from(resp.data);
    return {
      'contratoUrl': (m['contratoUrl'] ?? '').toString(),
      'cedulaUrl': (m['cedulaUrl'] ?? '').toString(),
    };
  }
}
