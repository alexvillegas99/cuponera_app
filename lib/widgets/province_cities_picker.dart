import 'dart:math' as math;
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Abre un selector MULTI-PROVINCIA (con buscador y opción "cercana" por GPS).
/// Devuelve el conjunto de ids de provincias elegidas, o null si se cancela.
Future<Set<String>?> showProvincePicker(
  BuildContext context, {
  required List<Provincia> provincias,
  required Set<String> initialIds,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ProvincePicker(provincias: provincias, initialIds: initialIds),
  );
}

class _ProvincePicker extends StatefulWidget {
  final List<Provincia> provincias;
  final Set<String> initialIds;
  const _ProvincePicker({required this.provincias, required this.initialIds});

  @override
  State<_ProvincePicker> createState() => _ProvincePickerState();
}

class _ProvincePickerState extends State<_ProvincePicker> {
  final _svc = CiudadesService();
  final Set<String> _sel = {};
  String _q = '';
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _sel.addAll(widget.initialIds);
  }

  String _norm(String s) {
    var r = s.toLowerCase();
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  double _dist(double a, double b, double c, double d) {
    final dLat = (c - a).abs();
    final dLng = (d - b).abs();
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  /// GPS → ciudad más cercana → marca su provincia.
  Future<void> _usarGps() async {
    setState(() => _gpsLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Permiso denegado');
      }
      final pos = await Geolocator.getCurrentPosition();
      final todas = await _svc.getParaPromos();
      String? mejorProv;
      double mejorD = double.infinity;
      for (final c in todas) {
        if (c.lat == null || c.lng == null || c.provinciaId == null) continue;
        final d = _dist(pos.latitude, pos.longitude, c.lat!, c.lng!);
        if (d < mejorD) {
          mejorD = d;
          mejorProv = c.provinciaId;
        }
      }
      if (mejorProv == null) throw Exception('No se encontró provincia cercana');
      if (mounted) setState(() => _sel.add(mejorProv!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q.trim());
    final filtered = q.isEmpty
        ? widget.provincias
        : widget.provincias.where((p) => _norm(p.nombre).contains(q)).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Palette.kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Elige tus provincias',
                      style: TextStyle(
                          color: Palette.kTitle,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: _gpsLoading ? null : _usarGps,
                  icon: _gpsLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Cercana'),
                  style: TextButton.styleFrom(foregroundColor: Palette.kAccent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Buscar provincia…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Palette.kMuted),
                filled: true,
                fillColor: Palette.kField,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Palette.kBorder)),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Sin resultados', style: TextStyle(color: Palette.kMuted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Palette.kBorder),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final sel = _sel.contains(p.id);
                      return CheckboxListTile(
                        value: sel,
                        activeColor: Palette.kAccent,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(p.nombre,
                            style: const TextStyle(color: Palette.kTitle, fontSize: 14)),
                        onChanged: (v) => setState(
                            () => v == true ? _sel.add(p.id) : _sel.remove(p.id)),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text('${_sel.length} provincia(s)',
                      style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _sel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
