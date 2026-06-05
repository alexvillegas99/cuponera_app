/// Item del catálogo del local: un producto/servicio que ofrece.
/// Genérico (no solo comida): foto + nombre + descripción.
class Producto {
  final String url;
  final String nombre;
  final String? descripcion;

  const Producto({
    required this.url,
    required this.nombre,
    this.descripcion,
  });

  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
        url: (j['url'] ?? '').toString(),
        nombre: (j['nombre'] ?? '').toString(),
        descripcion: j['descripcion']?.toString(),
      );

  /// Parsea una lista cruda de productos desde un subdocumento (detallePromocion).
  static List<Producto> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Producto.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.url.isNotEmpty)
        .toList();
  }
}
