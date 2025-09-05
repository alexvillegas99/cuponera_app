import 'package:flutter/material.dart';
import '../../ui/palette.dart';
import '../../models/promotion_models.dart';
import '../../widgets/promo_card_light.dart';

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

  @override
  Widget build(BuildContext context) {
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
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Buscar promociones…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Palette.kField,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.kAccent),
              ),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text(
                    'Busca por nombre, categoría o tag',
                    style: TextStyle(color: Palette.kMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PromoCardLight(
                    promo: results[i],
                    style: CardStyle.normal,
                    isFavorite: widget.isFavorite(results[i]),
                    onTap: () {},
                    onFavorite: () => widget.onFavorite(results[i]),
                    onShare: () {},
                  ),
                ),
        ),
      ],
    );
  }
}
