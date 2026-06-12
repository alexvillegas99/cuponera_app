import 'package:enjoy/services/core/api_client.dart';

class RangoFechas {
  final String? desde;
  final String? hasta;
  const RangoFechas({this.desde, this.hasta});

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (desde != null && desde!.isNotEmpty) q['desde'] = desde;
    if (hasta != null && hasta!.isNotEmpty) q['hasta'] = hasta;
    return q;
  }
}

class ReportesService {
  Future<Map<String, dynamic>> canjes(
    RangoFechas r, {
    String granularidad = 'dia',
  }) async {
    final params = {...r.toQuery(), 'granularidad': granularidad};
    final resp = await ApiClient.instance
        .get('/reportes/canjes', queryParameters: params);
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> ingresos(RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/ingresos', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> locales(RangoFechas r, {int limit = 25}) async {
    final params = {...r.toQuery(), 'limit': limit};
    final resp = await ApiClient.instance
        .get('/reportes/locales', queryParameters: params);
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> vendedores(RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/vendedores', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> creador(String id, RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/creador/$id', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> clientes(RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/clientes', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> flash(RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/flash', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> solicitudes(RangoFechas r) async {
    final resp = await ApiClient.instance
        .get('/reportes/solicitudes', queryParameters: r.toQuery());
    return Map<String, dynamic>.from(resp.data);
  }
}
