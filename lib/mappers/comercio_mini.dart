class PromoPrincipal {
  final String? id;
  final String? title;
  final String? placeName;
  final String? description;
  final String? imageUrl;
  final String? logoUrl;
  final bool? isTwoForOne;
  final List<String> tags;
  final double? rating;
  final String? scheduleLabel;
  final String? distanceLabel;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isFlash;
  final String? address;
  final bool? aplicaTodosLosDias;
  final List<String> fechasExcluidas;
   final String? telefono;    

  PromoPrincipal({
    required this.id,
    required this.title,
    required this.placeName,
    required this.description,
    required this.imageUrl,
    required this.logoUrl,
    required this.isTwoForOne,
    required this.tags,
    required this.rating,
    required this.scheduleLabel,
    required this.distanceLabel,
    required this.startDate,
    required this.endDate,
    required this.isFlash,
    required this.address,
    required this.aplicaTodosLosDias, 
    required this.fechasExcluidas,
        this.telefono, 
  });

  factory PromoPrincipal.fromJson(Map<String, dynamic> j) => PromoPrincipal(
    id: j['id']?.toString(),
    title: j['title']?.toString(),
    placeName: j['placeName']?.toString(),
    description: j['description']?.toString(),
    imageUrl: j['imageUrl']?.toString(),
    logoUrl: j['logoUrl']?.toString(),
    isTwoForOne: j['isTwoForOne'] as bool?,
    tags: ((j['tags'] as List?) ?? const []).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList(),
    rating: j['rating'] == null ? null : (j['rating'] as num).toDouble(),
    scheduleLabel: j['scheduleLabel']?.toString(),
    distanceLabel: j['distanceLabel']?.toString(),
    startDate: _d(j['startDate']),
    endDate: _d(j['endDate']),
    isFlash: j['isFlash'] as bool?,
    address: j['address']?.toString(),
      telefono: j['telefono']?.toString(), 
    aplicaTodosLosDias: j['aplicaTodosLosDias'] as bool?,
    fechasExcluidas: ((j['fechasExcluidas'] as List?) ?? const []).map((e) => e?.toString() ?? '').toList(),
  );
}

class ComentarioMini {
  final String? autorNombre;
  final String? texto;
  final double? rating;
  final DateTime? fecha;

  ComentarioMini({this.autorNombre, this.texto, this.rating, this.fecha});

  factory ComentarioMini.fromJson(Map<String, dynamic> j) => ComentarioMini(
    autorNombre: j['autorNombre']?.toString(),
    texto: j['texto']?.toString(),
    rating: j['rating'] == null ? null : (j['rating'] as num).toDouble(),
    fecha: _d(j['fecha']),
  );
}

class ComercioMini {
  final PromoPrincipal? promoPrincipal;
  final List<String> ciudades;
  final List<String> categorias;
  final double promedioCalificacion;
  final int totalComentarios;
  final String? telefono;                 // 👈 AÑADIR
  final List<ComentarioMini> comentarios;

  ComercioMini({
    required this.promoPrincipal,
    required this.ciudades,
    required this.categorias,
    required this.promedioCalificacion,
    required this.totalComentarios,
    required this.comentarios,
    this.telefono,                        // 👈 AÑADIR
  });

  factory ComercioMini.fromJson(Map<String, dynamic> j) => ComercioMini(
        promoPrincipal: j['promoPrincipal'] == null
            ? null
            : PromoPrincipal.fromJson(j['promoPrincipal']),
        ciudades: ((j['ciudades'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
        categorias: ((j['categorias'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
        promedioCalificacion: (j['promedioCalificacion'] ?? 0).toDouble(),
        totalComentarios: (j['totalComentarios'] ?? 0) as int,
        telefono: j['telefono']?.toString(),        // 👈 AÑADIR
        comentarios: ((j['comentarios'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ComentarioMini.fromJson)
            .toList(),
      );
}

DateTime? _d(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
