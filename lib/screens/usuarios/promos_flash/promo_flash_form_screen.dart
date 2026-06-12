import 'dart:convert';

import 'package:enjoy/services/promociones_flash_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/utils/image_compress.dart';
import 'package:enjoy/utils/image_pick.dart';
import 'package:flutter/material.dart';

/// Crear / editar una promoción flash.
class PromoFlashFormScreen extends StatefulWidget {
  final Map<String, dynamic>? promo; // null = crear

  const PromoFlashFormScreen({super.key, this.promo});

  @override
  State<PromoFlashFormScreen> createState() => _PromoFlashFormScreenState();
}

class _PromoFlashFormScreenState extends State<PromoFlashFormScreen> {
  final _svc = PromocionesFlashService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _etiqueta;
  late final TextEditingController _cupos;
  late final TextEditingController _limite;

  String _tipo = 'anuncio';
  DateTime? _inicia; // inicio de vigencia (permite programar a futuro)
  DateTime? _vence; // fin de vigencia
  bool _canjeable = false;
  bool _cuposLimitados = false;

  // Imagen: dataUrl nuevo (si el usuario seleccionó) o url existente.
  String? _imagenNueva; // data URL comprimido
  String? _imagenUrlExistente;
  bool _comprimiendo = false;
  int? _kbComprimido;

  bool _saving = false;

  bool get _isEdit => widget.promo != null;

