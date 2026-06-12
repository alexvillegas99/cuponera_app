import 'dart:convert';
import 'dart:io';
import 'package:enjoy/models/media_item.dart';
import 'package:enjoy/models/producto.dart';
import 'package:enjoy/screens/usuarios/establecimiento_wizard_screen.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

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
    if (pe is List) {
      return pe.map((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
    }
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
    final ec = context.ec;
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
          toolbarColor: ec.bgTop,
          toolbarWidgetColor: ec.text,
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
    final ec = context.ec;
    final nombreCtrl = TextEditingController(text: nombre);
    final descCtrl = TextEditingController(text: descripcion);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              minLines: 2,
              maxLines: 4,
              style: EnjoyTheme.body(size: 14, color: ec.text),
              decoration:
                  const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancelar', style: EnjoyTheme.body(color: ec.textMute)),
          ),
          ElevatedButton(
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
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ec.green : ec.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _copiar(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copiado al portapapeles', success: true);
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
        title: 'Detalle',
        actions: [
          if (widget.canEdit)
            GlassIconButton(
              icon: Icons.edit_rounded,
              accent: true,
              onTap: _saving ? null : _abrirEdicion,
            ),
        ],
      ),
      body: _saving
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(ec),
                  const SizedBox(height: 14),
                  _buildContacto(),
                  const SizedBox(height: 12),
                  _buildUbicacion(),
                  const SizedBox(height: 12),
                  _buildTaxonomia(ec),
                  const SizedBox(height: 12),
                  _buildPromocion(ec),
                  const SizedBox(height: 12),
                  if (_promocionesExtra.isNotEmpty) ...[
                    _buildPromocionesExtra(ec),
                    const SizedBox(height: 12),
                  ],
                  _buildImagenes(),
                  const SizedBox(height: 12),
                  _buildGaleria(ec),
                  const SizedBox(height: 12),
                  _buildProductos(ec),
                ],
              ),
            ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader(EnjoyColors ec) {
    return GlassCard(
      accent: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          EnjoyAvatar(_nombre, size: 64, radius: 18, imageUrl: _logoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nombre,
                    style: EnjoyTheme.heading(
                        size: 18, weight: FontWeight.w800, color: ec.text, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Pill(
                      _activo ? 'Activo' : 'Inactivo',
                      variant: _activo ? PillVariant.green : PillVariant.red,
                      dense: true,
                      dot: _activo,
                    ),
                    if (_isTwoForOne) ...[
                      const SizedBox(width: 6),
                      const Pill('2×1',
                          variant: PillVariant.orange, dense: true),
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
        _InfoRow(
            icon: Icons.email_rounded,
            label: 'Correo',
            value: _email,
            onCopy: () => _copiar(_email)),
        _InfoRow(
            icon: Icons.phone_rounded,
            label: 'Teléfono',
            value: _telefono,
            onCopy: _telefono != '—' ? () => _copiar(_telefono) : null),
        _InfoRow(
            icon: Icons.badge_rounded,
            label: 'Identificación (CI/RUC)',
            value: _identificacion,
            onCopy:
                _identificacion != '—' ? () => _copiar(_identificacion) : null),
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
          _InfoRow(
              icon: Icons.my_location_rounded,
              label: 'Coordenadas',
              value: '—'),
      ],
    );
  }

  // ── Categorías y Ciudades ────────────────────────────────────────
  Widget _buildTaxonomia(EnjoyColors ec) {
    return _SectionCard(
      title: 'Categorías y ciudades',
      icon: Icons.category_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Categorías', padding: EdgeInsets.zero),
              const SizedBox(height: 8),
              _categorias.isNotEmpty
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categorias
                          .map((c) => Pill(c,
                              variant: PillVariant.orange, dense: true))
                          .toList())
                  : Text('—', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Ciudades', padding: EdgeInsets.zero),
              const SizedBox(height: 8),
              _ciudades.isNotEmpty
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _ciudades
                          .map((c) => Pill(c,
                              variant: PillVariant.blue, dense: true))
                          .toList())
                  : Text('—', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Promoción ────────────────────────────────────────────────────
  Widget _buildPromocion(EnjoyColors ec) {
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
        _InfoRow(
            icon: Icons.title_rounded,
            label: 'Título',
            value: _titulo.isNotEmpty ? _titulo : '—'),
        _InfoRow(
            icon: Icons.description_rounded,
            label: 'Descripción',
            value: _descripcion.isNotEmpty ? _descripcion : '—'),
        _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Horario',
            value: _horario.isNotEmpty ? _horario : '—'),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Aplica días',
          value: aplicaTodos
              ? 'Todos los días'
              : (diasAplicables.isNotEmpty ? diasAplicables.join(', ') : '—'),
        ),
        if (fechasExcluidas.isNotEmpty)
          _InfoRow(
            icon: Icons.event_busy_rounded,
            label: 'Fechas excluidas',
            value: fechasExcluidas.join(', '),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Tags', padding: EdgeInsets.zero),
              const SizedBox(height: 8),
              _tags.isNotEmpty
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map((t) => Pill('#$t',
                              variant: PillVariant.glass, dense: true))
                          .toList())
                  : Text('—', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Promociones extra ────────────────────────────────────────────
  Widget _buildPromocionesExtra(EnjoyColors ec) {
    return _SectionCard(
      title: 'Promociones extra',
      icon: Icons.add_circle_outline_rounded,
      children: _promocionesExtra.asMap().entries.map((e) {
        final p = e.value;
        final title = (p['title'] ?? '').toString();
        final horario = (p['scheduleLabel'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.key > 0) EnjoyDivider(height: 16),
              Text('Promoción ${e.key + 1}',
                  style: EnjoyTheme.heading(size: 13, color: ec.text)),
              if (title.isNotEmpty) const SizedBox(height: 4),
              if (title.isNotEmpty)
                Text(title,
                    style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
              if (horario.isNotEmpty)
                Text(horario,
                    style: EnjoyTheme.body(size: 12, color: ec.textMute)),
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
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
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
  Widget _buildGaleria(EnjoyColors ec) {
    final items = _galeria;
    return _SectionCard(
      title: 'Galería (${items.length}/$_maxGaleria)',
      icon: Icons.collections_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
          child: Text(
            'Hasta $_maxGaleria fotos o videos. Usa las flechas para ordenar. Si hay video, se reproduce primero (de fondo) al entrar al detalle.',
            style: EnjoyTheme.body(size: 12, color: ec.textMute),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 16),
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
  Widget _buildProductos(EnjoyColors ec) {
    final items = _productos;
    return _SectionCard(
      title: 'Catálogo (${items.length})',
      icon: Icons.shopping_bag_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
          child: Text(
            'Productos o servicios que ofrece el local. Cada uno con foto, nombre y descripción. Sin límite.',
            style: EnjoyTheme.body(size: 12, color: ec.textMute),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 16),
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
                      color: ec.glass,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: ec.orange.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: ec.orangeSoft, size: 22),
                        const SizedBox(width: 6),
                        Text('Agregar producto',
                            style: EnjoyTheme.heading(
                                size: 13, color: ec.orangeSoft)),
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
// WIDGETS HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _ImageSlot extends StatelessWidget {
  final String label;
  final String? url;
  final bool canEdit;
  final VoidCallback onEdit;
  const _ImageSlot(
      {required this.label,
      this.url,
      required this.canEdit,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final hasImg = url != null && url!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, padding: EdgeInsets.zero),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: canEdit ? onEdit : null,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: ec.glass,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: canEdit ? ec.orange.withValues(alpha: 0.35) : ec.stroke,
                width: canEdit ? 1.5 : 1,
              ),
            ),
            child: hasImg
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EnjoyImage(url!,
                            fit: BoxFit.cover,
                            errorWidget: Icon(
                                Icons.broken_image_rounded,
                                color: ec.textMute)),
                        if (canEdit)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  gradient: ec.accentGradient,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.camera_alt_rounded,
                                  size: 14, color: ec.onAccent),
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
                          canEdit
                              ? Icons.add_photo_alternate_rounded
                              : Icons.image_not_supported_rounded,
                          color: canEdit ? ec.orangeSoft : ec.textMute,
                          size: 28,
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 4),
                          Text('Agregar',
                              style: EnjoyTheme.body(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: ec.orangeSoft)),
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
    final ec = context.ec;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: item.isVideo
                ? Container(
                    color: ec.glassStrong,
                    child: Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: ec.textMute, size: 34),
                    ),
                  )
                : EnjoyImage(
                    item.url,
                    fit: BoxFit.cover,
                    errorWidget:
                        Icon(Icons.broken_image_rounded, color: ec.textMute),
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
              decoration:
                  const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          if (item.isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Video · fondo',
                    style: TextStyle(color: Colors.white, fontSize: 8)),
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
                  _miniBtn(Icons.chevron_left_rounded, onMoveLeft,
                      enabled: index > 0),
                  const SizedBox(width: 3),
                  _miniBtn(Icons.chevron_right_rounded, onMoveRight,
                      enabled: index < total - 1),
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
  const _AddMediaButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: ec.orange.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ec.orangeSoft, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: EnjoyTheme.body(
                    size: 11, weight: FontWeight.w600, color: ec.orangeSoft)),
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

  Widget _miniBtn(BuildContext context, IconData icon, VoidCallback onTap,
      {bool enabled = true}) {
    final ec = context.ec;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: ec.glassStrong,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ec.stroke),
        ),
        child: Icon(icon, size: 15, color: enabled ? ec.textSoft : ec.textMute),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      padding: const EdgeInsets.all(10),
      radius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto (toca para cambiar)
          GestureDetector(
            onTap: canEdit ? onChangePhoto : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EnjoyImage(
                      producto.url,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: ec.glassStrong,
                        child: Icon(Icons.broken_image_rounded,
                            color: ec.textMute),
                      ),
                    ),
                    if (canEdit)
                      Positioned(
                        bottom: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              gradient: ec.accentGradient,
                              borderRadius: BorderRadius.circular(6)),
                          child: Icon(Icons.camera_alt_rounded,
                              size: 11, color: ec.onAccent),
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
                  style: EnjoyTheme.heading(size: 14, color: ec.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((producto.descripcion ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    producto.descripcion!,
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniBtn(context, Icons.edit_rounded, onEditText),
                      const SizedBox(width: 6),
                      _miniBtn(context, Icons.keyboard_arrow_up_rounded, onMoveUp,
                          enabled: index > 0),
                      const SizedBox(width: 6),
                      _miniBtn(
                          context, Icons.keyboard_arrow_down_rounded, onMoveDown,
                          enabled: index < total - 1),
                      const Spacer(),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: ec.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: ec.red.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 15, color: ec.red),
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
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
            child: Row(children: [
              Icon(icon, size: 16, color: ec.orangeSoft),
              const SizedBox(width: 8),
              Text(title, style: EnjoyTheme.heading(size: 13, color: ec.text)),
            ]),
          ),
          EnjoyDivider(height: 1),
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
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.onCopy});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ec.textMute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: EnjoyTheme.body(
                        size: 11, weight: FontWeight.w500, color: ec.textMute)),
                const SizedBox(height: 2),
                Text(value, style: EnjoyTheme.heading(size: 14, color: ec.text)),
              ],
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: ec.glassStrong,
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.copy_rounded, size: 14, color: ec.textSoft),
              ),
            ),
        ],
      ),
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
    final ec = context.ec;
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(widget.emptyText,
            style: EnjoyTheme.body(size: 13, color: ec.textMute)),
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? widget.color.withValues(alpha: 0.16)
                : ec.glassStrong,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: sel ? widget.color.withValues(alpha: 0.45) : ec.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.label,
                  style: EnjoyTheme.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: sel ? widget.color : ec.textSoft)),
              if (removable) ...[
                const SizedBox(width: 5),
                Icon(Icons.close_rounded, size: 14, color: widget.color),
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
            style: EnjoyTheme.body(size: 14, color: ec.text),
            decoration: InputDecoration(
              hintText: '${widget.hint}  (${widget.selected.length} sel.)',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
            ),
          ),
          // Seleccionadas (resumen)
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  selectedItems.map((i) => chip(i, removable: true)).toList(),
            ),
            EnjoyDivider(height: 18),
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
                          style: EnjoyTheme.body(size: 12, color: ec.textMute)),
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
