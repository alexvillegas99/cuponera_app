// lib/utils/map_backend_promos.dart
import '../models/promotion_models.dart';

List<String> _safeStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

String _safeStr(dynamic v, [String def = '']) =>
    v == null ? def : v.toString();

double _safeDouble(dynamic v, [double def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? def;
}

bool _safeBool(dynamic v, [bool def = false]) {
  if (v == null) return def;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

List<DateTime> _parseDateList(dynamic v) {
  if (v is List) {
    return v.map((e) => _parseDate(e)).toList();
  }
  return const [];
}

/// item: objeto del backend (cada elemento del array)
Promotion mapBackendItemToPromotion(Map<String, dynamic> item) {
  // Estructura: { _id, detallePromocion: {...}, ciudades: [], categorias: [] }
  final d = (item['detallePromocion'] ?? {}) as Map<String, dynamic>;
  final ciudades    = _safeStringList(item['ciudades']);
  final categorias  = _safeStringList(item['categorias']);

  return Promotion(
    id: _safeStr(d['id'], _safeStr(item['_id'])),
    city: ciudades.isNotEmpty ? ciudades.first : '—',
    title: _safeStr(d['title']),
    placeName: _safeStr(d['placeName']),
    description: _safeStr(d['description']),
    imageUrl: _safeStr(d['imageUrl']),
    logoUrl: _safeStr(d['logoUrl']),
    isTwoForOne: _safeBool(d['isTwoForOne']),
    categories: categorias.isNotEmpty ? categorias : const ['General'],
    tags: _safeStringList(d['tags']),
    rating: _safeDouble(d['rating'], 0),
    scheduleLabel: _safeStr(d['scheduleLabel']),
    distanceLabel: _safeStr(d['distanceLabel']),
    startDate: _parseDate(d['startDate']),
    endDate: _parseDate(d['endDate']),
    isFlash: _safeBool(d['isFlash']),
    address: _safeStr(d['address'], ''),

    // NUEVOS:
    aplicaTodosLosDias: d.containsKey('aplicaTodosLosDias')
        ? _safeBool(d['aplicaTodosLosDias'])
        : null,
    diasAplicables: d.containsKey('diasAplicables')
        ? _safeStringList(d['diasAplicables']).map((e) => e.toLowerCase()).toList()
        : null,
    horarioPorDia: d['horarioPorDia'] is Map<String, dynamic>
        ? d['horarioPorDia'] as Map<String, dynamic>
        : null,
    fechasExcluidas: d.containsKey('fechasExcluidas')
        ? _parseDateList(d['fechasExcluidas'])
        : null,
  );
}
