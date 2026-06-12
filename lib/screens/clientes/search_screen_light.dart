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

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final query = q.trim().toLowerCase();

    final List<Promotion> results = query.isEmpty
        ? <Promotion>[]
        : widget.all.where((p) {
            final haystack = (
              '${p.title} '
              '${p.placeName} '
              '${p.description} '
              '${p.categories.join(" ")} ' // 👈 antes: p.category
              '${p.tags.join(" ")}'
            ).toLowerCase();
            return haystack.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Buscar', style: EnjoyTheme.heading(size: 20, color: ec.text)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            style: EnjoyTheme.body(size: 14, color: ec.text),
            cursorColor: ec.orange,
            decoration: const InputDecoration(
              hintText: 'Buscar promociones…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    'Busca por nombre, categoría o tag',
                    style: EnjoyTheme.body(size: 13, color: ec.textMute),
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
                      subtitle: p.title,
                      imageUrl: p.coverUrl,
                      topBadge: p.categories.isNotEmpty ? p.categories.first : null,
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
