import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/services/geocoding_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Pantalla de **creación rápida** de un establecimiento.
///
/// Solo pide los datos principales (nombre, correo, identificación, teléfono)
/// y la **ubicación actual con dirección autocompletada** (reverse geocoding,
/// igual que el panel web). El local nace **inactivo**; el equipo de marketing
/// completa el resto (promoción, horarios, categorías, fotos, catálogo)
/// editándolo después desde el wizard.
class EstablecimientoFormScreen extends StatefulWidget {
  const EstablecimientoFormScreen({super.key});

  @override
  State<EstablecimientoFormScreen> createState() =>
      _EstablecimientoFormScreenState();
}

class _EstablecimientoFormScreenState extends State<EstablecimientoFormScreen> {
  final _svc = EstablecimientosEmpresaService();
  final _ciudadesSvc = CiudadesService();
  final _categoriasSvc = CategoriasService();

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _identificacion = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();

  // Clasificación (requeridos para que aparezca en el home).
  List<Provincia> _provincias = [];
  List<Ciudad> _ciudades = [];
  List<Categoria> _categorias = [];
  String? _provinciaId;
  String? _ciudadId;
  String? _categoriaId;
  bool _loadingCiudades = false;

  double? _lat;
  double? _lng;
  bool _geoLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarRefs();
  }

  Future<void> _cargarRefs() async {
    try {
      final results = await Future.wait([
        _ciudadesSvc.getProvincias(),
        _categoriasSvc.getActivas(),
      ]);
      if (!mounted) return;
      setState(() {
        _provincias = results[0] as List<Provincia>;
        _categorias = results[1] as List<Categoria>;
      });
    } catch (_) {}
  }

  Future<void> _onProvinciaChange(String? id) async {
    setState(() {
      _provinciaId = id;
      _ciudadId = null;
      _ciudades = [];
      _loadingCiudades = id != null;
    });
    if (id == null) return;
    try {
      final cs = await _ciudadesSvc.getParaPromosPorProvincia(id);
      if (mounted) {
        setState(() {
          _ciudades = cs;
          _loadingCiudades = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCiudades = false);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _identificacion.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Captura la ubicación actual del dispositivo y autocompleta la dirección
  /// vía Nominatim (la misma fuente que la web).
  Future<void> _usarUbicacionActual() async {
    setState(() => _geoLoading = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) throw Exception('Activa la ubicación del dispositivo');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado');
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      final dir = await GeocodingService.reverse(pos.latitude, pos.longitude);
      if (mounted && dir != null && dir.isNotEmpty) {
        setState(() => _direccion.text = dir);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_provinciaId == null || _ciudadId == null) {
      _snack('Selecciona la provincia y la ciudad');
      return;
    }
    if (_categoriaId == null) {
      _snack('Selecciona al menos una categoría');
      return;
    }
    setState(() => _saving = true);
    try {
      final tel = _telefono.text.trim();
      final dir = _direccion.text.trim();
      final payload = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'identificacion': _identificacion.text.trim(),
        'rol': 'admin-local',
        'estado': true,
        'ciudades': [_ciudadId],
        'categorias': [_categoriaId],
        if (tel.isNotEmpty)
          'telefono': '+593${tel.replaceFirst(RegExp(r'^0'), '')}',
        if (_lat != null && _lng != null)
          'ubicacion': {'lat': _lat, 'lng': _lng},
        if (dir.isNotEmpty) 'detallePromocion': {'address': dir},
      };
      await _svc.crear(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Establecimiento creado. Se envió la clave por correo.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Nuevo establecimiento'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const FieldLabel('Datos principales'),
            TextFormField(
              controller: _nombre,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(
                labelText: 'Nombre del establecimiento',
                prefixIcon: Icon(Icons.store_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Requerido';
                final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                if (!emailRegex.hasMatch(value)) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _identificacion,
              keyboardType: TextInputType.number,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(
                labelText: 'Identificación (CI / RUC)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Requerido';
                if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(value)) {
                  return 'CI (10 dígitos) o RUC (13 dígitos)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return null; // opcional
                if (!RegExp(r'^\d{7,10}$').hasMatch(value)) {
                  return 'Teléfono inválido (7 a 10 dígitos)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const FieldLabel('Provincia, ciudad y categoría'),
            SearchablePickerField(
              label: 'Provincia',
              icon: Icons.map_outlined,
              value: _provinciaId,
              items: _provincias
                  .map((p) => (id: p.id, label: p.nombre))
                  .toList(),
              onChanged: _onProvinciaChange,
            ),
            const SizedBox(height: 12),
            SearchablePickerField(
              label: _loadingCiudades
                  ? 'Cargando ciudades…'
                  : (_provinciaId == null
                      ? 'Ciudad (elige provincia primero)'
                      : 'Ciudad'),
              icon: Icons.location_city_outlined,
              value: _ciudadId,
              items:
                  _ciudades.map((c) => (id: c.id, label: c.nombre)).toList(),
              onChanged: (v) => setState(() => _ciudadId = v),
            ),
            const SizedBox(height: 12),
            SearchablePickerField(
              label: 'Categoría',
              icon: Icons.category_outlined,
              value: _categoriaId,
              items: _categorias
                  .map((c) => (id: c.id, label: c.nombre))
                  .toList(),
              onChanged: (v) => setState(() => _categoriaId = v),
            ),
            const SizedBox(height: 6),
            Text(
              'Requeridos para que el local aparezca en la app.',
              style: EnjoyTheme.body(size: 12, color: ec.textMute),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Ubicación'),
            EnjoyButton(
              label: _geoLoading
                  ? 'Obteniendo ubicación…'
                  : 'Usar mi ubicación actual',
              icon: Icons.my_location_rounded,
              variant: EnjoyButtonVariant.ghost,
              loading: _geoLoading,
              onPressed: _geoLoading ? null : _usarUbicacionActual,
            ),
            if (_lat != null && _lng != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Pill(
                  '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  variant: PillVariant.green,
                  icon: Icons.location_on_rounded,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccion,
              maxLines: 2,
              minLines: 1,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, referencia',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La dirección se autocompleta desde tu ubicación; puedes ajustarla.',
              style: EnjoyTheme.body(size: 12, color: ec.textMute),
            ),
            const SizedBox(height: 16),
            GlassCard(
              accent: true,
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: ec.orangeSoft),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Se crea Activo con clave temporal por correo. '
                      'Luego puedes completar promoción, horarios, '
                      'categorías y fotos editándolo desde el panel.',
                      style: EnjoyTheme.body(size: 12.5, color: ec.textSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            EnjoyButton(
              label: 'Crear establecimiento',
              icon: Icons.add_business_rounded,
              loading: _saving,
              onPressed: _saving ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo tipo dropdown pero con buscador (abre un modal con lista filtrable).
/// Ideal para listas largas como categorías (150+).
class SearchablePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<({String id, String label})> items;
  final ValueChanged<String?> onChanged;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  String? get _selectedLabel {
    for (final i in items) {
      if (i.id == value) return i.label;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(label: label, items: items, value: value),
    );
    if (selected != null) onChanged(selected == '__none__' ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final sel = _selectedLabel;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(15),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          suffixIcon: const Icon(Icons.search_rounded, size: 18),
        ),
        child: Text(
          sel ?? 'Seleccionar…',
          style: EnjoyTheme.body(
            size: 14,
            color: sel != null ? ec.text : ec.textMute,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String label;
  final List<({String id, String label})> items;
  final String? value;
  const _PickerSheet(
      {required this.label, required this.items, required this.value});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  String _norm(String s) {
    var r = s.toLowerCase();
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final q = _norm(_q.trim());
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((i) => _norm(i.label).contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: EnjoyTheme.body(size: 14, color: ec.text),
                decoration: InputDecoration(
                  hintText: 'Buscar ${widget.label.toLowerCase()}…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('Sin resultados',
                          style: EnjoyTheme.body(color: ec.textMute)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: ec.stroke),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final sel = item.id == widget.value;
                        return ListTile(
                          title: Text(item.label,
                              style: EnjoyTheme.body(
                                  size: 14,
                                  color: ec.text,
                                  weight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                          trailing: sel
                              ? Icon(Icons.check_rounded,
                                  color: ec.orange, size: 20)
                              : null,
                          onTap: () => Navigator.of(context).pop(item.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
