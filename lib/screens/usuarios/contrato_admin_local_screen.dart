import 'dart:convert';
import 'dart:io';

import 'package:enjoy/services/contrato_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla bloqueante que el admin-local NUEVO ve la primera vez que entra.
/// Form de datos faltantes + scroll obligatorio del contrato + foto de cédula
/// + checkbox de aceptación. Al firmar, el back genera el PDF y queda
/// almacenado en S3.
class ContratoAdminLocalScreen extends StatefulWidget {
  /// El home se cierra al firmar y se reabre desde cero para refrescar
  /// cualquier estado dependiente.
  final VoidCallback onFirmado;

  const ContratoAdminLocalScreen({super.key, required this.onFirmado});

  @override
  State<ContratoAdminLocalScreen> createState() =>
      _ContratoAdminLocalScreenState();
}

class _ContratoAdminLocalScreenState extends State<ContratoAdminLocalScreen> {
  final _svc = ContratoService();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  bool _cargando = true;
  bool _guardando = false;
  ContratoEstado? _estado;

  // Datos del local
  final _rucCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _repreCtrl = TextEditingController();
  final _cedulaRepreCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  String _estadoCivil = 'soltero';

  // Cédula
  File? _cedulaFile;
  String? _cedulaBase64;

  // Estado de UI
  bool _scrollCompleto = false;
  bool _aceptaTerminos = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _repreCtrl.dispose();
    _cedulaRepreCtrl.dispose();
    _celularCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final e = await _svc.miEstado();
      if (!mounted) return;
      setState(() {
        _estado = e;
        _rucCtrl.text = (e.datosLocal['ruc'] ?? '').toString();
        _direccionCtrl.text = (e.datosLocal['direccion'] ?? '').toString();
        _repreCtrl.text =
            (e.datosLocal['representanteLegal'] ?? '').toString();
        _cedulaRepreCtrl.text =
            (e.datosLocal['cedulaRepresentante'] ?? '').toString();
        _celularCtrl.text = (e.datosLocal['celular'] ?? '').toString();
        final ec = (e.datosLocal['estadoCivilRepresentante'] ?? '').toString();
        if (ec.isNotEmpty) _estadoCivil = ec;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (!_scrollCompleto && pos.pixels >= pos.maxScrollExtent - 16) {
      setState(() => _scrollCompleto = true);
    }
  }

  Future<void> _elegirCedula() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('La foto es muy grande. Tomala con menor resolución.');
      return;
    }
    setState(() {
      _cedulaFile = file;
      _cedulaBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _elegirCedulaGaleria() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('La foto es muy grande.');
      return;
    }
    setState(() {
      _cedulaFile = file;
      _cedulaBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  bool get _puedeFirmar =>
      _scrollCompleto &&
      _aceptaTerminos &&
      _cedulaBase64 != null &&
      _rucCtrl.text.trim().isNotEmpty &&
      _direccionCtrl.text.trim().isNotEmpty &&
      _repreCtrl.text.trim().isNotEmpty &&
      _cedulaRepreCtrl.text.trim().isNotEmpty &&
      _celularCtrl.text.trim().isNotEmpty;

  Future<void> _firmar() async {
    if (!_puedeFirmar) {
      _toast(
        'Completá los datos, leé el contrato hasta el final, subí tu cédula y aceptá los términos.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await _svc.aceptar(
        cedulaBase64: _cedulaBase64!,
        datosLocal: {
          'ruc': _rucCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'representanteLegal': _repreCtrl.text.trim(),
          'cedulaRepresentante': _cedulaRepreCtrl.text.trim(),
          'estadoCivilRepresentante': _estadoCivil,
          'celular': _celularCtrl.text.trim(),
        },
        aceptaTerminos: true,
      );
      if (!mounted) return;
      _toast('¡Contrato firmado!');
      widget.onFirmado();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _toast('No pudimos guardar tu contrato. Reintentá.');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return PopScope(
      canPop: false, // no se puede volver atrás
      child: EnjoyScaffold(
        appBar: const EnjoyAppBar(title: 'Contrato de cooperación'),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: ec.orange))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datos del local
                    _sectionTitle(ec, 'Datos del local'),
                    _label('RUC del local *'),
                    _input(_rucCtrl, hint: '1801234567001'),
                    _label('Dirección del local *'),
                    _input(_direccionCtrl, hint: 'Calle, número, sector'),
                    _label('Representante legal *'),
                    _input(_repreCtrl, hint: 'Nombres y apellidos'),
                    _label('Cédula del representante *'),
                    _input(_cedulaRepreCtrl, hint: '1801234567'),
                    _label('Estado civil'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: ec.glass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ec.stroke),
                      ),
                      child: DropdownButton<String>(
                        value: _estadoCivil,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: ec.surfaceTop,
                        items: const [
                          DropdownMenuItem(value: 'soltero', child: Text('Soltero/a')),
                          DropdownMenuItem(value: 'casado', child: Text('Casado/a')),
                          DropdownMenuItem(value: 'divorciado', child: Text('Divorciado/a')),
                          DropdownMenuItem(value: 'viudo', child: Text('Viudo/a')),
                          DropdownMenuItem(value: 'union_libre', child: Text('Unión libre')),
                        ],
                        onChanged: (v) => setState(() => _estadoCivil = v ?? 'soltero'),
                      ),
                    ),
                    _label('Celular *'),
                    _input(_celularCtrl, hint: '0991234567'),

                    const SizedBox(height: 18),
                    _sectionTitle(ec, 'Leé el contrato completo'),
                    if (!_scrollCompleto)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '↓ Desplazá hasta el final para poder aceptar.',
                          style: EnjoyTheme.body(size: 12, color: ec.orange),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: ec.green, size: 16),
                            const SizedBox(width: 6),
                            Text('Leído completo',
                                style: EnjoyTheme.body(size: 12, color: ec.green)),
                          ],
                        ),
                      ),
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: ec.glass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ec.stroke),
                      ),
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          child: _contratoTexto(ec),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    _sectionTitle(ec, 'Foto de tu cédula *'),
                    if (_cedulaFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _cedulaFile!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _cedulaFile = null;
                                _cedulaBase64 = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: EnjoyButton(
                              label: 'Cámara',
                              icon: Icons.photo_camera_outlined,
                              onPressed: _elegirCedula,
                              variant: EnjoyButtonVariant.ghost,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: EnjoyButton(
                              label: 'Galería',
                              icon: Icons.photo_outlined,
                              onPressed: _elegirCedulaGaleria,
                              variant: EnjoyButtonVariant.ghost,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _aceptaTerminos,
                          onChanged: _scrollCompleto
                              ? (v) =>
                                  setState(() => _aceptaTerminos = v ?? false)
                              : null,
                          activeColor: ec.orange,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Acepto los términos y condiciones del contrato de cooperación con Club Enjoy. Confirmo que leí el contrato completo y que los datos son verídicos.',
                              style: EnjoyTheme.body(
                                  size: 13, color: ec.text, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EnjoyButton(
                        label: _guardando ? 'Firmando…' : 'Firmar y continuar',
                        icon: Icons.check_circle_outline,
                        onPressed: _guardando || !_puedeFirmar ? null : _firmar,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(EnjoyColors ec, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          t,
          style: EnjoyTheme.heading(
            size: 16,
            color: ec.text,
            weight: FontWeight.w800,
          ),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          t,
          style: EnjoyTheme.body(
            size: 12.5,
            color: context.ec.textSoft,
            weight: FontWeight.w600,
          ),
        ),
      );

  Widget _input(TextEditingController ctrl, {String? hint}) {
    final ec = context.ec;
    return TextField(
      controller: ctrl,
      style: EnjoyTheme.body(color: ec.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: EnjoyTheme.body(color: ec.textMute),
        filled: true,
        fillColor: ec.glass,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ec.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ec.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ec.orange),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _contratoTexto(EnjoyColors ec) {
    final nombre = (_estado?.datosLocal['nombreLocal'] ?? '__________').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTRATO DE COOPERACIÓN ENTRE MARCAS',
          textAlign: TextAlign.center,
          style: EnjoyTheme.heading(
            size: 14,
            weight: FontWeight.w800,
            color: ec.text,
          ),
        ),
        const SizedBox(height: 10),
        _p('En la ciudad de Ambato, comparecen CLUB ENJOY (CONTRATADO) y $nombre (CONTRATANTE), libres y capaces para contratar.'),
        _h('CLÁUSULA PRIMERA: ANTECEDENTES'),
        _p('1. CLUB ENJOY es una compañía ecuatoriana ubicada en Cevallos, Tungurahua.'),
        _p('2. ENJOY es una plataforma de beneficios mediante promociones en consumo, operada vía app digital.'),
        _p('3. Club Enjoy distribuye membresías temporales e impulsa las ventas de locales afiliados.'),
        _h('CLÁUSULA SEGUNDA: OBJETO'),
        _p('Cooperación entre marcas, incorporando al local "$nombre" a la red de afiliados. No involucra relación laboral.'),
        _h('CLÁUSULA TERCERA: OBLIGACIONES DEL LOCAL'),
        _p('a) Honrar los Beneficios ofrecidos en la app a los Socios.'),
        _p('b) Mantenerlos activos durante todo el horario de atención.'),
        _p('c) Validar cada Beneficio solo vía escaneo de QR.'),
        _p('d) Designar y capacitar al personal responsable.'),
        _p('e) Entregar información veraz del establecimiento.'),
        _p('f) Notificar con anticipación cambios en horarios, ubicación o cierre.'),
        _p('g) Cumplir con la normativa aplicable.'),
        _p('h) Atender los reclamos de los Socios.'),
        _p('i) Pagar a Club Enjoy el valor económico pactado.'),
        _p('j) Abstenerse de usar marcas de Club Enjoy fuera de lo autorizado.'),
        _h('CLÁUSULA CUARTA: OBLIGACIONES DE CLUB ENJOY'),
        _p('a) Incorporar al local y difundir sus beneficios entre suscriptores.'),
        _p('b) Acceso a la plataforma y panel del afiliado.'),
        _p('c) Reportes y estadísticas de canjes.'),
        _p('d) Soporte y capacitación.'),
        _p('e) Acciones de promoción y marketing del local.'),
        _p('f) Emitir comprobante de venta por la afiliación.'),
        _p('g) Tratar los datos personales conforme a Ley.'),
        _p('h) Notificar suspensiones o cambios de la plataforma.'),
        _h('CLÁUSULA QUINTA: EXCLUSIVIDAD'),
        _p('El local no trabajará con otro aplicativo móvil de promociones similares.'),
        _h('CLÁUSULA SEXTA: CONFIDENCIALIDAD'),
        _p('Las partes mantienen confidencialidad hasta 1 año después del contrato.'),
        _h('CLÁUSULA SÉPTIMA: PROTECCIÓN DE DATOS'),
        _p('Conforme a la Ley Orgánica de Protección de Datos del Ecuador.'),
        _h('CLÁUSULA OCTAVA: RESPONSABILIDAD'),
        _p('Club Enjoy no responde por calidad de productos o servicios del local. El local es responsable de la higiene y presentación.'),
        _h('CLÁUSULA NOVENA: DISPOSICIONES GENERALES'),
        _p('Toda modificación debe ser escrita y aceptada por ambas partes. (Art. 1561 del Código Civil.)'),
        _h('CLÁUSULA DÉCIMA: DURACIÓN Y RENOVACIÓN'),
        _p('Vigencia de un año, renovable por mutuo acuerdo.'),
        _h('CLÁUSULA DÉCIMA PRIMERA: TERMINACIÓN'),
        _p('Causas previstas en el Código Civil o por acuerdo escrito.'),
        _h('CLÁUSULA DÉCIMA SEGUNDA: CLÁUSULA PENAL'),
        _p('Multa económica por incumplimiento, pagadera de manera inmediata.'),
        _h('CLÁUSULA DÉCIMA TERCERA: MEDIACIÓN'),
        _p('Centro de mediación y arbitraje de Ambato.'),
        _h('CLÁUSULA DÉCIMA CUARTA: JURISDICCIÓN'),
        _p('Jueces competentes de Ambato, provincia de Tungurahua.'),
        const SizedBox(height: 10),
        Text(
          'Las partes aceptan todas las cláusulas del presente instrumento.',
          style: EnjoyTheme.body(
            size: 12.5,
            color: ec.text,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          t,
          style: EnjoyTheme.heading(
            size: 12.5,
            weight: FontWeight.w800,
            color: context.ec.text,
          ),
        ),
      );

  Widget _p(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: EnjoyTheme.body(
            size: 12.5,
            color: context.ec.textSoft,
            height: 1.5,
          ),
        ),
      );
}
