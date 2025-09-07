// lib/models/profile_info.dart
class ProfileInfo {
  final String? id;
  final String name;
  final String email;
  final String? avatarUrl;

  final int favoritos;
  final int cuponeras;
  final int escaneos;

  final List<String> ciudades;
  final List<String> categoriasFav;

  ProfileInfo({
    this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.favoritos = 0,
    this.cuponeras = 0,
    this.escaneos = 0,
    this.ciudades = const [],
    this.categoriasFav = const [],
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> j) {
    List<String> _asStrList(dynamic v) {
      if (v is List) return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      return const [];
    }

    return ProfileInfo(
      id: j['_id']?.toString(),
      name: (j['name'] ?? j['nombre'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      avatarUrl: j['avatarUrl']?.toString(),
      favoritos: (j['favoritos'] ?? 0) is num ? (j['favoritos'] as num).toInt() : 0,
      cuponeras: (j['cuponeras'] ?? 0) is num ? (j['cuponeras'] as num).toInt() : 0,
      escaneos: (j['escaneos'] ?? 0) is num ? (j['escaneos'] as num).toInt() : 0,
      ciudades: _asStrList(j['ciudades']),
      categoriasFav: _asStrList(j['categoriasFav']),
    );
  }
}
