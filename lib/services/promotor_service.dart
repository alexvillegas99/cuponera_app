import 'package:enjoy/services/core/api_client.dart';

/// Resultado del cálculo del descuento por código de promotor.
class DescuentoPromotor {
  final String promotorId;
  final String promotorNombre;
  final double porcentajeDescuento;
  final double porcentajeComision;
  final double montoOriginal;
  final double montoDescuento;
  final double montoComision;
  final double montoFinal;

  DescuentoPromotor({
    required this.promotorId,
    required this.promotorNombre,
    required this.porcentajeDescuento,
    required this.porcentajeComision,
    required this.montoOriginal,
    required this.montoDescuento,
    required this.montoComision,
    required this.montoFinal,
  });

  factory DescuentoPromotor.fromJson(Map<String, dynamic> j) {
    double asD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return DescuentoPromotor(
      promotorId: (j['promotorId'] ?? '').toString(),
      promotorNombre: (j['promotorNombre'] ?? '').toString(),
      porcentajeDescuento: asD(j['porcentajeDescuento']),
      porcentajeComision: asD(j['porcentajeComision']),
      montoOriginal: asD(j['montoOriginal']),
      montoDescuento: asD(j['montoDescuento']),
      montoComision: asD(j['montoComision']),
      montoFinal: asD(j['montoFinal']),
    );
  }
}

/// Stats que ve el cliente promotor en su propio perfil.
class PromotorStats {
  final bool isPromotor;
  final String? codigoDescuento;
  final double porcentajeDescuento;
  final double porcentajeComision;
  final double saldoPromotor;

  PromotorStats({
    required this.isPromotor,
    this.codigoDescuento,
    required this.porcentajeDescuento,
    required this.porcentajeComision,
    required this.saldoPromotor,
  });

  factory PromotorStats.fromJson(Map<String, dynamic> j) {
    double asD(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return PromotorStats(
      isPromotor: j['isPromotor'] == true,
      codigoDescuento: j['codigoDescuento']?.toString(),
      porcentajeDescuento: asD(j['porcentajeDescuento']),
      porcentajeComision: asD(j['porcentajeComision']),
      saldoPromotor: asD(j['saldoPromotor']),
    );
  }
}

class PromotorService {
  /// Valida un código de promotor. Si pasás [monto] devuelve el desglose
  /// completo (descuento, comisión, montoFinal). Si no, solo valida que el
  /// código exista.
  Future<DescuentoPromotor> calcularDescuento({
    required String codigo,
    required double monto,
  }) async {
    final resp = await ApiClient.instance.post(
      '/clientes/promotor/validar-codigo',
      data: {'codigo': codigo, 'monto': monto},
    );
    return DescuentoPromotor.fromJson(Map<String, dynamic>.from(resp.data));
  }

  /// Stats del cliente promotor actual (saldo, código, % overrides).
  Future<PromotorStats> misStats() async {
    final resp = await ApiClient.instance.get('/clientes/me/promotor/stats');
    return PromotorStats.fromJson(Map<String, dynamic>.from(resp.data));
  }
}
