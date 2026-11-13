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

