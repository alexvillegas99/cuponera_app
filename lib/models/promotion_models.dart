class Promotion {
  final String id;
  final String city;
  final String title;
  final String placeName;
  final String description;
  final String imageUrl;
  final String logoUrl;
  final bool isTwoForOne;
  final String category; // Restaurante, Bar, Cafetería, Spa
  final List<String> tags;
  final double rating;
  final String scheduleLabel;
  final String distanceLabel;
  final String? address;
  final DateTime startDate;
  final DateTime endDate;
  final bool isFlash;

  const Promotion({
    required this.id,
    required this.city,
    required this.title,
    required this.placeName,
    required this.description,
    required this.imageUrl,
    required this.logoUrl,
    required this.isTwoForOne,
    required this.category,
    required this.tags,
    required this.rating,
    required this.scheduleLabel,
    required this.distanceLabel,
    required this.startDate,
    required this.endDate,
    required this.isFlash,
    this.address,
  });

  bool get isActiveToday {
    final now = DateTime.now();
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }
}

final List<Promotion> mockPromos = [
  Promotion(
    id: '1', city: 'Ambato',
    title: 'Plato 2x1 – Pizza Pepperoni', placeName: 'Pizzería San Marco',
    description: 'Disfruta 2x1 en nuestra pizza Pepperoni tamaño mediano. Válido en local y para llevar.',
    imageUrl: 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/16/76/05/20/restaurante.jpg?w=900&h=500&s=1',
    logoUrl: 'https://img.pikbest.com/png-images/20241030/chefs-delight-restaurant-logo_11024933.png!sw800',
    isTwoForOne: true, category: 'Restaurante', tags: ['Pizza', 'Familiar', 'Para llevar'], rating: 4.6,
    scheduleLabel: 'Hoy 12:00–22:00', distanceLabel: '1.2 km',
    startDate: DateTime.now().subtract(const Duration(days: 1)),
    endDate: DateTime.now().add(const Duration(days: 7)),
    isFlash: false,
    address: 'Av. Cevallos 123 y Montalvo',
  ),
  Promotion(
    id: '2', city: 'Ambato',
    title: 'Combo Brunch', placeName: 'Café Aurora',
    description: 'Café + Croissant + Yogurt griego con frutas a precio especial. Solo hoy.',
    imageUrl: 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/16/76/05/20/restaurante.jpg?w=900&h=500&s=1',
    logoUrl: 'https://img.pikbest.com/png-images/20241030/chefs-delight-restaurant-logo_11024933.png!sw800',
    isTwoForOne: false, category: 'Cafetería', tags: ['Desayuno', 'Dulce', 'Rápido'], rating: 4.4,
    scheduleLabel: 'Hoy 08:00–12:00', distanceLabel: '800 m',
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(hours: 8)),
    isFlash: true,
    address: 'C. Bolívar y Castillo',
  ),
  Promotion(
    id: '3', city: 'Latacunga',
    title: '2x1 en Cocteles', placeName: 'Bar La Terraza',
    description: 'Happy Hour extendido: 2x1 en cocteles clásicos de 18:00 a 20:00.',
    imageUrl: 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/16/76/05/20/restaurante.jpg?w=900&h=500&s=1',
    logoUrl: 'https://img.pikbest.com/png-images/20241030/chefs-delight-restaurant-logo_11024933.png!sw800',
    isTwoForOne: true, category: 'Bar', tags: ['HappyHour', 'Cocteles', 'Amigos'], rating: 4.5,
    scheduleLabel: 'Hoy 18:00–20:00', distanceLabel: '2.4 km',
    startDate: DateTime.now().subtract(const Duration(days: 2)),
    endDate: DateTime.now().add(const Duration(days: 2)),
    isFlash: false,
    address: 'Av. Amazonas y Quito',
  ),
  Promotion(
    id: '4', city: 'Riobamba',
    title: 'Spa Day Flash -40%', placeName: 'Wellness & Spa',
    description: 'Relájate con un 40% de descuento en masajes de 60 minutos. ¡Cupos limitados!',
    imageUrl: 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/16/76/05/20/restaurante.jpg?w=900&h=500&s=1',
    logoUrl: 'https://img.pikbest.com/png-images/20241030/chefs-delight-restaurant-logo_11024933.png!sw800',
    isTwoForOne: false, category: 'Spa', tags: ['Relax', 'Salud', 'Descuento'], rating: 4.8,
    scheduleLabel: 'Hoy 10:00–19:00', distanceLabel: '3.1 km',
    startDate: DateTime.now().subtract(const Duration(hours: 1)),
    endDate: DateTime.now().add(const Duration(hours: 3)),
    isFlash: true,
    address: 'Parque Sucre, local 5',
  ),
];

// ===== Cuponeras =====
class Cuponera {
  final String id;
  final String nombre;
  final String codigo;     // ej: ENJOY-AMB-2025
  final String qrData;     // data para QR
  final String descripcion;
  final DateTime emitidaEl;
  final DateTime? expiraEl;
  final List<CuponeraScan> scans;

  const Cuponera({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.qrData,
    required this.descripcion,
    required this.emitidaEl,
    this.expiraEl,
    this.scans = const [],
  });
}

class CuponeraScan {
  final String local;
  final String ciudad;
  final DateTime fecha;
  final String usuario;
  const CuponeraScan({
    required this.local,
    required this.ciudad,
    required this.fecha,
    required this.usuario,
  });
}

final List<Cuponera> mockCuponeras = [
  Cuponera(
    id: 'C-001',
    nombre: 'Enjoy Ambato Experience',
    codigo: 'ENJOY-AMB-2025',
    qrData: 'cuponera:ENJOY-AMB-2025',
    descripcion: 'Acceso a 50+ locales participantes en Ambato.',
    emitidaEl: DateTime.now().subtract(const Duration(days: 10)),
    expiraEl: DateTime.now().add(const Duration(days: 300)),
    scans: [
      CuponeraScan(local: 'Pizzería San Marco', ciudad: 'Ambato', fecha: DateTime.now().subtract(const Duration(days: 2, hours: 5)), usuario: 'JP'),
      CuponeraScan(local: 'Café Aurora', ciudad: 'Ambato', fecha: DateTime.now().subtract(const Duration(days: 1, hours: 3)), usuario: 'JP'),
    ],
  ),
  Cuponera(
    id: 'C-002',
    nombre: 'Ruta Riobamba & Spa',
    codigo: 'ENJOY-RIO-2025',
    qrData: 'cuponera:ENJOY-RIO-2025',
    descripcion: 'Descuentos en wellness y gastronomía de Riobamba.',
    emitidaEl: DateTime.now().subtract(const Duration(days: 30)),
    expiraEl: DateTime.now().add(const Duration(days: 200)),
    scans: [
      CuponeraScan(local: 'Wellness & Spa', ciudad: 'Riobamba', fecha: DateTime.now().subtract(const Duration(hours: 8)), usuario: 'JV'),
    ],
  ),
];
