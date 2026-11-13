import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:enjoy/services/versiones_service.dart';
import 'package:enjoy/ui/enjoy_colors.dart';
import 'package:enjoy/ui/enjoy_theme.dart';
import 'package:enjoy/ui/widgets/enjoy_widgets.dart';

/// Hoja "Elige tu cuponera": explica cómo funciona, permite buscar por
/// provincia / cantón / ciudad y ordena las cuponeras por cercanía al local
/// afiliado más próximo. Al elegir una, muestra cómo adquirirla.
Future<void> showElegirCuponera(
  BuildContext context, {
  required void Function(Map<String, dynamic> cuponera) onComprar,
  required void Function(Map<String, dynamic> cuponera) onWhatsApp,
  required VoidCallback onVerSolicitudes,
  String busquedaInicial = '',
}) {
  final ec = context.ec;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ec.surfaceMid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _ElegirCuponera(
        onComprar: onComprar,
        onWhatsApp: onWhatsApp,
        onVerSolicitudes: onVerSolicitudes,
        busquedaInicial: busquedaInicial,
      ),
    ),
  );
}

class _ElegirCuponera extends StatefulWidget {
  final void Function(Map<String, dynamic>) onComprar;
  final void Function(Map<String, dynamic>) onWhatsApp;
  final VoidCallback onVerSolicitudes;
  final String busquedaInicial;
  const _ElegirCuponera({
    required this.onComprar,
    required this.onWhatsApp,
    required this.onVerSolicitudes,
    this.busquedaInicial = '',
  });

  @override
  State<_ElegirCuponera> createState() => _ElegirCuponeraState();
}