  static const _tipos = [
    ('anuncio', 'Anuncio', Icons.campaign_outlined),
    ('nuevo_producto', 'Nuevo producto', Icons.restaurant_menu_outlined),
    ('descuento', 'Descuento', Icons.percent_rounded),
    ('evento', 'Evento', Icons.celebration_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.promo;
    _titulo = TextEditingController(text: (p?['titulo'] ?? '').toString());
    _descripcion =
        TextEditingController(text: (p?['descripcion'] ?? '').toString());
    _etiqueta = TextEditingController(text: (p?['etiqueta'] ?? '').toString());
    _cupos = TextEditingController(
        text: (p?['cupos'] != null) ? p!['cupos'].toString() : '');
    _limite = TextEditingController(
        text: (p?['limitePorCliente'] ?? 1).toString());
    _tipo = (p?['tipo'] ?? 'anuncio').toString();
    _canjeable = p?['canjeable'] == true;
    _cuposLimitados = p?['cupos'] != null;
    _imagenUrlExistente = p?['imagenUrl']?.toString();

    // Vigencia: precarga (edición) o defaults (crear: hoy → +3 días).
    _inicia = p?['inicia'] != null
        ? DateTime.tryParse(p!['inicia'].toString())?.toLocal()
        : null;
    _vence = p?['vence'] != null
        ? DateTime.tryParse(p!['vence'].toString())?.toLocal()
        : null;
    final hoy = DateTime.now();
    _inicia ??= DateTime(hoy.year, hoy.month, hoy.day);
    _vence ??= _inicia!.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _etiqueta.dispose();
    _cupos.dispose();
    _limite.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    setState(() => _comprimiendo = true);
    try {
      final dataUrl = await pickCropAndCompress(targetKB: 900);
      if (dataUrl == null) {
        if (mounted) setState(() => _comprimiendo = false);
        return;
      }
      final bytes = bytesFromDataUrl(dataUrl);
      if (!mounted) return;
      setState(() {
        _imagenNueva = dataUrl;
        _kbComprimido = bytes != null ? (bytes.length / 1024).round() : null;
        _comprimiendo = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _comprimiendo = false);
        _snack('No se pudo procesar la imagen');
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenNueva == null && _imagenUrlExistente == null) {
      _snack('Agrega una imagen para la promoción');
      return;
    }
    if (_vence!.isBefore(_inicia!) || _vence!.isAtSameMomentAs(_inicia!)) {
      _snack('La fecha de fin debe ser posterior a la de inicio');
      return;
    }
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'tipo': _tipo,
      'etiqueta': _etiqueta.text.trim().isEmpty ? null : _etiqueta.text.trim(),
      'inicia': _inicia!.toUtc().toIso8601String(),
      'vence': _vence!.toUtc().toIso8601String(),
      'canjeable': _canjeable,
    };
    if (_imagenNueva != null) data['imagenBase64'] = _imagenNueva;
    if (_canjeable) {
      data['limitePorCliente'] = int.tryParse(_limite.text.trim()) ?? 1;
      data['cupos'] =
          _cuposLimitados ? int.tryParse(_cupos.text.trim()) : null;
    }

    try {
      if (_isEdit) {
        await _svc.actualizar(widget.promo!['_id'].toString(), data);
      } else {
        await _svc.crear(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(_msgError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _msgError(Object e) {
    final s = e.toString();
    // Intentar extraer el message del backend si viene en el DioException.
    final m = RegExp(r'"message":\s*"([^"]+)"').firstMatch(s);
    if (m != null) return m.group(1)!;
    return 'No se pudo guardar la promoción. Intenta de nuevo.';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.ec.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final tieneImagen = _imagenNueva != null || _imagenUrlExistente != null;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
        title: _isEdit ? 'Editar promoción' : 'Nueva promoción flash',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            // ── Imagen ──
            FieldLabel('Imagen'),
            GestureDetector(
              onTap: _comprimiendo ? null : _seleccionarImagen,
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: ec.glass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ec.stroke),
                ),
                clipBehavior: Clip.antiAlias,
                child: _comprimiendo
                    ? Center(child: CircularProgressIndicator(color: ec.orange))
                    : tieneImagen
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_imagenNueva != null)
                                Image.memory(
                                  base64Decode(_imagenNueva!.split(',').last),
                                  fit: BoxFit.cover,
                                )
                              else
                                EnjoyImage(_imagenUrlExistente!,
                                    fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _kbComprimido != null
                                        ? 'Cambiar · $_kbComprimido KB'
                                        : 'Cambiar imagen',
                                    style: EnjoyTheme.body(
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 36, color: ec.orangeSoft),
                              const SizedBox(height: 8),
                              Text('Toca para subir una imagen',
                                  style: EnjoyTheme.body(
                                      size: 13, color: ec.textMute)),
                              const SizedBox(height: 2),
                              Text('Se optimiza a < 1 MB automáticamente',
                                  style: EnjoyTheme.body(
                                      size: 11, color: ec.textMute)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Tipo ──
            FieldLabel('Tipo de promoción'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tipos.map((t) {
                final sel = _tipo == t.$1;
                return Pill(
                  t.$2,
                  icon: t.$3,
                  variant: sel ? PillVariant.orange : PillVariant.glass,
                  onTap: () => setState(() => _tipo = t.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Datos ──
            FieldLabel('Información'),
            _field(_titulo, 'Título', Icons.title_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 12),
            _field(_descripcion, 'Descripción', Icons.notes_rounded,
                maxLines: 3),
            const SizedBox(height: 12),
            _field(_etiqueta, 'Etiqueta corta (ej. NUEVO, 2x1)',
                Icons.sell_outlined),
            const SizedBox(height: 20),

            // ── Vigencia (rango de fechas: permite programar a futuro) ──
            FieldLabel('Vigencia'),
            GlassCard(
              onTap: _pickRango,
              child: Row(
                children: [
                  const IconBox(Icons.date_range_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtFecha(_inicia)}  →  ${_fmtFecha(_vence)}',
                          style: EnjoyTheme.heading(size: 14, color: ec.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _inicia != null && _inicia!.isAfter(DateTime.now())
                              ? 'Programada · empieza ${_fmtFecha(_inicia)}'
                              : 'Toca para elegir inicio y fin',
                          style: EnjoyTheme.body(size: 12, color: ec.textMute),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar_outlined, color: ec.orangeSoft, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Puedes programarla a futuro. Duración máxima 30 días.',
              style: EnjoyTheme.body(size: 11, color: ec.textMute),
            ),
            const SizedBox(height: 20),

            // ── Canje ──
            FieldLabel('Canje'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Canjeable en el local',
                            style: EnjoyTheme.heading(
                                size: 14,
                                weight: FontWeight.w600,
                                color: ec.text)),
                        const SizedBox(height: 2),
                        Text(
                          _canjeable
                              ? 'El cliente muestra un QR y el staff lo valida'
                              : 'Solo anuncio (sin canje)',
                          style: EnjoyTheme.body(size: 12, color: ec.textMute),
                        ),
                      ],
                    ),
                  ),
                  EnjoyToggle(
                    value: _canjeable,
                    onChanged: (v) => setState(() => _canjeable = v),
                  ),
                ],
              ),
            ),

            if (_canjeable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(_limite, 'Máx. por cliente',
                        Icons.person_outline_rounded,
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Cupos limitados',
                                style: EnjoyTheme.body(
                                    size: 12, color: ec.textMute)),
                          ),
                          EnjoyToggle(
                            value: _cuposLimitados,
                            onChanged: (v) =>
                                setState(() => _cuposLimitados = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_cuposLimitados) ...[
                const SizedBox(height: 12),
                _field(_cupos, 'Cupos totales', Icons.confirmation_num_outlined,
                    keyboardType: TextInputType.number),
              ],
            ],

            const SizedBox(height: 28),
            EnjoyButton(
              label: _isEdit ? 'Guardar cambios' : 'Publicar promoción',
              loading: _saving,
              onPressed: _saving ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickRango() async {
    final hoy = DateTime.now();
    final inicial = DateTimeRange(
      start: _inicia ?? DateTime(hoy.year, hoy.month, hoy.day),
      end: _vence ?? DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 3)),
    );
    final rango = await showDateRangePicker(
      context: context,
      initialDateRange: inicial,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 120)),
      helpText: 'Vigencia de la promoción',
      saveText: 'Listo',
    );
    if (rango == null) return;
    var fin = rango.end;
    // Tope de duración: 30 días.
    if (fin.difference(rango.start).inDays > 30) {
      fin = rango.start.add(const Duration(days: 30));
      _snack('La duración máxima es 30 días; se ajustó el fin.');
    }
    setState(() {
      _inicia = rango.start;
      // Fin al final del día para incluir esa fecha completa.
      _vence = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
    });
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final ec = context.ec;
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      cursorColor: ec.orange,
      style: EnjoyTheme.body(size: 14, color: ec.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: ec.orangeSoft, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
