// lib/models/ciudad.dart
class Ciudad {
  final String id;
  final String nombre;
  final bool estado;
  final bool visibleParaRegistro;
  final String? provinciaId;
  final String? provinciaNombre;
  final double? lat;
  final double? lng;

  const Ciudad({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.visibleParaRegistro,
    this.provinciaId,
    this.provinciaNombre,
    this.lat,
    this.lng,
  });

  factory Ciudad.fromJson(Map<String, dynamic> j) {
    // provincia puede venir como id (string) o como objeto poblado {_id, nombre}
    final prov = j['provincia'];
    String? provId;
    String? provNombre;
    if (prov is Map) {
      provId = prov['_id']?.toString();
      provNombre = prov['nombre']?.toString();
    } else if (prov != null) {
      provId = prov.toString();
    }
    final geo = j['geo'];
    return Ciudad(
      id: j['_id'] as String,
      nombre: j['nombre'] as String? ?? '',
      estado: j['estado'] as bool? ?? false,
      visibleParaRegistro: j['visibleParaRegistro'] as bool? ?? false,
      provinciaId: provId,
      provinciaNombre: provNombre,
      lat: geo is Map ? (geo['lat'] as num?)?.toDouble() : null,
      lng: geo is Map ? (geo['lng'] as num?)?.toDouble() : null,
    );
  }
}
