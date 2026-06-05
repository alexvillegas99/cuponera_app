import 'dart:convert';
import 'dart:io';
import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/models/media_item.dart';
import 'package:enjoy/models/producto.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/usuarios/establecimiento_form_screen.dart' show SearchablePickerField;
import 'package:enjoy/screens/usuarios/establecimiento_wizard_screen.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EstablecimientoDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> establecimiento;
  final bool canEdit;
  final bool canEditFotos;

  const EstablecimientoDetalleScreen({
    super.key,
    required this.establecimiento,
    this.canEdit = false,
    this.canEditFotos = false,
  });

  @override
  State<EstablecimientoDetalleScreen> createState() =>
      _EstablecimientoDetalleScreenState();
}

class _EstablecimientoDetalleScreenState
    extends State<EstablecimientoDetalleScreen> {
  final _svc = EstablecimientosEmpresaService();
  late Map<String, dynamic> _data;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.establecimiento);
  }

  // ── Helpers de datos ─────────────────────────────────────────────
  String get _nombre => (_data['nombre'] ?? 'Sin nombre').toString();
  bool get _activo => _data['estado'] != false && _data['activo'] != false;
  String get _email => (_data['email'] ?? _data['correo'] ?? '—').toString();
  String get _telefono => (_data['telefono'] ?? '—').toString();
  String get _identificacion => (_data['identificacion'] ?? '—').toString();
  String get _id => (_data['_id'] ?? '').toString();

  Map<String, dynamic> get _detalle {
    final d = _data['detallePromocion'];
    return d is Map<String, dynamic> ? d : {};
  }

  String get _titulo => (_detalle['title'] ?? '').toString();
  String get _descripcion => (_detalle['description'] ?? '').toString();
  String get _horario => (_detalle['scheduleLabel'] ?? '').toString();
  String get _direccion => (_detalle['address'] ?? '').toString();
  bool get _isTwoForOne => _detalle['isTwoForOne'] == true;
  String? get _logoUrl => _detalle['logoUrl']?.toString();

  List<String> get _tags {
    final t = _detalle['tags'];
    if (t is List) return t.map((e) => e.toString()).toList();
    return [];
  }

  List<String> get _categorias {
    final c = _data['categorias'];
    if (c is List) {
      return c.map((e) {
        if (e is Map) return (e['nombre'] ?? e['_id'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  List<String> get _ciudades {
    final c = _data['ciudades'];
    if (c is List) {
      return c.map((e) {
        if (e is Map) return (e['nombre'] ?? e['_id'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Map<String, dynamic>? get _ubicacion {
    final u = _data['ubicacion'];
    return u is Map<String, dynamic> ? u : null;
  }

  List<Map<String, dynamic>> get _promocionesExtra {
    final pe = _data['detallePromocionesExtra'];
    if (pe is List) return pe.map((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
    return [];
  }

  // ── Galería del local ────────────────────────────────────────────
  List<MediaItem> get _galeria => MediaItem.listFrom(_detalle['galeria']);
  static const int _maxGaleria = 5;
  static const int _maxVideoMb = 25;

  // ── Catálogo de productos del local ──────────────────────────────
  List<Producto> get _productos => Producto.listFrom(_detalle['productos']);

  /// Selecciona una imagen, la recorta (aspecto libre) y devuelve el data URL base64.
  Future<String?> _pickAndCropImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar',
          toolbarColor: Palette.kTitle,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Recortar',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null;

    final path = cropped.path;
    final bytes = await File(path).readAsBytes();
    final mime = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  // ── Edición de fotos (logo / imagen principal) ───────────────────
  Future<void> _editarFoto(String campo) async {
    final base64Str = await _pickAndCropImage();
    if (base64Str == null || !mounted) return;

    setState(() => _saving = true);
    try {
      // Send full detallePromocion with all existing fields preserved.
      // Both imageUrl and logoUrl are kept so the backend doesn't clear the
      // photo we are NOT updating. Old base64 fields are removed to avoid
      // reprocessing; only the new base64 for this specific photo is added.
      final detallePayload = Map<String, dynamic>.from(_detalle);
      detallePayload.remove('imageBase64');
      detallePayload.remove('logoBase64');
      detallePayload.remove('galeria'); // no reenviar la galería en esta operación
      detallePayload[campo] = base64Str;

      await _svc.actualizar(_id, {'detallePromocion': detallePayload});

      final fresh = await _svc.obtener(_id);
      if (fresh != null && mounted) setState(() => _data = fresh);

      if (mounted) _snack('Foto actualizada correctamente', success: true);
    } catch (e) {
      if (mounted) _snack('Error al guardar la foto');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Persiste la galería: conserva los items existentes (url+type) y aplica el cambio.
  Future<void> _guardarGaleria(List<Map<String, dynamic>> galeria) async {
    setState(() => _saving = true);
    try {
      final detallePayload = Map<String, dynamic>.from(_detalle);
      detallePayload.remove('imageBase64');
      detallePayload.remove('logoBase64');
      detallePayload['galeria'] = galeria;

      await _svc.actualizar(_id, {'detallePromocion': detallePayload});

      final fresh = await _svc.obtener(_id);
      if (fresh != null && mounted) setState(() => _data = fresh);

      if (mounted) _snack('Galería actualizada', success: true);
    } catch (e) {
      if (mounted) _snack('Error al guardar la galería');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Items existentes serializados como {url, type} para reenviar al backend.
  List<Map<String, dynamic>> _galeriaExistentePayload() => _galeria
      .map((m) => {
            'url': m.url,
            'type': m.type,
            if (m.thumbnailUrl != null) 'thumbnailUrl': m.thumbnailUrl,
          })
      .toList();

  Future<void> _agregarFotoGaleria() async {
    if (_galeria.length >= _maxGaleria) {
      _snack('Máximo $_maxGaleria elementos en la galería');
      return;
    }
    final base64Str = await _pickAndCropImage();
    if (base64Str == null || !mounted) return;

    final galeria = _galeriaExistentePayload()
      ..add({'base64': base64Str, 'type': 'image'});
    await _guardarGaleria(galeria);
  }

  Future<void> _agregarVideoGaleria() async {
    if (_galeria.length >= _maxGaleria) {
      _snack('Máximo $_maxGaleria elementos en la galería');
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final bytes = await File(file.path).readAsBytes();
    if (bytes.length > _maxVideoMb * 1024 * 1024) {
      _snack('El video no debe superar los $_maxVideoMb MB');
      return;
    }
    final mime = file.path.toLowerCase().endsWith('.webm') ? 'video/webm' : 'video/mp4';
    final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';

    final galeria = _galeriaExistentePayload()
      ..add({'base64': base64Str, 'type': 'video'});
    await _guardarGaleria(galeria);
  }

  Future<void> _quitarGaleria(int index) async {
    final galeria = _galeriaExistentePayload();
    if (index < 0 || index >= galeria.length) return;
    galeria.removeAt(index);
    await _guardarGaleria(galeria);
  }

  /// Reordenar: mover un item a la izquierda (-1) o derecha (+1) y guardar.
  Future<void> _moverGaleria(int index, int dir) async {
    final galeria = _galeriaExistentePayload();
    final j = index + dir;
    if (index < 0 || index >= galeria.length || j < 0 || j >= galeria.length) {
      return;
    }
    final tmp = galeria[index];
    galeria[index] = galeria[j];
    galeria[j] = tmp;
    await _guardarGaleria(galeria);
  }

  // ── Catálogo de productos (sin límite) ───────────────────────────
  /// Persiste el catálogo: conserva los items existentes y aplica el cambio.
  Future<void> _guardarProductos(List<Map<String, dynamic>> productos) async {
    setState(() => _saving = true);
    try {
      final detallePayload = Map<String, dynamic>.from(_detalle);
      detallePayload.remove('imageBase64');
      detallePayload.remove('logoBase64');
      detallePayload.remove('galeria'); // no reenviar la galería en esta operación
      detallePayload['productos'] = productos;

      await _svc.actualizar(_id, {'detallePromocion': detallePayload});

      final fresh = await _svc.obtener(_id);
      if (fresh != null && mounted) setState(() => _data = fresh);

      if (mounted) _snack('Catálogo actualizado', success: true);
    } catch (e) {
      if (mounted) _snack('Error al guardar el catálogo');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Productos existentes serializados como {url, nombre, descripcion} para reenviar.
  List<Map<String, dynamic>> _productosExistentePayload() => _productos
      .map((p) => {
            'url': p.url,
            'nombre': p.nombre,
            if (p.descripcion != null) 'descripcion': p.descripcion,
          })
      .toList();

  Future<void> _agregarProducto() async {
    final base64Str = await _pickAndCropImage();
    if (base64Str == null || !mounted) return;

    final datos = await _editarDatosProducto();
    if (datos == null || !mounted) return;

    final productos = _productosExistentePayload()
      ..add({
        'base64': base64Str,
        'nombre': datos.$1,
        if (datos.$2.isNotEmpty) 'descripcion': datos.$2,
      });
    await _guardarProductos(productos);
  }

  Future<void> _editarProducto(int index) async {
    final productos = _productosExistentePayload();
    if (index < 0 || index >= productos.length) return;
    final actual = _productos[index];
    final datos = await _editarDatosProducto(
      nombre: actual.nombre,
      descripcion: actual.descripcion ?? '',
    );
    if (datos == null || !mounted) return;
    productos[index]['nombre'] = datos.$1;
    if (datos.$2.isNotEmpty) {
      productos[index]['descripcion'] = datos.$2;
    } else {
      productos[index].remove('descripcion');
    }
    await _guardarProductos(productos);
  }

  Future<void> _cambiarFotoProducto(int index) async {
    final productos = _productosExistentePayload();
    if (index < 0 || index >= productos.length) return;
    final base64Str = await _pickAndCropImage();
    if (base64Str == null || !mounted) return;
    productos[index]['base64'] = base64Str;
    productos[index].remove('url'); // el backend usará el base64 nuevo
    await _guardarProductos(productos);
  }

  Future<void> _quitarProducto(int index) async {
    final productos = _productosExistentePayload();
    if (index < 0 || index >= productos.length) return;
    productos.removeAt(index);
    await _guardarProductos(productos);
  }

  Future<void> _moverProducto(int index, int dir) async {
    final productos = _productosExistentePayload();
    final j = index + dir;
    if (index < 0 || index >= productos.length || j < 0 || j >= productos.length) {
      return;
    }
    final tmp = productos[index];
    productos[index] = productos[j];
    productos[j] = tmp;
    await _guardarProductos(productos);
  }

  /// Diálogo para capturar/editar nombre + descripción de un producto.
  /// Devuelve (nombre, descripcion) o null si se cancela / nombre vacío.
  Future<(String, String)?> _editarDatosProducto({
    String nombre = '',
    String descripcion = '',
  }) async {
    final nombreCtrl = TextEditingController(text: nombre);
    final descCtrl = TextEditingController(text: descripcion);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Producto',
            style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              style: const TextStyle(color: Palette.kTitle, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
                filled: true,
                fillColor: Palette.kField,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Palette.kBorder)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Palette.kTitle, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
                filled: true,
                fillColor: Palette.kField,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Palette.kBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Palette.kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Palette.kAccent, foregroundColor: Colors.white),
            onPressed: () {
              final n = nombreCtrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, (n, descCtrl.text.trim()));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    nombreCtrl.dispose();
    descCtrl.dispose();
    return result;
  }

  // ── Edición: abre el wizard por pasos (con guardado por sección) ──
  Future<void> _abrirEdicion() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EstablecimientoWizardScreen(establecimiento: _data),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _saving = true);
      try {
        final fresh = await _svc.obtener(_id);
        if (fresh != null && mounted) setState(() => _data = fresh);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _copiar(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copiado al portapapeles', success: true);
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Palette.kTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detalle', style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          if (widget.canEdit)
            TextButton.icon(
              onPressed: _saving ? null : _abrirEdicion,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Editar'),
              style: TextButton.styleFrom(foregroundColor: Palette.kAccent),
            ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Palette.kBorder))),
        ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator(color: Palette.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildContacto(),
                  const SizedBox(height: 12),
                  _buildUbicacion(),
                  const SizedBox(height: 12),
                  _buildTaxonomia(),
                  const SizedBox(height: 12),
                  _buildPromocion(),
                  const SizedBox(height: 12),
                  if (_promocionesExtra.isNotEmpty) ...[
                    _buildPromocionesExtra(),
                    const SizedBox(height: 12),
                  ],
                  _buildImagenes(),
                  const SizedBox(height: 12),
                  _buildGaleria(),
                  const SizedBox(height: 12),
                  _buildProductos(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    final initial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'E';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF152A47), Color(0xFF1E3A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: _logoUrl != null && _logoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                      ),
                    ),
                  )
                : Center(
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nombre,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BadgePill(label: _activo ? 'Activo' : 'Inactivo', color: _activo ? Colors.greenAccent : Colors.redAccent, filled: true),
                    if (_isTwoForOne) ...[
                      const SizedBox(width: 6),
                      const _BadgePill(label: '2×1', color: Palette.kAccentLight, filled: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Contacto ─────────────────────────────────────────────────────
  Widget _buildContacto() {
    return _SectionCard(
      title: 'Información de contacto',
      icon: Icons.contact_mail_rounded,
      children: [
        _InfoRow(icon: Icons.email_rounded, label: 'Correo', value: _email, onCopy: () => _copiar(_email)),
        _InfoRow(icon: Icons.phone_rounded, label: 'Teléfono', value: _telefono, onCopy: _telefono != '—' ? () => _copiar(_telefono) : null),
        _InfoRow(icon: Icons.badge_rounded, label: 'Identificación (CI/RUC)', value: _identificacion, onCopy: _identificacion != '—' ? () => _copiar(_identificacion) : null),
      ],
    );
  }

  // ── Ubicación ────────────────────────────────────────────────────
  Widget _buildUbicacion() {
    final lat = _ubicacion?['lat']?.toString() ?? '';
    final lng = _ubicacion?['lng']?.toString() ?? '';

    return _SectionCard(
      title: 'Ubicación',
      icon: Icons.location_on_rounded,
      children: [
        _InfoRow(
          icon: Icons.signpost_rounded,
          label: 'Dirección',
          value: _direccion.isNotEmpty ? _direccion : '—',
          onCopy: _direccion.isNotEmpty ? () => _copiar(_direccion) : null,
        ),
        if (lat.isNotEmpty && lng.isNotEmpty)
          _InfoRow(
            icon: Icons.my_location_rounded,
            label: 'Coordenadas',
            value: 'Lat $lat · Lng $lng',
            onCopy: () => _copiar('$lat, $lng'),
          ),
        if (lat.isEmpty || lng.isEmpty)
          _InfoRow(icon: Icons.my_location_rounded, label: 'Coordenadas', value: '—'),
      ],
    );
  }

  // ── Categorías y Ciudades ────────────────────────────────────────
  Widget _buildTaxonomia() {
    return _SectionCard(
      title: 'Categorías y ciudades',
      icon: Icons.category_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categorías', style: TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _categorias.isNotEmpty
                  ? Wrap(spacing: 6, runSpacing: 6, children: _categorias.map((c) => _ChipTag(label: c, color: Palette.kAccent)).toList())
                  : const Text('—', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ciudades', style: TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _ciudades.isNotEmpty
                  ? Wrap(spacing: 6, runSpacing: 6, children: _ciudades.map((c) => _ChipTag(label: c, color: Palette.kPrimary)).toList())
                  : const Text('—', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Promoción ────────────────────────────────────────────────────
  Widget _buildPromocion() {
    final aplicaTodos = _detalle['aplicaTodosLosDias'] != false;
    final diasAplicables = () {
      final da = _detalle['diasAplicables'];
      if (da is List && da.isNotEmpty) return da.map((e) => e.toString()).toList();
      return <String>[];
    }();
    final fechasExcluidas = () {
      final fe = _detalle['fechasExcluidas'];
      if (fe is List && fe.isNotEmpty) {
        return fe.map((f) => f.toString()).toList();
      }
      return <String>[];
    }();

    return _SectionCard(
      title: 'Detalle de promoción',
      icon: Icons.local_offer_rounded,
      children: [
        _InfoRow(icon: Icons.title_rounded, label: 'Título', value: _titulo.isNotEmpty ? _titulo : '—'),
        _InfoRow(icon: Icons.description_rounded, label: 'Descripción', value: _descripcion.isNotEmpty ? _descripcion : '—'),
        _InfoRow(icon: Icons.schedule_rounded, label: 'Horario', value: _horario.isNotEmpty ? _horario : '—'),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Aplica días',
          value: aplicaTodos ? 'Todos los días' : (diasAplicables.isNotEmpty ? diasAplicables.join(', ') : '—'),
        ),
        if (fechasExcluidas.isNotEmpty)
          _InfoRow(
            icon: Icons.event_busy_rounded,
            label: 'Fechas excluidas',
            value: fechasExcluidas.join(', '),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags', style: TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _tags.isNotEmpty
                  ? Wrap(spacing: 6, runSpacing: 6, children: _tags.map((t) => _ChipTag(label: '#$t', color: Palette.kMuted)).toList())
                  : const Text('—', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Promociones extra ────────────────────────────────────────────
  Widget _buildPromocionesExtra() {
    return _SectionCard(
      title: 'Promociones extra',
      icon: Icons.add_circle_outline_rounded,
      children: _promocionesExtra.asMap().entries.map((e) {
        final p = e.value;
        final title = (p['title'] ?? '').toString();
        final horario = (p['scheduleLabel'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.key > 0) const Divider(height: 1, color: Palette.kBorder),
              if (e.key > 0) const SizedBox(height: 10),
              Text('Promoción ${e.key + 1}', style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13)),
              if (title.isNotEmpty) const SizedBox(height: 4),
              if (title.isNotEmpty) Text(title, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
              if (horario.isNotEmpty) Text(horario, style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Imágenes ─────────────────────────────────────────────────────
  Widget _buildImagenes() {
    return _SectionCard(
      title: 'Imágenes',
      icon: Icons.image_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Solo Logo. La portada (imageUrl) la deriva el backend de la
              // primera foto de la galería, igual que la web: no se sube una
              // "imagen principal" aparte (eso congelaría la portada).
              SizedBox(
                width: 160,
                child: _ImageSlot(
                  label: 'Logo',
                  url: _logoUrl,
                  canEdit: widget.canEditFotos,
                  onEdit: () => _editarFoto('logoBase64'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Galería ──────────────────────────────────────────────────────
  Widget _buildGaleria() {
    final items = _galeria;
    return _SectionCard(
      title: 'Galería (${items.length}/$_maxGaleria)',
      icon: Icons.collections_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Hasta $_maxGaleria fotos o videos. Usa las flechas para ordenar. Si hay video, se reproduce primero (de fondo) al entrar al detalle.',
            style: const TextStyle(color: Palette.kMuted, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in items.asMap().entries)
                _GaleriaThumb(
                  item: entry.value,
                  index: entry.key,
                  total: items.length,
                  canEdit: widget.canEditFotos,
                  onRemove: () => _quitarGaleria(entry.key),
                  onMoveLeft: () => _moverGaleria(entry.key, -1),
                  onMoveRight: () => _moverGaleria(entry.key, 1),
                ),
              if (widget.canEditFotos && items.length < _maxGaleria) ...[
                _AddMediaButton(
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'Foto',
                  onTap: _agregarFotoGaleria,
                ),
                _AddMediaButton(
                  icon: Icons.video_call_rounded,
                  label: 'Video',
                  onTap: _agregarVideoGaleria,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Catálogo de productos ────────────────────────────────────────
  Widget _buildProductos() {
    final items = _productos;
    return _SectionCard(
      title: 'Catálogo (${items.length})',
      icon: Icons.shopping_bag_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Productos o servicios que ofrece el local. Cada uno con foto, nombre y descripción. Sin límite.',
            style: const TextStyle(color: Palette.kMuted, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              for (final entry in items.asMap().entries) ...[
                _ProductoCard(
                  producto: entry.value,
                  index: entry.key,
                  total: items.length,
                  canEdit: widget.canEditFotos,
                  onEditText: () => _editarProducto(entry.key),
                  onChangePhoto: () => _cambiarFotoProducto(entry.key),
                  onRemove: () => _quitarProducto(entry.key),
                  onMoveUp: () => _moverProducto(entry.key, -1),
                  onMoveDown: () => _moverProducto(entry.key, 1),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.canEditFotos)
                GestureDetector(
                  onTap: _agregarProducto,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Palette.kAccent.withOpacity(0.35), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Palette.kAccent, size: 22),
                        SizedBox(width: 6),
                        Text('Agregar producto',
                            style: TextStyle(
                                color: Palette.kAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET DE EDICIÓN COMPLETO
// ══════════════════════════════════════════════════════════════════════════════

class _EditSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const _EditSheet({required this.data});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _catSvc = CategoriasService();
  final _cidSvc = CiudadesService();

  // Controllers de texto
  late TextEditingController _nombre;
  late TextEditingController _email;
  late TextEditingController _telefono;
  late TextEditingController _identificacion;
  late TextEditingController _titulo;
  late TextEditingController _descripcion;
  late TextEditingController _horario;
  late TextEditingController _direccion;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  final _tagInput = TextEditingController();

  // GPS
  bool _geoLoading = false;
  String? _geoError;

  // Estado simple
  late bool _estado;
  late bool _isTwoForOne;
  late bool _aplicaTodosLosDias;

  // Estado complejo
  List<String> _selectedCategorias = [];
  List<String> _selectedCiudades = [];
  List<String> _tags = [];
  List<DateTime> _fechasExcluidas = [];
  List<String> _diasAplicables = [];
  Map<String, Map<String, String>> _horarioPorDia = {};
  List<Map<String, dynamic>> _promocionesExtra = [];

  // Datos disponibles (cargados desde API)
  List<Categoria> _categorias = [];
  List<Ciudad> _ciudades = [];
  List<Provincia> _provincias = [];
  String? _selectedProvincia;
  bool _loadingOptions = true;

  static const _diasSemana = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  static const _diasLabel = {
    'lunes': 'Lun', 'martes': 'Mar', 'miercoles': 'Mié',
    'jueves': 'Jue', 'viernes': 'Vie', 'sabado': 'Sáb', 'domingo': 'Dom'
  };

  @override
  void initState() {
    super.initState();
    _initData();
    _loadOptions();
  }

  void _initData() {
    final d = _getDetalle(widget.data);
    _nombre = TextEditingController(text: widget.data['nombre']?.toString() ?? '');
    _email = TextEditingController(text: (widget.data['email'] ?? widget.data['correo'] ?? '').toString());
    _telefono = TextEditingController(text: _desformatearTel(widget.data['telefono']?.toString() ?? ''));
    _identificacion = TextEditingController(text: widget.data['identificacion']?.toString() ?? '');
    _titulo = TextEditingController(text: d['title']?.toString() ?? '');
    _descripcion = TextEditingController(text: d['description']?.toString() ?? '');
    _horario = TextEditingController(text: d['scheduleLabel']?.toString() ?? '');
    _direccion = TextEditingController(text: d['address']?.toString() ?? '');
    _estado = widget.data['estado'] != false;
    _isTwoForOne = d['isTwoForOne'] == true;
    _aplicaTodosLosDias = d['aplicaTodosLosDias'] != false;

    // Tags
    final t = d['tags'];
    if (t is List) _tags = t.map((e) => e.toString()).toList();

    // Categorías seleccionadas (extraer IDs)
    final cats = widget.data['categorias'];
    if (cats is List) {
      _selectedCategorias = cats.map((c) {
        if (c is Map) return (c['_id'] ?? '').toString();
        return c.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    // Ciudades seleccionadas (extraer IDs)
    final cids = widget.data['ciudades'];
    if (cids is List) {
      _selectedCiudades = cids.map((c) {
        if (c is Map) return (c['_id'] ?? '').toString();
        return c.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    // Provincia precargada (la deriva el backend de la 1ª ciudad).
    _selectedProvincia = widget.data['provinciaId']?.toString();

    // Ubicación
    final ub = widget.data['ubicacion'];
    if (ub is Map) {
      _latCtrl = TextEditingController(text: ub['lat']?.toString() ?? '');
      _lngCtrl = TextEditingController(text: ub['lng']?.toString() ?? '');
    } else {
      _latCtrl = TextEditingController();
      _lngCtrl = TextEditingController();
    }

    // Fechas excluidas
    final fe = d['fechasExcluidas'];
    if (fe is List) {
      _fechasExcluidas = fe.map((f) => DateTime.tryParse(f.toString()) ?? DateTime.now()).toList();
    }

    // Días aplicables
    final da = d['diasAplicables'];
    if (da is List) _diasAplicables = da.map((e) => e.toString()).toList();

    // Horario por día
    final hpd = d['horarioPorDia'];
    if (hpd is Map) {
      for (final entry in hpd.entries) {
        final val = entry.value;
        if (val is Map) {
          _horarioPorDia[entry.key.toString()] = {
            'abre': val['abre']?.toString() ?? '09:00',
            'cierra': val['cierra']?.toString() ?? '18:00',
          };
        }
      }
    }

    // Promociones extra
    final pe = widget.data['detallePromocionesExtra'];
    if (pe is List) {
      _promocionesExtra = pe.map((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
    }
  }

  Future<void> _loadOptions() async {
    try {
      final cats = await _catSvc.getActivas();
      final provs = await _cidSvc.getProvincias();
      // Ciudades de la provincia precargada (o ninguna si no hay).
      final cids = _selectedProvincia == null
          ? <Ciudad>[]
          : await _cidSvc.getParaPromosPorProvincia(_selectedProvincia!);
      if (mounted) {
        setState(() {
          _categorias = cats;
          _provincias = provs;
          _ciudades = cids;
          _loadingOptions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _onProvinciaChange(String? id) async {
    if (id == _selectedProvincia) return;
    setState(() {
      _selectedProvincia = id;
      _selectedCiudades.clear();
      _ciudades = [];
    });
    if (id == null) return;
    try {
      final cids = await _cidSvc.getParaPromosPorProvincia(id);
      if (mounted) setState(() => _ciudades = cids);
    } catch (_) {}
  }

  Map<String, dynamic> _getDetalle(Map<String, dynamic> data) {
    final d = data['detallePromocion'];
    return d is Map<String, dynamic> ? d : {};
  }

  String _desformatearTel(String tel) {
    if (tel.isEmpty) return tel;
    String limpio = tel.replaceAll(RegExp(r'\D'), '');
    if (limpio.startsWith('593')) limpio = limpio.substring(3);
    if (!limpio.startsWith('0')) limpio = '0$limpio';
    return limpio;
  }

  String _formatearTel(String tel) {
    if (tel.isEmpty) return tel;
    String limpio = tel.replaceAll(RegExp(r'\D'), '');
    if (limpio.startsWith('593')) return '+$limpio';
    if (limpio.startsWith('0')) limpio = limpio.substring(1);
    return '+593$limpio';
  }

  bool _isObjectId(String s) => RegExp(r'^[a-f\d]{24}$', caseSensitive: false).hasMatch(s);

  @override
  void dispose() {
    for (final c in [_nombre, _email, _telefono, _identificacion,
        _titulo, _descripcion, _horario, _direccion, _latCtrl, _lngCtrl, _tagInput]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() { _geoLoading = true; _geoError = null; });
    try {
      // Verificar si el servicio está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _geoError = 'El GPS está desactivado. Actívalo en ajustes.'; _geoLoading = false; });
        return;
      }

      // Verificar y solicitar permiso
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _geoError = 'Permiso de ubicación denegado.'; _geoLoading = false; });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() { _geoError = 'Permiso denegado permanentemente. Ve a Ajustes > Aplicaciones > enjoy.'; _geoLoading = false; });
        return;
      }

      // Obtener posición
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );

      final lat = double.parse(pos.latitude.toStringAsFixed(7));
      final lng = double.parse(pos.longitude.toStringAsFixed(7));

      setState(() {
        _latCtrl.text = lat.toString();
        _lngCtrl.text = lng.toString();
        _geoLoading = false;
        _geoError = null;
      });
    } catch (e) {
      setState(() { _geoError = 'No se pudo obtener la ubicación. Intenta de nuevo.'; _geoLoading = false; });
    }
  }

  void _limpiarUbicacion() {
    setState(() {
      _latCtrl.clear();
      _lngCtrl.clear();
      _geoError = null;
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    // Start from existing detallePromocion to preserve imageUrl, logoUrl and
    // any other fields the form doesn't touch.
    final existingDetalle = _getDetalle(widget.data);
    final detallePromocion = <String, dynamic>{
      ...existingDetalle,
      'title': _titulo.text.trim(),
      'placeName': _nombre.text.trim(),
      'description': _descripcion.text.trim(),
      'scheduleLabel': _horario.text.trim(),
      'address': _direccion.text.trim(),
      'isTwoForOne': _isTwoForOne,
      'aplicaTodosLosDias': _aplicaTodosLosDias,
      // Never send old base64 data — backend would reprocess them
      'imageBase64': null,
      'logoBase64': null,
    };
    detallePromocion.removeWhere((k, v) => v == null && (k == 'imageBase64' || k == 'logoBase64'));

    if (_tags.isNotEmpty) detallePromocion['tags'] = _tags;
    if (_fechasExcluidas.isNotEmpty) {
      detallePromocion['fechasExcluidas'] = _fechasExcluidas.map((d) => d.toIso8601String()).toList();
    }
    if (!_aplicaTodosLosDias) {
      if (_diasAplicables.isNotEmpty) {
        detallePromocion['diasAplicables'] = _diasAplicables;
        detallePromocion['horarioPorDia'] = _horarioPorDia;
      }
    } else {
      detallePromocion['diasAplicables'] = <String>[];
      detallePromocion['horarioPorDia'] = <String, dynamic>{};
    }

    final payload = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'email': _email.text.trim(),
      'estado': _estado,
      'detallePromocion': detallePromocion,
    };

    final tel = _telefono.text.trim();
    if (tel.isNotEmpty) payload['telefono'] = _formatearTel(tel);

    final idVal = _identificacion.text.trim();
    if (idVal.isNotEmpty) payload['identificacion'] = idVal;

    // Categorías y ciudades - solo IDs válidos
    final catIds = _selectedCategorias.where(_isObjectId).toList();
    if (catIds.isNotEmpty) payload['categorias'] = catIds;

    final cidIds = _selectedCiudades.where(_isObjectId).toList();
    if (cidIds.isNotEmpty) payload['ciudades'] = cidIds;

    // Ubicación
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat != null && lng != null) {
      payload['ubicacion'] = {'lat': lat, 'lng': lng};
    }

    // Promociones extra
    if (_promocionesExtra.isNotEmpty) {
      payload['detallePromocionesExtra'] = _promocionesExtra.map((p) {
        final clean = Map<String, dynamic>.from(p);
        if (clean['startDate'] == null) clean.remove('startDate');
        if (clean['endDate'] == null) clean.remove('endDate');
        if ((clean['tags'] as List?)?.isEmpty ?? true) clean.remove('tags');
        clean['placeName'] = clean['placeName']?.toString().isEmpty ?? true
            ? _nombre.text.trim()
            : clean['placeName'];
        return clean;
      }).toList();
    }

    Navigator.pop(context, payload);
  }

  void _toggleCategoria(String id) {
    setState(() {
      if (_selectedCategorias.contains(id)) {
        _selectedCategorias.remove(id);
      } else {
        _selectedCategorias.add(id);
      }
    });
  }

  void _toggleCiudad(String id) {
    setState(() {
      if (_selectedCiudades.contains(id)) {
        _selectedCiudades.remove(id);
      } else {
        _selectedCiudades.add(id);
      }
    });
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInput.clear();
      });
    }
  }

  void _removeTag(int i) => setState(() => _tags.removeAt(i));

  Future<void> _addFechaExcluida() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Palette.kAccent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        final exists = _fechasExcluidas.any((f) => f.year == picked.year && f.month == picked.month && f.day == picked.day);
        if (!exists) _fechasExcluidas.add(picked);
      });
    }
  }

  void _removeFechaExcluida(int i) => setState(() => _fechasExcluidas.removeAt(i));

  void _toggleDia(String dia) {
    setState(() {
      if (_diasAplicables.contains(dia)) {
        _diasAplicables.remove(dia);
        _horarioPorDia.remove(dia);
      } else {
        _diasAplicables.add(dia);
        _horarioPorDia[dia] = {'abre': '09:00', 'cierra': '18:00'};
      }
    });
  }

  void _addPromocionExtra() {
    setState(() {
      _promocionesExtra.add({
        'title': '',
        'placeName': _nombre.text.trim(),
        'aplicaTodosLosDias': true,
        'scheduleLabel': '',
        'isTwoForOne': false,
        'isFlash': false,
        'tags': <String>[],
        'startDate': null,
        'endDate': null,
      });
    });
  }

  void _removePromocionExtra(int i) => setState(() => _promocionesExtra.removeAt(i));

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: Palette.kBorder, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Palette.kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: Palette.kAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Editar establecimiento',
                    style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
          ),
          const Divider(height: 1, color: Palette.kBorder),

          // Formulario
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── DATOS GENERALES ───────────────────────────
                    _sectionLabel('DATOS GENERALES'),
                    _field(_nombre, 'Nombre del establecimiento', Icons.store_rounded, required: true),
                    _field(_email, 'Correo electrónico', Icons.email_rounded, keyboard: TextInputType.emailAddress, required: true),
                    _field(_telefono, 'Teléfono (ej: 0999999999)', Icons.phone_rounded, keyboard: TextInputType.phone),
                    _field(_identificacion, 'CI / RUC', Icons.badge_rounded, keyboard: TextInputType.number),
                    _switchTile('Establecimiento activo', _estado, (v) => setState(() => _estado = v)),

                    // ── CATEGORÍAS ────────────────────────────────
                    const SizedBox(height: 16),
                    _sectionLabel('CATEGORÍAS'),
                    _loadingOptions
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator(color: Palette.kAccent, strokeWidth: 2)),
                          )
                        : SearchableChips(
                            items: _categorias.map((c) => (id: c.id, label: c.nombre)).toList(),
                            selected: _selectedCategorias,
                            onToggle: _toggleCategoria,
                            emptyText: 'Sin categorías disponibles',
                            hint: 'Buscar categoría',
                            color: Palette.kAccent,
                          ),

                    // ── PROVINCIA ─────────────────────────────────
                    const SizedBox(height: 8),
                    _sectionLabel('PROVINCIA'),
                    SearchablePickerField(
                      label: 'Provincia',
                      icon: Icons.map_rounded,
                      value: _selectedProvincia,
                      items: _provincias
                          .map((p) => (id: p.id, label: p.nombre))
                          .toList(),
                      onChanged: _onProvinciaChange,
                    ),

                    // ── CIUDADES ──────────────────────────────────
                    const SizedBox(height: 8),
                    _sectionLabel('CIUDADES'),
                    _loadingOptions
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator(color: Palette.kAccent, strokeWidth: 2)),
                          )
                        : _selectedProvincia == null
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Selecciona primero una provincia.',
                                    style: TextStyle(color: Palette.kMuted, fontSize: 13)),
                              )
                            : SearchableChips(
                                items: _ciudades.map((c) => (id: c.id, label: c.nombre)).toList(),
                                selected: _selectedCiudades,
                                onToggle: _toggleCiudad,
                                emptyText: 'Sin ciudades en esta provincia',
                                hint: 'Buscar ciudad',
                                color: Palette.kPrimary,
                              ),

                    // ── UBICACIÓN ─────────────────────────────────
                    const SizedBox(height: 8),
                    _sectionLabel('UBICACIÓN GPS'),

                    // Coordenadas actuales (si hay)
                    if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_latCtrl.text}, ${_lngCtrl.text}',
                                  style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                ),
                              ),
                              GestureDetector(
                                onTap: _limpiarUbicacion,
                                child: const Icon(Icons.close_rounded, size: 16, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Inputs manuales
                    Row(
                      children: [
                        Expanded(child: _field(_latCtrl, 'Latitud (ej: -0.2298)', Icons.location_on_rounded,
                            keyboard: const TextInputType.numberWithOptions(signed: true, decimal: true))),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_lngCtrl, 'Longitud (ej: -78.524)', Icons.location_on_rounded,
                            keyboard: const TextInputType.numberWithOptions(signed: true, decimal: true))),
                      ],
                    ),

                    // Botón GPS
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _geoLoading ? null : _obtenerUbicacion,
                          icon: _geoLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.kAccent))
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(_geoLoading ? 'Obteniendo ubicación...' : 'Usar mi ubicación actual (GPS)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Palette.kAccent,
                            side: const BorderSide(color: Palette.kAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    // Error GPS
                    if (_geoError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_geoError!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),

                    // ── DETALLE DE PROMOCIÓN ──────────────────────
                    const SizedBox(height: 4),
                    _sectionLabel('DETALLE DE PROMOCIÓN'),
                    _field(_titulo, 'Título (ej: 2x1 en colonche)', Icons.local_offer_rounded, required: true),
                    _field(_direccion, 'Dirección del local', Icons.signpost_rounded),
                    _field(_horario, 'Horario (ej: Lun–Dom 10:00–19:00)', Icons.schedule_rounded),
                    _field(_descripcion, 'Descripción de la promoción', Icons.description_rounded, maxLines: 3),

                    // Tags
                    const Text('Etiquetas',
                        style: TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _tags.asMap().entries.map((e) => Chip(
                          label: Text(e.value, style: const TextStyle(fontSize: 12, color: Palette.kAccent)),
                          backgroundColor: Palette.kAccent.withOpacity(0.1),
                          deleteIconColor: Palette.kMuted,
                          onDeleted: () => _removeTag(e.key),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagInput,
                            style: const TextStyle(color: Palette.kTitle, fontSize: 13),
                            onFieldSubmitted: (_) => _addTag(),
                            decoration: InputDecoration(
                              hintText: 'Nueva etiqueta',
                              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
                              filled: true, fillColor: Palette.kField,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTag,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.kAccent.withOpacity(0.12),
                            foregroundColor: Palette.kAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // isTwoForOne y aplicaTodosLosDias
                    _switchTile('Promoción 2×1', _isTwoForOne, (v) => setState(() => _isTwoForOne = v)),
                    const SizedBox(height: 6),
                    _switchTile('Aplica todos los días', _aplicaTodosLosDias, (v) {
                      setState(() {
                        _aplicaTodosLosDias = v;
                        if (v) { _diasAplicables.clear(); _horarioPorDia.clear(); }
                      });
                    }),

                    // ── FECHAS EXCLUIDAS ──────────────────────────
                    const SizedBox(height: 16),
                    _sectionLabel('FECHAS EXCLUIDAS'),
                    ..._fechasExcluidas.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Palette.kField,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Palette.kBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 15, color: Palette.kMuted),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_formatDate(e.value), style: const TextStyle(color: Palette.kTitle, fontSize: 13))),
                            GestureDetector(
                              onTap: () => _removeFechaExcluida(e.key),
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    )),
                    OutlinedButton.icon(
                      onPressed: _addFechaExcluida,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Añadir fecha excluida'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.kMuted,
                        side: BorderSide(color: Palette.kBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // ── DÍAS Y HORARIOS (si no aplica todos) ──────
                    if (!_aplicaTodosLosDias) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('DÍAS Y HORARIOS ESPECÍFICOS'),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _diasSemana.map((dia) {
                          final sel = _diasAplicables.contains(dia);
                          return GestureDetector(
                            onTap: () => _toggleDia(dia),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel ? Palette.kAccent : Palette.kField,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? Palette.kAccent : Palette.kBorder),
                              ),
                              child: Text(
                                _diasLabel[dia] ?? dia,
                                style: TextStyle(color: sel ? Colors.white : Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ..._diasAplicables.map((dia) => _HorarioDiaRow(
                        dia: dia,
                        abre: _horarioPorDia[dia]?['abre'] ?? '09:00',
                        cierra: _horarioPorDia[dia]?['cierra'] ?? '18:00',
                        onChanged: (abre, cierra) {
                          setState(() => _horarioPorDia[dia] = {'abre': abre, 'cierra': cierra});
                        },
                      )),
                    ],

                    // ── PROMOCIONES EXTRA ─────────────────────────
                    const SizedBox(height: 16),
                    _sectionLabel('PROMOCIONES EXTRA'),
                    ..._promocionesExtra.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PromoExtraCard(
                        index: e.key,
                        promo: e.value,
                        onRemove: () => _removePromocionExtra(e.key),
                        onChanged: (updated) => setState(() => _promocionesExtra[e.key] = updated),
                      ),
                    )),
                    OutlinedButton.icon(
                      onPressed: _addPromocionExtra,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Añadir promoción extra'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.kMuted,
                        side: BorderSide(color: Palette.kBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Palette.kBorder),
                              foregroundColor: Palette.kMuted,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.kAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(color: Palette.kField, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.kBorder)),
        child: SwitchListTile(
          title: Text(label, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w600, fontSize: 14)),
          value: value,
          onChanged: onChanged,
          activeColor: Palette.kAccent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }

  Widget _multiSelectChips({
    required List<({String id, String label})> items,
    required List<String> selected,
    required void Function(String) onToggle,
    required String emptyText,
    required Color color,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(emptyText, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: items.map((item) {
          final sel = selected.contains(item.id);
          return GestureDetector(
            onTap: () => onToggle(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? color : Palette.kField,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? color : Palette.kBorder),
              ),
              child: Text(item.label, style: TextStyle(color: sel ? Colors.white : Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Palette.kTitle, fontSize: 14),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Palette.kMuted),
          filled: true, fillColor: Palette.kField,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        ),
      ),
    );
  }
}

// ── Fila de horario por día ───────────────────────────────────────────────────

class _HorarioDiaRow extends StatefulWidget {
  final String dia;
  final String abre;
  final String cierra;
  final void Function(String abre, String cierra) onChanged;

  const _HorarioDiaRow({
    required this.dia,
    required this.abre,
    required this.cierra,
    required this.onChanged,
  });

  @override
  State<_HorarioDiaRow> createState() => _HorarioDiaRowState();
}

class _HorarioDiaRowState extends State<_HorarioDiaRow> {
  late TextEditingController _abreCtrl;
  late TextEditingController _cierraCtrl;

  static const _diasLabel = {
    'lunes': 'Lunes', 'martes': 'Martes', 'miercoles': 'Miércoles',
    'jueves': 'Jueves', 'viernes': 'Viernes', 'sabado': 'Sábado', 'domingo': 'Domingo'
  };

  @override
  void initState() {
    super.initState();
    _abreCtrl = TextEditingController(text: widget.abre);
    _cierraCtrl = TextEditingController(text: widget.cierra);
  }

  @override
  void dispose() {
    _abreCtrl.dispose();
    _cierraCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl, bool isAbre) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ctrl.text = formatted;
      widget.onChanged(
        isAbre ? formatted : _abreCtrl.text,
        isAbre ? _cierraCtrl.text : formatted,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.kField,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(_diasLabel[widget.dia] ?? widget.dia,
                  style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            const Text('Abre', style: TextStyle(color: Palette.kMuted, fontSize: 11)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _pickTime(_abreCtrl, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Palette.kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.kBorder)),
                child: Text(_abreCtrl.text, style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Cierra', style: TextStyle(color: Palette.kMuted, fontSize: 11)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _pickTime(_cierraCtrl, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Palette.kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.kBorder)),
                child: Text(_cierraCtrl.text, style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de promoción extra ───────────────────────────────────────────────────

class _PromoExtraCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> promo;
  final VoidCallback onRemove;
  final void Function(Map<String, dynamic>) onChanged;

  const _PromoExtraCard({
    required this.index,
    required this.promo,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_PromoExtraCard> createState() => _PromoExtraCardState();
}

class _PromoExtraCardState extends State<_PromoExtraCard> {
  late TextEditingController _title;
  late TextEditingController _horario;
  late bool _isTwoForOne;
  late bool _isFlash;
  late bool _aplicaTodos;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final p = widget.promo;
    _title = TextEditingController(text: p['title']?.toString() ?? '');
    _horario = TextEditingController(text: p['scheduleLabel']?.toString() ?? '');
    _isTwoForOne = p['isTwoForOne'] == true;
    _isFlash = p['isFlash'] == true;
    _aplicaTodos = p['aplicaTodosLosDias'] != false;
    _startDate = p['startDate'] is String ? DateTime.tryParse(p['startDate']) : null;
    _endDate = p['endDate'] is String ? DateTime.tryParse(p['endDate']) : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _horario.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      ...widget.promo,
      'title': _title.text.trim(),
      'scheduleLabel': _horario.text.trim(),
      'isTwoForOne': _isTwoForOne,
      'isFlash': _isFlash,
      'aplicaTodosLosDias': _aplicaTodos,
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Palette.kAccent)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) { _startDate = picked; } else { _endDate = picked; }
      });
      _notify();
    }
  }

  String _formatDate(DateTime? d) => d == null ? 'Seleccionar' : DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.kField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Promoción ${widget.index + 1}',
                  style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _miniField(_title, 'Título de la promoción', Icons.title_rounded),
          _miniField(_horario, 'Horario (ej: Lun–Dom 08:00–20:00)', Icons.schedule_rounded),
          // Fechas
          Row(
            children: [
              Expanded(child: _dateBtn('Inicio', _startDate, () => _pickDate(true))),
              const SizedBox(width: 8),
              Expanded(child: _dateBtn('Fin', _endDate, () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 8),
          // Switches
          _miniSwitch('2×1', _isTwoForOne, (v) { setState(() => _isTwoForOne = v); _notify(); }),
          _miniSwitch('Flash', _isFlash, (v) { setState(() => _isFlash = v); _notify(); }),
          _miniSwitch('Aplica todos los días', _aplicaTodos, (v) { setState(() => _aplicaTodos = v); _notify(); }),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Palette.kTitle, fontSize: 13),
        onChanged: (_) => _notify(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 12),
          prefixIcon: Icon(icon, size: 16, color: Palette.kMuted),
          filled: true, fillColor: Palette.kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Palette.kAccent)),
        ),
      ),
    );
  }

  Widget _dateBtn(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: Palette.kMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: ${_formatDate(date)}',
                style: TextStyle(
                  color: date != null ? Palette.kTitle : Palette.kMuted,
                  fontSize: 12,
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeColor: Palette.kAccent,
      contentPadding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _ImageSlot extends StatelessWidget {
  final String label;
  final String? url;
  final bool canEdit;
  final VoidCallback onEdit;
  const _ImageSlot({required this.label, this.url, required this.canEdit, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasImg = url != null && url!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: canEdit ? onEdit : null,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canEdit ? Palette.kAccent.withOpacity(0.35) : Palette.kBorder,
                width: canEdit ? 1.5 : 1,
              ),
            ),
            child: hasImg
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(url!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Palette.kMuted)),
                        if (canEdit)
                          Positioned(
                            bottom: 6, right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: Palette.kAccent, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canEdit ? Icons.add_photo_alternate_rounded : Icons.image_not_supported_rounded,
                          color: canEdit ? Palette.kAccent : Palette.kMuted,
                          size: 28,
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 4),
                          Text('Agregar', style: TextStyle(color: Palette.kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _GaleriaThumb extends StatelessWidget {
  final MediaItem item;
  final int index;
  final int total;
  final bool canEdit;
  final VoidCallback onRemove;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  const _GaleriaThumb({
    required this.item,
    required this.index,
    required this.total,
    required this.canEdit,
    required this.onRemove,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  Widget _miniBtn(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: enabled ? Colors.black54 : Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: enabled ? Colors.white : Colors.white38),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: item.isVideo
                ? Container(
                    color: Palette.kField,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill_rounded, color: Palette.kMuted, size: 34),
                    ),
                  )
                : Image.network(
                    item.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_rounded, color: Palette.kMuted),
                  ),
          ),
          // Número de orden
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          if (item.isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: const Text('Video · fondo', style: TextStyle(color: Colors.white, fontSize: 8)),
              ),
            ),
          if (canEdit) ...[
            Positioned(
              top: 3,
              right: 3,
              child: _miniBtn(Icons.close_rounded, onRemove),
            ),
            // Flechas de orden
            Positioned(
              bottom: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniBtn(Icons.chevron_left_rounded, onMoveLeft, enabled: index > 0),
                  const SizedBox(width: 3),
                  _miniBtn(Icons.chevron_right_rounded, onMoveRight, enabled: index < total - 1),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddMediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Palette.kField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.kAccent.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Palette.kAccent, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Palette.kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  final int index;
  final int total;
  final bool canEdit;
  final VoidCallback onEditText;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  const _ProductoCard({
    required this.producto,
    required this.index,
    required this.total,
    required this.canEdit,
    required this.onEditText,
    required this.onChangePhoto,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  Widget _miniBtn(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Palette.kField,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Icon(icon, size: 15, color: enabled ? Palette.kMuted : Palette.kBorder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.kField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto (toca para cambiar)
          GestureDetector(
            onTap: canEdit ? onChangePhoto : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      producto.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Palette.kSurface,
                        child: const Icon(Icons.broken_image_rounded, color: Palette.kMuted),
                      ),
                    ),
                    if (canEdit)
                      Positioned(
                        bottom: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Palette.kAccent, borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nombre + descripción
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre.isEmpty ? 'Sin nombre' : producto.nombre,
                  style: const TextStyle(
                      color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((producto.descripcion ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    producto.descripcion!,
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniBtn(Icons.edit_rounded, onEditText),
                      const SizedBox(width: 6),
                      _miniBtn(Icons.keyboard_arrow_up_rounded, onMoveUp, enabled: index > 0),
                      const SizedBox(width: 6),
                      _miniBtn(Icons.keyboard_arrow_down_rounded, onMoveDown,
                          enabled: index < total - 1),
                      const Spacer(),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 15, color: Colors.red.shade400),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(icon, size: 16, color: Palette.kAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
          const Divider(height: 1, color: Palette.kBorder),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoRow({required this.icon, required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Palette.kMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Palette.kField, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.copy_rounded, size: 14, color: Palette.kMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _BadgePill({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Selector de chips con buscador: muestra las seleccionadas arriba y una lista
/// filtrable con scroll. Pensado para listas largas (ej. 150+ categorías).
class SearchableChips extends StatefulWidget {
  final List<({String id, String label})> items;
  final List<String> selected;
  final void Function(String) onToggle;
  final Color color;
  final String emptyText;
  final String hint;

  const SearchableChips({
    super.key,
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.color,
    this.emptyText = 'Sin opciones',
    this.hint = 'Buscar…',
  });

  @override
  State<SearchableChips> createState() => _SearchableChipsState();
}

class _SearchableChipsState extends State<SearchableChips> {
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
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(widget.emptyText, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
      );
    }

    final selectedItems =
        widget.items.where((i) => widget.selected.contains(i.id)).toList();
    final q = _norm(_q.trim());
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((i) => _norm(i.label).contains(q)).toList();

    Widget chip(({String id, String label}) item, {bool removable = false}) {
      final sel = widget.selected.contains(item.id);
      return GestureDetector(
        onTap: () => widget.onToggle(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? widget.color : Palette.kField,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? widget.color : Palette.kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.label,
                  style: TextStyle(
                      color: sel ? Colors.white : Palette.kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (removable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador
          TextField(
            onChanged: (v) => setState(() => _q = v),
            style: const TextStyle(color: Palette.kTitle, fontSize: 14),
            decoration: InputDecoration(
              hintText: '${widget.hint}  (${widget.selected.length} sel.)',
              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Palette.kMuted),
              filled: true,
              fillColor: Palette.kField,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Palette.kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Palette.kBorder)),
            ),
          ),
          // Seleccionadas (resumen)
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedItems.map((i) => chip(i, removable: true)).toList(),
            ),
            const Divider(height: 18, color: Palette.kBorder),
          ],
          // Lista filtrada (scroll)
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Sin resultados para “$_q”',
                          style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: filtered.map((i) => chip(i)).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
