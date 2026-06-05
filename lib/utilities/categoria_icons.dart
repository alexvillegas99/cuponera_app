import 'package:flutter/material.dart';

const Map<String, IconData> _categoriaIconMap = {
  // Gastronomía y bebidas
  'restaurant': Icons.restaurant_outlined,
  'utensils': Icons.restaurant_outlined,
  'fastfood': Icons.fastfood_outlined,
  'food': Icons.fastfood_outlined,
  'pizza': Icons.local_pizza_outlined,
  'burger': Icons.lunch_dining_outlined,
  'dining': Icons.dining_outlined,
  'parrillada': Icons.outdoor_grill_outlined,
  'bbq': Icons.outdoor_grill_outlined,
  'grill': Icons.outdoor_grill_outlined,
  'asado': Icons.outdoor_grill_outlined,
  'mariscos': Icons.set_meal_outlined,
  'sushi': Icons.ramen_dining_outlined,
  'saludable': Icons.eco_outlined,
  'heladeria': Icons.icecream_outlined,
  'postres': Icons.cake_outlined,
  'panaderia': Icons.bakery_dining_outlined,
  'coffee': Icons.coffee_outlined,
  'cafe': Icons.coffee_outlined,
  'tea': Icons.emoji_food_beverage_outlined,
  'bar': Icons.wine_bar_outlined,
  'beer': Icons.sports_bar_outlined,
  'cocktail': Icons.local_bar_outlined,
  'disco': Icons.nightlife_outlined,
  'licoreria': Icons.liquor_outlined,
  'foodtruck': Icons.local_dining_outlined,
  'buffet': Icons.brunch_dining_outlined,

  // Belleza y bienestar
  'spa': Icons.spa_outlined,
  'hair': Icons.content_cut_outlined,
  'beauty': Icons.brush_outlined,
  'nails': Icons.back_hand_outlined,
  'masajes': Icons.self_improvement_outlined,
  'maquillaje': Icons.face_retouching_natural_outlined,
  'depilacion': Icons.auto_fix_high_outlined,
  'tatuajes': Icons.gesture_outlined,

  // Salud
  'pharmacy': Icons.local_pharmacy_outlined,
  'clinica': Icons.medical_services_outlined,
  'dentista': Icons.medication_liquid_outlined,
  'optica': Icons.visibility_outlined,
  'laboratorio': Icons.biotech_outlined,
  'psicologia': Icons.psychology_outlined,
  'nutricion': Icons.monitor_heart_outlined,
  'veterinaria': Icons.pets_outlined,
  'wellness': Icons.self_improvement_outlined,

  // Deporte y fitness
  'deportes': Icons.sports_outlined,
  'gym': Icons.fitness_center_outlined,
  'yoga': Icons.self_improvement_outlined,
  'crossfit': Icons.sports_gymnastics_outlined,
  'marciales': Icons.sports_martial_arts_outlined,
  'natacion': Icons.pool_outlined,
  'tenis': Icons.sports_tennis_outlined,
  'futbol': Icons.sports_soccer_outlined,
  'basquet': Icons.sports_basketball_outlined,
  'bike': Icons.pedal_bike_outlined,
  'running': Icons.directions_run_outlined,

  // Aventura y outdoor
  'aventura': Icons.hiking_outlined,
  'trekking': Icons.terrain_outlined,
  'camping': Icons.cabin_outlined,
  'escalada': Icons.landscape_outlined,
  'parapente': Icons.paragliding_outlined,
  'rafting': Icons.kayaking_outlined,
  'buceo': Icons.scuba_diving_outlined,
  'surf': Icons.surfing_outlined,
  'pesca': Icons.phishing_outlined,
  'kayak': Icons.kayaking_outlined,
  'equitacion': Icons.bedroom_baby_outlined,
  'atv': Icons.two_wheeler_outlined,
  'paintball': Icons.sports_handball_outlined,
  'canopy': Icons.forest_outlined,

  // Turismo y viajes
  'hotel': Icons.hotel_outlined,
  'hostal': Icons.bed_outlined,
  'bed': Icons.bed_outlined,
  'resort': Icons.pool_outlined,
  'cabana': Icons.cabin_outlined,
  'agencia': Icons.card_travel_outlined,
  'tours': Icons.tour_outlined,
  'travel': Icons.flight_outlined,
  'beach': Icons.beach_access_outlined,
  'termas': Icons.hot_tub_outlined,
  'aerolinea': Icons.flight_outlined,

  // Entretenimiento
  'cinema': Icons.movie_outlined,
  'theater': Icons.theater_comedy_outlined,
  'concierto': Icons.music_note_outlined,
  'karaoke': Icons.mic_outlined,
  'bowling': Icons.sports_baseball_outlined,
  'billar': Icons.sports_outlined,
  'game': Icons.sports_esports_outlined,
  'casino': Icons.casino_outlined,
  'parquediv': Icons.attractions_outlined,
  'acuario': Icons.water_outlined,
  'zoo': Icons.pets_outlined,
  'museum': Icons.museum_outlined,
  'galeria': Icons.palette_outlined,
  'escape': Icons.vpn_key_outlined,
  'eventos': Icons.festival_outlined,

  // Niños y familia
  'jugueteria': Icons.toys_outlined,
  'parqueinf': Icons.child_friendly_outlined,
  'guarderia': Icons.child_care_outlined,
  'ropainf': Icons.checkroom_outlined,
  'park': Icons.park_outlined,

  // Educación
  'cursos': Icons.school_outlined,
  'education': Icons.school_outlined,
  'idiomas': Icons.translate_outlined,
  'music': Icons.music_note_outlined,
  'arte': Icons.palette_outlined,
  'book': Icons.menu_book_outlined,

  // Compras y retail
  'mall': Icons.shopping_bag_outlined,
  'market': Icons.local_grocery_store_outlined,
  'ropa': Icons.checkroom_outlined,
  'calzado': Icons.directions_walk_outlined,
  'joyeria': Icons.diamond_outlined,
  'accesorios': Icons.watch_outlined,
  'electro': Icons.kitchen_outlined,
  'tech': Icons.devices_outlined,
  'phone': Icons.phone_android_outlined,
  'computer': Icons.computer_outlined,
  'muebles': Icons.chair_outlined,
  'hogar': Icons.home_outlined,
  'flores': Icons.local_florist_outlined,
  'petshop': Icons.pets_outlined,
  'regalos': Icons.card_giftcard_outlined,
  'shop': Icons.storefront_outlined,
  'store': Icons.store_outlined,

  // Servicios
  'lavanderia': Icons.local_laundry_service_outlined,
  'tintoreria': Icons.dry_cleaning_outlined,
  'lavadoauto': Icons.local_car_wash_outlined,
  'mecanica': Icons.car_repair_outlined,
  'llantera': Icons.tire_repair_outlined,
  'cerrajeria': Icons.vpn_key_outlined,
  'plomeria': Icons.plumbing_outlined,
  'electricista': Icons.electrical_services_outlined,
  'limpieza': Icons.cleaning_services_outlined,
  'mudanza': Icons.local_shipping_outlined,
  'mensajeria': Icons.local_post_office_outlined,
  'imprenta': Icons.print_outlined,
  'fotografia': Icons.camera_alt_outlined,
  'catering': Icons.room_service_outlined,
  'dj': Icons.headphones_outlined,

  // Transporte
  'taxi': Icons.local_taxi_outlined,
  'bus': Icons.directions_bus_outlined,
  'car': Icons.directions_car_outlined,
  'rentauto': Icons.directions_car_outlined,
  'rentamoto': Icons.two_wheeler_outlined,
  'rentabike': Icons.pedal_bike_outlined,

  // Inmobiliario y construcción
  'inmobiliaria': Icons.home_work_outlined,
  'construccion': Icons.construction_outlined,
  'arquitectura': Icons.architecture_outlined,
  'interiores': Icons.chair_alt_outlined,
  'office': Icons.apartment_outlined,

  // Financieros
  'banco': Icons.account_balance_outlined,
  'seguros': Icons.shield_outlined,
  'cambio': Icons.currency_exchange_outlined,

  // Mascotas (servicios)
  'pelucanina': Icons.pets_outlined,
  'adiestramiento': Icons.pets_outlined,
  'hotelpet': Icons.pets_outlined,

  // Tiempo (legacy)
  'time': Icons.access_time_outlined,
  'clock': Icons.schedule_outlined,
};

IconData iconForCategoria(String? key) {
  if (key == null) return Icons.category_outlined;
  final normalized = key.toLowerCase().trim();
  return _categoriaIconMap[normalized] ?? Icons.category_outlined;
}
