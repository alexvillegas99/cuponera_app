import 'package:geolocator/geolocator.dart';

/// Devuelve la distancia formateada ("350 m" / "1.2 km") entre el usuario y un
/// local, o null si falta alguna coordenada.
String? distanciaLabel(
  double? userLat,
  double? userLng,
  double? localLat,
  double? localLng,
) {
  if (userLat == null || userLng == null || localLat == null || localLng == null) {
    return null;
  }
  final metros =
      Geolocator.distanceBetween(userLat, userLng, localLat, localLng);
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
