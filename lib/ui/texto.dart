import "package:flutter/material.dart";
// Utilidades de presentación de texto compartidas por las pantallas.

/// Los locales suelen registrarse en MAYÚSCULAS ("MIDGARD RESTAURANTE-BAR").
/// Para una lectura más sobria se muestran en formato título; los nombres
/// escritos con mayúsculas y minúsculas se respetan tal cual.
String nombreLegible(String s) {
  final t = s.trim();
  final letras = t.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑÜáéíóúñü]'), '');
  if (letras.length < 4 || t != t.toUpperCase()) return t;
  const menores = {'de', 'del', 'la', 'el', 'y', 'en', 'los', 'las', 'a'};
  var i = 0;
  return t.toLowerCase().replaceAllMapped(RegExp(r"[A-Za-zÁÉÍÓÚÑÜáéíóúñü]+"), (m) {
    final w = m[0]!;
    final first = i++ == 0;
    if (!first && menores.contains(w)) return w;
    return w[0].toUpperCase() + w.substring(1);
  });
}


/// Teselas de mapa para el tema oscuro: escala de grises atenuada (sobrio,
/// sin la inversión de colores de `darkModeTileBuilder`).
Widget mapaOscuroTileBuilder(BuildContext context, Widget tile, dynamic _) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.25, -0.5, -0.08, 0, 205,
      -0.25, -0.5, -0.08, 0, 210,
      -0.25, -0.5, -0.08, 0, 220,
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}


/// El backend arma el horario con las fechas excluidas al final
/// ("Todos los días 16:00 a 00:00 · excepto 12/11"). En las tarjetas, donde
/// el texto se recorta, la excepción se muestra aparte y antes ("No aplica 12/11").
({String horario, String noAplica}) partesHorario(String? label) {
  final s = (label ?? '').trim();
  const marca = ' · excepto ';
  final i = s.indexOf(marca);
  if (i < 0) return (horario: s, noAplica: '');
  return (horario: s.substring(0, i), noAplica: 'No aplica ${s.substring(i + marca.length)}');
}