class _ElegirCuponeraState extends State<_ElegirCuponera> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _conUbicacion = false;
  late String _q = widget.busquedaInicial;
  late final TextEditingController _qCtrl = TextEditingController(text: widget.busquedaInicial);
  String? _seleccionId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  /// Ubicación solo si el permiso ya está concedido (no interrumpe con diálogos).
  Future<Position?> _ubicacion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargar() async {
    final pos = await _ubicacion();
    final list = await VersionesService.disponibles(lat: pos?.latitude, lng: pos?.longitude);
    if (!mounted) return;
    setState(() {
      _items = list;
      _conUbicacion = pos != null;
      _loading = false;
    });
  }

  static String _norm(String s) {
    const a = 'áàäâéèëêíìïîóòöôúùüûñ';
    const b = 'aaaaeeeeiiiioooouuuun';
    final low = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in low.split('')) {
      final i = a.indexOf(ch);
      buf.write(i >= 0 ? b[i] : ch);
    }
    return buf.toString();
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = _norm(_q.trim());
    if (q.isEmpty) return _items;
    return _items.where((c) {
      final campos = <String>[
        (c['nombre'] ?? '').toString(),
        ...((c['provincias'] as List?) ?? const []).map((e) => e.toString()),
        ...((c['ciudades'] as List?) ?? const []).map((e) => e.toString()),
      ];
      return campos.any((t) => _norm(t).contains(q));
    }).toList();
  }

  static String precio(dynamic raw) {
    final v = double.tryParse((raw ?? '').toString());
    if (v == null || v <= 0) return 'Consultar';
    final txt = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '\$$txt';
  }

  static String _cobertura(Map<String, dynamic> c, [String q = '']) {
    final prov = ((c['provincias'] as List?) ?? const []).map((e) => e.toString()).toList();
    final ciu = ((c['ciudades'] as List?) ?? const []).map((e) => e.toString()).toList();
    // La ciudad que el cliente buscó va primero (no escondida en "y N más").
    final nq = _norm(q.trim());
    if (nq.isNotEmpty) {
      ciu.sort((a, b) {
        final ma = _norm(a).contains(nq) ? 0 : 1;
        final mb = _norm(b).contains(nq) ? 0 : 1;
        return ma != mb ? ma - mb : a.compareTo(b);
      });
    }
    final ciudadesTxt = ciu.isEmpty
        ? ''
        : ciu.length <= 2
            ? ciu.join(' y ')
            : '${ciu.take(2).join(', ')} y ${ciu.length - 2} más';
    if (prov.length == 1 && ciu.length > 1) return '${prov.first} · $ciudadesTxt';
    if (ciudadesTxt.isNotEmpty) return ciudadesTxt;
    return prov.join(', ');
  }

  static String _meta(Map<String, dynamic> c) {
    final partes = <String>[];
    final d = c['distanciaKm'];
    if (d is num) {
      partes.add(d < 1 ? 'A menos de 1 km' : 'A ${d.toStringAsFixed(d < 10 ? 1 : 0).replaceAll('.', ',')} km');
    }
    final n = c['totalLocales'];
    if (n is num) {
      partes.add(n == 0 ? 'Aún sin locales afiliados' : n == 1 ? '1 local' : '$n locales');
    }
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final lista = _filtradas;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ec.strokeStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text('Elige tu cuponera',
                    style: EnjoyTheme.heading(size: 20, weight: FontWeight.w800, color: ec.text)),
                const SizedBox(height: 4),
                Text('Una membresía para usar los beneficios de los locales afiliados de tu zona.',
                    style: EnjoyTheme.body(size: 13, height: 1.45, color: ec.textMute)),
                const SizedBox(height: 16),
                _ComoFunciona(),
                const SizedBox(height: 18),
                TextField(
                  controller: _qCtrl,
                  onChanged: (v) => setState(() => _q = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Busca por provincia, cantón o ciudad',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loading
                      ? 'Cargando cuponeras…'
                      : _conUbicacion
                          ? 'Ordenadas por cercanía a tu ubicación'
                          : 'Activa tu ubicación para verlas por cercanía',
                  style: EnjoyTheme.body(size: 12, color: ec.textMute),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ec.textMute),
                      ),
                    ),
                  )
                else if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      _items.isEmpty
                          ? 'Ahora mismo no hay cuponeras a la venta. Escríbenos por WhatsApp y te avisamos.'
                          : 'No hay cuponeras para "$_q". Prueba con la provincia o con otra ciudad cercana.',
                      style: EnjoyTheme.body(size: 13, height: 1.45, color: ec.textMute),
                    ),
                  )
                else
                  for (final c in lista) _itemCuponera(context, c),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onVerSolicitudes();
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Ver mis solicitudes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCuponera(BuildContext context, Map<String, dynamic> c) {
    final ec = context.ec;
    final id = (c['_id'] ?? '').toString();
    final sel = id == _seleccionId;
    final meta = _meta(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _seleccionId = sel ? null : id),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ec.glass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? ec.secondaryDeep : ec.stroke,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((c['nombre'] ?? 'Cuponera').toString(),
                            style: EnjoyTheme.heading(size: 15, weight: FontWeight.w700, color: ec.text)),
                        const SizedBox(height: 3),
                        Text(_cobertura(c, _q),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: EnjoyTheme.body(size: 12.5, height: 1.35, color: ec.textSoft)),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(meta, style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(precio(c['precio']),
                      style: EnjoyTheme.heading(size: 20, weight: FontWeight.w800, color: ec.text)),
                ],
              ),
              if (sel) ...[
                const SizedBox(height: 14),
                EnjoyButton(
                  label: 'Comprar por transferencia',
                  icon: Icons.account_balance_outlined,
                  dense: true,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onComprar(c);
                  },
                ),
                const SizedBox(height: 8),
                EnjoyButton(
                  label: 'Consultar por WhatsApp',
                  icon: Icons.chat_outlined,
                  variant: EnjoyButtonVariant.ghost,
                  dense: true,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onWhatsApp(c);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Explicación breve, sin adornos: qué es y cómo se usa.
class _ComoFunciona extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    const pasos = [
      ['Elige la cuponera de tu zona', 'Cada una cubre una provincia o ciudad y sus locales afiliados.'],
      ['Págala una sola vez', 'Por transferencia o con ayuda por WhatsApp; la activamos en tu cuenta.'],
      ['Úsala en el local', 'Muestra tu cupón en la app y aprovecha el 2x1 o el descuento del local.'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ec.secondaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < pasos.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == pasos.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}',
                        style: EnjoyTheme.heading(size: 14, weight: FontWeight.w800, color: ec.secondaryDeep)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pasos[i][0],
                            style: EnjoyTheme.body(size: 13.5, weight: FontWeight.w700, color: ec.text)),
                        const SizedBox(height: 2),
                        Text(pasos[i][1],
                            style: EnjoyTheme.body(size: 12.5, height: 1.4, color: ec.textSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
