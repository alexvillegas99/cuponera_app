import 'package:enjoy/services/promociones_flash_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'promocion_flash_detalle_screen.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kSelectedProvinciasKey = 'selected_provincia_ids_v1';

/// Feed de promociones flash de la ciudad/provincia que el cliente tiene
/// seleccionada (lee la misma selección del Home).
class PromocionesFlashScreen extends StatefulWidget {
  const PromocionesFlashScreen({super.key});

  @override
  State<PromocionesFlashScreen> createState() => _PromocionesFlashScreenState();
}

class _PromocionesFlashScreenState extends State<PromocionesFlashScreen> {
  final _svc = PromocionesFlashService();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _sinUbicacion = false;

  String _query = '';
  String _orden = 'urgencia'; // 'urgencia' (termina pronto) | 'nombre'

  /// Lista filtrada por búsqueda y ordenada según [_orden].
  List<Map<String, dynamic>> get _filtrados {
    final q = _query.trim().toLowerCase();
    var list = q.isEmpty
        ? List<Map<String, dynamic>>.from(_items)
        : _items.where((p) {
            final t = (p['titulo'] ?? '').toString().toLowerCase();
            final l = (p['localNombre'] ?? '').toString().toLowerCase();
            return t.contains(q) || l.contains(q);
          }).toList();
    if (_orden == 'nombre') {
      list.sort((a, b) => (a['titulo'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['titulo'] ?? '').toString().toLowerCase()));
    } else {
      list.sort((a, b) {
        final av = DateTime.tryParse(a['vence']?.toString() ?? '') ??
            DateTime(2100);
        final bv = DateTime.tryParse(b['vence']?.toString() ?? '') ??
            DateTime(2100);
        return av.compareTo(bv);
      });
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cityIds = prefs.getStringList(_kSelectedCityIdsKey) ?? [];
      final provIds = prefs.getStringList(_kSelectedProvinciasKey) ?? [];

      if (cityIds.isEmpty && provIds.isEmpty) {
        if (mounted) {
          setState(() {
            _sinUbicacion = true;
            _items = [];
            _loading = false;
          });
        }
        return;
      }

      List<Map<String, dynamic>> items = [];
      if (cityIds.isNotEmpty) {
        final res = await _svc.feed(ciudades: cityIds, limit: 50);
        items = _extract(res);
      } else {
        // Sin ciudades concretas: unir promos de las provincias seleccionadas.
        final seen = <String>{};
        for (final pid in provIds) {
          final res = await _svc.feed(provincia: pid, limit: 50);
          for (final p in _extract(res)) {
            if (seen.add(p['_id'].toString())) items.add(p);
          }
        }
      }

      if (mounted) {
        setState(() {
          _items = items;
          _sinUbicacion = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extract(Map<String, dynamic> res) {
    final data = res['data'];
    return data is List ? List<Map<String, dynamic>>.from(data) : [];
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Promociones flash'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : _items.isEmpty
              ? _buildEmpty(ec)
              : Column(
                  children: [
                    _buildSearchSort(ec),
                    Expanded(
                      child: RefreshIndicator(
                        color: ec.orange,
                        backgroundColor: ec.surfaceTop,
                        onRefresh: _cargar,
                        child: _filtrados.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'Sin resultados para "$_query"',
                                      style: EnjoyTheme.body(
                                          size: 14, color: ec.textMute),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 28),
                                itemCount: _filtrados.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (_, i) => _FlashCard(
                                  p: _filtrados[i],
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PromocionFlashDetalleScreen(
                                          promocionId: _filtrados[i]['_id']
                                              .toString(),
                                        ),
                                      ),
                                    );
                                    if (mounted) _cargar();
                                  },
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmpty(EnjoyColors ec) {
    return RefreshIndicator(
      color: ec.orange,
      backgroundColor: ec.surfaceTop,
      onRefresh: _cargar,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                IconBox(Icons.bolt_outlined,
                    size: 72, radius: 20, iconSize: 34),
                const SizedBox(height: 14),
                Text(
                  _sinUbicacion
                      ? 'Selecciona tu ubicación'
                      : 'No hay promociones flash',
                  style: EnjoyTheme.heading(size: 17, color: ec.text),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _sinUbicacion
                        ? 'Elige tu provincia y ciudad en Inicio para ver las promociones de tu zona.'
                        : 'Vuelve pronto: los locales de tu zona publican promos de tiempo limitado.',
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.body(size: 13, color: ec.textMute),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSort(EnjoyColors ec) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: EnjoyTheme.body(size: 14, color: ec.text),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o local…',
              hintStyle: EnjoyTheme.body(size: 14, color: ec.textMute),
              prefixIcon: Icon(Icons.search_rounded, color: ec.textMute, size: 20),
              isDense: true,
              filled: true,
              fillColor: ec.glass,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ec.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ec.orange),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Ordenar:',
                  style: EnjoyTheme.body(size: 12, color: ec.textMute)),
              const SizedBox(width: 8),
              Pill(
                'Termina pronto',
                icon: Icons.schedule_rounded,
                variant: _orden == 'urgencia'
                    ? PillVariant.orange
                    : PillVariant.glass,
                dense: true,
                onTap: () => setState(() => _orden = 'urgencia'),
              ),
              const SizedBox(width: 8),
              Pill(
                'Nombre',
                icon: Icons.sort_by_alpha_rounded,
                variant:
                    _orden == 'nombre' ? PillVariant.orange : PillVariant.glass,
                dense: true,
                onTap: () => setState(() => _orden = 'nombre'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Texto de cuenta regresiva "Termina en …".
String tiempoRestante(String? venceIso) {
  if (venceIso == null) return '';
  final vence = DateTime.tryParse(venceIso)?.toLocal();
  if (vence == null) return '';
  final diff = vence.difference(DateTime.now());
  if (diff.isNegative) return 'Finalizada';
  if (diff.inDays >= 1) return 'Termina en ${diff.inDays}d ${diff.inHours % 24}h';
  if (diff.inHours >= 1) return 'Termina en ${diff.inHours}h ${diff.inMinutes % 60}m';
  return 'Termina en ${diff.inMinutes}m';
}

/// (texto, esProximamente) para una promo flash.
/// Si aún no inicia → "Empieza en X" (próximamente); si está activa → "Termina en X".
(String, bool) cuentaFlash(Map<String, dynamic> p) {
  final inicia = DateTime.tryParse(p['inicia']?.toString() ?? '')?.toLocal();
  final now = DateTime.now();
  if (inicia != null && inicia.isAfter(now)) {
    final d = inicia.difference(now);
    if (d.inHours >= 1) {
      return ('Empieza en ${d.inHours}h ${d.inMinutes % 60}m', true);
    }
    return ('Empieza en ${d.inMinutes}m', true);
  }
  return (tiempoRestante(p['vence']?.toString()), false);
}

class _FlashCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onTap;

  const _FlashCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final etiqueta = (p['etiqueta'] ?? '').toString();
    final (cuenta, proximamente) = cuentaFlash(p);

    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen + overlays
            Stack(
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: (p['imagenUrl'] != null)
                      ? EnjoyImage(p['imagenUrl'].toString(), fit: BoxFit.cover)
                      : Container(color: ec.glass),
                ),
                if (etiqueta.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: ec.accentGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(etiqueta,
                          style: EnjoyTheme.heading(
                              size: 11, color: ec.onAccent)),
                    ),
                  ),
                if (cuenta.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: proximamente ? ec.blue : Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              proximamente
                                  ? Icons.upcoming_rounded
                                  : Icons.schedule_rounded,
                              size: 13,
                              color: Colors.white),
                          const SizedBox(width: 4),
                          Text(cuenta,
                              style: EnjoyTheme.body(
                                  size: 11, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                if (proximamente)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ec.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('PRÓXIMAMENTE',
                          style: EnjoyTheme.heading(
                              size: 10, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (p['titulo'] ?? '').toString(),
                    style: EnjoyTheme.heading(size: 16, color: ec.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((p['descripcion'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p['descripcion'].toString(),
                      style: EnjoyTheme.body(size: 13, color: ec.textMute),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if ((p['localLogo'] ?? '').toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: EnjoyImage(p['localLogo'].toString(),
                                fit: BoxFit.cover),
                          ),
                        )
                      else
                        Icon(Icons.storefront_rounded,
                            size: 18, color: ec.textMute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (p['localNombre'] ?? '').toString(),
                          style:
                              EnjoyTheme.body(size: 13, color: ec.textSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p['canjeable'] == true)
                        Pill('Canjeable',
                            variant: PillVariant.orange, dense: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
