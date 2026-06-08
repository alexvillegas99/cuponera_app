import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/usuarios/establecimiento_detalle_screen.dart' show SearchableChips;
import 'package:enjoy/screens/usuarios/establecimiento_form_screen.dart' show SearchablePickerField;
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
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
  final _page = PageController();

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
    'Resumen',
  ];
  int _step = 0;

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
  bool _isTwoForOne = false;
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
    _isTwoForOne = dp['isTwoForOne'] == true;
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
    return limpio;
  }

  @override
  void dispose() {
    _page.dispose();
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

  // ── Navegación ──
  void _next() {
    if (!_validarPaso(_step)) return;
    if (_step < _labels.length - 1) {
      setState(() => _step++);
      _page.animateToPage(_step,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _page.animateToPage(_step,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green.shade700 : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Validación por paso ──
  bool _validarPaso(int step) {
    final errores = _erroresPaso(step);
    if (errores.isNotEmpty) {
      _snack(errores.first);
      return false;
    }
    return true;
  }

  List<String> _erroresPaso(int step) {
    final e = <String>[];
    switch (step) {
      case 0:
        if (_nombre.text.trim().isEmpty) e.add('El nombre es obligatorio');
        final email = _email.text.trim();
        if (email.isEmpty) {
          e.add('El email es obligatorio');
        } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
          e.add('Ingresa un email válido');
        }
        final id = _identificacion.text.trim();
        if (id.isEmpty) {
          e.add('La identificación es obligatoria');
        } else if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(id)) {
          e.add('CI (10 dígitos) o RUC (13 dígitos)');
        }
        final tel = _telefono.text.trim();
        if (tel.isNotEmpty &&
            !RegExp(r'^[0-9]{7,10}$').hasMatch(tel.replaceFirst(RegExp(r'^0'), ''))) {
          e.add('Teléfono inválido (7-10 dígitos)');
        }
        break;
      case 1:
        if (_selProvincia == null) e.add('Selecciona la provincia');
        if (_selCiudades.isEmpty) e.add('Selecciona al menos una ciudad');
        if (_selCategorias.isEmpty) e.add('Selecciona al menos una categoría');
        break;
      case 2:
        if (_titulo.text.trim().isEmpty) e.add('El título de la promoción es obligatorio');
        if (_horarioLabel.trim().isEmpty) {
          e.add('Arma el horario de la promoción');
        }
        if (!_aplicaTodosLosDias && _diasAplicables.isEmpty) {
          e.add('Selecciona al menos un día o marca "Aplica todos los días"');
        }
        break;
      case 4:
        for (var i = 0; i < _productos.length; i++) {
          final p = _productos[i];
          final foto = (p['base64'] ?? '').isNotEmpty;
          final nom = (p['nombre'] ?? '').trim().isNotEmpty;
          if (foto && !nom) e.add('Producto ${i + 1}: falta el nombre');
          if (nom && !foto) e.add('Producto ${i + 1}: falta la foto');
        }
        break;
    }
    return e;
  }

  List<String> get _faltantes {
    final all = <String>[];
    for (var s = 0; s <= 2; s++) {
      all.addAll(_erroresPaso(s));
    }
    all.addAll(_erroresPaso(4));
    return all;
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
    final faltan = _faltantes;
    if (faltan.isNotEmpty) {
      _snack(faltan.first);
      return;
    }
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
    final b64 = item['base64'];
    if (b64 != null && b64.isNotEmpty) {
      return Image.memory(bytesFromDataUrl(b64)!, fit: fit);
    }
    final url = item['url'];
    if (url != null && url.isNotEmpty) {
      return Image.network(url,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
              color: Palette.kSurface,
              child: const Icon(Icons.broken_image_rounded, color: Palette.kMuted)));
    }
    return Container(color: Palette.kField);
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
    final n = TextEditingController(text: nombre);
    final d = TextEditingController(text: descripcion);
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.kSurface,
        title: const Text('Producto',
            style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(n, 'Nombre', autofocus: true),
          const SizedBox(height: 10),
          _dialogField(d, 'Descripción (opcional)', lines: 3),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Palette.kMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Palette.kAccent),
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
    return TextField(
      controller: c,
      autofocus: autofocus,
      minLines: lines,
      maxLines: lines,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
        filled: true,
        fillColor: Palette.kField,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Palette.kTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? 'Editar establecimiento' : 'Nuevo establecimiento',
            style: TextStyle(
                color: Palette.kTitle, fontWeight: FontWeight.w800, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Palette.kBorder),
        ),
      ),
      body: _loadingRefs
          ? const Center(child: CircularProgressIndicator(color: Palette.kAccent))
          : Column(
              children: [
                _buildStepper(),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _stepDatos(),
                      _stepUbicacion(),
                      _stepPromocion(),
                      _stepImagenes(),
                      _stepCatalogo(),
                      _stepResumen(),
                    ],
                  ),
                ),
                _buildNav(),
              ],
            ),
    );
  }

  // ── Indicador de pasos ──
  Widget _buildStepper() {
    return Container(
      color: Palette.kSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paso ${_step + 1} de ${_labels.length} · ${_labels[_step]}',
              style: const TextStyle(
                  color: Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _labels.length; i++) ...[
                _dot(i),
                if (i < _labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < _step ? Palette.kAccent : Palette.kBorder,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(int i) {
    final done = i < _step;
    final active = i == _step;
    return GestureDetector(
      onTap: i <= _step
          ? () {
              setState(() => _step = i);
              _page.animateToPage(i,
                  duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
            }
          : null,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Palette.kAccent : (done ? Palette.kAccent.withOpacity(0.15) : Palette.kField),
          shape: BoxShape.circle,
          border: Border.all(
              color: active || done ? Palette.kAccent : Palette.kBorder, width: 1.5),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 15, color: Palette.kAccent)
            : Text('${i + 1}',
                style: TextStyle(
                    color: active ? Colors.white : Palette.kMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Navegación inferior ──
  Widget _buildNav() {
    final last = _step == _labels.length - 1;
    return Container(
      color: Palette.kSurface,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _saving ? null : _prev,
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              label: const Text('Atrás'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.kTitle,
                side: BorderSide(color: Palette.kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          // En edición: guardar SOLO esta sección (no en el resumen)
          if (_isEdit && !last) ...[
            OutlinedButton.icon(
              onPressed: _saving ? null : _guardarSeccion,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Guardar sección'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.kAccent,
                side: const BorderSide(color: Palette.kAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          if (!last)
            ElevatedButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('Siguiente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              ),
            )
          else
            ElevatedButton(
              onPressed: _saving ? null : _crear,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Guardar cambios' : 'Crear establecimiento',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ════════════════════════ PASOS ════════════════════════
  Widget _stepScroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(20),
        children: children,
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t, style: const TextStyle(color: Palette.kMuted, fontSize: 12.5)),
      );

  Widget _label(String t, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: RichText(
          text: TextSpan(
            text: t,
            style: const TextStyle(
                color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600),
            children: req
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))]
                : null,
          ),
        ),
      );

  Widget _input(TextEditingController c, String hint,
      {TextInputType? kb, int lines = 1}) {
    return TextField(
      controller: c,
      keyboardType: kb,
      minLines: lines,
      maxLines: lines,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
        filled: true,
        fillColor: Palette.kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Palette.kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Palette.kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kAccent)),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Palette.kTitle, fontSize: 14))),
          Switch(
            value: value,
            activeColor: Palette.kAccent,
            onChanged: onChanged,
          ),
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
  Widget _stepUbicacion() => _stepScroll([
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Selecciona primero una provincia.',
                style: TextStyle(color: Palette.kMuted, fontSize: 13)),
          )
        else if (_loadingCiudades)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Cargando ciudades…',
                style: TextStyle(color: Palette.kMuted, fontSize: 13)),
          )
        else
          SearchableChips(
            items: _ciudades.map((c) => (id: c.id, label: c.nombre)).toList(),
            selected: _selCiudades,
            color: Palette.kPrimary,
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
          color: Palette.kAccent,
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
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _geoLoading ? null : _usarGps,
              icon: _geoLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(_geoLoading ? 'Obteniendo…' : 'Usar mi ubicación'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.kAccent,
                side: const BorderSide(color: Palette.kAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
        if (_lat != null && _lng != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('📍 ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
          ),
      ]);

  // ── Paso 3: Promoción y horarios ──
  Widget _stepPromocion() => _stepScroll([
        _hint('La promoción principal y el horario que verá el cliente.'),
        _label('Título de la promoción', req: true),
        _input(_titulo, 'Ej: 2x1 en pizzas'),
        const SizedBox(height: 14),
        _label('Horario de la promoción', req: true),
        _hint('Elige días y rango de hora; el texto se arma solo en formato estándar.'),
        if (_horarioLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Actual: $_horarioLabel',
                style: const TextStyle(
                    color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600)),
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
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _diasAplicables.remove(d);
                    _horarioPorDia.remove(d);
                  } else {
                    _diasAplicables.add(d);
                    _horarioPorDia[d] = {'abre': '09:00', 'cierra': '18:00'};
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? Palette.kAccent : Palette.kField,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Palette.kAccent : Palette.kBorder),
                  ),
                  child: Text(d,
                      style: TextStyle(
                          color: sel ? Colors.white : Palette.kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
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
          IconButton(
            onPressed: () {
              final t = _tagInput.text.trim();
              if (t.isNotEmpty && !_tags.contains(t)) {
                setState(() {
                  _tags.add(t);
                  _tagInput.clear();
                });
              }
            },
            icon: const Icon(Icons.add_circle, color: Palette.kAccent),
          ),
        ]),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => _tags.remove(t)),
                        backgroundColor: Palette.kField,
                      ))
                  .toList(),
            ),
          ),
      ]);

  Widget _horarioRow(String dia) {
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
                  style: const TextStyle(
                      color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600))),
          _timeChip(h['abre'] ?? '09:00', () => pick('abre')),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('—', style: TextStyle(color: Palette.kMuted)),
          ),
          _timeChip(h['cierra'] ?? '18:00', () => pick('cierra')),
        ],
      ),
    );
  }

  Widget _timeChip(String value, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.kField,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Palette.kBorder),
          ),
          child: Text(value, style: const TextStyle(color: Palette.kTitle, fontSize: 13)),
        ),
      );

  // ── Paso 4: Imágenes ──
  Widget _stepImagenes() => _stepScroll([
        _hint('Logo y galería del local. La portada se toma de la primera foto de la galería.'),
        _label('Logo'),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.kAccent.withOpacity(0.4), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: _logoBase64 != null
                ? Image.memory(bytesFromDataUrl(_logoBase64)!, fit: BoxFit.cover)
                : (_logoUrl != null && _logoUrl!.isNotEmpty)
                ? Image.network(_logoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded, color: Palette.kMuted))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: Palette.kAccent, size: 26),
                      SizedBox(height: 4),
                      Text('Logo', style: TextStyle(color: Palette.kAccent, fontSize: 11)),
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
                    borderRadius: BorderRadius.circular(11),
                    child: _itemImage(_galeria[i]),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: GestureDetector(
                      onTap: () => setState(() => _galeria.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
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
                    color: Palette.kField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Palette.kAccent.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, color: Palette.kAccent, size: 24),
                      SizedBox(height: 4),
                      Text('Foto', style: TextStyle(color: Palette.kAccent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ]);

  // ── Paso 5: Catálogo ──
  Widget _stepCatalogo() => _stepScroll([
        _hint('Productos o servicios que ofrece el local (foto + nombre + descripción). Sin límite.'),
        for (var i = 0; i < _productos.length; i++) _productoCard(i),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _addProducto,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.kAccent.withOpacity(0.4), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Palette.kAccent),
                SizedBox(width: 6),
                Text('Agregar producto',
                    style: TextStyle(
                        color: Palette.kAccent, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ]);

  Widget _productoCard(int i) {
    final p = _productos[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.kField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
                style: const TextStyle(
                    color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w700)),
            if ((p['descripcion'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p['descripcion']!,
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 6),
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
                child: const Icon(Icons.edit_rounded, size: 18, color: Palette.kMuted),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => setState(() => _productos.removeAt(i)),
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red.shade400),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Paso 6: Resumen ──
  Widget _stepResumen() {
    final faltan = _faltantes;
    return _stepScroll([
      _hint('Revisa antes de crear.'),
      if (faltan.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              Text('Falta completar:',
                  style: TextStyle(
                      color: Colors.amber.shade900, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ...faltan.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $f',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12)),
                )),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Todo listo para crear el establecimiento.',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
            ),
          ]),
        ),
      const SizedBox(height: 16),
      _resumenRow('Nombre', _nombre.text.trim().isEmpty ? '—' : _nombre.text.trim()),
      _resumenRow('Email', _email.text.trim().isEmpty ? '—' : _email.text.trim()),
      _resumenRow('Ciudades / Categorías',
          '${_selCiudades.length} ciudad(es) · ${_selCategorias.length} categoría(s)'),
      _resumenRow('Promoción', _titulo.text.trim().isEmpty ? '—' : _titulo.text.trim()),
      _resumenRow('Galería', '${_galeria.length} foto(s)'),
      _resumenRow('Catálogo', '${_productos.length} producto(s)'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Palette.kAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.kAccent.withOpacity(0.25)),
        ),
        child: const Text(
          'Se creará como Inactivo. Un administrador deberá activarlo desde el panel para que aparezca al cliente. Se envía una clave temporal por correo.',
          style: TextStyle(color: Palette.kTitle, fontSize: 12),
        ),
      ),
    ]);
  }

  Widget _resumenRow(String k, String v) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Row(children: [
          Expanded(
              child: Text(k, style: const TextStyle(color: Palette.kMuted, fontSize: 12))),
          Text(v,
              style: const TextStyle(
                  color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}
