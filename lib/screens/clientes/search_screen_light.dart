import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import '../../models/promotion_models.dart';
import '../../screens/clientes/comercio_detalle_mini_screen.dart';

class SearchScreenLight extends StatefulWidget {
  final List<Promotion> all;
  final bool Function(Promotion) isFavorite;
  final void Function(Promotion) onFavorite;

  const SearchScreenLight({
    super.key,
    required this.all,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  State<SearchScreenLight> createState() => _SearchScreenLightState();
}

class _SearchScreenLightState extends State<SearchScreenLight> {
  String q = '';

  void _openDetalle(Promotion p) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
      ),
    );
  }

  static String _n(String s) {
    const a = 'áàäâéèëêíìïîóòöôúùüûñ';
    const b = 'aaaaeeeeiiiioooouuuun';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = a.indexOf(ch);
      buf.write(i >= 0 ? b[i] : ch);
    }
    return buf.toString();
  }

  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _sugerir(String t) {
    _ctrl.text = t;
    setState(() => q = t);
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final query = _n(q.trim());

    // Busca en local, oferta, ciudad, categorías y descripción, sin tildes.
    final List<Promotion> results = query.isEmpty
        ? <Promotion>[]
        : widget.all.where((p) {
            final haystack = _n(
              '${p.title} ${p.placeName} ${p.city} ${p.description} '
              '${p.categories.join(" ")} ${p.tags.join(" ")}',
            );
            return query.split(RegExp(r'\s+')).every(haystack.contains);
          }).toList();

    // Sugerencias reales: ciudades y categorías con promociones.
    final sugerencias = <String>{
      ...widget.all.map((p) => p.city).where((c) => c.trim().isNotEmpty),
      ...widget.all.expand((p) => p.categories.take(1)),
    }.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => q = v),
            textInputAction: TextInputAction.search,
            style: EnjoyTheme.body(size: 14, color: ec.text),
            cursorColor: ec.orange,
            decoration: const InputDecoration(
              hintText: 'Local, plato, ciudad o categoría',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    Text('Sugerencias',
                        style: EnjoyTheme.body(size: 12.5, weight: FontWeight.w600, color: ec.textSoft)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in sugerencias)
                          Pill(t, onTap: () => _sugerir(t)),
                      ],
                    ),
                  ],
                )
              : results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'No encontramos promociones para "${q.trim()}". Prueba con otra ciudad o categoría.',
                    style: EnjoyTheme.body(size: 13, height: 1.45, color: ec.textMute),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = results[i];
                    return PromoCard(
                      title: p.placeName.isNotEmpty ? p.placeName : p.title,
                      subtitle: promoTextos(p).oferta,
                      meta: promoTextos(p).meta,
                      imageUrl: p.coverUrl,
                      discount: p.isTwoForOne ? '2x1' : null,
                      isFavorite: widget.isFavorite(p),
                      onFavorite: () => widget.onFavorite(p),
                      onTap: () => _openDetalle(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
