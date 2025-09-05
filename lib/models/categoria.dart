// lib/models/categoria.dart
class Categoria {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? icono;

  Categoria({required this.id, required this.nombre, this.descripcion, this.icono});

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
    id: j['_id'] as String,
    nombre: j['nombre'] as String,
    descripcion: j['descripcion'] as String?,
    icono: j['icono'] as String?,
  );
}
