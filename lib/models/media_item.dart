/// Item de la galería del local: foto o video.
/// Los videos solo se reproducen al entrar al detalle del establecimiento.
class MediaItem {
  final String url;
  final String type; // 'image' | 'video'
  final String? thumbnailUrl;

  const MediaItem({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });

  bool get isVideo => type == 'video';

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        url: (j['url'] ?? '').toString(),
        type: (j['type'] ?? 'image').toString() == 'video' ? 'video' : 'image',
        thumbnailUrl: j['thumbnailUrl']?.toString(),
      );

  /// Parsea una lista cruda de galería desde un subdocumento (detallePromocion).
  static List<MediaItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.url.isNotEmpty)
        .toList();
  }
}
