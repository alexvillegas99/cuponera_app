import 'package:flutter/foundation.dart';

class Promotion {
  /// ✅ Este es el ObjectId del negocio/Usuario (24 hex) que usa favoritos
  final String id;

  /// Solo para debug/mostrar si te sirve (id “humano” del detalle)
  final String? detailId;

  final bool? isFavorite;
  final String city;
  final String title;
  final String placeName;
  final String description;
  final String imageUrl;
  final String logoUrl;
  final bool isTwoForOne;
  final List<String> categories;
  final List<String> tags;
  final double rating;
  final String scheduleLabel;
  final String distanceLabel;
  final String? address;
  final DateTime startDate;
  final DateTime endDate;
  final bool isFlash;

  final bool? aplicaTodosLosDias;
  final List<String>? diasAplicables;
  final Map<String, dynamic>? horarioPorDia;
  final List<DateTime>? fechasExcluidas;

  const Promotion({
    required this.id,
    this.detailId,
    this.isFavorite,
    required this.city,
    required this.title,
    required this.placeName,
    required this.description,
    required this.imageUrl,
    required this.logoUrl,
    required this.isTwoForOne,
    required this.categories,
    required this.tags,
    required this.rating,
    required this.scheduleLabel,
    required this.distanceLabel,
    required this.startDate,
    required this.endDate,
    required this.isFlash,
    this.address,
    this.aplicaTodosLosDias,
    this.diasAplicables,
    this.horarioPorDia,
    this.fechasExcluidas,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) {
    final d = (j['detallePromocion'] as Map?) ?? const {};

    // ⚠️ NUNCA caer al 'id' del detalle como backend id
    final rootId = j['_id']?.toString() ?? '';
    if (rootId.length != 24) {
      debugPrint('[PROMO][ERROR] _id inválido o ausente en JSON: $j');
    }

    // En tu JSON real viene "ciudades": ["Ambato"]
    final city = (j['ciudad'] ??
            ((j['ciudades'] is List && (j['ciudades'] as List).isNotEmpty)
                ? (j['ciudades'] as List).first.toString()
                : ''))
        .toString();

    return Promotion(
      id: rootId,                                   // ✅ usa SIEMPRE _id
      detailId: (d['id'] as String?),               // “4”, “5”, …
      isFavorite: (j['isFavorite'] as bool?) ?? false,
      city: city,
      title: (d['title'] ?? '') as String,
      placeName: (d['placeName'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      imageUrl: (d['imageUrl'] ?? '') as String,
      logoUrl: (d['logoUrl'] ?? '') as String,
      isTwoForOne: (d['isTwoForOne'] ?? false) as bool,
      categories: (j['categorias'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      tags: (d['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      rating: (d['rating'] is num) ? (d['rating'] as num).toDouble() : 0,
      scheduleLabel: (d['scheduleLabel'] ?? '') as String,
      distanceLabel: (d['distanceLabel'] ?? '') as String,
      address: d['address'] as String?,
      startDate: DateTime.tryParse(d['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(d['endDate'] ?? '') ?? DateTime.now(),
      isFlash: (d['isFlash'] ?? false) as bool,
      aplicaTodosLosDias: d['aplicaTodosLosDias'] as bool?,
      diasAplicables: (d['diasAplicables'] as List?)?.map((e) => e.toString()).toList(),
      horarioPorDia: d['horarioPorDia'] as Map<String, dynamic>?,
      fechasExcluidas: (d['fechasExcluidas'] as List?)
          ?.map((e) => DateTime.tryParse(e.toString())!)
          .whereType<DateTime>()
          .toList(),
    );
  }

  bool get hasValidBackendId => RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);


  /// === Helpers de fecha (solo día) ===
  DateTime _dOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;





  bool appliesTodaySimple([DateTime? when]) {
    final now = when ?? DateTime.now();
    final dow = _weekdayEs(now.weekday); // "lunes", "martes", ...

    // 1) Si aplica a todos los días -> true
    if (aplicaTodosLosDias == true) return true;

    // 2) Si la lista de días contiene el día de hoy -> true
    final dias = (diasAplicables ?? const [])
        .map((e) => e.toString().toLowerCase().trim())
        .toSet();

    return dias.contains(dow);
  }

  /// Día de la semana en español (minúsculas)
  String _weekdayEs(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'lunes';
      case DateTime.tuesday: return 'martes';
      case DateTime.wednesday: return 'miercoles';
      case DateTime.thursday: return 'jueves';
      case DateTime.friday: return 'viernes';
      case DateTime.saturday: return 'sabado';
      case DateTime.sunday: return 'domingo';
    }
    return 'lunes';
  }
}
