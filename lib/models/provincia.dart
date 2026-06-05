/// Provincia del Ecuador (catálogo).
class Provincia {
  final String id;
  final String nombre;
  final String? codigo;
  final bool estado;

  const Provincia({
    required this.id,
    required this.nombre,
    this.codigo,
    this.estado = true,
  });

  factory Provincia.fromJson(Map<String, dynamic> j) => Provincia(
        id: (j['_id'] ?? '').toString(),
        nombre: (j['nombre'] ?? '').toString(),
        codigo: j['codigo']?.toString(),
        estado: j['estado'] as bool? ?? true,
      );

  static List<Provincia> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Provincia.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }
}
