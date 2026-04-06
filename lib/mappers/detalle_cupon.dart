class DetalleCupon {
  final CuponMeta cupon;
  final VersionMeta version;
  final int candidatosTotal;
  final List<LugarScaneado> lugaresScaneados;
  final List<LugarPendiente> lugaresSinScannear;
  final int totalLugaresScaneados;
  final int totalEscaneos;

  DetalleCupon({
    required this.cupon,
    required this.version,
    required this.candidatosTotal,
    required this.lugaresScaneados,
    required this.lugaresSinScannear,
    required this.totalLugaresScaneados,
    required this.totalEscaneos,
  });

  factory DetalleCupon.fromJson(Map<String, dynamic> j) => DetalleCupon(
    cupon: CuponMeta.fromJson(j['cupon'] ?? const {}),
    version: VersionMeta.fromJson(j['version'] ?? const {}),
    candidatosTotal: (j['candidatosTotal'] ?? 0) as int,
    lugaresScaneados: ((j['lugaresScaneados'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LugarScaneado.fromJson)
        .toList(),
    lugaresSinScannear: ((j['lugaresSinScannear'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LugarPendiente.fromJson)
        .toList(),
    totalLugaresScaneados: (j['totalLugaresScaneados'] ?? 0) as int,
    totalEscaneos: (j['totalEscaneos'] ?? 0) as int,
  );
}

class CuponMeta {
  final int? secuencial;
  final String estado;
  final int numeroDeEscaneos;
  final DateTime? fechaActivacion;
  final DateTime? fechaVencimiento;
  final DateTime? ultimoScaneo;

  CuponMeta({
    required this.secuencial,
    required this.estado,
    required this.numeroDeEscaneos,
    required this.fechaActivacion,
    required this.fechaVencimiento,
    required this.ultimoScaneo,
  });

  factory CuponMeta.fromJson(Map<String, dynamic> j) => CuponMeta(
    secuencial: j['secuencial'] is num ? (j['secuencial'] as num).toInt() : null,
    estado: (j['estado'] ?? '') as String,
    numeroDeEscaneos: (j['numeroDeEscaneos'] ?? 0) as int,
    fechaActivacion: _tryDate(j['fechaActivacion']),
    fechaVencimiento: _tryDate(j['fechaVencimiento']),
    ultimoScaneo: _tryDate(j['ultimoScaneo']),
  );
}

class VersionMeta {
  final String nombre;
  final bool estado;
  final List<String> ciudadesDisponibles;
  final int totalLocales;
  final String? descripcion;
  final String? precio;

  VersionMeta({
    required this.nombre,
    required this.estado,
    required this.ciudadesDisponibles,
    required this.totalLocales,
    required this.descripcion,
    this.precio,
  });

  factory VersionMeta.fromJson(Map<String, dynamic> j) => VersionMeta(
    nombre: (j['nombre'] ?? '') as String,
    estado: (j['estado'] ?? false) as bool,
    ciudadesDisponibles: ((j['ciudadesDisponibles'] as List?) ?? const [])
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
    totalLocales: (j['totalLocales'] ?? j['numeroDeLocales'] ?? 0) as int,
    descripcion: j['descripcion']?.toString(),
    precio: j['precio']?.toString(),
  );
}

class LugarBase {
  final String nombre;        // local
  final String email;
  final List<String> ciudades;
  final String? title;
  final String? logoUrl;
  final double? rating;
  final String? scheduleLabel;
  LugarBase({
    required this.nombre,
    required this.email,
    required this.ciudades,
    required this.title,
    required this.logoUrl,
    required this.rating,
    required this.scheduleLabel,
  });
}

class LugarScaneado extends LugarBase {
  final int count;
  final DateTime? lastScan;
  final String usuarioId; // 👈 id del local/usuario

  LugarScaneado({
    required super.nombre,
    required super.email,
    required super.ciudades,
    required super.title,
    required super.logoUrl,
    required super.rating,
    required super.scheduleLabel,
    required this.count,
    required this.lastScan,
    required this.usuarioId, // 👈 ¡asignación correcta!
  });

  factory LugarScaneado.fromJson(Map<String, dynamic> j) => LugarScaneado(
    usuarioId: (j['usuarioId'] ?? '').toString(),
    nombre: (j['nombre'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    ciudades: ((j['ciudades'] as List?) ?? const [])
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
    title: j['title']?.toString(),
    logoUrl: j['logoUrl']?.toString(),
    rating: j['rating'] == null ? null : (j['rating'] as num).toDouble(),
    scheduleLabel: j['scheduleLabel']?.toString(),
    count: (j['count'] ?? 0) as int,
    lastScan: _tryDate(j['lastScan']),
  );
}

class LugarPendiente extends LugarBase {
  final String usuarioId; // 👈 opcional pero recomendado para navegación

  LugarPendiente({
    required super.nombre,
    required super.email,
    required super.ciudades,
    required super.title,
    required super.logoUrl,
    required super.rating,
    required super.scheduleLabel,
    required this.usuarioId,
  });

  factory LugarPendiente.fromJson(Map<String, dynamic> j) => LugarPendiente(
    usuarioId: (j['usuarioId'] ?? '').toString(),
    nombre: (j['nombre'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    ciudades: ((j['ciudades'] as List?) ?? const [])
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
    title: j['title']?.toString(),
    logoUrl: j['logoUrl']?.toString(),
    rating: j['rating'] == null ? null : (j['rating'] as num).toDouble(),
    scheduleLabel: j['scheduleLabel']?.toString(),
  );
}

DateTime? _tryDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
