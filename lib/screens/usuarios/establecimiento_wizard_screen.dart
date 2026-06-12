import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/usuarios/establecimiento_detalle_screen.dart' show SearchableChips;
import 'package:enjoy/screens/usuarios/establecimiento_form_screen.dart' show SearchablePickerField;
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/services/geocoding_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/widgets/horario_builder.dart';
import 'package:enjoy/utils/image_pick.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Asistente guiado por pasos para crear un establecimiento.
/// Recoge TODO (datos, ubicación/categorías, promoción/horarios, imágenes y
/// catálogo) y crea el establecimiento en un solo POST. Se crea como Inactivo.
class EstablecimientoWizardScreen extends StatefulWidget {
  /// Si se pasa un establecimiento, el wizard entra en modo EDICIÓN
  /// (precarga datos y permite guardar cada sección por separado).
  final Map<String, dynamic>? establecimiento;
  const EstablecimientoWizardScreen({super.key, this.establecimiento});

  @override
  State<EstablecimientoWizardScreen> createState() =>
      _EstablecimientoWizardScreenState();
}

class _EstablecimientoWizardScreenState
    extends State<EstablecimientoWizardScreen> {
  final _svc = EstablecimientosEmpresaService();
  final _ciudadesSvc = CiudadesService();
  final _categoriasSvc = CategoriasService();

  // ── Estado de carga de referencias ──
  bool _loadingRefs = true;
  bool _saving = false;
  List<Provincia> _provincias = [];
  List<Ciudad> _ciudades = [];
  List<Categoria> _categorias = [];
  String? _selProvincia;
  bool _loadingCiudades = false;

  // ── Pasos ──
  static const _labels = [
    'Datos',
    'Ubicación',
    'Promoción',
    'Imágenes',
    'Catálogo',
  ];
  int _step = 0;
  bool _menuOpen = true; // true = menú de secciones; false = sección abierta

  // ── Campos: Datos ──
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _identificacion = TextEditingController();
  final _telefono = TextEditingController();
  bool _estado = false;

  // ── Campos: Ubicación y categorías ──
  final List<String> _selCiudades = [];
  final List<String> _selCategorias = [];
  final _direccion = TextEditingController();
  double? _lat;
  double? _lng;
  bool _geoLoading = false;

  // ── Campos: Promoción ──
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  String _horarioLabel = '';
  bool _aplicaTodosLosDias = true;
  final List<String> _diasAplicables = [];
  final Map<String, Map<String, String>> _horarioPorDia = {};
  final List<String> _tags = [];
  final _tagInput = TextEditingController();
  static const _dias = [
    'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'
  ];

  // ── Campos: Imágenes ──
  String? _logoBase64; // foto nueva (data URL)
  String? _logoUrl; // foto existente (edición)
  final List<Map<String, String>> _galeria = []; // {base64} o {url}
  static const int _maxGaleria = 5;

  // ── Campos: Catálogo ──
  // cada item: {base64|url, nombre, descripcion}
  final List<Map<String, String>> _productos = [];

  // ── Edición ──
  bool get _isEdit => widget.establecimiento != null;
  String? _id;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
    _cargarReferencias();
  }

  /// Precarga el estado desde el establecimiento (modo edición).
  void _prefill() {
    final e = widget.establecimiento!;
    _id = e['_id']?.toString();
    _nombre.text = e['nombre']?.toString() ?? '';
    _email.text = (e['email'] ?? e['correo'] ?? '').toString();
    _identificacion.text = e['identificacion']?.toString() ?? '';
    _telefono.text = _desformatearTel(e['telefono']?.toString() ?? '');
    _estado = e['estado'] != false;

    _selProvincia = e['provinciaId']?.toString();
    final cids = e['ciudades'];
    if (cids is List) {
      _selCiudades.addAll(cids
          .map((c) => c is Map ? (c['_id'] ?? '').toString() : c.toString())
          .where((s) => s.isNotEmpty && _isObjectId(s)));
    }
    final cats = e['categorias'];
    if (cats is List) {
      _selCategorias.addAll(cats
          .map((c) => c is Map ? (c['_id'] ?? '').toString() : c.toString())
          .where((s) => s.isNotEmpty && _isObjectId(s)));
    }
    final ub = e['ubicacion'];
    if (ub is Map) {
      _lat = (ub['lat'] as num?)?.toDouble();
      _lng = (ub['lng'] as num?)?.toDouble();
    }

    final d = e['detallePromocion'];
    final dp = d is Map ? d : {};
    _titulo.text = dp['title']?.toString() ?? '';
    _descripcion.text = dp['description']?.toString() ?? '';
    _horarioLabel = dp['scheduleLabel']?.toString() ?? '';
    _direccion.text = dp['address']?.toString() ?? '';
    _aplicaTodosLosDias = dp['aplicaTodosLosDias'] != false;
    final t = dp['tags'];
    if (t is List) _tags.addAll(t.map((e) => e.toString()));
    final dias = dp['diasAplicables'];
    if (dias is List) _diasAplicables.addAll(dias.map((e) => e.toString()));
    final hpd = dp['horarioPorDia'];
    if (hpd is Map) {
      hpd.forEach((k, v) {
        if (v is Map) {
          _horarioPorDia[k.toString()] = {
            'abre': v['abre']?.toString() ?? '09:00',
            'cierra': v['cierra']?.toString() ?? '18:00',
          };
        }
      });
    }
    _logoUrl = dp['logoUrl']?.toString();
    final gal = dp['galeria'];
    if (gal is List) {
      for (final m in gal) {
        if (m is Map && (m['url']?.toString() ?? '').isNotEmpty) {
          _galeria.add({'url': m['url'].toString()});
        }
      }
    }
    final prods = dp['productos'];
    if (prods is List) {
      for (final p in prods) {
        if (p is Map && (p['url']?.toString() ?? '').isNotEmpty) {
          _productos.add({
            'url': p['url'].toString(),
            'nombre': p['nombre']?.toString() ?? '',
            'descripcion': p['descripcion']?.toString() ?? '',
          });
        }
      }
    }
  }

  String _desformatearTel(String tel) {
    if (tel.isEmpty) return tel;
    var limpio = tel.replaceAll(RegExp(r'\D'), '');
    if (limpio.startsWith('593')) limpio = limpio.substring(3);
    // Restaurar el 0 inicial del formato local (ej. 999... → 0999...).
    if (limpio.length == 9 && limpio.startsWith('9')) limpio = '0$limpio';
    return limpio;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _identificacion.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _titulo.dispose();
    _descripcion.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _cargarReferencias() async {
    try {
      final provincias = await _ciudadesSvc.getProvincias();
      final categorias = await _categoriasSvc.getActivas();
      // En edición, cargar las ciudades de la provincia precargada.
      final ciudades = _selProvincia == null
          ? <Ciudad>[]
          : await _ciudadesSvc.getParaPromosPorProvincia(_selProvincia!);
      if (!mounted) return;
      setState(() {
        _provincias = provincias;
        _categorias = categorias;
        _ciudades = ciudades;
        _loadingRefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRefs = false);
    }
  }

  Future<void> _onProvinciaChange(String? id) async {
    if (id == _selProvincia) return;
    setState(() {
      _selProvincia = id;
      _selCiudades.clear();
      _ciudades = [];
      _loadingCiudades = id != null;
    });
    if (id == null) return;
    try {
      final ciudades = await _ciudadesSvc.getParaPromosPorProvincia(id);
      if (!mounted) return;
      setState(() {
        _ciudades = ciudades;
        _loadingCiudades = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCiudades = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? ec.green : ec.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Builders de payload (reutilizados por crear y guardar-por-sección) ──
  Map<String, dynamic> _datosPayload() {
    final p = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'identificacion': _identificacion.text.trim(),
      'estado': _estado,
    };
    final tel = _telefono.text.trim();
    if (tel.isNotEmpty) {
      p['telefono'] = '+593${tel.replaceFirst(RegExp(r'^0'), '')}';
    }
    return p;
  }

  Map<String, dynamic> _ubicacionPayload() {
    final p = <String, dynamic>{
      'categorias': _selCategorias.where(_isObjectId).toList(),
      'ciudades': _selCiudades.where(_isObjectId).toList(),
    };
    if (_lat != null && _lng != null) {
      p['ubicacion'] = {'lat': _lat, 'lng': _lng};
    }
    return p;
  }

  Map<String, dynamic> _promoDetalle() {
    final d = <String, dynamic>{
      'title': _titulo.text.trim(),
      'placeName': _nombre.text.trim(),
      'description': _descripcion.text.trim(),
      'scheduleLabel': _horarioLabel.trim(),
      'address': _direccion.text.trim(),
      'isTwoForOne': true,
      'aplicaTodosLosDias': _aplicaTodosLosDias,
    };
    if (_tags.isNotEmpty) d['tags'] = _tags;
    if (!_aplicaTodosLosDias && _diasAplicables.isNotEmpty) {
      d['diasAplicables'] = _diasAplicables;
      d['horarioPorDia'] = _horarioPorDia;
    }
    return d;
  }

  List<Map<String, dynamic>> _galeriaPayload() => _galeria.map((m) {
        if ((m['base64'] ?? '').isNotEmpty) {
          return {'base64': m['base64'], 'type': 'image'};
        }
        return {'url': m['url'], 'type': 'image'};
      }).toList();

  List<Map<String, dynamic>> _productosPayload() => _productos
      .where((p) =>
          (p['base64'] ?? '').isNotEmpty || (p['url'] ?? '').isNotEmpty)
      .map((p) {
        final out = <String, dynamic>{'nombre': (p['nombre'] ?? '').trim()};
        if ((p['descripcion'] ?? '').trim().isNotEmpty) {
          out['descripcion'] = (p['descripcion'] ?? '').trim();
        }
        if ((p['base64'] ?? '').isNotEmpty) {
          out['base64'] = p['base64'];
        } else {
          out['url'] = p['url'];
        }
        return out;
      })
      .toList();

  // ── Crear (POST) o, en edición, guardar TODO (PATCH) ──
  Future<void> _crear() async {
    setState(() => _saving = true);
    try {
      final detalle = _promoDetalle();
      if (_logoBase64 != null) detalle['logoBase64'] = _logoBase64;
      detalle['galeria'] = _galeriaPayload();
      detalle['productos'] = _productosPayload();

      final payload = <String, dynamic>{
        ..._datosPayload(),
        ..._ubicacionPayload(),
        'detallePromocion': detalle,
      };
      if (!_isEdit) payload['rol'] = 'admin-local';

      if (_isEdit) {
        await _svc.actualizar(_id!, payload);
        if (!mounted) return;
        _snack('Cambios guardados', ok: true);
      } else {
        await _svc.crear(payload);
        if (!mounted) return;
        _snack('Establecimiento creado. Se envió la clave por correo.', ok: true);
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Guardar SOLO la sección actual (edición) ──
  Future<void> _guardarSeccion() async {
    if (!_isEdit || _id == null) return;
    Map<String, dynamic> payload;
    switch (_step) {
      case 0:
        payload = _datosPayload();
        break;
      case 1:
        payload = _ubicacionPayload();
        break;
      case 2:
        payload = {'detallePromocion': _promoDetalle()};
        break;
      case 3:
        final dp = <String, dynamic>{'galeria': _galeriaPayload()};
        if (_logoBase64 != null) dp['logoBase64'] = _logoBase64;
        payload = {'detallePromocion': dp};
        break;
      case 4:
        payload = {
          'detallePromocion': {'productos': _productosPayload()}
        };
        break;
      default:
        return;
    }
    setState(() => _saving = true);
    try {
      await _svc.actualizar(_id!, payload);
      if (mounted) _snack('Sección guardada', ok: true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isObjectId(String v) => RegExp(r'^[a-f\d]{24}$').hasMatch(v);

  /// Renderiza la imagen de un item {base64} o {url}.
  Widget _itemImage(Map<String, String> item, {BoxFit fit = BoxFit.cover}) {
    final ec = context.ec;
    final b64 = item['base64'];
    if (b64 != null && b64.isNotEmpty) {
      return Image.memory(bytesFromDataUrl(b64)!, fit: fit);
    }
    final url = item['url'];
    if (url != null && url.isNotEmpty) {
      return EnjoyImage(url,
          fit: fit,
          errorWidget: Container(
              color: ec.glassStrong,
              child: Icon(Icons.broken_image_rounded, color: ec.textMute)));
    }
    return Container(color: ec.glassStrong);
  }

  // ── Imágenes ──
  Future<void> _pickLogo() async {
    final b = await pickAndCropImage();
    if (b != null && mounted) setState(() => _logoBase64 = b);
  }

  Future<void> _addGaleria() async {
    if (_galeria.length >= _maxGaleria) {
      _snack('Máximo $_maxGaleria fotos en la galería');
      return;
    }
    final b = await pickAndCropImage();
    if (b != null && mounted) setState(() => _galeria.add({'base64': b}));
  }

  Future<void> _addProducto() async {
    final b = await pickAndCropImage();
    if (b == null || !mounted) return;
    final datos = await _dialogoProducto();
    if (datos == null || !mounted) return;
    setState(() => _productos.add(
        {'base64': b, 'nombre': datos.$1, 'descripcion': datos.$2}));
  }

  Future<(String, String)?> _dialogoProducto(
      {String nombre = '', String descripcion = ''}) async {
    final ec = context.ec;
    final n = TextEditingController(text: nombre);
    final d = TextEditingController(text: descripcion);
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Producto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(n, 'Nombre', autofocus: true),
          const SizedBox(height: 10),
          _dialogField(d, 'Descripción (opcional)', lines: 3),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: EnjoyTheme.body(color: ec.textMute))),
          ElevatedButton(
            onPressed: () {
              if (n.text.trim().isEmpty) return;
              Navigator.pop(ctx, (n.text.trim(), d.text.trim()));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    n.dispose();
    d.dispose();
    return res;
  }

  Widget _dialogField(TextEditingController c, String label,
      {bool autofocus = false, int lines = 1}) {
    final ec = context.ec;
    return TextField(
      controller: c,
      autofocus: autofocus,
      minLines: lines,
      maxLines: lines,
      style: EnjoyTheme.body(size: 14, color: ec.text),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _usarGps() async {
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
      // Autocompleta la dirección desde las coordenadas (igual que la web).
      final dir = await GeocodingService.reverse(pos.latitude, pos.longitude);
      if (mounted && dir != null && dir.isNotEmpty) {
        setState(() => _direccion.text = dir);
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
          title: _isEdit ? 'Editar establecimiento' : 'Nuevo establecimiento'),
      body: _loadingRefs
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : (_menuOpen ? _buildMenu(ec) : _buildSeccionView(ec)),
    );
  }

  static const _secciones = [
    (i: 0, icon: Icons.store_rounded, sub: 'Nombre, correo, identificación, teléfono'),
    (i: 1, icon: Icons.place_outlined, sub: 'Provincia, ciudades, categorías y GPS'),
    (i: 2, icon: Icons.local_offer_outlined, sub: 'Título, descripción y horario'),
    (i: 3, icon: Icons.photo_library_outlined, sub: 'Logo y galería del local'),
    (i: 4, icon: Icons.restaurant_menu_outlined, sub: 'Productos/servicios con foto'),
  ];

  // ── Menú de secciones ──
  Widget _buildMenu(EnjoyColors ec) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        if (_isEdit) ...[
          GlassCard(
            accent: true,
            child: Row(
              children: [
                const IconBox(Icons.storefront_rounded, accent: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre.text.trim().isEmpty
                            ? 'Establecimiento'
                            : _nombre.text.trim(),
                        style: EnjoyTheme.heading(size: 16, color: ec.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('Toca una sección para editarla',
                          style:
                              EnjoyTheme.body(size: 12, color: ec.textMute)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_estado ? 'Activo' : 'Inactivo',
                          style: EnjoyTheme.heading(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _estado ? ec.text : ec.textMute)),
                      const SizedBox(height: 2),
                      Text(_estado ? 'Visible en la app' : 'Oculto en la app',
                          style:
                              EnjoyTheme.body(size: 12, color: ec.textMute)),
                    ],
                  ),
                ),
                EnjoyToggle(
                  value: _estado,
                  onChanged: (v) async {
                    setState(() => _estado = v);
                    if (_isEdit && _id != null) {
                      try {
                        await _svc.actualizar(_id!, {'estado': v});
                        if (mounted) _snack('Estado actualizado', ok: true);
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._secciones.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListRowTile(
                leading: IconBox(s.icon),
                title: _labels[s.i],
                subtitle: s.sub,
                trailing:
                    Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => setState(() {
                  _step = s.i;
                  _menuOpen = false;
                }),
              ),
            )),
        if (!_isEdit) ...[
          const SizedBox(height: 16),
          EnjoyButton(
            label: 'Crear establecimiento',
            icon: Icons.add_business_rounded,
            loading: _saving,
            onPressed: _saving ? null : _crear,
          ),
        ],
      ],
    );
  }

  // ── Vista de una sección ──
  Widget _buildSeccionView(EnjoyColors ec) {
    final builders = [
      _stepDatos,
      _stepUbicacion,
      _stepPromocion,
      _stepImagenes,
      _stepCatalogo,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _menuOpen = true),
              ),
              Expanded(
                child: Text(_labels[_step],
                    style: EnjoyTheme.heading(size: 18, color: ec.text)),
              ),
            ],
          ),
        ),
        Expanded(child: builders[_step]()),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: Row(
            children: [
              Expanded(
                child: EnjoyButton(
                  label: 'Volver al menú',
                  variant: EnjoyButtonVariant.ghost,
                  dense: true,
                  onPressed: _saving ? null : () => setState(() => _menuOpen = true),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: EnjoyButton(
                    label: 'Guardar',
                    icon: Icons.check_rounded,
                    dense: true,
                    loading: _saving,
                    onPressed: _saving
                        ? null
                        : () async {
                            await _guardarSeccion();
                            if (mounted) setState(() => _menuOpen = true);
                          },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════ PASOS ════════════════════════
  Widget _stepScroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        children: children,
      );

  Widget _hint(String t) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t, style: EnjoyTheme.body(size: 12.5, color: ec.textMute)),
    );
  }

  Widget _label(String t, {bool req = false}) =>
      FieldLabel(req ? '$t *' : t);

  Widget _input(TextEditingController c, String hint,
      {TextInputType? kb, int lines = 1}) {
    final ec = context.ec;
    return TextField(
      controller: c,
      keyboardType: kb,
      minLines: lines,
      maxLines: lines,
      style: EnjoyTheme.body(size: 14, color: ec.text),
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: EnjoyTheme.body(size: 14, color: ec.text))),
          EnjoyToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Paso 1: Datos ──
  Widget _stepDatos() => _stepScroll([
        _hint('Datos de contacto del local. Se creará como Inactivo y se enviará una clave por correo.'),
        _label('Nombre del establecimiento', req: true),
        _input(_nombre, 'Ej: Pizzería Roma'),
        const SizedBox(height: 14),
        _label('Correo electrónico', req: true),
        _input(_email, 'correo@ejemplo.com', kb: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _label('Identificación (CI / RUC)', req: true),
        _input(_identificacion, 'CI 10 dígitos o RUC 13', kb: TextInputType.number),
        const SizedBox(height: 14),
        _label('Teléfono'),
        _input(_telefono, '0999999999', kb: TextInputType.phone),
        const SizedBox(height: 6),
        _switch('Activo (visible al cliente)', _estado, (v) => setState(() => _estado = v)),
      ]);

  // ── Paso 2: Ubicación y categorías ──
  Widget _stepUbicacion() {
    final ec = context.ec;
    return _stepScroll([
      _hint('¿Dónde está y qué tipo de local es? Elige la provincia, sus ciudades y al menos una categoría.'),
      _label('Provincia', req: true),
      SearchablePickerField(
        label: 'Provincia',
        icon: Icons.map_rounded,
        value: _selProvincia,
        items: _provincias.map((p) => (id: p.id, label: p.nombre)).toList(),
        onChanged: _onProvinciaChange,
      ),
      const SizedBox(height: 14),
      _label('Ciudades', req: true),
      if (_selProvincia == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Selecciona primero una provincia.',
              style: EnjoyTheme.body(size: 13, color: ec.textMute)),
        )
      else if (_loadingCiudades)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Cargando ciudades…',
              style: EnjoyTheme.body(size: 13, color: ec.textMute)),
        )
      else
        SearchableChips(
          items: _ciudades.map((c) => (id: c.id, label: c.nombre)).toList(),
          selected: _selCiudades,
          color: ec.blue,
          hint: 'Buscar ciudad',
          emptyText: 'No hay ciudades en esta provincia',
          onToggle: (id) => setState(() => _selCiudades.contains(id)
              ? _selCiudades.remove(id)
              : _selCiudades.add(id)),
        ),
      const SizedBox(height: 8),
      _label('Categorías', req: true),
      SearchableChips(
        items: _categorias.map((c) => (id: c.id, label: c.nombre)).toList(),
        selected: _selCategorias,
        color: ec.orange,
        hint: 'Buscar categoría',
        emptyText: 'No hay categorías disponibles',
        onToggle: (id) => setState(() => _selCategorias.contains(id)
            ? _selCategorias.remove(id)
            : _selCategorias.add(id)),
      ),
      const SizedBox(height: 8),
      _label('Dirección'),
      _input(_direccion, 'Calle, número, referencia'),
      const SizedBox(height: 14),
      _label('Ubicación en el mapa (GPS)'),
      EnjoyButton(
        label: _geoLoading ? 'Obteniendo…' : 'Usar mi ubicación',
        icon: Icons.my_location_rounded,
        variant: EnjoyButtonVariant.ghost,
        loading: _geoLoading,
        onPressed: _geoLoading ? null : _usarGps,
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
    ]);
  }

  // ── Paso 3: Promoción y horarios ──
  Widget _stepPromocion() {
    final ec = context.ec;
    return _stepScroll([
      _hint('La promoción principal y el horario que verá el cliente.'),
      _label('Título de la promoción', req: true),
      _input(_titulo, 'Ej: 2x1 en pizzas'),
      const SizedBox(height: 14),
      _label('Horario de la promoción', req: true),
      _hint('Elige días y rango de hora; el texto se arma solo en formato estándar.'),
      if (_horarioLabel.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Actual: $_horarioLabel',
              style: EnjoyTheme.body(
                  size: 13, weight: FontWeight.w600, color: ec.text)),
        ),
      HorarioBuilder(
        onChanged: (v) => setState(() => _horarioLabel = v),
      ),
      const SizedBox(height: 14),
      _label('Descripción'),
      _input(_descripcion, 'Describe la promoción…', lines: 3),
      const SizedBox(height: 6),
      // 2x1 ya no es editable: todas las promos son 2x1 (siempre true).
      _switch('Aplica todos los días', _aplicaTodosLosDias,
          (v) => setState(() => _aplicaTodosLosDias = v)),
      if (!_aplicaTodosLosDias) ...[
        const SizedBox(height: 8),
        _label('Días que aplica', req: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dias.map((d) {
            final sel = _diasAplicables.contains(d);
            return Pill(
              d,
              variant: sel ? PillVariant.orange : PillVariant.glass,
              onTap: () => setState(() {
                if (sel) {
                  _diasAplicables.remove(d);
                  _horarioPorDia.remove(d);
                } else {
                  _diasAplicables.add(d);
                  _horarioPorDia[d] = {'abre': '09:00', 'cierra': '18:00'};
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        for (final d in _diasAplicables) _horarioRow(d),
      ],
      const SizedBox(height: 14),
      _label('Etiquetas (tags)'),
      Row(children: [
        Expanded(child: _input(_tagInput, 'Agregar etiqueta')),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.add_rounded,
          accent: true,
          onTap: () {
            final t = _tagInput.text.trim();
            if (t.isNotEmpty && !_tags.contains(t)) {
              setState(() {
                _tags.add(t);
                _tagInput.clear();
              });
            }
          },
        ),
      ]),
      if (_tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags
                .map((t) => Pill(
                      t,
                      variant: PillVariant.glass,
                      icon: Icons.close_rounded,
                      onTap: () => setState(() => _tags.remove(t)),
                    ))
                .toList(),
          ),
        ),
    ]);
  }

  Widget _horarioRow(String dia) {
    final ec = context.ec;
    final h = _horarioPorDia[dia] ?? {'abre': '09:00', 'cierra': '18:00'};
    Future<void> pick(String key) async {
      final parts = (h[key] ?? '09:00').split(':');
      final res = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0),
      );
      if (res != null) {
        setState(() {
          final hh = res.hour.toString().padLeft(2, '0');
          final mm = res.minute.toString().padLeft(2, '0');
          _horarioPorDia[dia] = {...h, key: '$hh:$mm'};
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(dia,
                  style: EnjoyTheme.heading(size: 13, color: ec.text))),
          _timeChip(h['abre'] ?? '09:00', () => pick('abre')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('—', style: EnjoyTheme.body(color: ec.textMute)),
          ),
          _timeChip(h['cierra'] ?? '18:00', () => pick('cierra')),
        ],
      ),
    );
  }

  Widget _timeChip(String value, VoidCallback onTap) =>
      Pill(value, variant: PillVariant.glass, onTap: onTap);

  // ── Paso 4: Imágenes ──
  Widget _stepImagenes() {
    final ec = context.ec;
    return _stepScroll([
      _hint('Logo y galería del local. La portada se toma de la primera foto de la galería.'),
      _label('Logo'),
      GestureDetector(
        onTap: _pickLogo,
        child: Container(
          height: 110,
          width: 110,
          decoration: BoxDecoration(
            color: ec.glass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ec.orange.withValues(alpha: 0.4), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: _logoBase64 != null
              ? Image.memory(bytesFromDataUrl(_logoBase64)!, fit: BoxFit.cover)
              : (_logoUrl != null && _logoUrl!.isNotEmpty)
                  ? EnjoyImage(_logoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                          Icons.broken_image_rounded, color: ec.textMute))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded,
                            color: ec.orangeSoft, size: 26),
                        const SizedBox(height: 4),
                        Text('Logo',
                            style: EnjoyTheme.body(
                                size: 11,
                                weight: FontWeight.w600,
                                color: ec.orangeSoft)),
                      ],
                    ),
        ),
      ),
      const SizedBox(height: 20),
      _label('Galería (${_galeria.length}/$_maxGaleria)'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < _galeria.length; i++)
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _itemImage(_galeria[i]),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _galeria.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          if (_galeria.length < _maxGaleria)
            GestureDetector(
              onTap: _addGaleria,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: ec.glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: ec.orange.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: ec.orangeSoft, size: 24),
                    const SizedBox(height: 4),
                    Text('Foto',
                        style: EnjoyTheme.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: ec.orangeSoft)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ]);
  }

  // ── Paso 5: Catálogo ──
  Widget _stepCatalogo() {
    final ec = context.ec;
    return _stepScroll([
      _hint('Productos o servicios que ofrece el local (foto + nombre + descripción). Sin límite.'),
      for (var i = 0; i < _productos.length; i++) _productoCard(i),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: _addProducto,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ec.glass,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: ec.orange.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: ec.orangeSoft),
              const SizedBox(width: 6),
              Text('Agregar producto',
                  style: EnjoyTheme.heading(size: 13, color: ec.orangeSoft)),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _productoCard(int i) {
    final ec = context.ec;
    final p = _productos[i];
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 64,
            height: 64,
            child: _itemImage(p),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['nombre'] ?? '',
                style: EnjoyTheme.heading(size: 14, color: ec.text)),
            if ((p['descripcion'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p['descripcion']!,
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () async {
                  final d = await _dialogoProducto(
                      nombre: p['nombre'] ?? '', descripcion: p['descripcion'] ?? '');
                  if (d != null) {
                    setState(() {
                      _productos[i]['nombre'] = d.$1;
                      _productos[i]['descripcion'] = d.$2;
                    });
                  }
                },
                child: Icon(Icons.edit_rounded, size: 18, color: ec.textSoft),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => setState(() => _productos.removeAt(i)),
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: ec.red),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

}
