// lib/models/ciudad.dart
class Ciudad {
  final String id;
  final String nombre;
  final bool estado;
  final bool visibleParaRegistro;

  const Ciudad({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.visibleParaRegistro,
  });

  factory Ciudad.fromJson(Map<String, dynamic> j) => Ciudad(
        id: j['_id'] as String,
        nombre: j['nombre'] as String? ?? '',
        estado: j['estado'] as bool? ?? false,
        visibleParaRegistro: j['visibleParaRegistro'] as bool? ?? false,
      );
}
